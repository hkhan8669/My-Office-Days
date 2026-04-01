import SwiftUI
import SwiftData

struct InsightsView: View {
    let viewModel: AttendanceViewModel

    @Query(sort: \GeoLog.timestamp, order: .reverse)
    private var geoLogs: [GeoLog]

    @State private var showShareSheet = false
    @State private var csvContent = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    geoLogSection
                    statCardsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.surfaceGradient.ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: csvContent)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GEOFENCE EVENTS")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.5)

            HStack(alignment: .bottom) {
                Text("\(geoLogs.count) events")
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

    // MARK: - Geo Log Table

    private var geoLogSection: some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                Text("TIME")
                    .frame(width: 90, alignment: .leading)
                Text("LOCATION")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("EVENT")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.textTertiary)
            .tracking(1.2)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surfaceContainerHighest.opacity(0.7))

            if geoLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.textTertiary)
                    Text("No geofence events yet")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Events will appear here when you enter or leave a tracked location.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(geoLogs.enumerated()), id: \.offset) { index, log in
                    geoLogRow(log: log, isEven: index % 2 == 0)
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

    private func geoLogRow(log: GeoLog, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            // Time column – date + time
            VStack(alignment: .leading, spacing: 1) {
                Text(dateString(from: log.timestamp))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                Text(timeString(from: log.timestamp))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.primary)
            }
            .frame(width: 90, alignment: .leading)

            // Location column
            HStack(spacing: 5) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(eventColor(for: log.eventType))
                Text(log.locationName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Event badge
            eventBadge(for: log.eventType)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isEven ? Theme.cardBackground : Theme.surfaceContainerLow.opacity(0.5))
        .accessibilityElement(children: .combine)
    }

    private func eventBadge(for eventType: GeoLog.EventType) -> some View {
        let color = eventColor(for: eventType)
        return HStack(spacing: 3) {
            Image(systemName: eventIcon(for: eventType))
                .font(.system(size: 9))
            Text(eventLabel(for: eventType))
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }

    private func eventColor(for eventType: GeoLog.EventType) -> Color {
        switch eventType {
        case .entry: return Theme.vacation    // Green
        case .exit: return Theme.behind       // Red
        case .autoLogged: return Theme.onTrack // Blue
        }
    }

    private func eventIcon(for eventType: GeoLog.EventType) -> String {
        switch eventType {
        case .entry: return "arrow.down.circle.fill"
        case .exit: return "arrow.up.circle.fill"
        case .autoLogged: return "checkmark.shield.fill"
        }
    }

    private func eventLabel(for eventType: GeoLog.EventType) -> String {
        switch eventType {
        case .entry: return "ENTERED"
        case .exit: return "EXITED"
        case .autoLogged: return "LOGGED"
        }
    }

    // MARK: - Stat Cards

    private var statCardsSection: some View {
        VStack(spacing: 12) {
            streakCard

            HStack(spacing: 12) {
                frequentLocationCard
                totalEventsCard
            }
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let allDays = loadAllDays()
        let officeDays = allDays
            .filter { $0.dayType.countsTowardTarget }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)

        var streak = 0
        var checkDate = today

        while true {
            if !AppPreferences.isWorkDay(checkDate) {
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

    private func loadAllDays() -> [AttendanceDay] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var days: [AttendanceDay] = []
        for year in (currentYear - 2)...currentYear {
            let yearPeriod = PeriodHelper.yearInfo(
                for: Calendar.current.date(from: DateComponents(year: year, month: 6, day: 15))!
            )
            days.append(contentsOf: viewModel.allDays(in: yearPeriod))
        }
        var seen = Set<String>()
        return days.filter { seen.insert($0.dateKey).inserted }
    }

    private var mostFrequentLocation: String {
        let names = geoLogs
            .filter { $0.eventType == .autoLogged }
            .map(\.locationName)
        guard !names.isEmpty else { return "---" }
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? "---"
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

                Text(currentStreak > 0 ? "consecutive office days" : "Start your streak!")
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

            Text("Auto-logged")
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

    private var totalEventsCard: some View {
        let entryCount = geoLogs.filter { $0.eventType == .entry }.count
        let exitCount = geoLogs.filter { $0.eventType == .exit }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("EVENTS TODAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.3)

            let todayLogs = geoLogs.filter {
                Calendar.current.isDateInToday($0.timestamp)
            }

            Text("\(todayLogs.count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Text("\(entryCount) entries, \(exitCount) exits")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)

            Spacer(minLength: 0)
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
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total events: \(entryCount) entries, \(exitCount) exits")
    }

    // MARK: - Helpers

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfficeDays_Export.csv")
        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            return UIActivityViewController(activityItems: [text], applicationActivities: nil)
        }
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
