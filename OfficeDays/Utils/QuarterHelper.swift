import Foundation

// MARK: - Tracking Period

enum TrackingPeriod: String, CaseIterable, Identifiable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }

    var shortLabel: String {
        switch self {
        case .monthly: "Month"
        case .quarterly: "Quarter"
        case .yearly: "Year"
        }
    }

    var progressHeader: String {
        switch self {
        case .monthly: "MONTH PROGRESS"
        case .quarterly: "QUARTER PROGRESS"
        case .yearly: "YEAR PROGRESS"
        }
    }
}

// MARK: - App Preferences

enum AppPreferences {
    private static let targetDaysKey = "targetDaysPerQuarter"
    private static let trackingEnabledKey = "trackingEnabled"
    private static let trackingPeriodKey = "trackingPeriod"
    static let defaultTargetDaysPerQuarter = 39

    // MARK: Tracking Period

    static var trackingPeriod: TrackingPeriod {
        if let raw = UserDefaults.standard.string(forKey: trackingPeriodKey),
           let period = TrackingPeriod(rawValue: raw) {
            return period
        }
        return .quarterly
    }

    static func setTrackingPeriod(_ period: TrackingPeriod) {
        UserDefaults.standard.set(period.rawValue, forKey: trackingPeriodKey)
    }

    // MARK: Target Days

    static var targetDaysPerPeriod: Int {
        let storedValue = UserDefaults.standard.integer(forKey: targetDaysKey)
        return storedValue > 0 ? storedValue : defaultTargetForPeriod(trackingPeriod)
    }

    /// Sensible default target for each period type
    static func defaultTargetForPeriod(_ period: TrackingPeriod) -> Int {
        switch period {
        case .monthly: 13
        case .quarterly: 39
        case .yearly: 156
        }
    }

    static func setTargetDaysPerPeriod(_ days: Int) {
        UserDefaults.standard.set(max(1, days), forKey: targetDaysKey)
    }

    /// Legacy accessor – many call sites still use this name
    static var targetDaysPerQuarter: Int { targetDaysPerPeriod }
    static func setTargetDaysPerQuarter(_ days: Int) { setTargetDaysPerPeriod(days) }

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

    // MARK: - Work Days

    private static let workDaysKey = "workDays"
    /// Default work days: Mon(2) through Fri(6) in Calendar weekday numbering
    static let defaultWorkDays: Set<Int> = [2, 3, 4, 5, 6]

    static var workDays: Set<Int> {
        if let stored = UserDefaults.standard.array(forKey: workDaysKey) as? [Int], !stored.isEmpty {
            return Set(stored)
        }
        return defaultWorkDays
    }

    static func setWorkDays(_ days: Set<Int>) {
        UserDefaults.standard.set(Array(days).sorted(), forKey: workDaysKey)
    }

    static func isWorkDay(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return workDays.contains(weekday)
    }

    // MARK: - Counts Toward Target

    private static let targetCountsKey = "dayTypesCountTowardTarget"

    /// Day types that count toward the attendance target. Default: office, travel, credit, holiday, vacation
    static var dayTypesCountingTowardTarget: Set<String> {
        if let stored = UserDefaults.standard.array(forKey: targetCountsKey) as? [String], !stored.isEmpty {
            return Set(stored)
        }
        return Set(["office", "freeDay", "travel", "holiday", "vacation"])
    }

    static func setDayTypesCountingTowardTarget(_ types: Set<String>) {
        UserDefaults.standard.set(Array(types).sorted(), forKey: targetCountsKey)
    }

    // MARK: - Holidays

    private static let holidaysEnabledKey = "holidaysEnabled"

    static var holidaysEnabled: Bool {
        if UserDefaults.standard.object(forKey: holidaysEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: holidaysEnabledKey)
    }

    static func setHolidaysEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: holidaysEnabledKey)
    }

    // MARK: - Dismissed Holidays

    private static let dismissedHolidaysKey = "dismissedHolidayDateKeys"

    static var dismissedHolidayDateKeys: Set<String> {
        if let stored = UserDefaults.standard.array(forKey: dismissedHolidaysKey) as? [String] {
            return Set(stored)
        }
        return []
    }

    static func addDismissedHoliday(_ dateKey: String) {
        var dismissed = dismissedHolidayDateKeys
        dismissed.insert(dateKey)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedHolidaysKey)
    }

    static func removeDismissedHoliday(_ dateKey: String) {
        var dismissed = dismissedHolidayDateKeys
        dismissed.remove(dateKey)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedHolidaysKey)
    }

    static func clearDismissedHolidays() {
        UserDefaults.standard.removeObject(forKey: dismissedHolidaysKey)
    }
}

// MARK: - Period Info

struct PeriodInfo {
    let index: Int      // 1-4 for quarters, 1-12 for months, 1 for year
    let year: Int
    let startDate: Date
    let endDate: Date
    let label: String   // "Q1 2026", "Jan 2026", "2026"

    var workDaysInPeriod: Int {
        var count = 0
        var current = startDate
        while current <= endDate {
            if AppPreferences.isWorkDay(current) { count += 1 }
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }
        return count
    }

    /// Legacy accessors for backwards compatibility
    var weekdaysInQuarter: Int { workDaysInPeriod }
    var quarter: Int { index }
}

// MARK: - Period Helper

struct PeriodHelper {
    static var targetDaysPerPeriod: Int { AppPreferences.targetDaysPerPeriod }

