import XCTest
@testable import OfficeDays

final class OfficeDaysTests: XCTestCase {

    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        calendar = Calendar.current
    }

    override func tearDownWithError() throws {
        calendar = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.startOfDay(for: calendar.date(from: components)!)
    }

    // MARK: - DayType Tests

    func testCountsTowardTarget_officeFreeTravel_returnsTrue() {
        XCTAssertTrue(DayType.office.countsTowardTarget)
        XCTAssertTrue(DayType.freeDay.countsTowardTarget)
        XCTAssertTrue(DayType.travel.countsTowardTarget)
    }

    func testCountsTowardTarget_otherTypes_returnsFalse() {
        XCTAssertFalse(DayType.remote.countsTowardTarget)
        XCTAssertFalse(DayType.holiday.countsTowardTarget)
        XCTAssertFalse(DayType.vacation.countsTowardTarget)
        XCTAssertFalse(DayType.planned.countsTowardTarget)
    }

    func testLetterCodes_areUniqueForEachType() {
        let codes = DayType.allCases.map { $0.letterCode }
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "Letter codes must be unique across all DayType cases")
    }

    func testLetterCodes_expectedValues() {
        XCTAssertEqual(DayType.office.letterCode, "O")
        XCTAssertEqual(DayType.remote.letterCode, "R")
        XCTAssertEqual(DayType.holiday.letterCode, "H")
        XCTAssertEqual(DayType.vacation.letterCode, "V")
        XCTAssertEqual(DayType.planned.letterCode, "P")
        XCTAssertEqual(DayType.freeDay.letterCode, "C")
        XCTAssertEqual(DayType.travel.letterCode, "T")
    }

    func testManualOptions_containsAllSevenTypes() {
        let options = DayType.manualOptions
        XCTAssertEqual(options.count, 7)
        XCTAssertTrue(options.contains(.office))
        XCTAssertTrue(options.contains(.remote))
        XCTAssertTrue(options.contains(.holiday))
        XCTAssertTrue(options.contains(.vacation))
        XCTAssertTrue(options.contains(.planned))
        XCTAssertTrue(options.contains(.freeDay))
        XCTAssertTrue(options.contains(.travel))
    }

    func testAllCases_matchesManualOptions() {
        // manualOptions should contain the same types as allCases
        XCTAssertEqual(Set(DayType.manualOptions), Set(DayType.allCases))
    }

    // MARK: - Holiday Tests

    func testCompanyHolidays2025_returnsExactly13() {
        let holidays = Holiday.companyHolidays(for: 2025)
        XCTAssertEqual(holidays.count, 13, "Expected 13 company holidays for 2025, got \(holidays.count)")
    }

    func testCompanyHolidays2026_returnsExactly13() {
        let holidays = Holiday.companyHolidays(for: 2026)
        XCTAssertEqual(holidays.count, 13, "Expected 13 company holidays for 2026, got \(holidays.count)")
    }

    func testThanksgiving_isFourthThursdayOfNovember() {
        for year in 2024...2030 {
            let holidays = Holiday.companyHolidays(for: year)
            guard let thanksgiving = holidays.first(where: { $0.name == "Thanksgiving" }) else {
                XCTFail("No Thanksgiving found for \(year)")
                continue
            }

            let weekday = calendar.component(.weekday, from: thanksgiving.date)
            let day = calendar.component(.day, from: thanksgiving.date)
            let month = calendar.component(.month, from: thanksgiving.date)

            XCTAssertEqual(weekday, 5, "Thanksgiving \(year) should be a Thursday (weekday 5), got \(weekday)")
            XCTAssertEqual(month, 11, "Thanksgiving \(year) should be in November")
            // 4th Thursday falls between day 22 and 28
            XCTAssertTrue((22...28).contains(day),
                          "Thanksgiving \(year) day \(day) should be 22-28 (4th Thursday), not 5th")
        }
    }

    func testGoodFriday_fallsBeforeEasterSunday() {
        // Good Friday is 2 days before Easter Sunday
        for year in 2024...2030 {
            let holidays = Holiday.companyHolidays(for: year)
            guard let goodFriday = holidays.first(where: { $0.name == "Good Friday" }) else {
                XCTFail("No Good Friday found for \(year)")
                continue
            }
            let weekday = calendar.component(.weekday, from: goodFriday.date)
            XCTAssertEqual(weekday, 6, "Good Friday \(year) should be a Friday (weekday 6), got \(weekday)")

            // Verify it is exactly 2 days before a Sunday
            let easterSunday = calendar.date(byAdding: .day, value: 2, to: goodFriday.date)!
            let easterWeekday = calendar.component(.weekday, from: easterSunday)
            XCTAssertEqual(easterWeekday, 1, "Easter Sunday derived from Good Friday \(year) should be Sunday (weekday 1)")
        }
    }

    func testNewYearsDay_isJan1OrObserved() {
        for year in 2024...2030 {
            let holidays = Holiday.companyHolidays(for: year)
            guard let newYear = holidays.first(where: { $0.name == "New Year's Day" }) else {
                XCTFail("No New Year's Day found for \(year)")
                continue
            }
            let month = calendar.component(.month, from: newYear.date)
            let day = calendar.component(.day, from: newYear.date)
            let weekday = calendar.component(.weekday, from: newYear.date)

            // Observed date should be a weekday
            XCTAssertTrue((2...6).contains(weekday),
                          "New Year's Day \(year) observed date should be a weekday, got \(weekday)")

            // If Jan 1 is a weekday, the observed date should be Jan 1
            let jan1 = makeDate(year: year, month: 1, day: 1)
            let jan1Weekday = calendar.component(.weekday, from: jan1)
            if (2...6).contains(jan1Weekday) {
                XCTAssertEqual(month, 1)
                XCTAssertEqual(day, 1, "When Jan 1 is a weekday, observed date should be Jan 1")
            }
        }
    }

    func testChristmas_isDec25OrObserved() {
        for year in 2024...2030 {
            let holidays = Holiday.companyHolidays(for: year)
            guard let christmas = holidays.first(where: { $0.name == "Christmas" }) else {
                XCTFail("No Christmas found for \(year)")
                continue
            }
            let weekday = calendar.component(.weekday, from: christmas.date)

            // Observed date should be a weekday
            XCTAssertTrue((2...6).contains(weekday),
                          "Christmas \(year) observed date should be a weekday, got \(weekday)")

            // If Dec 25 is a weekday, the observed date should be Dec 25
            let dec25 = makeDate(year: year, month: 12, day: 25)
            let dec25Weekday = calendar.component(.weekday, from: dec25)
            if (2...6).contains(dec25Weekday) {
                let day = calendar.component(.day, from: christmas.date)
                let month = calendar.component(.month, from: christmas.date)
                XCTAssertEqual(month, 12)
                XCTAssertEqual(day, 25, "When Dec 25 is a weekday, observed date should be Dec 25")
            }
        }
    }

    func testHolidays_noDuplicateDatesInYear() {
        for year in 2024...2030 {
            let holidays = Holiday.companyHolidays(for: year)
            let dateKeys = holidays.map { AttendanceDay.key(for: $0.date) }
            let uniqueKeys = Set(dateKeys)
            XCTAssertEqual(dateKeys.count, uniqueKeys.count,
                           "Year \(year) has duplicate holiday dates: \(dateKeys)")
        }
    }

    func testHolidays_allNamesPresent() {
        let expectedNames: Set<String> = [
            "New Year's Day", "MLK Day", "Presidents' Day", "Good Friday",
            "Memorial Day", "Juneteenth", "Independence Day", "Labor Day",
            "Columbus Day", "Veterans Day", "Thanksgiving",
            "Day after Thanksgiving", "Christmas"
        ]
        let holidays = Holiday.companyHolidays(for: 2025)
        let actualNames = Set(holidays.map { $0.name })
        XCTAssertEqual(actualNames, expectedNames)
    }

    // MARK: - QuarterHelper Tests

    func testQuarter_Q1_Jan1() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 1)
    }

    func testQuarter_Q1_Mar31() {
        let date = makeDate(year: 2026, month: 3, day: 31)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 1)
    }

    func testQuarter_Q2_Apr1() {
        let date = makeDate(year: 2026, month: 4, day: 1)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 2)
    }

    func testQuarter_Q2_Jun30() {
        let date = makeDate(year: 2026, month: 6, day: 30)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 2)
    }

    func testQuarter_Q3_Jul1() {
        let date = makeDate(year: 2026, month: 7, day: 1)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 3)
    }

    func testQuarter_Q3_Sep30() {
        let date = makeDate(year: 2026, month: 9, day: 30)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 3)
    }

    func testQuarter_Q4_Oct1() {
        let date = makeDate(year: 2026, month: 10, day: 1)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 4)
    }

    func testQuarter_Q4_Dec31() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        XCTAssertEqual(QuarterHelper.quarter(for: date), 4)
    }

    func testQuarterInfo_Q1_dateRange() {
        let date = makeDate(year: 2026, month: 2, day: 15)
        let info = QuarterHelper.quarterInfo(for: date)

        XCTAssertEqual(info.quarter, 1)
        XCTAssertEqual(info.year, 2026)
        XCTAssertEqual(info.label, "Q1 2026")

        let startComponents = calendar.dateComponents([.month, .day], from: info.startDate)
        XCTAssertEqual(startComponents.month, 1)
        XCTAssertEqual(startComponents.day, 1)

        let endComponents = calendar.dateComponents([.month, .day], from: info.endDate)
        XCTAssertEqual(endComponents.month, 3)
        XCTAssertEqual(endComponents.day, 31)
    }

    func testQuarterInfo_Q4_dateRange() {
        let date = makeDate(year: 2026, month: 11, day: 15)
        let info = QuarterHelper.quarterInfo(for: date)

        XCTAssertEqual(info.quarter, 4)
        XCTAssertEqual(info.year, 2026)
        XCTAssertEqual(info.label, "Q4 2026")

        let startComponents = calendar.dateComponents([.month, .day], from: info.startDate)
        XCTAssertEqual(startComponents.month, 10)
        XCTAssertEqual(startComponents.day, 1)

        let endComponents = calendar.dateComponents([.month, .day], from: info.endDate)
        XCTAssertEqual(endComponents.month, 12)
        XCTAssertEqual(endComponents.day, 31)
    }

    func testWeekdaysRemaining_countsOnlyWeekdays() {
        // Use a known week: Mon Mar 2 2026 to Fri Mar 6 2026
        let monday = makeDate(year: 2026, month: 3, day: 2)
        let info = QuarterHelper.quarterInfo(for: monday)
        let remaining = QuarterHelper.weekdaysRemaining(in: info, from: monday)

        // Remaining should only include Mon-Fri days, not Sat-Sun
        XCTAssertTrue(remaining > 0)

        // Verify: from Mar 2 to Mar 31 2026 there should be exactly 22 weekdays
        // Mar 2-6 (5), Mar 9-13 (5), Mar 16-20 (5), Mar 23-27 (5), Mar 30-31 (2) = 22
        XCTAssertEqual(remaining, 22)
    }

    func testWeekdaysRemaining_afterQuarterEnd_returnsZero() {
        let q1Date = makeDate(year: 2026, month: 1, day: 15)
        let info = QuarterHelper.quarterInfo(for: q1Date)
        let afterEnd = makeDate(year: 2026, month: 4, day: 1)
        let remaining = QuarterHelper.weekdaysRemaining(in: info, from: afterEnd)
        XCTAssertEqual(remaining, 0)
    }

    func testDefaultTargetDaysPerQuarter_is39() {
        XCTAssertEqual(QuarterHelper.defaultTargetDaysPerQuarter, 39)
    }

    func testAllQuarters_returnsFourQuarters() {
        let quarters = QuarterHelper.allQuarters(for: 2026)
        XCTAssertEqual(quarters.count, 4)
        XCTAssertEqual(quarters[0].quarter, 1)
        XCTAssertEqual(quarters[1].quarter, 2)
        XCTAssertEqual(quarters[2].quarter, 3)
        XCTAssertEqual(quarters[3].quarter, 4)
    }

    func testWeekdaysInQuarter_Q1_2026() {
        let info = QuarterHelper.quarterInfo(for: makeDate(year: 2026, month: 1, day: 15))
        // Q1 2026: Jan 1 - Mar 31
        // Jan: 22 weekdays, Feb: 20 weekdays, Mar: 22 weekdays = 64
        XCTAssertEqual(info.weekdaysInQuarter, 64)
    }

    // MARK: - DateHelper Tests

    func testIsWeekday_mondayThroughFriday_returnsTrue() {
        // March 2, 2026 is a Monday
        for dayOffset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: dayOffset,
                                     to: makeDate(year: 2026, month: 3, day: 2))!
            XCTAssertTrue(DateHelper.isWeekday(date),
                          "Day offset \(dayOffset) from Monday should be a weekday")
        }
    }

    func testIsWeekday_saturdayAndSunday_returnsFalse() {
        // March 7, 2026 is a Saturday; March 8 is Sunday
        let saturday = makeDate(year: 2026, month: 3, day: 7)
        let sunday = makeDate(year: 2026, month: 3, day: 8)
        XCTAssertFalse(DateHelper.isWeekday(saturday))
        XCTAssertFalse(DateHelper.isWeekday(sunday))
    }

    func testIsToday_withTodaysDate_returnsTrue() {
        XCTAssertTrue(DateHelper.isToday(Date()))
    }

    func testIsToday_withYesterday_returnsFalse() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(DateHelper.isToday(yesterday))
    }

    func testIsFuture_withTomorrow_returnsTrue() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(DateHelper.isFuture(tomorrow))
    }

    func testIsFuture_withYesterday_returnsFalse() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(DateHelper.isFuture(yesterday))
    }

    func testIsFuture_withToday_returnsFalse() {
        XCTAssertFalse(DateHelper.isFuture(Date()))
    }

    func testDayOfMonthString_returnsCorrectValues() {
        let jan1 = makeDate(year: 2026, month: 1, day: 1)
        XCTAssertEqual(DateHelper.dayOfMonthString(for: jan1), "1")

        let jan15 = makeDate(year: 2026, month: 1, day: 15)
        XCTAssertEqual(DateHelper.dayOfMonthString(for: jan15), "15")

        let jan31 = makeDate(year: 2026, month: 1, day: 31)
        XCTAssertEqual(DateHelper.dayOfMonthString(for: jan31), "31")
    }

    func testIsSameDay_sameDayDifferentTimes() {
        let morning = makeDate(year: 2026, month: 6, day: 15)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 23
        components.minute = 59
        let evening = calendar.date(from: components)!
        XCTAssertTrue(DateHelper.isSameDay(morning, evening))
    }

    func testIsSameDay_differentDays_returnsFalse() {
        let day1 = makeDate(year: 2026, month: 6, day: 15)
        let day2 = makeDate(year: 2026, month: 6, day: 16)
        XCTAssertFalse(DateHelper.isSameDay(day1, day2))
    }

    func testIsPast_withYesterday_returnsTrue() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(DateHelper.isPast(yesterday))
    }

    func testIsPast_withTomorrow_returnsFalse() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertFalse(DateHelper.isPast(tomorrow))
    }

    // MARK: - AttendanceDay Tests

    func testKey_producesConsistentYMDFormat() {
        let date = makeDate(year: 2026, month: 3, day: 5)
        let key = AttendanceDay.key(for: date)
        XCTAssertEqual(key, "2026-03-05")
    }

    func testKey_singleDigitMonthAndDay_areZeroPadded() {
        let date = makeDate(year: 2026, month: 1, day: 9)
        let key = AttendanceDay.key(for: date)
        XCTAssertEqual(key, "2026-01-09")
    }

    func testKey_doubleDigitMonthAndDay() {
        let date = makeDate(year: 2026, month: 12, day: 25)
        let key = AttendanceDay.key(for: date)
        XCTAssertEqual(key, "2026-12-25")
    }

    func testKey_uniquePerDay() {
        let date1 = makeDate(year: 2026, month: 6, day: 1)
        let date2 = makeDate(year: 2026, month: 6, day: 2)
        let key1 = AttendanceDay.key(for: date1)
        let key2 = AttendanceDay.key(for: date2)
        XCTAssertNotEqual(key1, key2)
    }

    func testKey_sameDateDifferentTimes_produceSameKey() {
        let morning = makeDate(year: 2026, month: 6, day: 15)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 18
        components.minute = 30
        let evening = calendar.date(from: components)!
        XCTAssertEqual(AttendanceDay.key(for: morning), AttendanceDay.key(for: evening))
    }

    func testKey_matchesExpectedRegex() {
        let date = makeDate(year: 2026, month: 7, day: 4)
        let key = AttendanceDay.key(for: date)
        let regex = #"^\d{4}-\d{2}-\d{2}$"#
        XCTAssertNotNil(key.range(of: regex, options: .regularExpression),
                        "Key '\(key)' should match yyyy-MM-dd format")
    }
}
