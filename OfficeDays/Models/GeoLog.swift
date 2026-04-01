import Foundation
import SwiftData

@Model
final class GeoLog {
    enum EventType: String, Codable {
        case entry = "entry"
        case exit = "exit"
        case autoLogged = "autoLogged"
    }

    var timestamp: Date
    var locationName: String
    var eventTypeRaw: String

    @Transient
    var eventType: EventType {
        get { EventType(rawValue: eventTypeRaw) ?? .entry }
        set { eventTypeRaw = newValue.rawValue }
    }

    init(timestamp: Date, locationName: String, eventType: EventType) {
        self.timestamp = timestamp
        self.locationName = locationName
        self.eventTypeRaw = eventType.rawValue
    }
}
