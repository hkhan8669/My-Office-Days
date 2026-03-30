import Combine
import CoreLocation
import Foundation
import Observation
import SwiftData
import UserNotifications

@Observable
@MainActor
final class TrackingManager {
    private let geofenceService: GeofenceService
    private var cancellables: Set<AnyCancellable> = []

    var locationAuthorizationStatus: CLAuthorizationStatus
    var notificationAuthorizationStatus: UNAuthorizationStatus
    var isAutoTrackingEnabled: Bool
    var isMonitoring: Bool
    var lastCheckedInOffice: String?
    var lastCheckInDate: Date?
    var lastErrorMessage: String?
    var statusMessage: String
    var isShowingOnboarding = false

    init(
        viewModel: AttendanceViewModel,
        modelContext: ModelContext,
        geofenceService: GeofenceService = GeofenceService()
    ) {
        self.geofenceService = geofenceService
        self.locationAuthorizationStatus = geofenceService.authorizationStatus
        self.notificationAuthorizationStatus = geofenceService.notificationAuthorizationStatus
        self.isAutoTrackingEnabled = geofenceService.isTrackingEnabled
        self.isMonitoring = geofenceService.isMonitoring
        self.lastCheckedInOffice = geofenceService.lastCheckedInOffice
        self.lastCheckInDate = geofenceService.lastCheckInDate
        self.lastErrorMessage = geofenceService.errorMessage
        self.statusMessage = geofenceService.statusMessage

        geofenceService.configure(
            modelContext: modelContext,
            officesProvider: { viewModel.offices() },
            onAttendanceChange: { viewModel.refreshSnapshot() }
        )

        geofenceService.$authorizationStatus
            .sink { [weak self] value in self?.locationAuthorizationStatus = value }
            .store(in: &cancellables)

        geofenceService.$notificationAuthorizationStatus
            .sink { [weak self] value in self?.notificationAuthorizationStatus = value }
            .store(in: &cancellables)

        geofenceService.$isMonitoring
            .sink { [weak self] value in self?.isMonitoring = value }
            .store(in: &cancellables)

        geofenceService.$lastCheckedInOffice
            .sink { [weak self] value in self?.lastCheckedInOffice = value }
            .store(in: &cancellables)

        geofenceService.$lastCheckInDate
            .sink { [weak self] value in self?.lastCheckInDate = value }
            .store(in: &cancellables)

        geofenceService.$errorMessage
            .sink { [weak self] value in self?.lastErrorMessage = value }
            .store(in: &cancellables)

        geofenceService.$statusMessage
            .sink { [weak self] value in self?.statusMessage = value }
            .store(in: &cancellables)
    }

    func bootstrap() {
        syncFromService()
        updateOnboardingState()
    }

    func handleAppDidBecomeActive() {
        geofenceService.handleAppDidBecomeActive()
        syncFromService()
        updateOnboardingState()
    }

    func setAutoTrackingEnabled(_ enabled: Bool) {
        AppPreferences.setHasSeenTrackingOnboarding(true)

        if enabled {
            geofenceService.enableTracking()
        } else {
            geofenceService.disableTracking()
        }

        syncFromService()
        updateOnboardingState()
    }

    func handleOfficeConfigurationChanged() {
        geofenceService.refreshMonitoring()
        syncFromService()
    }

    func dismissOnboarding() {
        AppPreferences.setHasSeenTrackingOnboarding(true)
        isShowingOnboarding = false
    }

    func clearLastError() {
        geofenceService.dismissError()
        lastErrorMessage = nil
    }

    var locationStatusText: String {
        switch locationAuthorizationStatus {
        case .authorizedAlways:
            return "Always allowed"
        case .authorizedWhenInUse:
            return "While Using the App"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
    }

    var notificationStatusText: String {
        switch notificationAuthorizationStatus {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
    }

    private func syncFromService() {
        locationAuthorizationStatus = geofenceService.authorizationStatus
        notificationAuthorizationStatus = geofenceService.notificationAuthorizationStatus
        isAutoTrackingEnabled = geofenceService.isTrackingEnabled
        isMonitoring = geofenceService.isMonitoring
        lastCheckedInOffice = geofenceService.lastCheckedInOffice
        lastCheckInDate = geofenceService.lastCheckInDate
        lastErrorMessage = geofenceService.errorMessage
        statusMessage = geofenceService.statusMessage
    }

    private func updateOnboardingState() {
        isShowingOnboarding = !AppPreferences.hasSeenTrackingOnboarding
    }
}
