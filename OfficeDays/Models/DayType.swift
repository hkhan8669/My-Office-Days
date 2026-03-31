import SwiftUI

enum DayType: String, Codable, CaseIterable, Identifiable {
    case office
    case remote
    case holiday
    case vacation
    case planned
    case freeDay // repurposed as "Office Credit" — travel/offsite that counts toward target
    case travel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .office: "Office"
        case .remote: "Remote"
        case .holiday: "Holiday"
        case .vacation: "Vacation"
        case .planned: "Planned Office Day"
        case .freeDay: "Office Credit"
        case .travel: "Travel"
        }
    }

    var shortLabel: String {
        switch self {
        case .office: "Office"
        case .remote: "Remote"
        case .holiday: "Holiday"
        case .vacation: "Vacation"
        case .planned: "Planned"
        case .freeDay: "Credit"
        case .travel: "Travel"
        }
    }

    var icon: String {
        switch self {
        case .office: "building.2.fill"
        case .remote: "house.fill"
        case .holiday: "star.fill"
        case .vacation: "airplane"
        case .planned: "calendar.badge.clock"
        case .freeDay: "checkmark.seal.fill"
        case .travel: "car.fill"
        }
    }

    var letterCode: String {
        switch self {
        case .office: "O"
        case .remote: "R"
        case .holiday: "H"
        case .vacation: "V"
        case .planned: "P"
        case .freeDay: "C"
        case .travel: "T"
        }
    }

    var countsTowardTarget: Bool {
        self == .office || self == .freeDay || self == .travel || self == .holiday || self == .vacation
    }

    static var manualOptions: [DayType] {
        [.office, .remote, .holiday, .vacation, .planned, .freeDay, .travel]
    }
}
