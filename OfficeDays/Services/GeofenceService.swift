import CoreLocation
import Foundation
import SwiftData
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
        scheduleMondayReminder()
        refreshMonitoring()
    }

    func disableTracking() {
        AppPreferences.setTrackingEnabled(false)
        requiresAlwaysPermission = false
        stopMonitoring()
        notificationService.removeMondayNotification()
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

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        for office in offices {
            let region = office.region
            locationManager.startMonitoring(for: region)
            locationManager.requestState(for: region)
        }

        isMonitoring = true
        refreshStatusMessage()
    }

    func handleAppDidBecomeActive() {
        authorizationStatus = locationManager.authorizationStatus
        refreshNotificationStatus()
        refreshMonitoring()
        scheduleMondayReminder()

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
        guard DateHelper.isWeekday(now()) else { return }

        persistEntryTimestamp(now(), for: circularRegion.identifier)
        recordGeoLog(eventType: .entry, locationName: circularRegion.identifier)

        // Log the office day immediately on entry – no dwell wait.
        logOfficeDayIfNeeded(officeName: circularRegion.identifier)

        // Always notify on entry, even if the day was already logged.
        sendArrivalNotification(officeName: circularRegion.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        recordGeoLog(eventType: .exit, locationName: circularRegion.identifier)
        clearEntryTimestamp(for: circularRegion.identifier)
        refreshStatusMessage()
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        guard DateHelper.isWeekday(now()) else { return }

        switch state {
        case .inside:
            if entryTimestamps[circularRegion.identifier] == nil {
                persistEntryTimestamp(now(), for: circularRegion.identifier)
                recordGeoLog(eventType: .entry, locationName: circularRegion.identifier)
            }
            // Log immediately when detected inside
            logOfficeDayIfNeeded(officeName: circularRegion.identifier)
        case .outside:
            clearEntryTimestamp(for: circularRegion.identifier)
        default:
            break
        }
    }

    // MARK: - Private

    private func scheduleMondayReminder() {
        guard AppPreferences.trackingEnabled, let context = modelContext else { return }

        let quarter = QuarterHelper.quarterInfo(for: now())
        let startKey = AttendanceDay.key(for: quarter.startDate)
        let endKey = AttendanceDay.key(for: quarter.endDate)
        var descriptor = FetchDescriptor<AttendanceDay>(
            predicate: #Predicate { $0.dateKey >= startKey && $0.dateKey <= endKey && ($0.dayTypeRaw == "office" || $0.dayTypeRaw == "freeDay" || $0.dayTypeRaw == "travel") }
        )
        descriptor.fetchLimit = 200

        let officeDays = (try? context.fetch(descriptor).count) ?? 0
        let target = QuarterHelper.targetDaysPerQuarter

        notificationService.scheduleMondayNotificationIfAuthorized(
            officeDays: officeDays,
            target: target,
            quarterLabel: quarter.label
        ) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = "Monday reminder scheduling failed: \(error.localizedDescription)"
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
            statusMessage = "Allow Always Location to auto-log in the background"
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
            if let existing, existing.dayType == .office {
                return
            }

            // Allow geofence to override remote days even if manually set,
            // but respect manual overrides for other types (vacation, holiday, etc.)
            if let existing, existing.isManualOverride, existing.dayType != .remote {
                return
            }

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

            recordGeoLog(eventType: .autoLogged, locationName: officeName)

            lastCheckedInOffice = officeName
            lastCheckInDate = now()
            userDefaults.set(officeName, forKey: lastCheckInOfficeKey)
            userDefaults.set(lastCheckInDate, forKey: lastCheckInDateKey)

            attendanceRefreshHandler?()
            refreshStatusMessage()
        } catch {
            errorMessage = "Auto check-in failed: \(error.localizedDescription)"
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
