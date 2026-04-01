import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("tracking.onboarding.complete") private var hasCompletedTrackingOnboarding = false

    @State private var viewModel: AttendanceViewModel?
    @StateObject private var geofenceService = GeofenceService()
    @State private var showTrackingOnboarding = false
    @State private var showSplash = true
    @State private var showViewModelError = false
    @State private var showTrackingError = false

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    MainTabView(viewModel: viewModel, geofenceService: geofenceService)

                    if showSplash {
                        SplashView(isActive: $showSplash)
                            .transition(.opacity)
                    }

                    // Blocking overlay when Always permission is required
                    if geofenceService.requiresAlwaysPermission && !showSplash {
                        AlwaysLocationRequiredView(geofenceService: geofenceService)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: showSplash)
                .animation(.easeInOut(duration: 0.3), value: geofenceService.requiresAlwaysPermission)
                .sheet(isPresented: $showTrackingOnboarding) {
                    TrackingOnboardingView(
                        geofenceService: geofenceService,
                        onEnable: {
                            geofenceService.enableTracking()
                            hasCompletedTrackingOnboarding = true
                            showTrackingOnboarding = false
                        },
                        onSkip: {
                            hasCompletedTrackingOnboarding = true
                            showTrackingOnboarding = false
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .onChange(of: viewModel.lastErrorMessage) { _, newValue in
                    showViewModelError = newValue != nil
                }
                .onChange(of: geofenceService.errorMessage) { _, newValue in
                    showTrackingError = newValue != nil
                }
                .alert("Unable to complete action", isPresented: $showViewModelError) {
                    Button("OK") { viewModel.clearError() }
                } message: {
                    Text(viewModel.lastErrorMessage ?? "")
                }
                .alert("Tracking issue", isPresented: $showTrackingError) {
                    Button("OK") { geofenceService.dismissError() }
                } message: {
                    Text(geofenceService.errorMessage ?? "")
                }
            } else {
                Color(hex: 0xF8F9FB).ignoresSafeArea()
            }
        }
        .task {
            guard viewModel == nil else { return }
            let vm = AttendanceViewModel(modelContext: modelContext)
            vm.seedIfNeeded()
            viewModel = vm
            syncServices(using: vm)
            if !hasCompletedTrackingOnboarding {
                showTrackingOnboarding = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let viewModel else { return }
            viewModel.seedIfNeeded()
            geofenceService.handleAppDidBecomeActive()
        }
    }

    private func syncServices(using viewModel: AttendanceViewModel) {
        geofenceService.configure(
            modelContext: modelContext,
            officesProvider: { viewModel.offices() },
            onAttendanceChange: { viewModel.refreshSnapshot() }
        )
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel, geofenceService: geofenceService)
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.3.group")
                }

            CalendarTabView(viewModel: viewModel)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            InsightsView(viewModel: viewModel)
                .tabItem {
                    Label("Log", systemImage: "list.clipboard")
                }

            SettingsView(viewModel: viewModel, geofenceService: geofenceService)
                .tabItem {
                    Label("Setup", systemImage: "gearshape")
                }
        }
        .tint(Theme.accent)
    }
}

// MARK: - Tracking Onboarding

private struct TrackingOnboardingView: View {
    @ObservedObject var geofenceService: GeofenceService
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enable Auto Tracking")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.textPrimary)

                        Text("Office Days can detect enabled offices in the background, log the day as soon as you arrive, and keep weekly reminders in sync with your pace.")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    VStack(spacing: 12) {
                        onboardingCard(
                            icon: "location.fill",
                            color: Theme.accent,
                            title: "Always location",
                            subtitle: "Needed for reliable background office arrivals."
                        )
                        onboardingCard(
                            icon: "bell.badge.fill",
                            color: Theme.planned,
                            title: "Notifications",
                            subtitle: "Used for Monday reminders and check-in confirmations."
                        )
                        onboardingCard(
                            icon: "building.2.fill",
                            color: Theme.vacation,
                            title: "Office controls",
                            subtitle: "You can disable offices or change radiuses later in Setup."
                        )
                    }

                    Spacer(minLength: 0)

                    Button {
                        onEnable()
                    } label: {
                        Text("Enable tracking")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.primaryGradient)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button("Not now") {
                        onSkip()
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .padding(24)
            }
            .background(Theme.surfaceGradient.ignoresSafeArea())
            .navigationTitle("Tracking")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func onboardingCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surfaceContainerLow)
                .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Always Location Required

private struct AlwaysLocationRequiredView: View {
    @ObservedObject var geofenceService: GeofenceService

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Theme.behind.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Theme.behind)
                }

                VStack(spacing: 8) {
                    Text("Location Set to \"Always\"")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Office Days requires \"Always\" location access to detect when you arrive at the office — even when the app is closed or your phone restarts.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Open **Settings** below")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Tap **Location** → **Always**")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "3.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Come back — tracking resumes automatically")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 8)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.headline)
                        Text("Open Settings")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.primaryGradient)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    geofenceService.disableTracking()
                } label: {
                    Text("Disable Tracking Instead")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.cardBackground)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            )
            .padding(.horizontal, 24)
        }
    }
}
