import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool

    // MARK: - Animation State

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var badgeOpacity: Double = 0
    @State private var versionOpacity: Double = 0
    @State private var activeDotIndex: Int = 0
    @State private var backgroundOpacity: Double = 0

    // Decorative shape animation
    @State private var shapeRotation: Double = 0
    @State private var shapeScale: CGFloat = 0.8

    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            Theme.surface
                .ignoresSafeArea()

            // Decorative background shapes
            decorativeShapes

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Icon container
                iconView
                    .padding(.bottom, 28)

                // Title
                titleView
                    .padding(.bottom, 10)

                // Subtitle
                subtitleView
                    .padding(.bottom, 40)

                // Loading dots
                loadingDots
                    .padding(.bottom, 12)

                Spacer()

                // Security badge
                securityBadge
                    .padding(.bottom, 16)

                // Version
                versionLabel
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            startEntryAnimations()
            scheduleDismissal()
        }
    }

    // MARK: - Subviews

    private var decorativeShapes: some View {
        GeometryReader { geo in
            // Top-left blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.06), Theme.accent.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -120, y: -100)
                .scaleEffect(shapeScale)
                .opacity(backgroundOpacity)

            // Bottom-right blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.primary.opacity(0.04), Theme.primary.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: geo.size.width - 160, y: geo.size.height - 240)
                .scaleEffect(shapeScale)
                .opacity(backgroundOpacity)

            // Top-right accent
            RoundedRectangle(cornerRadius: 40)
                .fill(Theme.accent.opacity(0.03))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(shapeRotation))
                .offset(x: geo.size.width - 80, y: -40)
                .opacity(backgroundOpacity)
        }
        .ignoresSafeArea()
    }

    private var iconView: some View {
        ZStack {
            // Outer glow
            RoundedRectangle(cornerRadius: 28)
                .fill(Theme.primary.opacity(0.08))
                .frame(width: 112, height: 112)

            // Icon container
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Theme.primary, Theme.primaryContainer],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
                .shadow(color: Theme.primary.opacity(0.1), radius: 4, y: 2)

            // Icon
            Image(systemName: "building.2.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
    }

    private var titleView: some View {
        Text("My Office Days")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.primary, Theme.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(titleOpacity)
            .offset(y: titleOffset)
    }

    private var subtitleView: some View {
        Text("OFFICE ATTENDANCE TRACKER")
            .font(.system(size: 11, weight: .semibold, design: .default))
            .tracking(3)
            .foregroundStyle(Theme.outline)
            .opacity(subtitleOpacity)
    }

    private var loadingDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(activeDotIndex == index ? Theme.accent : Theme.outlineVariant)
                    .frame(width: 8, height: 8)
                    .scaleEffect(activeDotIndex == index ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: activeDotIndex)
            }
        }
        .opacity(dotsOpacity)
        .onReceive(dotTimer) { _ in
            activeDotIndex = (activeDotIndex + 1) % 3
        }
    }

    private var securityBadge: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.accent)

                Text("Your data stays on this device")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.onSurface)
            }

            Text("Nothing is uploaded or shared — ever.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.onSurfaceVariant)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceContainerLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.accent.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(badgeOpacity)
    }

    private var versionLabel: some View {
        Text("V1.0.0")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Theme.outline.opacity(0.6))
            .opacity(versionOpacity)
    }

    // MARK: - Animations

    private func startEntryAnimations() {
        // Background shapes fade in
        withAnimation(.easeOut(duration: 0.8)) {
            backgroundOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            shapeScale = 1.05
            shapeRotation = 15
        }

        // Icon: spring in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Title: fade up
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            titleOpacity = 1.0
            titleOffset = 0
        }

        // Subtitle
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            subtitleOpacity = 1.0
        }

        // Dots
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            dotsOpacity = 1.0
        }

        // Badge
        withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
            badgeOpacity = 1.0
        }

        // Version
        withAnimation(.easeOut(duration: 0.3).delay(1.0)) {
            versionOpacity = 1.0
        }
    }

    private func scheduleDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isActive = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView(isActive: .constant(true))
}
