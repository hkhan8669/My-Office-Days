import Foundation
import SwiftData

@Model
final class Holiday {
    @Attribute(.unique) var dateKey: String // legacy model kept for compatibility
    var date: Date
    var name: String
    var year: Int

    init(date: Date, name: String) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        self.dateKey = AttendanceDay.key(for: normalizedDate)
        self.date = normalizedDate
        self.name = name
        self.year = Calendar.current.component(.year, from: normalizedDate)
    }

    static func federalHolidays(for year: Int, calendar: Calendar = .current) -> [(date: Date, name: String)] {
        let thanksgiving = nthWeekday(4, weekday: 5, month: 11, year: year, calendar: calendar)
        let dayAfterThanksgiving = calendar.date(byAdding: .day, value: 1, to: thanksgiving) ?? thanksgiving

        return [
            (observedDate(for: date(year: year, month: 1, day: 1, calendar: calendar), calendar: calendar), "New Year's Day"),
            (nthWeekday(3, weekday: 2, month: 1, year: year, calendar: calendar), "MLK Day"),
            (nthWeekday(3, weekday: 2, month: 2, year: year, calendar: calendar), "Presidents' Day"),

            (lastWeekday(weekday: 2, month: 5, year: year, calendar: calendar), "Memorial Day"),
            (observedDate(for: date(year: year, month: 6, day: 19, calendar: calendar), calendar: calendar), "Juneteenth"),
            (observedDate(for: date(year: year, month: 7, day: 4, calendar: calendar), calendar: calendar), "Independence Day"),
            (nthWeekday(1, weekday: 2, month: 9, year: year, calendar: calendar), "Labor Day"),
            (nthWeekday(2, weekday: 2, month: 10, year: year, calendar: calendar), "Columbus Day"),
            (observedDate(for: date(year: year, month: 11, day: 11, calendar: calendar), calendar: calendar), "Veterans Day"),
            (thanksgiving, "Thanksgiving"),
            (dayAfterThanksgiving, "Day after Thanksgiving"),
            (observedDate(for: date(year: year, month: 12, day: 25, calendar: calendar), calendar: calendar), "Christmas"),
        ]
    }

    /// Legacy accessor
    static func companyHolidays(for year: Int, calendar: Calendar = .current) -> [(date: Date, name: String)] {
        federalHolidays(for: year, calendar: calendar)
    }

    private static func easterSunday(year: Int, calendar: Calendar) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        return date(year: year, month: month, day: day, calendar: calendar)
    }

    static func date(year: Int, month: Int, day: Int, calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.startOfDay(for: calendar.date(from: components)!)
    }

    private static func observedDate(for date: Date, calendar: Calendar) -> Date {
        switch calendar.component(.weekday, from: date) {
        case 7:
            return calendar.date(byAdding: .day, value: -1, to: date)!
        case 1:
            return calendar.date(byAdding: .day, value: 1, to: date)!
        default:
            return date
        }
    }

    private static func nthWeekday(
        _ ordinal: Int,
        weekday: Int,
        month: Int,
        year: Int,
        calendar: Calendar
    ) -> Date {
        let firstOfMonth = date(year: year, month: month, day: 1, calendar: calendar)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (weekday - firstWeekday + 7) % 7
        let day = 1 + offset + ((ordinal - 1) * 7)
        return date(year: year, month: month, day: day, calendar: calendar)
    }

    private static func lastWeekday(
        weekday: Int,
        month: Int,
        year: Int,
        calendar: Calendar
    ) -> Date {
        let firstOfNextMonth = date(year: year, month: month + 1, day: 1, calendar: calendar)
        let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: firstOfNextMonth)!

        var current = lastOfMonth
        while calendar.component(.weekday, from: current) != weekday {
            current = calendar.date(byAdding: .day, value: -1, to: current)!
        }
        return calendar.startOfDay(for: current)
    }

}
