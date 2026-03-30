import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService

    @State private var showExportShare = false
    @State private var csvContent = ""
    @State private var showImport = false
    @State private var exportYear = Calendar.current.component(.year, from: Date())
    @State private var targetDaysPerQuarter = QuarterHelper.targetDaysPerQuarter
    @State private var detectionRadius: Double = 820
    @State private var showAddOffice = false
    @State private var currentYearHolidays: [AttendanceViewModel.ManagedHoliday] = []
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
            .sheet(isPresented: $showImport) {
                ImportDaysView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showAddOffice) {
            AddOfficeSheet(viewModel: viewModel, geofenceService: geofenceService)
        }
        .onAppear {
            targetDaysPerQuarter = QuarterHelper.targetDaysPerQuarter
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
            Text("CONFIGURATION")
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
        let name = office.name.lowercased()
        if name.contains("hq") || name.contains("newark") {
            return "Primary Hub - Delaware"
        } else if name.contains("sterling") {
            return "Satellite - Virginia"
        } else if name.contains("reston") {
            return "Satellite - Virginia"
        } else if name.contains("indianapolis") {
            return "Regional - Indiana"
        } else if name.contains("newton") {
            return "Regional - Massachusetts"
        } else if name.contains("new castle") {
            return "Satellite - Delaware"
        } else if name.contains("salt lake") {
            return "Regional - Utah"
        } else if office.isCustom {
            return "Custom Office"
        } else {
            return office.address
        }
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
                        Text("Monday morning reminder to stay on track with your quarterly target.")
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
                Button {
                    showImport = true
                } label: {
                    configRow(
                        icon: "square.and.arrow.down.fill",
                        iconColor: Theme.vacation,
                        title: "Import Past Days",
                        subtitle: "Add office days from before the app"
                    )
                }

                Divider()
                    .foregroundStyle(Theme.outlineVariant.opacity(0.3))
                    .padding(.leading, 60)

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

                        Text("\(exportYear)")
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Office Details") {
                    TextField("Name", text: $editName)
                    TextField("Address", text: $editAddress, axis: .vertical)
                }
            }
            .navigationTitle("Edit Office")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        viewModel.updateOfficeName(office, newName: editName)
                        office.address = editAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                editName = office.name
                editAddress = office.address
            }
        }
    }
}

// MARK: - Add Office Sheet

struct AddOfficeSheet: View {
    let viewModel: AttendanceViewModel
    @ObservedObject var geofenceService: GeofenceService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var radiusInFeet = "250"

    var body: some View {
        NavigationStack {
            Form {
                Section("Office") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address, axis: .vertical)
                }

                Section("Coordinates") {
                    TextField("Latitude", text: $latitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $longitude)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section("Geofence") {
                    TextField("Radius (feet)", text: $radiusInFeet)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Office")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(latitude) != nil &&
        Double(longitude) != nil &&
        Double(radiusInFeet) != nil
    }

    private func save() {
        guard
            let latitudeValue = Double(latitude),
            let longitudeValue = Double(longitude),
            let radiusValue = Double(radiusInFeet)
        else { return }

        viewModel.addOffice(
            name: name,
            address: address,
            latitude: latitudeValue,
            longitude: longitudeValue,
            radiusInFeet: radiusValue
        )
        geofenceService.refreshMonitoring()
        dismiss()
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

                    Text("\(selectedYear)")
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
                        Text("No holidays for \(selectedYear)")
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

// MARK: - Import Days View

struct ImportDaysView: View {
    let viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDates: Set<Date> = []
    @State private var displayedMonth = Date()

    private let weekdayHeaders = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Tap weekdays to mark as office days")
                        .font(.subheadline)
                        .foregroundStyle(Theme.onSurfaceVariant)

                    Text("\(selectedDates.count) days selected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }

                HStack {
                    Button { moveMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accent.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Spacer()

                    Text(DateHelper.monthYearString(for: displayedMonth))
                        .font(.headline)
                        .foregroundStyle(Theme.onSurface)

                    Spacer()

                    Button { moveMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accent.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(weekdayHeaders, id: \.self) { header in
                            Text(header)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.onSurfaceVariant)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    let days = calendarDays()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                        ForEach(days, id: \.self) { date in
                            if let date {
                                importDayCell(date)
                            } else {
                                Color.clear.frame(height: 40)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    viewModel.importOfficeDays(dates: Array(selectedDates))
                    dismiss()
                } label: {
                    Text("Import \(selectedDates.count) Days")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.primaryGradient)
                                .opacity(selectedDates.isEmpty ? 0.3 : 1)
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(selectedDates.isEmpty)
                .padding(.horizontal, 20)
            }
            .padding(.vertical)
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle("Import Past Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func importDayCell(_ date: Date) -> some View {
        let isWeekday = DateHelper.isWeekday(date)
        let isPast = DateHelper.isPast(date) || DateHelper.isToday(date)
        let isSelected = selectedDates.contains(Calendar.current.startOfDay(for: date))
        let canSelect = isWeekday && isPast

        return Button {
            guard canSelect else { return }
            let key = Calendar.current.startOfDay(for: date)
            if selectedDates.contains(key) {
                selectedDates.remove(key)
            } else {
                selectedDates.insert(key)
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 34, height: 34)
                }
                Text(DateHelper.dayOfMonthString(for: date))
                    .font(.body.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(
                        isSelected ? .white :
                            canSelect ? Theme.onSurface : Theme.onSurfaceVariant
                    )
            }
        }
        .buttonStyle(PressableButtonStyle())
        .frame(height: 40)
    }

    private func calendarDays() -> [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let firstOfMonth = calendar.date(from: components) ?? displayedMonth
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday + 5) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0

        var result: [Date?] = Array(repeating: nil, count: offset)
        for day in 1...daysInMonth {
            var dayComponents = components
            dayComponents.day = day
            result.append(calendar.date(from: dayComponents))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func moveMonth(by value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
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
