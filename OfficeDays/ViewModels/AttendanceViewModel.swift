import Foundation
import OSLog
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AttendanceViewModel {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.officedays.app", category: "AttendanceViewModel")

    struct ManagedHoliday: Identifiable, Hashable {
        let id: String
        let date: Date
        let name: String
    }

    struct QuarterSnapshot {
        var officeDays: Int = 0
        var plannedDays: Int = 0
        var vacationDays: Int = 0
        var holidayDays: Int = 0
        var officeCreditDays: Int = 0
        var travelDays: Int = 0
        /// Future credited days (vacation, holiday, credit, travel scheduled after today)
        var futureCreditedDays: Int = 0

        /// Credited days up to and including today
        var targetDays: Int {
            officeDays + officeCreditDays + travelDays + holidayDays + vacationDays
        }

        /// Total credited including future
        var totalCredited: Int {
            targetDays + futureCreditedDays
        }
    }

    struct QuarterStats {
        let officeDays: Int
        let plannedDays: Int
        let vacationDays: Int
        let holidayDays: Int
        let officeCreditDays: Int
        let travelDays: Int

        var targetDays: Int {
            officeDays + officeCreditDays + travelDays + holidayDays + vacationDays
        }

        var delta: Int { targetDays - QuarterHelper.targetDaysPerQuarter }
    }

    private(set) var currentQuarterSnapshot = QuarterSnapshot()
    private(set) var monthCache: [String: AttendanceDay] = [:]
    private var cachedMonthKey = ""
    var lastErrorMessage: String?

    var targetDaysPerQuarter: Int {
        QuarterHelper.targetDaysPerQuarter
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func clearError() {
        lastErrorMessage = nil
    }

    // MARK: - Seed Data

    func seedIfNeeded() {
        seedOffices()
        migrateLegacyHolidays()

        let currentYear = Calendar.current.component(.year, from: Date())
        for year in (currentYear - 1)...(currentYear + 2) {
            ensureHolidays(for: year)
        }

        resolveStaleEntries()
        refreshSnapshot()
    }

    func ensureHolidays(for year: Int) {
        var inserted = false
        for holiday in Holiday.companyHolidays(for: year) {
            if let existingDay = attendanceDay(for: holiday.date) {
                if existingDay.dayType == .holiday || !existingDay.isManualOverride {
                    existingDay.dayType = .holiday
                    existingDay.holidayName = holiday.name
                    existingDay.officeName = nil
                    existingDay.isAutoLogged = false
                    existingDay.isManualOverride = false
                    existingDay.updatedAt = Date()
                    inserted = true
                }
            } else {
                let attendanceDay = AttendanceDay(
                    date: holiday.date,
                    dayType: .holiday,
                    holidayName: holiday.name
                )
                modelContext.insert(attendanceDay)
                inserted = true
            }
        }

        if inserted {
            saveChanges("Unable to save holiday updates.")
            invalidateMonthCache()
        }
    }

    func refreshSnapshot() {
        let quarter = QuarterHelper.quarterInfo(for: Date())
        let startKey = AttendanceDay.key(for: quarter.startDate)
        let endKey = AttendanceDay.key(for: quarter.endDate)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey
            }
        )
        let days = fetch(descriptor, userMessage: "Unable to refresh the current quarter.")

        let todayKey = AttendanceDay.key(for: Date())
        var snapshot = QuarterSnapshot()
        for day in days {
            let isFuture = day.dateKey > todayKey
            switch day.dayType {
            case .office:
                if isFuture {
                    snapshot.futureCreditedDays += 1
                } else {
                    snapshot.officeDays += 1
                }
            case .planned:
                // Only future planned days count; past unresolved planned days are stale
                if isFuture {
                    snapshot.plannedDays += 1
                }
            case .vacation, .holiday, .freeDay, .travel:
                if isFuture {
                    snapshot.futureCreditedDays += 1
                } else {
                    switch day.dayType {
                    case .vacation: snapshot.vacationDays += 1
                    case .holiday: snapshot.holidayDays += 1
                    case .freeDay: snapshot.officeCreditDays += 1
                    case .travel: snapshot.travelDays += 1
                    default: break
                    }
                }
            default: break
            }
        }
        currentQuarterSnapshot = snapshot
    }

    func refreshMonthCache(for date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let monthKey = "\(components.year ?? 0)-\(components.month ?? 0)"
        guard monthKey != cachedMonthKey else { return }

        let firstOfMonth = calendar.date(from: components) ?? date
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) ?? firstOfMonth
        let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? firstOfMonth

        let startKey = AttendanceDay.key(for: firstOfMonth)
        let endKey = AttendanceDay.key(for: lastOfMonth)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey
            }
        )

        let days = fetch(descriptor, userMessage: "Unable to load the selected month.")
        monthCache = Dictionary(uniqueKeysWithValues: days.map { ($0.dateKey, $0) })
        cachedMonthKey = monthKey
    }

    func cachedAttendanceDay(for date: Date) -> AttendanceDay? {
        monthCache[AttendanceDay.key(for: date)]
    }

    func invalidateMonthCache() {
        cachedMonthKey = ""
    }

    // MARK: - Fetch

    func attendanceDay(for date: Date) -> AttendanceDay? {
        let key = AttendanceDay.key(for: date)
        var descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate { $0.dateKey == key }
        )
        descriptor.fetchLimit = 1
        return fetch(descriptor, userMessage: "Unable to load attendance details.").first
    }

    func holidayName(for date: Date) -> String? {
        attendanceDay(for: date)?.holidayName
    }

    func officeDays(in quarter: QuarterHelper.QuarterInfo) -> [AttendanceDay] {
        let officeType = DayType.office.rawValue
        let (startKey, endKey) = quarterBounds(for: quarter)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey && $0.dayTypeRaw == officeType
            }
        )
        return fetch(descriptor, userMessage: "Unable to load office-day totals.")
    }

    func allDays(in quarter: QuarterHelper.QuarterInfo) -> [AttendanceDay] {
        let (startKey, endKey) = quarterBounds(for: quarter)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey
            }
        )
        return fetch(descriptor, userMessage: "Unable to load quarter details.")
    }

    func officeDayCount(in quarter: QuarterHelper.QuarterInfo) -> Int {
        quarterStats(in: quarter).targetDays
    }

    func quarterStats(in quarter: QuarterHelper.QuarterInfo) -> QuarterStats {
        let days = allDays(in: quarter)
        var officeDays = 0
        var plannedDays = 0
        var vacationDays = 0
        var holidayDays = 0
        var officeCreditDays = 0
        var travelDays = 0

        for day in days {
            switch day.dayType {
            case .office: officeDays += 1
            case .planned: plannedDays += 1
            case .vacation: vacationDays += 1
            case .holiday: holidayDays += 1
            case .freeDay: officeCreditDays += 1
            case .travel: travelDays += 1
            default: break
            }
        }

        return QuarterStats(
            officeDays: officeDays,
            plannedDays: plannedDays,
            vacationDays: vacationDays,
            holidayDays: holidayDays,
            officeCreditDays: officeCreditDays,
            travelDays: travelDays
        )
    }

    func dayCount(of type: DayType, in quarter: QuarterHelper.QuarterInfo) -> Int {
        let (startKey, endKey) = quarterBounds(for: quarter)
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey && $0.dayTypeRaw == typeRaw
            }
        )
        return fetchCount(descriptor, userMessage: "Unable to count quarter days.")
    }

    func delta(in quarter: QuarterHelper.QuarterInfo) -> Int {
        officeDayCount(in: quarter) - QuarterHelper.targetDaysPerQuarter
    }

    func offices() -> [OfficeLocation] {
        let descriptor = FetchDescriptor<OfficeLocation>(
            sortBy: [SortDescriptor(\.name)]
        )
        return fetch(descriptor, userMessage: "Unable to load office locations.")
    }

    func holidays(for year: Int) -> [ManagedHoliday] {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? startOfYear
        let startKey = AttendanceDay.key(for: startOfYear)
        let endKey = AttendanceDay.key(for: endOfYear)
        let holidayType = DayType.holiday.rawValue

        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey && $0.dayTypeRaw == holidayType
            },
            sortBy: [SortDescriptor(\.date)]
        )

        return fetch(descriptor, userMessage: "Unable to load holidays.").map {
            ManagedHoliday(
                id: $0.dateKey,
                date: $0.date,
                name: $0.holidayName ?? "Holiday"
            )
        }
    }

    // MARK: - Mutations

    @discardableResult
    func logOfficeDay(date: Date, officeName: String, isAutoLogged: Bool = true) -> Bool {
        if let existing = attendanceDay(for: date) {
            guard !existing.isManualOverride else { return false }
            existing.dayType = .office
            existing.officeName = officeName
            existing.holidayName = nil
            existing.isAutoLogged = isAutoLogged
            existing.updatedAt = Date()
        } else {
            let day = AttendanceDay(
                date: date,
                dayType: .office,
                officeName: officeName,
                isAutoLogged: isAutoLogged
            )
            modelContext.insert(day)
        }
        return saveAndRefresh(userMessage: "Unable to save the office day.")
    }

    func setDayType(date: Date, type: DayType, notes: String? = nil) {
        applyDayType(date: date, type: type, notes: notes)
        saveAndRefresh(userMessage: "Unable to save the selected day.")
    }

    func setDayTypes(dates: [Date], type: DayType, notes: String? = nil) {
        let normalizedDates = dates.map { Calendar.current.startOfDay(for: $0) }.sorted()
        for date in normalizedDates {
            applyDayType(date: date, type: type, notes: notes)
        }
        saveAndRefresh(userMessage: "Unable to apply the bulk update.")
    }

    func togglePlanned(date: Date) {
        if let existing = attendanceDay(for: date) {
            if existing.dayType == .planned {
                modelContext.delete(existing)
            } else {
                existing.dayType = .planned
                existing.officeName = nil
                existing.holidayName = nil
                existing.isAutoLogged = false
                existing.isManualOverride = true
                existing.updatedAt = Date()
            }
        } else {
            let day = AttendanceDay(date: date, dayType: .planned, isManualOverride: true)
            modelContext.insert(day)
        }

        saveAndRefresh(userMessage: "Unable to update the plan.")
    }

    func addHoliday(date: Date, name: String) {
        applyDayType(date: date, type: .holiday, notes: name)
        saveAndRefresh(userMessage: "Unable to add the holiday.")
    }

    func deleteHoliday(_ holiday: ManagedHoliday) {
        if let day = attendanceDay(for: holiday.date), day.dayType == .holiday {
            modelContext.delete(day)
        }
        saveAndRefresh(userMessage: "Unable to delete the holiday.")
    }

    func addOffice(name: String, address: String, latitude: Double, longitude: Double, radiusInFeet: Double) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastErrorMessage = "Office name is required."
            return
        }

        if offices().contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            lastErrorMessage = "Office names need to be unique."
            return
        }

        let office = OfficeLocation(
            name: trimmedName,
            address: address,
            latitude: latitude,
            longitude: longitude,
            geofenceRadius: radiusInFeet * 0.3048,
            isCustom: true
        )
        modelContext.insert(office)
        saveChanges("Unable to save the office location.")
    }

    func updateOfficeName(_ office: OfficeLocation, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastErrorMessage = "Office name is required."
            return
        }
        if offices().contains(where: { $0.id != office.id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            lastErrorMessage = "Office names need to be unique."
            return
        }
        office.name = trimmed
        saveChanges("Unable to update the office name.")
    }

    func deleteOffice(_ office: OfficeLocation) {
        guard office.isCustom else {
            lastErrorMessage = "Default offices can be disabled, but not deleted."
            return
        }

        modelContext.delete(office)
        saveChanges("Unable to delete the office location.")
    }

    func setTargetDaysPerQuarter(_ days: Int) {
        AppPreferences.setTargetDaysPerQuarter(days)
        refreshSnapshot()
    }

    // MARK: - Planned Day Resolution

    func resolveStaleEntries() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayKey = AttendanceDay.key(for: today)
        let plannedType = DayType.planned.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dayTypeRaw == plannedType && $0.dateKey < todayKey
            }
        )
        let stalePlanned = fetch(descriptor, userMessage: "Unable to resolve older planned days.")

        var changed = false
        for day in stalePlanned {
            let dayDate = Calendar.current.startOfDay(for: day.date)
            let daysSince = Calendar.current.dateComponents([.day], from: dayDate, to: today).day ?? 0
            if daysSince >= 1 {
                // Intentional: stale planned days are converted to .remote rather than
                // deleted so the user still sees a record for that date. Changing this
                // behaviour is deferred until we add an "unlogged" state.
                day.dayType = .remote
                day.updatedAt = Date()
                changed = true
            }
        }

        if changed {
            saveChanges("Unable to resolve older planned days.")
        }
    }

    // MARK: - CSV Export

    func exportCSV(year: Int) -> String {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? startOfYear
        let startKey = AttendanceDay.key(for: startOfYear)
        let endKey = AttendanceDay.key(for: endOfYear)

        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey
            }
        )
        let days = fetch(descriptor, userMessage: "Unable to prepare the CSV export.")
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.dateKey, $0) })

        func csvField(_ value: String) -> String {
            if value.contains(",") || value.contains("\"") || value.contains("\n") {
                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return value
        }

        var lines = ["Week #,Date,Day,Type,Office"]
        var current = startOfYear

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEE"

        while current <= endOfYear {
            let weekday = calendar.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 {
                let day = dayMap[AttendanceDay.key(for: current)]
                let typeString = day?.dayType.shortLabel ?? "Unlogged"
                let office = day?.officeName ?? ""
                let weekOfYear = calendar.component(.weekOfYear, from: current)
                lines.append("\(weekOfYear),\(formatter.string(from: current)),\(weekdayFormatter.string(from: current)),\(csvField(typeString)),\(csvField(office))")
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }

        lines.append("")
        lines.append("Quarter,Credited Days,Target,Delta")
        for quarter in QuarterHelper.allQuarters(for: year) {
            let count = officeDayCount(in: quarter)
            let delta = count - QuarterHelper.targetDaysPerQuarter
            let sign = delta >= 0 ? "+" : ""
            lines.append("\(quarter.label),\(count),\(QuarterHelper.targetDaysPerQuarter),\(sign)\(delta)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Import

    func importOfficeDays(dates: [Date]) {
        var inserted = false
        for date in dates {
            let normalizedDate = Calendar.current.startOfDay(for: date)
            if attendanceDay(for: normalizedDate) == nil {
                let day = AttendanceDay(date: normalizedDate, dayType: .office, isManualOverride: true)
                modelContext.insert(day)
                inserted = true
            }
        }

        if inserted {
            saveAndRefresh(userMessage: "Unable to import the selected office days.")
        }
    }

    // MARK: - Velocity Helpers

    func futureHolidaysInQuarter() -> Int {
        let quarter = QuarterHelper.quarterInfo(for: Date())
        let todayKey = AttendanceDay.key(for: Calendar.current.startOfDay(for: Date()))
        let endKey = AttendanceDay.key(for: quarter.endDate)
        let holidayType = DayType.holiday.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dayTypeRaw == holidayType && $0.dateKey >= todayKey && $0.dateKey <= endKey
            }
        )
        return fetchCount(descriptor, userMessage: "Unable to count remaining holidays.")
    }

    func futureVacationsInQuarter() -> Int {
        let quarter = QuarterHelper.quarterInfo(for: Date())
        let todayKey = AttendanceDay.key(for: Calendar.current.startOfDay(for: Date()))
        let endKey = AttendanceDay.key(for: quarter.endDate)
        let vacationType = DayType.vacation.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dayTypeRaw == vacationType && $0.dateKey >= todayKey && $0.dateKey <= endKey
            }
        )
        return fetchCount(descriptor, userMessage: "Unable to count remaining vacations.")
    }

    // MARK: - Office Management

    func updateOfficeRadius(office: OfficeLocation, radiusInFeet: Double) {
        office.geofenceRadius = radiusInFeet * 0.3048
        saveChanges("Unable to update the office radius.")
    }

    func toggleOfficeEnabled(office: OfficeLocation) {
        office.isEnabled.toggle()
        saveChanges("Unable to update office tracking.")
    }

    // MARK: - Helpers

    private func seedOffices() {
        let descriptor = FetchDescriptor<OfficeLocation>()
        let count = fetchCount(descriptor, userMessage: "Unable to load office locations.")
        guard count == 0 else { return }

        for (name, address, latitude, longitude) in OfficeLocation.defaultOffices {
            let office = OfficeLocation(
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude
            )
            modelContext.insert(office)
        }
        saveChanges("Unable to seed office locations.")
    }

    private func migrateLegacyHolidays() {
        let descriptor = FetchDescriptor<Holiday>(sortBy: [SortDescriptor(\.date)])
        let legacyHolidays = fetch(descriptor, userMessage: "Unable to load legacy holidays.")
        guard !legacyHolidays.isEmpty else { return }

        var changed = false
        for holiday in legacyHolidays {
            if let existingDay = attendanceDay(for: holiday.date) {
                if existingDay.dayType == .holiday {
                    existingDay.holidayName = holiday.name
                    existingDay.updatedAt = Date()
                    changed = true
                }
            } else {
                let day = AttendanceDay(
                    date: holiday.date,
                    dayType: .holiday,
                    holidayName: holiday.name
                )
                modelContext.insert(day)
                changed = true
            }
        }

        if changed {
            saveChanges("Unable to migrate older holiday records.")
        }
    }

    private func applyDayType(date: Date, type: DayType, notes: String?) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let holidayName = type == .holiday
            ? notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        if let existing = attendanceDay(for: normalizedDate) {
            existing.dayType = type
            existing.officeName = type == .office ? existing.officeName : nil
            existing.holidayName = holidayName?.isEmpty == false ? holidayName : nil
            existing.isAutoLogged = false
            existing.isManualOverride = true
            existing.notes = type == .holiday ? nil : notes
            existing.updatedAt = Date()
        } else {
            let day = AttendanceDay(
                date: normalizedDate,
                dayType: type,
                holidayName: holidayName?.isEmpty == false ? holidayName : nil,
                isManualOverride: true,
                notes: type == .holiday ? nil : notes
            )
            modelContext.insert(day)
        }
    }

    @discardableResult
    private func saveAndRefresh(userMessage: String) -> Bool {
        let didSave = saveChanges(userMessage)
        invalidateMonthCache()
        refreshSnapshot()
        return didSave
    }

    @discardableResult
    private func saveChanges(_ userMessage: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            report(error, userMessage: userMessage)
            return false
        }
    }

    private func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>, userMessage: String) -> [Model] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            report(error, userMessage: userMessage)
            return []
        }
    }

    private func fetchCount<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>, userMessage: String) -> Int {
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            report(error, userMessage: userMessage)
            return 0
        }
    }

    private func report(_ error: Error, userMessage: String) {
        logger.error("\(userMessage, privacy: .public) \(error.localizedDescription, privacy: .public)")
        lastErrorMessage = userMessage
    }

    private func quarterBounds(for quarter: QuarterHelper.QuarterInfo) -> (String, String) {
        (AttendanceDay.key(for: quarter.startDate), AttendanceDay.key(for: quarter.endDate))
    }
}
