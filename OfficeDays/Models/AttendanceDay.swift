import Foundation
import SwiftData

@Model
final class AttendanceDay {
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    @Attribute(.unique) var dateKey: String // "yyyy-MM-dd" for uniqueness
    var date: Date
    var dayTypeRaw: String // stored as String for SwiftData compatibility
    var officeName: String? // which office triggered the geofence
    var holidayName: String?
    var isAutoLogged: Bool // true if geofence triggered, false if manual
    var isManualOverride: Bool // true if user manually changed the value
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    @Transient
    var dayType: DayType {
        get { DayType(rawValue: dayTypeRaw) ?? .remote }
        set { dayTypeRaw = newValue.rawValue }
    }

    init(
        date: Date,
        dayType: DayType,
        officeName: String? = nil,
        holidayName: String? = nil,
        isAutoLogged: Bool = false,
        isManualOverride: Bool = false,
        notes: String? = nil
    ) {
        self.dateKey = AttendanceDay.key(for: date)
        self.date = Calendar.current.startOfDay(for: date)
        self.dayTypeRaw = dayType.rawValue
        self.officeName = officeName
        self.holidayName = holidayName
        self.isAutoLogged = isAutoLogged
        self.isManualOverride = isManualOverride
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    static func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }
}
