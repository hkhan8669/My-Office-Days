import SwiftUI
import UniformTypeIdentifiers
import MapKit

struct SettingsView: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService

    @State private var showExportShare = false
    @State private var csvContent = ""
    @State private var exportYear = Calendar.current.component(.year, from: Date())
    @State private var targetDaysPerQuarter = QuarterHelper.targetDaysPerQuarter
    @State private var nudgeWeekday = AppPreferences.nudgeWeekday
    @State private var nudgeTime = Self.nudgeDate()
    @State private var selectedWorkDays: Set<Int> = AppPreferences.workDays
    @State private var holidaysEnabled = AppPreferences.holidaysEnabled
    @State private var travelCounts = AppPreferences.dayTypesCountingTowardTarget.contains("travel")
    @State private var vacationCounts = AppPreferences.dayTypesCountingTowardTarget.contains("vacation")
    @State private var holidayCounts = AppPreferences.dayTypesCountingTowardTarget.contains("holiday")
    @State private var creditCounts = AppPreferences.dayTypesCountingTowardTarget.contains("freeDay")
    @State private var detectionRadius: Double = 820
    @State private var showAddOffice = false
    @State private var currentYearHolidays: [AttendanceViewModel.ManagedHoliday] = []
    private static func nudgeDate() -> Date {
        Calendar.current.date(from: DateComponents(hour: AppPreferences.nudgeHour, minute: AppPreferences.nudgeMinute)) ?? Date()
    }

    private static let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var activeOfficeCount: Int {
        viewModel.offices().filter(\.isEnabled).count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Header
                    configHeader
                        .padding(.bottom, 28)

                    // MARK: - Office Locations
                    officeLocationsSection
                        .padding(.bottom, 24)

                    // MARK: - Tracking Logic
                    trackingLogicSection
                        .padding(.bottom, 24)

                    // MARK: - Goals
                    goalsSection
                        .padding(.bottom, 24)

                    // MARK: - Work Schedule
                    workScheduleSection
                        .padding(.bottom, 24)

                    // MARK: - Target Counting
                    targetCountingSection
                        .padding(.bottom, 24)

                    // MARK: - Notifications & Status
                    notificationsSection
                        .padding(.bottom, 24)

                    // MARK: - Bank Holidays
                    bankHolidaysSection
                        .padding(.bottom, 24)

                    // MARK: - Data Management
                    dataSection
                        .padding(.bottom, 24)

                    // MARK: - About
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Setup")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .sheet(isPresented: $showExportShare) {
                CSVShareSheet(csvContent: csvContent, year: exportYear)
            }
        }
        .sheet(isPresented: $showAddOffice) {
            AddOfficeSheet(viewModel: viewModel, geofenceService: geofenceService)
        }
        .onAppear {
            targetDaysPerQuarter = QuarterHelper.targetDaysPerQuarter
            nudgeWeekday = AppPreferences.nudgeWeekday
            nudgeTime = Self.nudgeDate()
            selectedWorkDays = AppPreferences.workDays
            holidaysEnabled = AppPreferences.holidaysEnabled
            let targetTypes = AppPreferences.dayTypesCountingTowardTarget
            travelCounts = targetTypes.contains("travel")
            vacationCounts = targetTypes.contains("vacation")
            holidayCounts = targetTypes.contains("holiday")
            creditCounts = targetTypes.contains("freeDay")
            if let firstOffice = viewModel.offices().first {
                detectionRadius = firstOffice.geofenceRadius * 3.28084
            }
            let year = Calendar.current.component(.year, from: Date())
            currentYearHolidays = viewModel.holidays(for: year)
                .filter { $0.date >= Date() }
                .sorted { $0.date < $1.date }
        }
    }

    // MARK: - Config Header

    private var configHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETUP")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(Theme.onSurface)
                .tracking(2)

            Text("Manage your workspace parameters and tracking logic.")
                .font(.subheadline)
                .foregroundStyle(Theme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: String? = nil) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accent)
                .frame(width: 4, height: 24)
                .padding(.trailing, 12)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.onSurface)
                .tracking(1.5)

            Spacer()

            if let count {
                Text(count)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.accent.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Office Locations Section

    private var officeLocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("OFFICE LOCATIONS", count: "\(activeOfficeCount) Active Sites")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.offices().enumerated()), id: \.element.id) { index, office in
                    if index > 0 {
                        Divider()
                            .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                            .padding(.leading, 60)
                    }
                    officeRow(office)
                }

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))

                NavigationLink {
                    OfficeListView(viewModel: viewModel, geofenceService: geofenceService)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                        Text("Manage All Offices")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Button {
                    showAddOffice = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Location")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private func officeRow(_ office: OfficeLocation) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(office.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onSurface)
                Text(officeSubtitle(office))
                    .font(.caption)
                    .foregroundStyle(Theme.onSurfaceVariant)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { office.isEnabled },
                set: { _ in
                    viewModel.toggleOfficeEnabled(office: office)
                    geofenceService.refreshMonitoring()
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Theme.primaryContainer))
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(office.isEnabled ? 1.0 : 0.55)
    }

    private func officeSubtitle(_ office: OfficeLocation) -> String {
        if office.isCustom {
            return "Custom Office"
        }
        return office.address
    }

    // MARK: - Tracking Logic Section

    private var trackingLogicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TRACKING LOGIC")

            VStack(spacing: 0) {
                // Auto Geofencing Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Geofencing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text("Detect office presence via location services")
                            .font(.caption)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { geofenceService.isTrackingEnabled },
                        set: { enabled in
                            if enabled {
                                geofenceService.enableTracking()
                            } else {
                                geofenceService.disableTracking()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.primaryContainer))
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)

                // Detection Radius Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Detection Radius")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Spacer()
                        Text("\(Int(detectionRadius)) ft")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.accent.opacity(0.1))
                            )
                    }

                    Slider(value: $detectionRadius, in: 165...3280, step: 5)
                        .tint(Theme.accent)

                    HStack {
                        Text("Precise (165 ft)")
                            .font(.caption2)
                            .foregroundStyle(Theme.onSurfaceVariant)
                        Spacer()
                        Text("Broad (3,280 ft)")
                            .font(.caption2)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .onChange(of: detectionRadius) { _, newValue in
                    for office in viewModel.offices() {
                        viewModel.updateOfficeRadius(office: office, radiusInFeet: newValue)
                    }
                    geofenceService.refreshMonitoring()
                }

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)

                // Permission Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Permission")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.onSurfaceVariant)
                        Text(locationStatusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(locationStatusColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Monitoring")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.onSurfaceVariant)
                        Text(geofenceService.isMonitoring ? "Active" : "Inactive")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(geofenceService.isMonitoring ? Theme.vacation : Theme.behind)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if geofenceService.authorizationStatus == .authorizedWhenInUse {
                    Divider()
                        .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                        .padding(.leading, 16)

                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.planned)
                            Text("\"While Using App\" won't track in the background. Change to \"Always\" in Settings for automatic office detection.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 16)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                    .font(.caption.weight(.semibold))
                                Text("Open Settings → Always Allow")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Theme.planned)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.vertical, 4)
                }

                if geofenceService.authorizationStatus == .denied || geofenceService.authorizationStatus == .restricted {
                    Divider()
                        .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                        .padding(.leading, 16)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.caption.weight(.semibold))
                            Text("Open Settings to Grant Location Access")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.behind)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)

                // Refresh Button
                Button {
                    geofenceService.handleAppDidBecomeActive()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                        Text("Refresh Monitoring Status")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private var locationStatusColor: Color {
        switch geofenceService.authorizationStatus {
        case .authorizedAlways: return Theme.vacation
        case .authorizedWhenInUse: return Theme.planned
        case .denied, .restricted: return Theme.behind
        default: return Theme.onSurfaceVariant
        }
    }

    private var locationStatusText: String {
        switch geofenceService.authorizationStatus {
        case .authorizedAlways: return "Always allowed"
        case .authorizedWhenInUse: return "While using app"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    private var notificationStatusText: String {
        switch geofenceService.notificationAuthorizationStatus {
        case .authorized: return "Allowed"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("QUARTERLY GOALS")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.vacation.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "target")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.vacation)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quarterly Target")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text("Days required per quarter")
                            .font(.caption)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            if targetDaysPerQuarter > 20 {
                                targetDaysPerQuarter -= 1
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(targetDaysPerQuarter > 20 ? Theme.accent : Theme.outline)
                                .frame(width: 32, height: 32)
                                .background(Theme.surfaceContainer)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(targetDaysPerQuarter <= 20)

                        Text("\(targetDaysPerQuarter)")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .foregroundStyle(Theme.onSurface)
                            .frame(minWidth: 36)

                        Button {
                            if targetDaysPerQuarter < 60 {
                                targetDaysPerQuarter += 1
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(targetDaysPerQuarter < 60 ? Theme.accent : Theme.outline)
                                .frame(width: 32, height: 32)
                                .background(Theme.surfaceContainer)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(targetDaysPerQuarter >= 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
        .onChange(of: targetDaysPerQuarter) { _, newValue in
            viewModel.setTargetDaysPerQuarter(newValue)
        }
    }

    // MARK: - Work Schedule Section

    private var workScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("WORK SCHEDULE")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "calendar.day.timeline.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Work Days")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text("Select which days you go into the office")
                            .font(.caption)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

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
                            viewModel.refreshSnapshot()
                        } label: {
                            Text(Self.weekdayLabels[i])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : Theme.onSurfaceVariant)
                                .frame(width: 38, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Theme.accent : Theme.surfaceContainer))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceContainerLowest))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5))
        }
    }

    // MARK: - Target Counting Section

    private var targetCountingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("COUNTS TOWARD TARGET")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.vacation.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "checklist")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.vacation)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day Types")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text("Office days always count. Toggle others below.")
                            .font(.caption)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                settingsTargetToggle(label: "Travel", icon: "car.fill", isOn: $travelCounts)
                Divider().padding(.leading, 52)
                settingsTargetToggle(label: "Vacation", icon: "airplane", isOn: $vacationCounts)
                Divider().padding(.leading, 52)
                settingsTargetToggle(label: "Holidays", icon: "star.fill", isOn: $holidayCounts)
                Divider().padding(.leading, 52)
                settingsTargetToggle(label: "Office Credit", icon: "checkmark.seal.fill", isOn: $creditCounts)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceContainerLowest))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5))
        }
        .onChange(of: travelCounts) { _, _ in saveTargetCountPrefs() }
        .onChange(of: vacationCounts) { _, _ in saveTargetCountPrefs() }
        .onChange(of: holidayCounts) { _, _ in saveTargetCountPrefs() }
        .onChange(of: creditCounts) { _, _ in saveTargetCountPrefs() }
    }

    private func settingsTargetToggle(label: String, icon: String, isOn: Binding<Bool>) -> some View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func saveTargetCountPrefs() {
        var types: Set<String> = ["office"]
        if travelCounts { types.insert("travel") }
        if vacationCounts { types.insert("vacation") }
        if holidayCounts { types.insert("holiday") }
        if creditCounts { types.insert("freeDay") }
        AppPreferences.setDayTypesCountingTowardTarget(types)
        viewModel.refreshSnapshot()
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("NOTIFICATIONS")

            VStack(spacing: 0) {
                // Weekly Nudge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Nudge")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text("Recurring reminder to stay on track with your quarterly target.")
                            .font(.caption)
                            .foregroundStyle(Theme.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)

                // Day picker
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let isSelected = nudgeWeekday == day
                        Button {
                            nudgeWeekday = day
                            AppPreferences.setNudgeWeekday(day)
                            geofenceService.scheduleWeeklyNudge()
                        } label: {
                            Text(Self.weekdayLabels[day - 1])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : Theme.onSurfaceVariant)
                                .frame(width: 38, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Theme.accent : Theme.surfaceContainer)
                                )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)

                // Time picker
                HStack {
                    Text("Time")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.onSurfaceVariant)
                    Spacer()
                    DatePicker("", selection: $nudgeTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: nudgeTime) { _, newValue in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            AppPreferences.setNudgeTime(hour: comps.hour ?? 8, minute: comps.minute ?? 30)
                            geofenceService.scheduleWeeklyNudge()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)

                // Notification Permission Status
                HStack {
                    Text("Notification Permission")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.onSurfaceVariant)
                    Spacer()
                    Text(notificationStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.onSurface)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if geofenceService.notificationAuthorizationStatus == .denied {
                    Divider()
                        .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                        .padding(.leading, 16)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.caption.weight(.semibold))
                            Text("Open Settings to Enable Notifications")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.behind)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                if let lastOffice = geofenceService.lastCheckedInOffice {
                    Divider()
                        .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                        .padding(.leading, 16)

                    HStack {
                        Text("Last Auto Check-In")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.onSurfaceVariant)
                        Spacer()
                        Text(
                            geofenceService.lastCheckInDate.map {
                                "\(lastOffice) on \(DateHelper.shortDateString(for: $0))"
                            } ?? lastOffice
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.onSurface)
                        .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Bank Holidays Section

    private var bankHolidaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("HOLIDAYS", count: "\(currentYearHolidays.count) Upcoming")

            VStack(spacing: 0) {
                // US Federal Holidays toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("US Federal Holidays")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text("Auto-populate federal holidays each year")
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().foregroundStyle(Theme.outlineVariant.opacity(0.3)).padding(.leading, 16)

                let holidays = Array(currentYearHolidays.prefix(5))
                ForEach(Array(holidays.enumerated()), id: \.element.id) { index, holiday in
                    if index > 0 {
                        Divider()
                            .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                            .padding(.leading, 16)
                    }
                    HStack {
                        Text(holiday.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.onSurface)
                        Spacer()
                        Text(DateHelper.fullDateString(for: holiday.date))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if holidays.isEmpty {
                    HStack {
                        Text("No upcoming holidays this year")
                            .font(.subheadline)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))

                NavigationLink {
                    HolidayManagementView(viewModel: viewModel)
                } label: {
                    Text("Manage Holidays")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.primaryContainer)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DATA MANAGEMENT")

            VStack(spacing: 0) {
                HStack {
                    Text("Export Year")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.onSurface)

                    Spacer()

                    HStack(spacing: 10) {
                        Button {
                            exportYear -= 1
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(PressableButtonStyle())

                        Text(String(exportYear))
                            .font(.system(.body, design: .monospaced).weight(.bold))
                            .foregroundStyle(Theme.onSurface)
                            .frame(minWidth: 48)

                        Button {
                            exportYear += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 60)

                Button {
                    csvContent = viewModel.exportCSV(year: exportYear)
                    showExportShare = true
                } label: {
                    configRow(
                        icon: "square.and.arrow.up.fill",
                        iconColor: Theme.holiday,
                        title: "Export to CSV",
                        subtitle: "Download spreadsheet for \(exportYear)"
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ABOUT")

            VStack(spacing: 0) {
                infoRow("Version", "1.0.0")
                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 16)
                infoRow("Quarterly Target", "\(QuarterHelper.targetDaysPerQuarter) days")
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Reusable Row Components

    private func configRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onSurface)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.onSurfaceVariant)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onSurface)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Office List View

struct OfficeListView: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService
    @State private var editingDetailsOffice: OfficeLocation?
    @State private var showAddOffice = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(viewModel.offices()) { office in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(office.isEnabled ? Theme.accent.opacity(0.12) : Theme.surfaceContainerLow)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(office.isEnabled ? Theme.accent : Theme.onSurfaceVariant)
                            }

                            VStack(alignment: .leading, spacing: 3) {
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
                                editingDetailsOffice = office
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.accent.opacity(0.7))
                            }
                            .buttonStyle(PressableButtonStyle())

                            Toggle("", isOn: Binding(
                                get: { office.isEnabled },
                                set: { _ in
                                    viewModel.toggleOfficeEnabled(office: office)
                                    geofenceService.refreshMonitoring()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: Theme.primaryContainer))
                            .labelsHidden()
                            .fixedSize()
                        }

                        Divider()
                            .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                            .padding(.vertical, 8)

                        HStack(spacing: 10) {
                            Image(systemName: "scope")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.onSurfaceVariant)
                            Text("Radius")
                                .font(.caption)
                                .foregroundStyle(Theme.onSurfaceVariant)
                            Spacer()
                            Text("\(Int(office.geofenceRadius * 3.28084)) ft")
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                .foregroundStyle(Theme.accent)

                            if office.isCustom {
                                Button(role: .destructive) {
                                    viewModel.deleteOffice(office)
                                    geofenceService.refreshMonitoring()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.behind)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.surfaceContainerLowest)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
                    )
                    .opacity(office.isEnabled ? 1 : 0.55)
                }

                Button {
                    showAddOffice = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Custom Office")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.primaryContainer)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Offices")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddOffice) {
            AddOfficeSheet(viewModel: viewModel, geofenceService: geofenceService)
        }
        .sheet(item: $editingDetailsOffice) { office in
            EditOfficeSheet(office: office, viewModel: viewModel)
        }
    }
}

