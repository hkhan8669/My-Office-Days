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

        /// Credited days up to and including today, respecting user preferences
        var targetDays: Int {
            let types = AppPreferences.dayTypesCountingTowardTarget
            var total = officeDays // office always counts
            if types.contains("freeDay") { total += officeCreditDays }
            if types.contains("travel") { total += travelDays }
            if types.contains("holiday") { total += holidayDays }
            if types.contains("vacation") { total += vacationDays }
            return total
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
            let types = AppPreferences.dayTypesCountingTowardTarget
            var total = officeDays
            if types.contains("freeDay") { total += officeCreditDays }
            if types.contains("travel") { total += travelDays }
            if types.contains("holiday") { total += holidayDays }
            if types.contains("vacation") { total += vacationDays }
            return total
        }

        var delta: Int { targetDays - PeriodHelper.targetDaysPerPeriod }
    }

    private(set) var currentQuarterSnapshot = QuarterSnapshot()
    private(set) var monthCache: [String: AttendanceDay] = [:]
    private var cachedMonthKey = ""
    var lastErrorMessage: String?

    var targetDaysPerPeriod: Int {
        PeriodHelper.targetDaysPerPeriod
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

        if AppPreferences.holidaysEnabled {
            let currentYear = Calendar.current.component(.year, from: Date())
            for year in (currentYear - 1)...(currentYear + 2) {
                ensureHolidays(for: year)
            }
        }

        resolveStaleEntries()
        refreshSnapshot()
    }

    func ensureHolidays(for year: Int) {
        var inserted = false
        for holiday in Holiday.federalHolidays(for: year) {
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
        let period = PeriodHelper.currentPeriod()
        let startKey = AttendanceDay.key(for: period.startDate)
        let endKey = AttendanceDay.key(for: period.endDate)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey
            }
        )
        let days = fetch(descriptor, userMessage: "Unable to refresh the current period.")

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
                    // Only count future days as upcoming credit if the type counts toward target
                    if day.dayType.countsTowardTarget {
                        snapshot.futureCreditedDays += 1
                    }
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

    func officeDays(in period: PeriodInfo) -> [AttendanceDay] {
        let officeType = DayType.office.rawValue
        let (startKey, endKey) = periodBounds(for: period)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey && $0.dayTypeRaw == officeType
            }
        )
        return fetch(descriptor, userMessage: "Unable to load office-day totals.")
    }

    func allDays(in period: PeriodInfo) -> [AttendanceDay] {
        let (startKey, endKey) = periodBounds(for: period)
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey
            }
        )
        return fetch(descriptor, userMessage: "Unable to load period details.")
    }

    func officeDayCount(in period: PeriodInfo) -> Int {
        periodStats(in: period).targetDays
    }

    func periodStats(in period: PeriodInfo) -> QuarterStats {
        let days = allDays(in: period)
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

    func dayCount(of type: DayType, in period: PeriodInfo) -> Int {
        let (startKey, endKey) = periodBounds(for: period)
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dateKey >= startKey && $0.dateKey <= endKey && $0.dayTypeRaw == typeRaw
            }
        )
        return fetchCount(descriptor, userMessage: "Unable to count quarter days.")
    }

    func delta(in period: PeriodInfo) -> Int {
        officeDayCount(in: period) - PeriodHelper.targetDaysPerPeriod
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

    /// Auto-populate planned days for selected work days from today through end of year.
    /// Skips dates that already have an entry (office, vacation, holiday, etc.).
    func autoPopulatePlannedDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: Date())
        let endOfYear = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31))!

        let workDays = AppPreferences.workDays

        // Remove existing auto-planned days (non-manual-override planned) from today onward
        let todayKey = AttendanceDay.key(for: today)
        let endKey = AttendanceDay.key(for: endOfYear)
        let plannedType = DayType.planned.rawValue
        let removeDescriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dayTypeRaw == plannedType && $0.dateKey >= todayKey && $0.dateKey <= endKey && $0.isManualOverride == false
            }
        )
        let existingAutoPlanned = fetch(removeDescriptor, userMessage: "Unable to clear auto-planned days.")
        for day in existingAutoPlanned {
            modelContext.delete(day)
        }

        // Populate planned days from today onward, skipping any date that already has an entry
        var current = today
        var inserted = false
        while current <= endOfYear {
            let weekday = calendar.component(.weekday, from: current)
            if workDays.contains(weekday) {
                if attendanceDay(for: current) == nil {
                    let day = AttendanceDay(date: current, dayType: .planned, isManualOverride: false)
                    modelContext.insert(day)
                    inserted = true
                }
            }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        if inserted || !existingAutoPlanned.isEmpty {
            saveAndRefresh(userMessage: "Unable to auto-populate planned days.")
        }
    }

    /// Remove all auto-seeded holiday entries (non-manual-override holidays).
    func removeAllAutoHolidays() {
        let holidayType = DayType.holiday.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dayTypeRaw == holidayType && $0.isManualOverride == false
            }
        )
        let holidays = fetch(descriptor, userMessage: "Unable to load holidays for removal.")
        guard !holidays.isEmpty else { return }
        for day in holidays {
            modelContext.delete(day)
        }
        saveAndRefresh(userMessage: "Unable to remove holidays.")
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
        modelContext.delete(office)
        saveChanges("Unable to delete the office location.")
    }

    func setTargetDaysPerPeriod(_ days: Int) {
        AppPreferences.setTargetDaysPerPeriod(days)
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
            invalidateMonthCache()
        }
    }

    // MARK: - Spreadsheet Export

    func exportSpreadsheet(year: Int) -> String {
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
        let days = fetch(descriptor, userMessage: "Unable to prepare the export.")
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.dateKey, $0) })

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"

        func escapeHTML(_ string: String) -> String {
            string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }

        func typeColor(_ type: DayType?) -> String {
            guard let t = type else { return "#F3F4F6" }
            switch t {
            case .office: return "#DBEAFE"
            case .planned: return "#FEF3C7"
            case .vacation: return "#D1FAE5"
            case .holiday: return "#EDE9FE"
            case .freeDay: return "#E0F2FE"
            case .travel: return "#FEE2E2"
            case .remote: return "#F3F4F6"
            }
        }

        var html = """
        <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">
        <head><meta charset="utf-8">
        <style>
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }
        th { background: #1E3A5F; color: white; font-weight: 600; padding: 10px 14px; text-align: left; font-size: 13px; }
        td { padding: 8px 14px; border-bottom: 1px solid #E5E7EB; font-size: 13px; }
        tr:nth-child(even) td { background: #F9FAFB; }
        .title { font-size: 22px; font-weight: 700; color: #1E3A5F; margin-bottom: 4px; }
        .subtitle { font-size: 13px; color: #6B7280; margin-bottom: 20px; }
        .type-badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-weight: 500; font-size: 12px; }
        .section-title { font-size: 16px; font-weight: 600; color: #1E3A5F; margin: 24px 0 8px 0; }
        .summary-table th { background: #374151; }
        .ahead { color: #059669; font-weight: 600; }
        .behind { color: #DC2626; font-weight: 600; }
        .even { color: #6B7280; font-weight: 600; }
        </style>
        </head><body>
        <div class="title">My Office Days — \(year)</div>
        <div class="subtitle">Exported \(formatter.string(from: Date())) · \(AppPreferences.trackingPeriod.label) tracking · Target: \(PeriodHelper.targetDaysPerPeriod) days per \(AppPreferences.trackingPeriod.shortLabel.lowercased())</div>
        <table>
        <tr><th>Week</th><th>Date</th><th>Day</th><th>Type</th><th>Office / Notes</th></tr>
        """

        var current = startOfYear
        while current <= endOfYear {
            if AppPreferences.isWorkDay(current) {
                let day = dayMap[AttendanceDay.key(for: current)]
                let typeString = day?.dayType.shortLabel ?? "Unlogged"
                let office = escapeHTML(day?.officeName ?? day?.holidayName ?? "")
                let weekOfYear = calendar.component(.weekOfYear, from: current)
                let bgColor = typeColor(day?.dayType)
                html += "<tr><td>\(weekOfYear)</td><td>\(formatter.string(from: current))</td><td>\(weekdayFormatter.string(from: current))</td><td><span class=\"type-badge\" style=\"background:\(bgColor)\">\(typeString)</span></td><td>\(office)</td></tr>\n"
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }

        html += "</table>\n"

        // Period summary
        let periodLabel = AppPreferences.trackingPeriod.shortLabel
        html += "<div class=\"section-title\">\(periodLabel) Summary</div>\n"
        html += "<table class=\"summary-table\"><tr><th>\(periodLabel)</th><th>Credited Days</th><th>Target</th><th>Delta</th></tr>\n"

        var yearTotal = 0
        for period in PeriodHelper.allPeriods(for: year) {
            let count = officeDayCount(in: period)
            yearTotal += count
            let target = PeriodHelper.targetDaysPerPeriod
            let delta = count - target
            let sign = delta >= 0 ? "+" : ""
            let cls = delta > 0 ? "ahead" : (delta < 0 ? "behind" : "even")
            html += "<tr><td><b>\(period.label)</b></td><td>\(count)</td><td>\(target)</td><td class=\"\(cls)\">\(sign)\(delta)</td></tr>\n"
        }

        let yearTarget = PeriodHelper.targetDaysPerPeriod * PeriodHelper.periodsPerYear
        let yearDelta = yearTotal - yearTarget
        let yearSign = yearDelta >= 0 ? "+" : ""
        let yearCls = yearDelta > 0 ? "ahead" : (yearDelta < 0 ? "behind" : "even")
        html += "<tr style=\"background:#F3F4F6;font-weight:600\"><td><b>Year Total</b></td><td>\(yearTotal)</td><td>\(yearTarget)</td><td class=\"\(yearCls)\">\(yearSign)\(yearDelta)</td></tr>\n"
        html += "</table>\n</body></html>"

        return html
    }

    /// Legacy CSV accessor
    func exportCSV(year: Int) -> String { exportSpreadsheet(year: year) }

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

    private func periodBounds(for period: PeriodInfo) -> (String, String) {
        (AttendanceDay.key(for: period.startDate), AttendanceDay.key(for: period.endDate))
    }
}
