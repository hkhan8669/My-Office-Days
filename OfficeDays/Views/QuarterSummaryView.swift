import SwiftUI

struct PeriodSummaryView: View {
    let viewModel: AttendanceViewModel
    var periodOverride: TrackingPeriod? = nil
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    private var trackingPeriod: TrackingPeriod { periodOverride ?? AppPreferences.trackingPeriod }

    private var periods: [PeriodInfo] {
        PeriodHelper.allPeriods(for: selectedYear, period: trackingPeriod)
    }

    private var yearTotal: Int {
        periods.reduce(0) { $0 + viewModel.officeDayCount(in: $1) }
    }

    private var navigationTitle: String {
        switch trackingPeriod {
        case .monthly: "Months"
        case .quarterly: "Quarters"
        case .yearly: "Year"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                yearSelector

                ForEach(periods, id: \.label) { period in
                    periodCard(period)
                }

                if trackingPeriod != .yearly {
                    yearTotalCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Year Selector

    private var yearSelector: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedYear -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.primaryContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(PressableButtonStyle())

            Text("\(String(selectedYear))")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedYear += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.primaryContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Period Card

    private func periodCard(_ period: PeriodInfo) -> some View {
        let stats = viewModel.periodStats(in: period)
        let count = stats.targetDays
        let target = PeriodHelper.targetDaysPerPeriod
        let delta = stats.delta
        let progress = min(1.0, Double(count) / Double(max(1, target)))
        let isCurrent = isCurrentPeriod(period)

        return VStack(alignment: .leading, spacing: 0) {
            // Section header with left accent border
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 4, height: 20)

                Text(period.label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(1.5)
                    .padding(.leading, 10)

                if isCurrent {
                    Text("NOW")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                        .padding(.leading, 8)
                }

                Spacer()

                Text(periodDateRange(period))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.bottom, 16)

            // Count + Delta row
            HStack(alignment: .bottom) {
                // Large count
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("of \(target) days")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                // Delta indicator
                Text(deltaLabel(delta))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(deltaColor(delta))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(deltaColor(delta).opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 16)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceContainerHigh)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: max(0, geo.size.width * progress), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.bottom, 18)

            // Separator
            Rectangle()
                .fill(Theme.outlineVariant.opacity(0.3))
                .frame(height: 0.5)
                .padding(.bottom, 14)

            // Breakdown row
            HStack(spacing: 0) {
                breakdownItem("OFFICE", stats.officeDays, Theme.office)
                breakdownItem("CREDIT", stats.officeCreditDays, Theme.freeDay)
                breakdownItem("TRAVEL", stats.travelDays, Theme.travel)
                breakdownItem("VACATION", stats.vacationDays, Theme.vacation)
                breakdownItem("HOLIDAY", stats.holidayDays, Theme.holiday)
            }
        }
        .cardStyle()
    }

    // MARK: - Breakdown Item

    private func breakdownItem(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Year Total Card

    private var yearTotalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with left accent border
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 4, height: 20)

                Text("YEAR TOTAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(1.5)
                    .padding(.leading, 10)

                Spacer()
            }
            .padding(.bottom, 16)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(yearTotal)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                    Text("of \(PeriodHelper.targetDaysPerPeriod * PeriodHelper.periodsPerYear) target days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                // Year progress ring
                let yearTarget = Double(PeriodHelper.targetDaysPerPeriod * PeriodHelper.periodsPerYear)
                let yearProgress = min(1.0, Double(yearTotal) / max(1, yearTarget))

                ZStack {
                    Circle()
                        .stroke(Theme.surfaceContainerHigh, lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: yearProgress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: yearProgress)

                    Text("\(Int(yearProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func isCurrentPeriod(_ period: PeriodInfo) -> Bool {
        let current = PeriodHelper.currentPeriod()
        return period.label == current.label
    }

    private func deltaLabel(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta) ahead" }
        if delta < 0 { return "\(delta) behind" }
        return "On target"
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta > 0 { return Theme.ahead }
        if delta < 0 { return Theme.behind }
        return Theme.onTrack
    }

    private func periodDateRange(_ p: PeriodInfo) -> String {
        "\(DateHelper.shortDateString(for: p.startDate)) \u{2013} \(DateHelper.shortDateString(for: p.endDate))"
    }
}
