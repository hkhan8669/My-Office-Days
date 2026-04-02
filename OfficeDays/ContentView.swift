import MapKit
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
                .fullScreenCover(isPresented: $showTrackingOnboarding) {
                    OnboardingFlowView(
                        viewModel: viewModel,
                        geofenceService: geofenceService,
                        onComplete: {
                            hasCompletedTrackingOnboarding = true
                            showTrackingOnboarding = false
                            viewModel.autoPopulatePlannedDays()
                        }
                    )
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

// MARK: - Onboarding Flow

private struct OnboardingFlowView: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService
    let onComplete: () -> Void

    @State private var step = 0

    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // Preferences state
    @State private var selectedWorkDays: Set<Int> = AppPreferences.workDays
    @State private var holidaysEnabled = AppPreferences.holidaysEnabled
    @State private var travelCounts = AppPreferences.dayTypesCountingTowardTarget.contains("travel")
    @State private var vacationCounts = AppPreferences.dayTypesCountingTowardTarget.contains("vacation")
    @State private var holidayCounts = AppPreferences.dayTypesCountingTowardTarget.contains("holiday")
    @State private var creditCounts = AppPreferences.dayTypesCountingTowardTarget.contains("freeDay")

    // Office search state
    @State private var officeName = ""
    @State private var officeSearchQuery = ""
    @State private var officeSearchResults: [MKMapItem] = []
    @State private var selectedOfficeMapItem: MKMapItem?
    @State private var isSearchingOffice = false
    @State private var officeMapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Theme.accent : Theme.outlineVariant.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Content
                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    officesStep.tag(1)
                    preferencesStep.tag(2)
                    permissionsStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .disabled(false) // Pages are controlled programmatically via step buttons
                .allowsHitTesting(true)
                .animation(.easeInOut(duration: 0.3), value: step)
                .gesture(DragGesture()) // Consume swipe to prevent skipping steps
            }
        }
    }

    // MARK: Step 1 – Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 112, height: 112)
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [Theme.primary, Theme.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 28)

            Text("My Office Days")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 8)

            Text("Track your office attendance effortlessly with automatic check-ins and smart insights.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent.opacity(0.7))
                Text("All data stays securely on your device")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.onSurfaceVariant)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.surfaceContainerLow))

            Spacer()

            onboardingButton("Get Started") { step = 1 }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    // MARK: Step 2 – Offices

    private var officesStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "building.2.fill",
                    color: Theme.accent,
                    title: "Add Your Office",
                    subtitle: "Search for your office address to enable automatic check-ins."
                )

                // Office name
                VStack(alignment: .leading, spacing: 6) {
                    Text("OFFICE NAME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)
                    TextField("e.g. Main Office", text: $officeName)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Address search
                VStack(alignment: .leading, spacing: 6) {
                    Text("SEARCH ADDRESS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textTertiary)
                        TextField("Search for an address...", text: $officeSearchQuery)
                            .font(.body)
                            .onSubmit { performOfficeSearch() }
                        if isSearchingOffice {
                            ProgressView().scaleEffect(0.8)
                        }
                        if !officeSearchQuery.isEmpty {
                            Button {
                                officeSearchQuery = ""
                                officeSearchResults = []
                                selectedOfficeMapItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .onChange(of: officeSearchQuery) { _, newValue in
                    guard newValue.count >= 3 else {
                        officeSearchResults = []
                        return
                    }
                    performOfficeSearch()
                }

                // Search results
                if !officeSearchResults.isEmpty && selectedOfficeMapItem == nil {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(officeSearchResults, id: \.self) { item in
                                Button {
                                    selectOfficeMapItem(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Theme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name ?? "Unknown")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Theme.textPrimary)
                                            if let address = item.placemark.formattedAddress {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.textSecondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceContainerLowest))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5))
                }

                // Map preview + Add button
                if let selected = selectedOfficeMapItem {
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            Map(coordinateRegion: .constant(officeMapRegion),
                                annotationItems: [OnboardingMapPin(coordinate: selected.placemark.coordinate)]) { pin in
                                MapMarker(coordinate: pin.coordinate, tint: Color(hex: 0x0064D2))
                            }
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5))

                            HStack(spacing: 4) {
                                Image(systemName: "map.fill").font(.system(size: 9, weight: .semibold))
                                Text("Apple Maps").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .padding(10)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.vacation)
                            Text(selected.placemark.formattedAddress ?? "Location selected")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Button {
                            addOnboardingOffice()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Add Office")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }

                // Added offices list
                let offices = viewModel.offices()
                if !offices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR OFFICES")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            ForEach(offices, id: \.name) { office in
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.accent.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Theme.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(office.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.onSurface)
                                        Text(office.address)
                                            .font(.caption)
                                            .foregroundStyle(Theme.onSurfaceVariant)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button {
                                        viewModel.deleteOffice(office)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceContainerLowest))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5))
                    }
                }

                Text("You can add more offices anytime in Setup.")
                    .font(.caption)
                    .foregroundStyle(Theme.onSurfaceVariant)

                Spacer(minLength: 40)

                onboardingButton("Continue") { step = 2 }
                    .disabled(viewModel.offices().isEmpty)
                    .opacity(viewModel.offices().isEmpty ? 0.5 : 1.0)
            }
            .padding(24)
        }
    }

    // MARK: Step 3 – Preferences

    private var preferencesStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "slider.horizontal.3",
                    color: Theme.vacation,
                    title: "Your Preferences",
                    subtitle: "Customize how tracking works for you."
                )

                // Work days
                VStack(alignment: .leading, spacing: 10) {
                    Text("WORK DAYS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1)

                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let weekday = i + 1
                            let isSelected = selectedWorkDays.contains(weekday)
                            Button {
                                if isSelected {
                                    if selectedWorkDays.count > 1 { selectedWorkDays.remove(weekday) }
                                } else {
                                    selectedWorkDays.insert(weekday)
                                }
                                AppPreferences.setWorkDays(selectedWorkDays)
                            } label: {
                                Text(weekdayLabels[i])
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : Theme.onSurfaceVariant)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Theme.accent : Theme.surfaceContainer))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // What counts toward target
                VStack(alignment: .leading, spacing: 10) {
                    Text("COUNTS TOWARD TARGET")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1)

                    Text("Office days always count. Choose which other day types should count toward your attendance target.")
                        .font(.caption)
                        .foregroundStyle(Theme.onSurfaceVariant)

                    VStack(spacing: 0) {
                        targetToggle(label: "Travel Days", icon: "car.fill", isOn: $travelCounts)
                        Divider().padding(.leading, 52)
                        targetToggle(label: "Vacation Days", icon: "airplane", isOn: $vacationCounts)
                        Divider().padding(.leading, 52)
                        targetToggle(label: "Holidays", icon: "star.fill", isOn: $holidayCounts)
                        Divider().padding(.leading, 52)
                        targetToggle(label: "Office Credit", icon: "checkmark.seal.fill", isOn: $creditCounts)
                    }
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceContainerLowest))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5))
                }

                // US Holidays
                VStack(alignment: .leading, spacing: 10) {
                    Text("HOLIDAYS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("US Federal Holidays")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.onSurface)
                            Text("Auto-populate 12 US federal holidays each year")
                                .font(.caption)
                                .foregroundStyle(Theme.onSurfaceVariant)
                        }
                        Spacer()
                        Toggle("", isOn: $holidaysEnabled)
                            .tint(Theme.accent)
                            .labelsHidden()
                            .onChange(of: holidaysEnabled) { _, newValue in
                                AppPreferences.setHolidaysEnabled(newValue)
                            }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceContainerLowest))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5))

                    Text("You can always add custom holidays in Setup.")
                        .font(.caption)
                        .foregroundStyle(Theme.onSurfaceVariant)
                }

                Spacer(minLength: 40)

                onboardingButton("Continue") {
                    saveTargetPreferences()
                    step = 3
                }
            }
            .padding(24)
        }
    }

    // MARK: Step 4 – Permissions

    private var permissionsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "checkmark.shield.fill",
                    color: Theme.accent,
                    title: "Permissions",
                    subtitle: "For the best experience, enable location and notifications."
                )

                VStack(spacing: 12) {
                    permissionCard(
                        icon: "location.fill",
                        color: Theme.accent,
                        title: "Location — Always",
                        subtitle: "Detects when you arrive at the office, even in the background. We recommend \"Always\" for reliable auto-logging.",
                        recommended: true
                    )
                    permissionCard(
                        icon: "bell.badge.fill",
                        color: Theme.planned,
                        title: "Notifications",
                        subtitle: "Get check-in confirmations when you arrive and weekly progress reminders.",
                        recommended: false
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent.opacity(0.7))
                    Text("Your location is only used to detect office arrivals. Nothing is shared or uploaded.")
                        .font(.caption)
                        .foregroundStyle(Theme.onSurfaceVariant)
                }

                Spacer(minLength: 40)

                onboardingButton("Enable Tracking") {
                    geofenceService.enableTracking()
                    onComplete()
                }

                Button("Skip for now") { onComplete() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func stepHeader(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func onboardingButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.primaryGradient))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func targetToggle(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.onSurfaceVariant)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.onSurface)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Theme.accent)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func permissionCard(icon: String, color: Color, title: String, subtitle: String, recommended: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if recommended {
                        Text("Recommended")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surfaceContainerLow)
                .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5))
    }

    private func saveTargetPreferences() {
        var types: Set<String> = ["office"]
        if travelCounts { types.insert("travel") }
        if vacationCounts { types.insert("vacation") }
        if holidayCounts { types.insert("holiday") }
        if creditCounts { types.insert("freeDay") }
        AppPreferences.setDayTypesCountingTowardTarget(types)
    }

    // MARK: - Office Search Helpers

    private func performOfficeSearch() {
        isSearchingOffice = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = officeSearchQuery
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            DispatchQueue.main.async {
                isSearchingOffice = false
                if let response {
                    officeSearchResults = Array(response.mapItems.prefix(8))
                }
            }
        }
    }

    private func selectOfficeMapItem(_ item: MKMapItem) {
        selectedOfficeMapItem = item
        let coord = item.placemark.coordinate
        officeMapRegion = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        if officeName.isEmpty {
            officeName = item.name ?? ""
        }
    }

    private func addOnboardingOffice() {
        guard let item = selectedOfficeMapItem else { return }
        let coord = item.placemark.coordinate
        let address = item.placemark.formattedAddress ?? officeSearchQuery

        viewModel.addOffice(
            name: officeName,
            address: address,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusInFeet: 820
        )

        // Reset search state for adding another
        officeName = ""
        officeSearchQuery = ""
        officeSearchResults = []
        selectedOfficeMapItem = nil
    }
}

private struct OnboardingMapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
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
