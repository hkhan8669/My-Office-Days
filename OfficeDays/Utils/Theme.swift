import SwiftUI
import UIKit

enum Theme {
    // MARK: - Primary Palette

    /// Deep navy - main text, headers
    static let primary = Color.dynamic(light: 0x001E40, dark: 0xA7C8FF)
    /// Architectural blue - office days, CTAs
    static let primaryContainer = Color.dynamic(light: 0x003366, dark: 0x3A7BD5)
    /// Vibrant blue - logo, active states, links
    static let accent = Color.dynamic(light: 0x0064D2, dark: 0x5BC0EB)

    // MARK: - Surfaces

    /// Base canvas
    static let surface = Color.dynamic(light: 0xF8F9FB, dark: 0x111317)
    /// Secondary areas
    static let surfaceContainerLow = Color.dynamic(light: 0xF2F4F6, dark: 0x191C20)
    /// Cards, inputs
    static let surfaceContainer = Color.dynamic(light: 0xECEEF0, dark: 0x1E2126)
    static let surfaceContainerHigh = Color.dynamic(light: 0xE6E8EA, dark: 0x24272C)
    /// Table headers
    static let surfaceContainerHighest = Color.dynamic(light: 0xE0E3E5, dark: 0x2A2D33)
    /// Elevated cards
    static let surfaceContainerLowest = Color.dynamic(light: 0xFFFFFF, dark: 0x1A1D22)

    // MARK: - On-Surface / Text

    /// Primary text
    static let onSurface = Color.dynamic(light: 0x191C1E, dark: 0xE2E2E6)
    /// Secondary text
    static let onSurfaceVariant = Color.dynamic(light: 0x43474F, dark: 0xC3C6CF)
    /// Muted labels
    static let secondary = Color.dynamic(light: 0x4C616C, dark: 0x8E9DA7)

    // MARK: - Borders

    /// Subtle borders
    static let outline = Color.dynamic(light: 0x737780, dark: 0x8D9199)
    /// Ghost borders
    static let outlineVariant = Color.dynamic(light: 0xC3C6D1, dark: 0x43474E)

    // MARK: - Text Aliases

    static let textPrimary = onSurface
    static let textSecondary = onSurfaceVariant
    static let textTertiary = secondary

    // MARK: - Card / Surface Aliases

    static let cardBackground = surfaceContainerLowest
    static let cardBorder = outlineVariant

    // MARK: - Day Type Colors

    /// Office - architectural blue
    static let office = Color.dynamic(light: 0x003366, dark: 0x3A7BD5)
    /// Planned - amber
    static let planned = Color.dynamic(light: 0xF59E0B, dark: 0xFBBF24)
    /// Vacation - emerald green
    static let vacation = Color.dynamic(light: 0x10B981, dark: 0x34D399)
    /// Holiday - violet/purple
    static let holiday = Color.dynamic(light: 0x8B5CF6, dark: 0xA78BFA)
    /// Free day / credit - accent blue
    static let freeDay = Color.dynamic(light: 0x0064D2, dark: 0x5BC0EB)
    /// Travel - teal/cyan
    static let travel = Color.dynamic(light: 0x0891B2, dark: 0x22D3EE)
    /// Remote - gray
    static let remote = Color.dynamic(light: 0x9CA3AF, dark: 0xD1D5DB)

    // MARK: - Semantic / Status

    static let onTrack = accent
    static let ahead = vacation
    static let behind = Color.dynamic(light: 0xEF4444, dark: 0xFCA5A5)

    // MARK: - Day Type Mapping

    static func color(for dayType: DayType) -> Color {
        switch dayType {
        case .office: office
        case .remote: remote
        case .holiday: holiday
        case .vacation: vacation
        case .planned: planned
        case .freeDay: freeDay
        case .travel: travel
        }
    }

    // MARK: - Gradients

    /// Primary gradient - 135 degrees (topLeading to bottomTrailing)
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryContainer],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [surface, surfaceContainerLow],
        startPoint: .top,
        endPoint: .bottom
    )

}

// MARK: - Color Extensions

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                UIColor(
                    hex: traitCollection.userInterfaceStyle == .dark ? dark : light
                )
            }
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - Card Modifier

struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.cardBackground)
                    .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 14, padding: CGFloat = 20) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Press Effect

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
