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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        applyDayType(date: date, type: .holiday, notes: trimmed)
        saveAndRefresh(userMessage: "Unable to add the holiday.")
    }

    /// Add a holiday on the same month/day for multiple subsequent years.
    func addHolidayRepeating(date: Date, name: String, throughYear: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let calendar = Calendar.current
        let baseYear = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        for year in baseYear...throughYear {
            if let yearDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                let normalized = calendar.startOfDay(for: yearDate)
                // Skip if a non-holiday entry already exists
                if let existing = attendanceDay(for: normalized), existing.dayType != .holiday {
                    continue
                }
                applyDayType(date: normalized, type: .holiday, notes: trimmed)
            }
        }
        saveAndRefresh(userMessage: "Unable to add recurring holidays.")
    }

    func deleteHoliday(_ holiday: ManagedHoliday) {
        if let day = attendanceDay(for: holiday.date), day.dayType == .holiday {
            modelContext.delete(day)
        }
        saveAndRefresh(userMessage: "Unable to delete the holiday.")
    }

    /// Delete all holidays with the same name across all years.
    func deleteHolidayAllYears(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let holidayType = DayType.holiday.rawValue
        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate {
                $0.dayTypeRaw == holidayType
            }
        )
        let allHolidays = fetch(descriptor, userMessage: "Unable to find holidays.")
        for day in allHolidays where day.holidayName == name {
            modelContext.delete(day)
        }
        saveAndRefresh(userMessage: "Unable to delete holidays.")
    }

    /// Auto-populate planned days for selected work days from today through end of year.
    /// Skips dates that already have an entry (office, vacation, holiday, etc.).
    func autoPopulatePlannedDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: Date())
        guard let endOfYear = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31)) else { return }

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
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
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
        let today = calendar.startOfDay(for: Date())
        let startKey = AttendanceDay.key(for: startOfYear)
        let todayKey = AttendanceDay.key(for: today)

        let descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate { $0.dateKey >= startKey && $0.dateKey <= todayKey }
        )
        let days = fetch(descriptor, userMessage: "Unable to prepare the export.")
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.dateKey, $0) })

        let geoDescriptor = FetchDescriptor<GeoLog>(
            predicate: #Predicate { $0.eventTypeRaw == "autoLogged" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let geoLogs = (try? modelContext.fetch(geoDescriptor)) ?? []
        var checkInTimes: [String: Date] = [:]
        for log in geoLogs {
            let key = AttendanceDay.key(for: log.timestamp)
            if checkInTimes[key] == nil { checkInTimes[key] = log.timestamp }
        }

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "MMM d, yyyy"
        let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEEE"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "h:mm a"

        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }

        func styleID(_ type: DayType) -> String {
            switch type {
            case .office: return "office"
            case .vacation: return "vacation"
            case .holiday: return "holiday"
            case .travel: return "travel"
            case .freeDay: return "freeDay"
            case .planned: return "planned"
            case .remote: return "remote"
            }
        }

        // ── XML Spreadsheet with tabs ──
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
        <Styles>
         <Style ss:ID="Default"><Font ss:Size="11"/></Style>
         <Style ss:ID="header"><Font ss:Bold="1" ss:Color="#FFFFFF" ss:Size="11"/><Interior ss:Color="#1E3A5F" ss:Pattern="Solid"/></Style>
         <Style ss:ID="summaryHeader"><Font ss:Bold="1" ss:Color="#FFFFFF" ss:Size="11"/><Interior ss:Color="#374151" ss:Pattern="Solid"/></Style>
         <Style ss:ID="bold"><Font ss:Bold="1" ss:Size="11"/></Style>
         <Style ss:ID="time"><Font ss:Color="#6B7280" ss:Size="10"/></Style>
         <Style ss:ID="autoGeo"><Font ss:Bold="1" ss:Color="#1D4ED8" ss:Size="10"/><Interior ss:Color="#DBEAFE" ss:Pattern="Solid"/></Style>
         <Style ss:ID="manual"><Font ss:Bold="1" ss:Color="#6B7280" ss:Size="10"/><Interior ss:Color="#F3F4F6" ss:Pattern="Solid"/></Style>
         <Style ss:ID="office"><Font ss:Bold="1" ss:Color="#1E40AF" ss:Size="10"/><Interior ss:Color="#DBEAFE" ss:Pattern="Solid"/></Style>
         <Style ss:ID="travel"><Font ss:Bold="1" ss:Color="#991B1B" ss:Size="10"/><Interior ss:Color="#FEE2E2" ss:Pattern="Solid"/></Style>
         <Style ss:ID="vacation"><Font ss:Bold="1" ss:Color="#065F46" ss:Size="10"/><Interior ss:Color="#D1FAE5" ss:Pattern="Solid"/></Style>
         <Style ss:ID="holiday"><Font ss:Bold="1" ss:Color="#5B21B6" ss:Size="10"/><Interior ss:Color="#EDE9FE" ss:Pattern="Solid"/></Style>
         <Style ss:ID="freeDay"><Font ss:Bold="1" ss:Color="#0C4A6E" ss:Size="10"/><Interior ss:Color="#E0F2FE" ss:Pattern="Solid"/></Style>
         <Style ss:ID="planned"><Font ss:Bold="1" ss:Color="#92400E" ss:Size="10"/><Interior ss:Color="#FEF3C7" ss:Pattern="Solid"/></Style>
         <Style ss:ID="remote"><Font ss:Bold="1" ss:Color="#374151" ss:Size="10"/><Interior ss:Color="#F3F4F6" ss:Pattern="Solid"/></Style>
         <Style ss:ID="totalRow"><Font ss:Bold="1" ss:Size="11"/><Interior ss:Color="#F3F4F6" ss:Pattern="Solid"/></Style>
         <Style ss:ID="ahead"><Font ss:Bold="1" ss:Color="#059669" ss:Size="11"/></Style>
         <Style ss:ID="behind"><Font ss:Bold="1" ss:Color="#DC2626" ss:Size="11"/></Style>
         <Style ss:ID="even"><Font ss:Bold="1" ss:Color="#6B7280" ss:Size="11"/></Style>
        </Styles>
        """

        // ── Tab 1: Daily Log ──
        xml += "<Worksheet ss:Name=\"Daily Log\"><Table>"
        xml += "<Column ss:Width=\"100\"/><Column ss:Width=\"80\"/><Column ss:Width=\"70\"/>"
        xml += "<Column ss:Width=\"80\"/><Column ss:Width=\"130\"/><Column ss:Width=\"80\"/>"
        xml += "<Row>"
        xml += "<Cell ss:StyleID=\"header\"><Data ss:Type=\"String\">Date</Data></Cell>"
        xml += "<Cell ss:StyleID=\"header\"><Data ss:Type=\"String\">Day</Data></Cell>"
        xml += "<Cell ss:StyleID=\"header\"><Data ss:Type=\"String\">Check-in</Data></Cell>"
        xml += "<Cell ss:StyleID=\"header\"><Data ss:Type=\"String\">Status</Data></Cell>"
        xml += "<Cell ss:StyleID=\"header\"><Data ss:Type=\"String\">Location</Data></Cell>"
        xml += "<Cell ss:StyleID=\"header\"><Data ss:Type=\"String\">Logged By</Data></Cell>"
        xml += "</Row>\n"

        var current = startOfYear
        while current <= today {
            let key = AttendanceDay.key(for: current)
            if AppPreferences.isWorkDay(current), let day = dayMap[key] {
                if day.dayType != .planned && day.dayType != .remote {
                    let location: String
                    switch day.dayType {
                    case .office: location = esc(day.officeName ?? "Office")
                    case .holiday: location = esc(day.holidayName ?? "Holiday")
                    case .vacation: location = "—"
                    case .travel: location = esc(day.officeName ?? "Travel")
                    case .freeDay: location = esc(day.officeName ?? "—")
                    default: location = "—"
                    }

                    let checkIn = checkInTimes[key].map { timeFmt.string(from: $0) } ?? ""
                    let logStyle = day.isAutoLogged ? "autoGeo" : "manual"
                    let logLabel = day.isAutoLogged ? "Auto (Geo)" : "Manual"

                    xml += "<Row>"
                    xml += "<Cell><Data ss:Type=\"String\">\(esc(dateFmt.string(from: current)))</Data></Cell>"
                    xml += "<Cell><Data ss:Type=\"String\">\(esc(dayFmt.string(from: current)))</Data></Cell>"
                    xml += "<Cell ss:StyleID=\"time\"><Data ss:Type=\"String\">\(esc(checkIn))</Data></Cell>"
                    xml += "<Cell ss:StyleID=\"\(styleID(day.dayType))\"><Data ss:Type=\"String\">\(esc(day.dayType.label))</Data></Cell>"
                    xml += "<Cell><Data ss:Type=\"String\">\(location)</Data></Cell>"
                    xml += "<Cell ss:StyleID=\"\(logStyle)\"><Data ss:Type=\"String\">\(logLabel)</Data></Cell>"
                    xml += "</Row>\n"
                }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDay
        }

        xml += "</Table></Worksheet>\n"

        // ── Tab 2: Summary ──
        xml += "<Worksheet ss:Name=\"Summary\"><Table>"
        xml += "<Column ss:Width=\"110\"/><Column ss:Width=\"70\"/><Column ss:Width=\"70\"/>"
        xml += "<Column ss:Width=\"70\"/><Column ss:Width=\"70\"/><Column ss:Width=\"70\"/><Column ss:Width=\"100\"/>"

        // Monthly summary
        xml += "<Row>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Month</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Office</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Travel</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Vacation</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Holidays</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Credit</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Total Credited</Data></Cell>"
        xml += "</Row>\n"

        let monthNames = DateFormatter().monthSymbols ?? []
        let currentMonth = calendar.component(.month, from: today)
        var yO = 0, yT = 0, yV = 0, yH = 0, yC = 0, yCr = 0

        for month in 1...currentMonth {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let cappedEnd = min(calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? monthStart, today)
            var o = 0, t = 0, v = 0, h = 0, c = 0
            var d = monthStart
            while d <= cappedEnd {
                if let day = dayMap[AttendanceDay.key(for: d)] {
                    switch day.dayType {
                    case .office: o += 1; case .travel: t += 1; case .vacation: v += 1
                    case .holiday: h += 1; case .freeDay: c += 1; default: break
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
            let types = AppPreferences.dayTypesCountingTowardTarget
            var cr = o
            if types.contains("travel") { cr += t }
            if types.contains("vacation") { cr += v }
            if types.contains("holiday") { cr += h }
            if types.contains("freeDay") { cr += c }
            yO += o; yT += t; yV += v; yH += h; yC += c; yCr += cr

            let name = month <= monthNames.count ? monthNames[month - 1] : "Month \(month)"
            xml += "<Row>"
            xml += "<Cell ss:StyleID=\"bold\"><Data ss:Type=\"String\">\(name)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"office\"><Data ss:Type=\"Number\">\(o)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"travel\"><Data ss:Type=\"Number\">\(t)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"vacation\"><Data ss:Type=\"Number\">\(v)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"holiday\"><Data ss:Type=\"Number\">\(h)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"freeDay\"><Data ss:Type=\"Number\">\(c)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"bold\"><Data ss:Type=\"Number\">\(cr)</Data></Cell>"
            xml += "</Row>\n"
        }

        xml += "<Row>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"String\">Year Total</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yO)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yT)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yV)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yH)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yC)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yCr)</Data></Cell>"
        xml += "</Row>\n"

        // Spacer then period summary
        xml += "<Row></Row><Row></Row>\n"
        let periodTarget = PeriodHelper.targetDaysPerPeriod
        let periodLabel = AppPreferences.trackingPeriod.shortLabel

        xml += "<Row>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">\(periodLabel)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Credited</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Target</Data></Cell>"
        xml += "<Cell ss:StyleID=\"summaryHeader\"><Data ss:Type=\"String\">Delta</Data></Cell>"
        xml += "</Row>\n"

        var yearTotal = 0
        for period in PeriodHelper.allPeriods(for: year) {
            guard period.startDate <= today else { continue }
            let count = officeDayCount(in: period)
            yearTotal += count
            let delta = count - periodTarget
            let sign = delta >= 0 ? "+" : ""
            let cls = delta > 0 ? "ahead" : (delta < 0 ? "behind" : "even")
            xml += "<Row>"
            xml += "<Cell ss:StyleID=\"bold\"><Data ss:Type=\"String\">\(esc(period.label))</Data></Cell>"
            xml += "<Cell><Data ss:Type=\"Number\">\(count)</Data></Cell>"
            xml += "<Cell><Data ss:Type=\"Number\">\(periodTarget)</Data></Cell>"
            xml += "<Cell ss:StyleID=\"\(cls)\"><Data ss:Type=\"String\">\(sign)\(delta)</Data></Cell>"
            xml += "</Row>\n"
        }

        let yearTarget = periodTarget * PeriodHelper.periodsPerYear
        let yearDelta = yearTotal - yearTarget
        let yearSign = yearDelta >= 0 ? "+" : ""
        let yearCls = yearDelta > 0 ? "ahead" : (yearDelta < 0 ? "behind" : "even")
        xml += "<Row>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"String\">Year Total</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yearTotal)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"totalRow\"><Data ss:Type=\"Number\">\(yearTarget)</Data></Cell>"
        xml += "<Cell ss:StyleID=\"\(yearCls)\"><Data ss:Type=\"String\">\(yearSign)\(yearDelta)</Data></Cell>"
        xml += "</Row>\n"

        xml += "</Table></Worksheet>\n</Workbook>"
        return xml
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
