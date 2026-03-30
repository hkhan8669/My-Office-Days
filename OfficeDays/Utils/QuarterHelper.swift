import Foundation

enum AppPreferences {
    private static let targetDaysKey = "targetDaysPerQuarter"
    private static let trackingEnabledKey = "trackingEnabled"
    private static let hasSeenTrackingOnboardingKey = "hasSeenTrackingOnboarding"
    static let defaultTargetDaysPerQuarter = 39

    static var targetDaysPerQuarter: Int {
        let storedValue = UserDefaults.standard.integer(forKey: targetDaysKey)
        return storedValue > 0 ? storedValue : defaultTargetDaysPerQuarter
    }

    static func setTargetDaysPerQuarter(_ days: Int) {
        UserDefaults.standard.set(max(1, days), forKey: targetDaysKey)
    }

    static var trackingEnabled: Bool {
        if UserDefaults.standard.object(forKey: trackingEnabledKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: trackingEnabledKey)
    }

    static func setTrackingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: trackingEnabledKey)
    }

    static var hasSeenTrackingOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasSeenTrackingOnboardingKey)
    }

    static func setHasSeenTrackingOnboarding(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: hasSeenTrackingOnboardingKey)
    }
}

struct QuarterHelper {
    static let defaultTargetDaysPerQuarter = AppPreferences.defaultTargetDaysPerQuarter
    static var targetDaysPerQuarter: Int { AppPreferences.targetDaysPerQuarter }

    struct QuarterInfo {
        let quarter: Int // 1-4
        let year: Int
        let startDate: Date
        let endDate: Date
        let label: String // "Q1 2026"

        var weekdaysInQuarter: Int {
            var count = 0
            var current = startDate
            while current <= endDate {
                let weekday = Calendar.current.component(.weekday, from: current)
                if weekday >= 2 && weekday <= 6 { count += 1 }
                current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
            }
            return count
        }
    }

    static func quarter(for date: Date) -> Int {
        let month = Calendar.current.component(.month, from: date)
        return ((month - 1) / 3) + 1
    }

    static func quarterInfo(for date: Date) -> QuarterInfo {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let q = quarter(for: date)
        let startMonth = (q - 1) * 3 + 1
        let endMonth = q * 3

        let start = cal.date(from: DateComponents(year: year, month: startMonth, day: 1))!
        let endComponents = DateComponents(year: year, month: endMonth + 1, day: 1)
        let end = cal.date(byAdding: .day, value: -1, to: cal.date(from: endComponents)!)!

        return QuarterInfo(
            quarter: q,
            year: year,
            startDate: start,
            endDate: end,
            label: "Q\(q) \(year)"
        )
    }

    static func allQuarters(for year: Int) -> [QuarterInfo] {
        (1...4).map { q in
            let date = Calendar.current.date(from: DateComponents(year: year, month: (q - 1) * 3 + 1, day: 15))!
            return quarterInfo(for: date)
        }
    }

    static func weekdaysRemaining(in quarter: QuarterInfo, from date: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        guard today <= quarter.endDate else { return 0 }
        let start = max(today, quarter.startDate)
        var count = 0
        var current = start
        while current <= quarter.endDate {
            let weekday = cal.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 { count += 1 }
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return count
    }

    static func weeksRemaining(in quarter: QuarterInfo, from date: Date) -> Int {
        let days = weekdaysRemaining(in: quarter, from: date)
        return (days + 4) / 5
    }

    enum PaceStatus {
        case onTrack, ahead, behind

        var label: String {
            switch self {
            case .onTrack: "On Track"
            case .ahead: "Ahead"
            case .behind: "Behind"
            }
        }

        var icon: String {
            switch self {
            case .onTrack: "checkmark.circle.fill"
            case .ahead: "arrow.up.circle.fill"
            case .behind: "exclamationmark.triangle.fill"
            }
        }
    }

    static func paceStatus(officeDays: Int, in quarter: QuarterInfo, asOf date: Date) -> PaceStatus {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        guard today >= quarter.startDate else { return .onTrack }

        let totalWeekdays = quarter.weekdaysInQuarter
        guard totalWeekdays > 0 else { return .onTrack }

        // Calculate elapsed weekdays
        let elapsed = totalWeekdays - weekdaysRemaining(in: quarter, from: date)
        guard elapsed > 0 else { return .onTrack }

        let expectedRate = Double(targetDaysPerQuarter) / Double(totalWeekdays)
        let expectedDays = expectedRate * Double(elapsed)

        let diff = Double(officeDays) - expectedDays
        if diff >= 1.0 { return .ahead }
        if diff <= -2.0 { return .behind }
        return .onTrack
    }
}
