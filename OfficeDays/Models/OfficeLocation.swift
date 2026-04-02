import Foundation
import SwiftData
import CoreLocation

@Model
final class OfficeLocation {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var geofenceRadius: Double // meters (200-300)
    var isEnabled: Bool
    var isCustom: Bool

    init(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        geofenceRadius: Double = 250,
        isEnabled: Bool = true,
        isCustom: Bool = false
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.geofenceRadius = geofenceRadius
        self.isEnabled = isEnabled
        self.isCustom = isCustom
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var region: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: geofenceRadius,
            identifier: name
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    static let defaultOffices: [(String, String, Double, Double)] = []
}