    // MARK: Current Period

    static func currentPeriod(for date: Date = Date()) -> PeriodInfo {
        switch AppPreferences.trackingPeriod {
        case .monthly: return monthInfo(for: date)
        case .quarterly: return quarterInfo(for: date)
        case .yearly: return yearInfo(for: date)
        }
    }

    // MARK: All Periods for a Year

    static func allPeriods(for year: Int) -> [PeriodInfo] {
        switch AppPreferences.trackingPeriod {
        case .monthly: return allMonths(for: year)
        case .quarterly: return allQuarters(for: year)
        case .yearly: return [yearInfo(for: Calendar.current.date(from: DateComponents(year: year, month: 6, day: 15))!)]
        }
    }

    /// Number of periods in a year for the current tracking mode
    static var periodsPerYear: Int {
        switch AppPreferences.trackingPeriod {
        case .monthly: 12
        case .quarterly: 4
        case .yearly: 1
        }
    }

    // MARK: Quarter-specific (kept for backwards compat)

    static func quarter(for date: Date) -> Int {
        let month = Calendar.current.component(.month, from: date)
        return ((month - 1) / 3) + 1
    }

    static func quarterInfo(for date: Date) -> PeriodInfo {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let q = quarter(for: date)
        let startMonth = (q - 1) * 3 + 1
        let endMonth = q * 3

        let start = cal.date(from: DateComponents(year: year, month: startMonth, day: 1))!
        let endComponents = DateComponents(year: year, month: endMonth + 1, day: 1)
        let end = cal.date(byAdding: .day, value: -1, to: cal.date(from: endComponents)!)!

        return PeriodInfo(
            index: q,
            year: year,
            startDate: start,
            endDate: end,
            label: "Q\(q) \(year)"
        )
    }

    static func allQuarters(for year: Int) -> [PeriodInfo] {
        (1...4).map { q in
            let date = Calendar.current.date(from: DateComponents(year: year, month: (q - 1) * 3 + 1, day: 15))!
            return quarterInfo(for: date)
        }
    }

    // MARK: Month-specific

    static func monthInfo(for date: Date) -> PeriodInfo {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)

        let start = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let nextMonth = cal.date(byAdding: .month, value: 1, to: start)!
        let end = cal.date(byAdding: .day, value: -1, to: nextMonth)!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return PeriodInfo(
            index: month,
            year: year,
            startDate: start,
            endDate: end,
            label: formatter.string(from: start)
        )
    }

    static func allMonths(for year: Int) -> [PeriodInfo] {
        (1...12).map { m in
            let date = Calendar.current.date(from: DateComponents(year: year, month: m, day: 15))!
            return monthInfo(for: date)
        }
    }

    // MARK: Year-specific

    static func yearInfo(for date: Date) -> PeriodInfo {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = cal.date(from: DateComponents(year: year, month: 12, day: 31))!

        return PeriodInfo(
            index: 1,
            year: year,
            startDate: start,
            endDate: end,
            label: "\(year)"
        )
    }

    // MARK: Remaining Work Days

    static func weekdaysRemaining(in period: PeriodInfo, from date: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        guard today <= period.endDate else { return 0 }
        let start = max(today, period.startDate)
        var count = 0
        var current = start
        while current <= period.endDate {
            if AppPreferences.isWorkDay(current) { count += 1 }
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return count
    }

    static func weeksRemaining(in period: PeriodInfo, from date: Date) -> Int {
        let days = weekdaysRemaining(in: period, from: date)
        let daysPerWeek = max(1, AppPreferences.workDays.count)
        return (days + daysPerWeek - 1) / daysPerWeek
    }

    // MARK: Pace

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

    static func paceStatus(officeDays: Int, in period: PeriodInfo, asOf date: Date) -> PaceStatus {
        let remaining = max(0, targetDaysPerPeriod - officeDays)
        if remaining == 0 { return .complete }

        let weeks = weeksRemaining(in: period, from: date)
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

// MARK: - Legacy QuarterHelper (thin wrapper)

/// Backwards-compatible wrapper. New code should use `PeriodHelper` directly.
struct QuarterHelper {
    static let defaultTargetDaysPerQuarter = AppPreferences.defaultTargetDaysPerQuarter
    static var targetDaysPerQuarter: Int { AppPreferences.targetDaysPerPeriod }

    typealias QuarterInfo = PeriodInfo

    static func quarter(for date: Date) -> Int {
        PeriodHelper.quarter(for: date)
    }

    static func quarterInfo(for date: Date) -> PeriodInfo {
        PeriodHelper.quarterInfo(for: date)
    }

    static func allQuarters(for year: Int) -> [PeriodInfo] {
        PeriodHelper.allQuarters(for: year)
    }

    static func weekdaysRemaining(in quarter: PeriodInfo, from date: Date) -> Int {
        PeriodHelper.weekdaysRemaining(in: quarter, from: date)
    }

    static func weeksRemaining(in quarter: PeriodInfo, from date: Date) -> Int {
        PeriodHelper.weeksRemaining(in: quarter, from: date)
    }

    typealias PaceStatus = PeriodHelper.PaceStatus

    static func paceStatus(officeDays: Int, in quarter: PeriodInfo, asOf date: Date) -> PaceStatus {
        PeriodHelper.paceStatus(officeDays: officeDays, in: quarter, asOf: date)
    }
}
