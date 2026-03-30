import SwiftUI

struct DashboardView: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService

    @State private var animateProgress = false
    @State private var appeared = false
    @State private var showDayDetail = false

    // MARK: - Computed Properties

    private var quarter: QuarterHelper.QuarterInfo {
        QuarterHelper.quarterInfo(for: Date())
    }

    private var snap: AttendanceViewModel.QuarterSnapshot {
        viewModel.currentQuarterSnapshot
    }

    private var creditedDays: Int {
        snap.targetDays
    }

    private var target: Int {
        QuarterHelper.targetDaysPerQuarter
    }

    private var daysRemaining: Int {
        max(0, target - creditedDays)
    }

    private var weeksRemaining: Int {
        QuarterHelper.weeksRemaining(in: quarter, from: Date())
    }

    private var weekdaysRemaining: Int {
        QuarterHelper.weekdaysRemaining(in: quarter, from: Date())
    }

    private var pace: QuarterHelper.PaceStatus {
        QuarterHelper.paceStatus(officeDays: creditedDays, in: quarter, asOf: Date())
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(creditedDays) / Double(target))
    }

    private var projectedProgress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(creditedDays + snap.plannedDays) / Double(target))
    }

    private var todayAttendance: AttendanceDay? {
        viewModel.attendanceDay(for: Date())
    }

    private var paceColor: Color {
        switch pace {
        case .onTrack: return Theme.accent
        case .ahead: return Theme.vacation
        case .behind: return Theme.behind
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    progressRingSection
                    currentStatusSection
                    statBlocks
                    recentActivitySection
                    infoCardsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.surface.ignoresSafeArea())
            .refreshable {
                viewModel.refreshSnapshot()
                geofenceService.handleAppDidBecomeActive()
            }
            .navigationTitle("My Office Days")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.4)) {
                animateProgress = true
            }
        }
        .sheet(isPresented: $showDayDetail, onDismiss: {
            viewModel.refreshSnapshot()
        }) {
            DayDetailView(viewModel: viewModel, date: Date())
        }
    }

    // MARK: - Progress Ring

    private var progressRingSection: some View {
        VStack(spacing: 8) {
            Text("QUARTER PROGRESS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.5)

            ZStack {
                // Background track
                Circle()
                    .stroke(Theme.surfaceContainer, lineWidth: 18)
                    .frame(width: 200, height: 200)

                // Projected (planned) arc
                if snap.plannedDays > 0 {
                    Circle()
                        .trim(from: 0, to: animateProgress ? projectedProgress : 0)
                        .stroke(
                            Theme.planned.opacity(0.35),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                }

                // Credited days arc
                Circle()
                    .trim(from: 0, to: animateProgress ? progress : 0)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.accent, Theme.primaryContainer],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 0) {
                    (Text("\(creditedDays)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    +
                    Text(" / \(target)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
                        .baselineOffset(-4))
                    .contentTransition(.numericText())

                    Text("DAYS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(2)
                        .padding(.top, 2)
                }
            }
            .padding(9)

            // Pace badge
            HStack(spacing: 5) {
                Image(systemName: pace.icon)
                    .font(.caption2.weight(.bold))
                Text(pace.label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
            }
            .foregroundStyle(paceColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(paceColor.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(paceColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.top, 4)

            NavigationLink {
                QuarterSummaryView(viewModel: viewModel)
            } label: {
                HStack(spacing: 4) {
                    Text("View Quarters")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quarter progress. \(creditedDays) of \(target) credited office days. \(daysRemaining) remaining. \(pace.label).")
    }

    // MARK: - Current Status

    private var currentStatusSection: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(Theme.outlineVariant.opacity(0.4))
                .frame(height: 1)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                Text("CURRENT STATUS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(1.5)

                Text(currentStatusText)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                if geofenceService.isMonitoring, let office = geofenceService.lastCheckedInOffice {
                    Text("Auto-detected at \(office)")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            if DateHelper.isWeekday(Date()) {
                Button {
                    showDayDetail = true
                } label: {
                    Text("Log Today's Status")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Theme.accent)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var currentStatusText: String {
        guard let day = todayAttendance else {
            return "Not Logged Today"
        }

        switch day.dayType {
        case .office:
            if let office = day.officeName, !office.isEmpty {
                return "In Office at \(office)"
            }
            return "In Office"
        case .remote:
            return "Working Remotely"
        case .holiday:
            let name = day.holidayName ?? "Holiday"
            return name
        case .vacation:
            return "On Vacation"
        case .planned:
            return "Planned Office Day"
        case .freeDay:
            return "Office Credit Day"
        case .travel:
            return "Traveling for Work"
        }
    }

    // MARK: - Stat Blocks

    private var statBlocks: some View {
        VStack(spacing: 12) {
            statBlock(
                label: "Threshold Goal",
                value: "\(daysRemaining) Days Remaining",
                description: daysRemaining > 0
                    ? "You need \(daysRemaining) more credited days to hit \(target) this quarter."
                    : "Quarterly target of \(target) days has been reached.",
                systemIcon: "arrow.triangle.2.circlepath",
                color: Theme.accent
            )

            statBlock(
                label: "Quarter Capacity",
                value: "\(weekdaysRemaining) Work Days Left",
                description: "\(weeksRemaining) weeks remaining in \(quarter.label). Plan ahead to stay on track.",
                systemIcon: "clock.badge.checkmark",
                color: Theme.primaryContainer
            )
        }
    }

    private func statBlock(
        label: String,
        value: String,
        description: String,
        systemIcon: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: systemIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(1.2)

                Text(value)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .cardStyle(cornerRadius: 16, padding: 16)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1.5)

            VStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    Text("Date")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Location")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Type")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surfaceContainerHighest.opacity(0.5))

                // Activity rows
                let recentDays = recentActivityDays
                if recentDays.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundStyle(Theme.textTertiary)
                        Text("No logged days yet this quarter")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(recentDays.enumerated()), id: \.element.dateKey) { index, day in
                        activityRow(day: day, isLast: index == recentDays.count - 1)
                    }
                }
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    private var recentActivityDays: [(dateKey: String, date: Date, dayType: DayType, officeName: String?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [(dateKey: String, date: Date, dayType: DayType, officeName: String?)] = []

        // Walk backwards from today up to 14 days to find recent logged days
        for offset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            guard weekday >= 2 && weekday <= 6 else { continue } // weekdays only
            guard date >= quarter.startDate else { break }

            if let day = viewModel.attendanceDay(for: date) {
                if day.dayType != .remote {
                    results.append((dateKey: AttendanceDay.key(for: date), date: date, dayType: day.dayType, officeName: day.officeName))
                }
            }
            if results.count >= 5 { break }
        }

        return results
    }

    private func activityRow(day: (dateKey: String, date: Date, dayType: DayType, officeName: String?), isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(day.date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(day.officeName ?? day.dayType.label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.color(for: day.dayType))
                        .frame(width: 8, height: 8)
                    Text(day.dayType.shortLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.color(for: day.dayType))
                }
                .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if !isLast {
                Divider()
                    .padding(.leading, 14)
            }
        }
    }

    // MARK: - Info Cards

    private var infoCardsSection: some View {
        let futureHolidays = viewModel.futureHolidaysInQuarter()
        let futureVacations = viewModel.futureVacationsInQuarter()
        let availableWorkdays = max(0, weekdaysRemaining - futureHolidays - futureVacations)
        let daysPerWeek = weeksRemaining > 0 ? Double(daysRemaining) / Double(weeksRemaining) : 0

        return VStack(spacing: 12) {
            // Upcoming buffer card
            infoCard(
                icon: "calendar.badge.exclamationmark",
                title: "Upcoming Buffer",
                subtitle: bufferSubtitle(
                    futureHolidays: futureHolidays,
                    futureVacations: futureVacations,
                    availableWorkdays: availableWorkdays
                ),
                color: Theme.planned
            )

            // Policy / pace card
            infoCard(
                icon: "gauge.with.dots.needle.33percent",
                title: daysRemaining > 0 ? "Required Pace" : "Target Complete",
                subtitle: daysRemaining > 0
                    ? String(format: "%.1f days per week needed across %d remaining weeks.", daysPerWeek, weeksRemaining)
                    : "You have met the \(target)-day target for \(quarter.label).",
                color: daysRemaining > 0 ? Theme.accent : Theme.vacation
            )

            // Tracking status card
            infoCard(
                icon: trackingIcon,
                title: "Auto Tracking",
                subtitle: trackingSubtitle,
                color: trackingColor
            )
        }
    }

    private func bufferSubtitle(futureHolidays: Int, futureVacations: Int, availableWorkdays: Int) -> String {
        var parts: [String] = []
        if futureHolidays > 0 {
            parts.append("\(futureHolidays) holiday\(futureHolidays == 1 ? "" : "s")")
        }
        if futureVacations > 0 {
            parts.append("\(futureVacations) vacation day\(futureVacations == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            return "\(availableWorkdays) available work days remaining this quarter."
        }
        return "\(parts.joined(separator: " and ")) upcoming. \(availableWorkdays) work days available."
    }

    private func infoCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .cardStyle(cornerRadius: 14, padding: 14)
    }

    // MARK: - Tracking Helpers

    private var trackingIcon: String {
        if geofenceService.isMonitoring {
            return "location.circle.fill"
        }
        if !geofenceService.isTrackingEnabled {
            return "location.slash"
        }
        return "exclamationmark.triangle.fill"
    }

    private var trackingColor: Color {
        if !geofenceService.isTrackingEnabled {
            return Theme.textSecondary
        }
        if geofenceService.isMonitoring {
            return Theme.vacation
        }
        switch geofenceService.authorizationStatus {
        case .denied, .restricted:
            return Theme.behind
        default:
            return Theme.planned
        }
    }

    private var trackingSubtitle: String {
        if !geofenceService.isTrackingEnabled {
            return "Location tracking is disabled. Enable it in Settings."
        }
        let enabledOfficeCount = viewModel.offices().filter(\.isEnabled).count
        if geofenceService.isMonitoring {
            if let office = geofenceService.lastCheckedInOffice {
                return "Last auto check-in at \(office). Monitoring \(enabledOfficeCount) offices."
            }
            return "Actively monitoring \(enabledOfficeCount) office\(enabledOfficeCount == 1 ? "" : "s")."
        }
        switch geofenceService.authorizationStatus {
        case .denied, .restricted:
            return "Location permission needed. Open Settings to allow access."
        default:
            return "Setup required. Open Settings to configure tracking."
        }
    }
}
