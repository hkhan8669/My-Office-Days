import Foundation

enum AppPreferences {
    private static let targetDaysKey = "targetDaysPerQuarter"
    private static let trackingEnabledKey = "trackingEnabled"
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

    // MARK: - Weekly Nudge

    private static let nudgeDayKey = "nudgeWeekday"
    private static let nudgeHourKey = "nudgeHour"
    private static let nudgeMinuteKey = "nudgeMinute"

    /// Weekday for the nudge notification (1=Sun … 7=Sat). Default: 2 (Monday).
    static var nudgeWeekday: Int {
        let stored = UserDefaults.standard.integer(forKey: nudgeDayKey)
        return (1...7).contains(stored) ? stored : 2
    }

    static func setNudgeWeekday(_ day: Int) {
        UserDefaults.standard.set(day, forKey: nudgeDayKey)
    }

    static var nudgeHour: Int {
        if UserDefaults.standard.object(forKey: nudgeHourKey) == nil { return 8 }
        return UserDefaults.standard.integer(forKey: nudgeHourKey)
    }

    static var nudgeMinute: Int {
        if UserDefaults.standard.object(forKey: nudgeMinuteKey) == nil { return 30 }
        return UserDefaults.standard.integer(forKey: nudgeMinuteKey)
    }

    static func setNudgeTime(hour: Int, minute: Int) {
        UserDefaults.standard.set(hour, forKey: nudgeHourKey)
        UserDefaults.standard.set(minute, forKey: nudgeMinuteKey)
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
        case complete, onTrack, tight, atRisk, offTrack

        var label: String {
            switch self {
            case .complete: "Complete"
            case .onTrack: "On Track"
            case .tight: "Tight"
            case .atRisk: "At Risk"
            case .offTrack: "Off Track"
            }
        }

        var icon: String {
            switch self {
            case .complete: "star.fill"
            case .onTrack: "checkmark.seal.fill"
            case .tight: "gauge.with.dots.needle.50percent"
            case .atRisk: "exclamationmark.triangle.fill"
            case .offTrack: "xmark.octagon.fill"
            }
        }
    }

    static func paceStatus(officeDays: Int, in quarter: QuarterInfo, asOf date: Date) -> PaceStatus {
        let remaining = max(0, targetDaysPerQuarter - officeDays)
        if remaining == 0 { return .complete }

        let weeks = weeksRemaining(in: quarter, from: date)
        guard weeks > 0 else {
            return remaining > 0 ? .offTrack : .complete
        }

        let daysPerWeek = Double(remaining) / Double(weeks)
        if daysPerWeek <= 3.0 { return .onTrack }
        if daysPerWeek <= 4.0 { return .tight }
        if daysPerWeek <= 5.0 { return .atRisk }
        return .offTrack
    }
}
