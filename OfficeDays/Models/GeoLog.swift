import Foundation
import SwiftData

@Model
final class GeoLog {
    enum EventType: String, Codable {
        case entry = "entry"
        case exit = "exit"
    }

    var timestamp: Date
    var locationName: String
    var eventTypeRaw: String

    @Transient
    var eventType: EventType {
        // Legacy "autoLogged" records are treated as entry
        get { EventType(rawValue: eventTypeRaw) ?? .entry }
        set { eventTypeRaw = newValue.rawValue }
    }

    init(timestamp: Date, locationName: String, eventType: EventType) {
        self.timestamp = timestamp
        self.locationName = locationName
        self.eventTypeRaw = eventType.rawValue
    }
}
