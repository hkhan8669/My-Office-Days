import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            ) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func requestAuthorization(completion: @escaping (UNAuthorizationStatus, Error?) -> Void) {
        Task {
            do {
                _ = try await requestAuthorization()
                let status = await notificationAuthorizationStatus()
                completion(status, nil)
            } catch {
                let status = await notificationAuthorizationStatus()
                completion(status, error)
            }
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        Task {
            completion(await notificationAuthorizationStatus())
        }
    }

    func scheduleMondayNotificationIfAuthorized(
        officeDays: Int,
        target: Int,
        quarterLabel: String,
        completion: @escaping (Error?) -> Void
    ) {
        Task {
            let status = await notificationAuthorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else {
                completion(nil)
                return
            }

            do {
                try await scheduleMondayNotification(
                    officeDays: officeDays,
                    target: target,
                    quarterLabel: quarterLabel
                )
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func scheduleMondayNotification(officeDays: Int, target: Int, quarterLabel: String) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["monday-nudge"])

        let remaining = max(0, target - officeDays)
        let content = UNMutableNotificationContent()
        content.title = "My Office Days"
        content.body = remaining > 0
            ? "\(quarterLabel): \(officeDays)/\(target) days completed. \(remaining) remaining this quarter."
            : "\(quarterLabel): Target reached at \(officeDays)/\(target). Nice work."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 2
        components.hour = 8
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "monday-nudge",
            content: content,
            trigger: trigger
        )

        try await add(request)
    }

    func sendCheckInConfirmation(officeName: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "My Office Days"
        content.body = "You've arrived at \(officeName). Your attendance has been logged."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "checkin-\(AttendanceDay.key(for: Date()))",
            content: content,
            trigger: trigger
        )

        try await add(request)
    }

    func sendCheckInConfirmation(officeName: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await sendCheckInConfirmation(officeName: officeName)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func removeMondayNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["monday-nudge"])
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