// MARK: - Edit Office Sheet

private struct EditOfficeSheet: View {
    let office: OfficeLocation
    let viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editName = ""
    @State private var editAddress = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.6685, longitude: -75.7506),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    // Re-search state
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    @State private var isSearching = false
    @State private var isRelocating = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Map preview
                    ZStack(alignment: .bottomTrailing) {
                        Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: currentCoordinate)]) { pin in
                            MapMarker(coordinate: pin.coordinate, tint: Color(hex: 0x0064D2))
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
                        )

                        // Apple Maps badge
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Apple Maps")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.5))
                        )
                        .padding(10)
                    }

                    // Current address
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                        Text(editAddress)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OFFICE NAME")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .tracking(1.5)
                        TextField("Office name", text: $editName)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.surfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Change location
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isRelocating.toggle()
                                if !isRelocating {
                                    searchQuery = ""
                                    searchResults = []
                                    selectedMapItem = nil
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isRelocating ? "xmark.circle.fill" : "arrow.triangle.swap")
                                    .font(.caption.weight(.semibold))
                                Text(isRelocating ? "Cancel Relocation" : "Change Location")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(isRelocating ? Theme.behind : Theme.accent)
                        }
                        .buttonStyle(PressableButtonStyle())

                        if isRelocating {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SEARCH NEW ADDRESS")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.textTertiary)
                                    .tracking(1.5)

                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(Theme.textTertiary)
                                    TextField("Search for an address...", text: $searchQuery)
                                        .font(.body)
                                        .onSubmit { performSearch() }
                                    if isSearching {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    if !searchQuery.isEmpty {
                                        Button {
                                            searchQuery = ""
                                            searchResults = []
                                            selectedMapItem = nil
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

                                // Search results
                                if !searchResults.isEmpty && selectedMapItem == nil {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults, id: \.self) { item in
                                            Button {
                                                selectMapItem(item)
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "mappin.circle.fill")
                                                        .font(.body)
                                                        .foregroundStyle(Theme.accent)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(item.name ?? "Unknown")
                                                            .font(.subheadline.weight(.medium))
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
                                                .padding(.vertical, 10)
                                            }
                                            Divider()
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }

                                if let selected = selectedMapItem {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.vacation)
                                        Text(selected.placemark.formattedAddress ?? "New location selected")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Geofence radius info
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Detection radius")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text("\(Int(office.geofenceRadius * 3.28084)) ft")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.surfaceContainerLow)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.surfaceContainerLowest)
            .navigationTitle("Edit Office")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                editName = office.name
                editAddress = office.address
                region = MKCoordinateRegion(
                    center: office.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            .onChange(of: searchQuery) { _, newValue in
                guard newValue.count >= 3 else {
                    searchResults = []
                    return
                }
                performSearch()
            }
        }
    }

    private var currentCoordinate: CLLocationCoordinate2D {
        selectedMapItem?.placemark.coordinate ?? office.coordinate
    }

    private func performSearch() {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let response {
                    searchResults = Array(response.mapItems.prefix(8))
                }
            }
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        selectedMapItem = item
        let coord = item.placemark.coordinate
        region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        editAddress = item.placemark.formattedAddress ?? searchQuery
    }

    private func save() {
        viewModel.updateOfficeName(office, newName: editName)
        office.address = editAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if let selected = selectedMapItem {
            office.latitude = selected.placemark.coordinate.latitude
            office.longitude = selected.placemark.coordinate.longitude
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Office Sheet

struct AddOfficeSheet: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    @State private var isSearching = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.6685, longitude: -75.7506),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("OFFICE NAME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)
                    TextField("e.g. Main Office", text: $name)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Search field
                VStack(alignment: .leading, spacing: 8) {
                    Text("SEARCH ADDRESS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textTertiary)
                        TextField("Search for an address...", text: $searchQuery)
                            .font(.body)
                            .onSubmit { performSearch() }
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchResults = []
                                selectedMapItem = nil
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
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Search results or map
                if !searchResults.isEmpty && selectedMapItem == nil {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                Button {
                                    selectMapItem(item)
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
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                }
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                } else if let selected = selectedMapItem {
                    // Show map preview
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            Map(coordinateRegion: .constant(region), annotationItems: [MapPin(coordinate: selected.placemark.coordinate)]) { pin in
                                MapMarker(coordinate: pin.coordinate, tint: Color(hex: 0x0064D2))
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
                            )

                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Apple Maps")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.black.opacity(0.5))
                            )
                            .padding(10)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.vacation)
                            Text(selected.placemark.formattedAddress ?? "Location selected")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .background(Theme.surfaceContainerLowest)
            .navigationTitle("Add Office")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: searchQuery) { _, newValue in
                guard newValue.count >= 3 else {
                    searchResults = []
                    return
                }
                performSearch()
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMapItem != nil
    }

    private func performSearch() {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let response {
                    searchResults = Array(response.mapItems.prefix(8))
                }
            }
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        selectedMapItem = item
        let coord = item.placemark.coordinate
        region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        if name.isEmpty {
            name = item.name ?? ""
        }
    }

    private func save() {
        guard let item = selectedMapItem else { return }
        let coord = item.placemark.coordinate
        let address = item.placemark.formattedAddress ?? searchQuery

        // Use the global detection radius from the first office
        let radiusInFeet: Double = {
            if let firstOffice = viewModel.offices().first {
                return firstOffice.geofenceRadius * 3.28084
            }
            return 820
        }()

        viewModel.addOffice(
            name: name,
            address: address,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusInFeet: radiusInFeet
        )
        geofenceService.refreshMonitoring()
        dismiss()
    }
}

// Helper for map annotation
private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// Extension to get formatted address from CLPlacemark
extension CLPlacemark {
    var formattedAddress: String? {
        var parts: [String] = []
        if let street = thoroughfare {
            if let subThoroughfare = subThoroughfare {
                parts.append("\(subThoroughfare) \(street)")
            } else {
                parts.append(street)
            }
        }
        if let city = locality { parts.append(city) }
        if let state = administrativeArea { parts.append(state) }
        if let zip = postalCode { parts.append(zip) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Holiday Management View

struct HolidayManagementView: View {
    let viewModel: AttendanceViewModel
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showAddHoliday = false
    @State private var holidayName = ""
    @State private var holidayDate = Date()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Year Selector
                HStack(spacing: 20) {
                    Button {
                        selectedYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accent.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Text(String(selectedYear))
                        .font(.title3.bold())
                        .foregroundStyle(Theme.onSurface)

                    Button {
                        selectedYear += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accent.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.vertical, 4)

                // Holiday List
                VStack(spacing: 0) {
                    let holidays = viewModel.holidays(for: selectedYear)
                    ForEach(Array(holidays.enumerated()), id: \.element.id) { index, holiday in
                        if index > 0 {
                            Divider()
                                .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                                .padding(.leading, 16)
                        }
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.holiday.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.holiday)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(holiday.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.onSurface)
                                Text(DateHelper.fullDateString(for: holiday.date))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.onSurfaceVariant)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                viewModel.deleteHoliday(holiday)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(Theme.behind)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if holidays.isEmpty {
                        Text("No holidays for \(String(selectedYear))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.onSurfaceVariant)
                            .padding(.vertical, 20)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surfaceContainerLowest)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
                )

                // Add Holiday Button
                Button {
                    holidayName = ""
                    holidayDate = Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date()
                    showAddHoliday = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Custom Holiday")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.primaryContainer)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Holidays")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddHoliday) {
            NavigationStack {
                Form {
                    Section("Holiday") {
                        TextField("Holiday Name", text: $holidayName)
                        DatePicker("Date", selection: $holidayDate, displayedComponents: .date)
                    }
                }
                .navigationTitle("Add Holiday")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddHoliday = false }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save") {
                            viewModel.addHoliday(date: holidayDate, name: holidayName)
                            showAddHoliday = false
                        }
                        .disabled(holidayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - CSV Share Sheet

struct CSVShareSheet: UIViewControllerRepresentable {
    let csvContent: String
    let year: Int

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfficeDays_\(year).csv")
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            return UIActivityViewController(activityItems: [csvContent], applicationActivities: nil)
        }
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
