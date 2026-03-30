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

    static let defaultOffices: [(String, String, Double, Double)] = [
        ("Newark, DE (HQ)", "300 Continental Drive, Newark, DE 19713", 39.6685, -75.7506),
        ("New Castle, DE", "New Castle, DE 19720", 39.6582, -75.5663),
        ("Indianapolis, IN", "8425 Woodfield Crossing Blvd, Indianapolis, IN 46240", 39.9098, -86.1121),
        ("Newton, MA", "95 Wells Ave, Newton, MA 02459", 42.3318, -71.2108),
        ("Sterling, VA", "21000 Atlantic Blvd, Sterling, VA", 39.0066, -77.4291),
        ("Reston, VA", "12061 Bluemont Way, Reston, VA", 38.9531, -77.3503),
        ("Salt Lake City, UT", "175 S West Temple, Suite 600, Salt Lake City, UT 84101", 40.7641, -111.8961),
    ]
}
