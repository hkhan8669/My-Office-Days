import SwiftUI
import SwiftData

@main
struct OfficeDaysApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: AttendanceDay.self, OfficeLocation.self, Holiday.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            container = try! ModelContainer(
                for: AttendanceDay.self, OfficeLocation.self, Holiday.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
