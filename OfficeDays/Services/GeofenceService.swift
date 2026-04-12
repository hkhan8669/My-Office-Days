import CoreLocation
import Foundation
import SwiftData
import UIKit
import UserNotifications

@MainActor
final class GeofenceService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let notificationService: NotificationService
    private let userDefaults: UserDefaults
    private let now: () -> Date
    private let entryTimestampsKey = "tracking.entryTimestamps"
    private let lastCheckInOfficeKey = "tracking.lastCheckInOffice"
    private let lastCheckInDateKey = "tracking.lastCheckInDate"

    private var modelContext: ModelContext?
    private var officesProvider: (() -> [OfficeLocation])?
    private var attendanceRefreshHandler: (() -> Void)?
    private var entryTimestamps: [String: Date]

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var lastCheckedInOffice: String?
    @Published var lastCheckInDate: Date?
    @Published var isMonitoring = false
    @Published var errorMessage: String?
    @Published var statusMessage = "Auto tracking is off"
    @Published var requiresAlwaysPermission = false

    var isTrackingEnabled: Bool {
        AppPreferences.trackingEnabled
    }

    override init() {
        self.notificationService = .shared
        self.userDefaults = .standard
        self.now = Date.init
        self.entryTimestamps = Self.loadEntryTimestamps(from: .standard, key: "tracking.entryTimestamps")
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true

        lastCheckedInOffice = userDefaults.string(forKey: lastCheckInOfficeKey)
        lastCheckInDate = userDefaults.object(forKey: lastCheckInDateKey) as? Date
        refreshStatusMessage()
        refreshNotificationStatus()
    }

    func configure(
        modelContext: ModelContext,
        officesProvider: @escaping () -> [OfficeLocation],
        onAttendanceChange: @escaping () -> Void
    ) {
        self.modelContext = modelContext
        self.officesProvider = officesProvider
        self.attendanceRefreshHandler = onAttendanceChange
        refreshMonitoring()
        handleAppDidBecomeActive()
    }

    func enableTracking() {
        AppPreferences.setTrackingEnabled(true)
        requestAuthorization()
        requestNotificationAuthorization()
        scheduleWeeklyNudge()
        refreshMonitoring()
    }

    func disableTracking() {
        AppPreferences.setTrackingEnabled(false)
        requiresAlwaysPermission = false
        stopMonitoring()
        notificationService.removeWeeklyNudge()
        refreshStatusMessage()
    }

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestNotificationAuthorization() {
        notificationService.requestAuthorization { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationAuthorizationStatus = status
                if let error {
                    self.errorMessage = "Notification permission failed: \(error.localizedDescription)"
                }
                self.refreshStatusMessage()
            }
        }
    }

    func refreshMonitoring() {
        refreshNotificationStatus()

        guard AppPreferences.trackingEnabled else {
            stopMonitoring()
            return
        }

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            errorMessage = "Region monitoring is not available on this device."
            isMonitoring = false
            refreshStatusMessage()
            return
        }

        guard authorizationStatus == .authorizedAlways else {
            stopMonitoring(clearEntries: false)
            refreshStatusMessage()
            return
        }

        let offices = officesProvider?().filter(\.isEnabled) ?? []
        guard !offices.isEmpty else {
            stopMonitoring(clearEntries: false)
            refreshStatusMessage()
            return
        }

        // iOS allows max 20 monitored regions per app.
        let monitorableOffices = Array(offices.prefix(20))
        if offices.count > 20 {
            errorMessage = "Only the first 20 offices can be monitored. Please disable some offices."
        }

        // Only update regions that actually changed — avoid stop/restart
        // which resets iOS region state and drops pending exit events.
        let desiredRegions = Set(monitorableOffices.map(\.stableID))
        let currentRegions = Set(locationManager.monitoredRegions.compactMap(\.identifier))

        // Remove regions no longer needed
        for region in locationManager.monitoredRegions {
            if !desiredRegions.contains(region.identifier) {
                locationManager.stopMonitoring(for: region)
            }
        }

        // Add new regions not yet monitored
        for office in monitorableOffices {
            if !currentRegions.contains(office.stableID) {
                let region = office.region
                locationManager.startMonitoring(for: region)
            }
            // Always request state to catch up
            locationManager.requestState(for: office.region)
        }

        isMonitoring = true
        refreshStatusMessage()
    }

    func handleAppDidBecomeActive() {
        // Only clear entry timestamps from PREVIOUS days.
        // Same-day timestamps must persist to prevent duplicate GeoLog entries
        // when the user opens the app multiple times in one day.
        let todayStart = Calendar.current.startOfDay(for: now())
        for (office, timestamp) in entryTimestamps {
            if timestamp < todayStart {
                clearEntryTimestamp(for: office)
            }
        }

        authorizationStatus = locationManager.authorizationStatus
        refreshNotificationStatus()
        refreshMonitoring()
        scheduleWeeklyNudge()

        // Enforce "Always" permission when tracking is enabled.
        // If the user changed it to "While Using" or denied, flag it
        // so the UI can show a blocking prompt.
        if AppPreferences.trackingEnabled && authorizationStatus != .authorizedAlways {
            requiresAlwaysPermission = true
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .notDetermined {
                locationManager.requestAlwaysAuthorization()
            }
        } else {
            requiresAlwaysPermission = false
        }

        for region in locationManager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion {
                locationManager.requestState(for: circularRegion)
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedAlways {
            requiresAlwaysPermission = false
        } else if AppPreferences.trackingEnabled {
            requiresAlwaysPermission = true
            // When the user grants "When In Use" from the initial prompt, iOS requires
            // a second requestAlwaysAuthorization() call to show the upgrade prompt.
            if authorizationStatus == .authorizedWhenInUse {
                locationManager.requestAlwaysAuthorization()
            }
        }

        refreshMonitoring()
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            manager.requestState(for: circularRegion)
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        errorMessage = "Monitoring failed: \(error.localizedDescription)"
        refreshStatusMessage()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location failed: \(error.localizedDescription)"
        refreshStatusMessage()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        // Request background time to ensure saves complete before iOS kills the app.
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(taskID)
        }

        let regionID = circularRegion.identifier
        let name = officeName(for: regionID)

        persistEntryTimestamp(now(), for: regionID)
        recordGeoLog(eventType: .entry, locationName: name)
        logOfficeDayIfNeeded(officeName: name)
        sendArrivalNotification(officeName: name)

        UIApplication.shared.endBackgroundTask(taskID)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(taskID)
        }

        let regionID = circularRegion.identifier
        let name = officeName(for: regionID)

        recordGeoLog(eventType: .exit, locationName: name)
        clearEntryTimestamp(for: regionID)
        sendDepartureNotification(officeName: name)
        refreshStatusMessage()

        UIApplication.shared.endBackgroundTask(taskID)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(taskID)
        }

        let regionID = circularRegion.identifier
        let name = officeName(for: regionID)

        switch state {
        case .inside:
            let alreadyTracked = entryTimestamps[regionID] != nil
            if !alreadyTracked {
                persistEntryTimestamp(now(), for: regionID)
                // One GeoLog per office per day. Home office users never
                // trigger didEnterRegion (they never leave), so this is
                // their only path to get a log entry. The alreadyTracked
                // check prevents duplicates on subsequent app opens.
                recordGeoLog(eventType: .entry, locationName: name)
                sendArrivalNotification(officeName: name)
            }
            // Always log the attendance day (idempotent if already office).
            // This ensures manual Remote changes get overwritten by physical presence.
            logOfficeDayIfNeeded(officeName: name)
        case .outside:
            clearEntryTimestamp(for: regionID)
        default:
            break
        }

        UIApplication.shared.endBackgroundTask(taskID)
    }

    // MARK: - Private

    func scheduleWeeklyNudge() {
        guard AppPreferences.trackingEnabled, let context = modelContext else { return }

        let period = PeriodHelper.currentPeriod()
        let startKey = AttendanceDay.key(for: period.startDate)
        let endKey = AttendanceDay.key(for: period.endDate)
        // Fetch all non-remote day types in the period, then filter by user preferences
        var descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate { $0.dateKey >= startKey && $0.dateKey <= endKey && $0.dayTypeRaw != "remote" }
        )
        descriptor.fetchLimit = 500

        let allDays = (try? context.fetch(descriptor)) ?? []
        let officeDays = allDays.filter { $0.dayType.countsTowardTarget }.count
        let target = PeriodHelper.targetDaysPerPeriod

        notificationService.scheduleWeeklyNudgeIfAuthorized(
            officeDays: officeDays,
            target: target,
            periodLabel: period.label
        ) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = "Weekly nudge scheduling failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func stopMonitoring(clearEntries: Bool = true) {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        isMonitoring = false
        if clearEntries {
            entryTimestamps.removeAll()
            saveEntryTimestamps()
        }
        refreshStatusMessage()
    }

    private func refreshNotificationStatus() {
        notificationService.authorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationAuthorizationStatus = status
                self.refreshStatusMessage()
            }
        }
    }

    private func refreshStatusMessage() {
        if !AppPreferences.trackingEnabled {
            statusMessage = "Auto tracking is off"
            return
        }

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            statusMessage = "Location permission is blocked"
            return
        }

        if authorizationStatus != .authorizedAlways {
            statusMessage = "Set location to \"Always\" for arrival reminders in the background"
            return
        }

        let enabledOfficeCount = officesProvider?().filter(\.isEnabled).count ?? 0
        if enabledOfficeCount == 0 {
            statusMessage = "Enable at least one office to start tracking"
            return
        }

        if isMonitoring {
            statusMessage = "Tracking is active for \(enabledOfficeCount) office\(enabledOfficeCount == 1 ? "" : "s")"
        } else {
            statusMessage = "Tracking is waiting to start"
        }
    }

    private func logOfficeDayIfNeeded(officeName: String) {
        guard let context = modelContext else { return }
        let today = Calendar.current.startOfDay(for: now())
        let key = AttendanceDay.key(for: today)
        var descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate { $0.dateKey == key }
        )
        descriptor.fetchLimit = 1

        do {
            let existing = try context.fetch(descriptor).first

            // If already logged as office for THIS same office, nothing to do.
            if let existing, existing.dayType == .office, existing.officeName == officeName {
                return
            }

            // Never override a holiday — driving past the office on MLK Day
            // shouldn't destroy the holiday entry.
            if let existing, existing.dayType == .holiday {
                return
            }

            // Physical presence is the ground truth — if the geofence
            // detected you at an office, override whatever was set before
            // (vacation by mistake, travel, planned, remote, etc.).

            if let existing {
                existing.dayType = .office
                existing.officeName = officeName
                existing.holidayName = nil
                existing.notes = nil
                existing.isAutoLogged = true
                existing.isManualOverride = false
                existing.updatedAt = now()
            } else {
                let day = AttendanceDay(
                    date: today,
                    dayType: .office,
                    officeName: officeName,
                    isAutoLogged: true
                )
                context.insert(day)
            }

            try context.save()

            lastCheckedInOffice = officeName
            lastCheckInDate = now()
            userDefaults.set(officeName, forKey: lastCheckInOfficeKey)
            userDefaults.set(lastCheckInDate, forKey: lastCheckInDateKey)

            attendanceRefreshHandler?()
            refreshStatusMessage()
        } catch {
            errorMessage = "Attendance logging failed: \(error.localizedDescription)"
        }
    }

    /// Resolve a region stableID to the office name.
    /// Also checks by name for backward compatibility with old regions.
    private func officeName(for regionIdentifier: String) -> String {
        let offices = officesProvider?() ?? []
        // First try stableID match (new regions)
        if let office = offices.first(where: { $0.stableID == regionIdentifier }) {
            return office.name
        }
        // Fallback: try name match (old regions registered before stableID)
        if let office = offices.first(where: { $0.name == regionIdentifier }) {
            return office.name
        }
        return "Unknown Office"
    }

    private func sendDepartureNotification(officeName: String) {
        notificationService.sendDepartureConfirmation(officeName: officeName) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = "Departure notification failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func persistEntryTimestamp(_ date: Date, for officeName: String) {
        entryTimestamps[officeName] = date
        saveEntryTimestamps()
    }

    private func clearEntryTimestamp(for officeName: String) {
        entryTimestamps.removeValue(forKey: officeName)
        saveEntryTimestamps()
    }

    private func saveEntryTimestamps() {
        let payload = entryTimestamps.mapValues { $0.timeIntervalSince1970 }
        userDefaults.set(payload, forKey: entryTimestampsKey)
    }

    private func sendArrivalNotification(officeName: String) {
        notificationService.sendCheckInConfirmation(officeName: officeName) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = "Check-in notification failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func recordGeoLog(eventType: GeoLog.EventType, locationName: String) {
        guard let context = modelContext else { return }
        let log = GeoLog(timestamp: now(), locationName: locationName, eventType: eventType)
        context.insert(log)
        try? context.save()
    }

    private static func loadEntryTimestamps(from userDefaults: UserDefaults, key: String) -> [String: Date] {
        guard let stored = userDefaults.dictionary(forKey: key) as? [String: Double] else {
            return [:]
        }

        return stored.reduce(into: [:]) { result, entry in
            result[entry.key] = Date(timeIntervalSince1970: entry.value)
        }
    }
}
