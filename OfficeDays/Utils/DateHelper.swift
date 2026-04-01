import Foundation

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct DateHelper {
    static let calendar = Calendar.current

    // Cached formatters — creating DateFormatter is expensive
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let dayOfMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let weekdayShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    static func isWeekday(_ date: Date) -> Bool {
        AppPreferences.isWorkDay(date)
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    static func isPast(_ date: Date) -> Bool {
        startOfDay(date) < startOfDay(Date())
    }

    static func isFuture(_ date: Date) -> Bool {
        startOfDay(date) > startOfDay(Date())
    }

    static func daysInMonth(for date: Date) -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: date)!
        let components = calendar.dateComponents([.year, .month], from: date)
        return range.compactMap { day in
            var dc = components
            dc.day = day
            return calendar.date(from: dc)
        }
    }

    static func firstWeekdayOfMonth(for date: Date) -> Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstDay = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstDay)
    }

    static func monthYearString(for date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    static func dayOfMonthString(for date: Date) -> String {
        dayOfMonthFormatter.string(from: date)
    }

    static func fullDateString(for date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    static func shortDateString(for date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func weekdayShort(for date: Date) -> String {
        weekdayShortFormatter.string(from: date)
    }

}
