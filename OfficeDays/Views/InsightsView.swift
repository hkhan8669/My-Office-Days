import SwiftUI

struct InsightsView: View {
    let viewModel: AttendanceViewModel

    @State private var filterType: DayTypeFilter = .all
    @State private var showShareSheet = false
    @State private var csvContent = ""

    private var quarter: QuarterHelper.QuarterInfo {
        QuarterHelper.quarterInfo(for: Date())
    }

    /// All attendance days across current year and previous year for the full activity log.
    private var allDays: [AttendanceDay] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var days: [AttendanceDay] = []
        for year in (currentYear - 1)...currentYear {
            for q in QuarterHelper.allQuarters(for: year) {
                days.append(contentsOf: viewModel.allDays(in: q))
            }
        }
        // Deduplicate by dateKey in case of overlap
        var seen = Set<String>()
        return days.filter { seen.insert($0.dateKey).inserted }
    }

    private var ledgerEntries: [AttendanceDay] {
        let days = allDays.sorted { $0.date > $1.date }

        switch filterType {
        case .all:
            return days
        case .office:
            return days.filter { $0.dayType == .office || $0.dayType == .freeDay || $0.dayType == .travel }
        case .remote:
            return days.filter { $0.dayType == .remote }
        case .vacation:
            return days.filter { $0.dayType == .vacation }
        case .holiday:
            return days.filter { $0.dayType == .holiday }
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let officeDays = allDays
            .filter { $0.dayType.countsTowardTarget }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)

        var streak = 0
        var checkDate = today

        // Walk backwards through weekdays
        while true {
            let weekday = calendar.component(.weekday, from: checkDate)
            // Skip weekends
            if weekday == 1 || weekday == 7 {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                continue
            }
            if officeDays.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    private var mostFrequentLocation: String {
        let officeNames = allDays
            .compactMap { $0.officeName }
            .filter { !$0.isEmpty }

        guard !officeNames.isEmpty else { return "---" }

        let counts = Dictionary(grouping: officeNames, by: { $0 })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "---"
    }

    private var nextPlannedDay: AttendanceDay? {
        let today = Calendar.current.startOfDay(for: Date())
        return allDays
            .filter { $0.dayType == .planned && Calendar.current.startOfDay(for: $0.date) > today }
            .sorted { $0.date < $1.date }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    filterBar
                    ledgerSection
                    statCardsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.surfaceGradient.ignoresSafeArea())
            .navigationTitle("Activity Log")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: csvContent)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT HISTORY")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.5)

            HStack(alignment: .bottom) {
                Text("\(ledgerEntries.count) entries")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Button {
                    let year = Calendar.current.component(.year, from: Date())
                    csvContent = viewModel.exportCSV(year: year)
                    showShareSheet = true
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Theme.accent.opacity(0.1))
                                .overlay(Capsule().stroke(Theme.accent.opacity(0.2), lineWidth: 1))
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DayTypeFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            filterType = filter
                        }
                    } label: {
                        Text(filter.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(filterType == filter ? .white : Theme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(filterType == filter ? Theme.primaryContainer : Theme.surfaceContainer)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Ledger Table

    private var ledgerSection: some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                Text("DATE")
                    .frame(width: 90, alignment: .leading)
                Text("TIME")
                    .frame(width: 64, alignment: .leading)
                Text("LOCATION")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("STATUS")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.textTertiary)
            .tracking(1.2)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surfaceContainerHighest.opacity(0.7))

            if ledgerEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.textTertiary)
                    Text("No entries found")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(ledgerEntries.prefix(50).enumerated()), id: \.element.dateKey) { index, day in
                    ledgerRow(day: day, isEven: index % 2 == 0)
                }
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private func ledgerRow(day: AttendanceDay, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            // Date column
            VStack(alignment: .leading, spacing: 1) {
                Text(DateHelper.shortDateString(for: day.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                Text(DateHelper.weekdayShort(for: day.date))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(width: 90, alignment: .leading)

            // Time column - auto-log time chip
            Group {
                if day.isAutoLogged {
                    Text(timeString(from: day.createdAt))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.accent.opacity(0.08))
                        )
                } else {
                    Text("--:--")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 64, alignment: .leading)

            // Location column
            HStack(spacing: 4) {
                if let officeName = day.officeName, !officeName.isEmpty {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                    Text(officeName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else if let holidayName = day.holidayName, !holidayName.isEmpty {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.holiday)
                    Text(holidayName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(day.dayType.label)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status badge
            statusBadge(for: day)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isEven ? Theme.cardBackground : Theme.surfaceContainerLow.opacity(0.5))
        .accessibilityElement(children: .combine)
    }

    private func statusBadge(for day: AttendanceDay) -> some View {
        let color = Theme.color(for: day.dayType)
        return HStack(spacing: 3) {
            if day.isAutoLogged {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 8))
            }
            Text(day.dayType.shortLabel)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Stat Cards

    private var statCardsSection: some View {
        VStack(spacing: 12) {
            // Current Streak - full width, dark blue
            streakCard

            HStack(spacing: 12) {
                frequentLocationCard
                nextPlannedCard
            }
        }
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT STREAK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(1.3)

                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("consecutive office days")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.primaryContainer,
                            Theme.primary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current streak, \(currentStreak) consecutive office days")
    }

    private var frequentLocationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP LOCATION")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.3)

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text(mostFrequentLocation)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Text("All time")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
        .overlay(
            HStack {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Most frequent location, \(mostFrequentLocation)")
    }

    private var nextPlannedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT PLANNED")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.3)

            if let nextDay = nextPlannedDay {
                Text(DateHelper.shortDateString(for: nextDay.date))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)

                Text(DateHelper.weekdayShort(for: nextDay.date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("None")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)

                Text("No planned days")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 120)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
                    .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)

                // Subtle calendar pattern overlay
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.planned.opacity(0.04))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            nextPlannedDay.map { "Next planned day, \(DateHelper.fullDateString(for: $0.date))" }
                ?? "No upcoming planned days"
        )
    }

    // MARK: - Helpers

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Filter Enum

private enum DayTypeFilter: CaseIterable {
    case all, office, remote, vacation, holiday

    var label: String {
        switch self {
        case .all: "All"
        case .office: "Office"
        case .remote: "Remote"
        case .vacation: "Vacation"
        case .holiday: "Holiday"
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfficeDays_Export.csv")
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
