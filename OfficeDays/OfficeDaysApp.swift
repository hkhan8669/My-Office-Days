import SwiftUI
import SwiftData

@main
struct OfficeDaysApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            AttendanceDay.self,
            OfficeLocation.self,
            Holiday.self,
        ], isAutosaveEnabled: true)
    }
}
