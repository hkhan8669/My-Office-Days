import SwiftUI

struct CalendarTabView: View {
    let viewModel: AttendanceViewModel

    @State private var displayedMonth = Date()
    @State private var selectedDate: IdentifiableDate?
    @State private var isMultiSelectMode = false
    @State private var multiSelectedDates: Set<String> = []
    @State private var cachedCalendarDays: [Date?] = []

    private let weekdayHeaders = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    calendarGrid
                        .padding(.horizontal, 16)

                    if !isMultiSelectMode {
                        legendSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, isMultiSelectMode ? 160 : 100)
            }
            .background(Theme.surface.ignoresSafeArea())

            if isMultiSelectMode {
                multiSelectBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // FAB
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isMultiSelectMode = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.primaryContainer)
                        .clipShape(Circle())
                        .shadow(color: Theme.primaryContainer.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $selectedDate, onDismiss: {
            viewModel.refreshMonthCache(for: displayedMonth)
        }) { item in
            DayDetailView(viewModel: viewModel, date: item.date)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.refreshMonthCache(for: displayedMonth)
            cachedCalendarDays = calendarDays()
        }
        .onChange(of: displayedMonth) { _, newValue in
            viewModel.refreshMonthCache(for: newValue)
            cachedCalendarDays = calendarDays()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ATTENDANCE PLAN")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.onSurfaceVariant)
                .tracking(1.5)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle)
                        .font(.title.bold())
                        .foregroundStyle(Theme.onSurface)

                    if isMultiSelectMode {
                        Text("\(multiSelectedDates.count) selected")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if !Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                displayedMonth = Date()
                            }
                        } label: {
                            Text("Today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.accent.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }

                    if isMultiSelectMode {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isMultiSelectMode = false
                                multiSelectedDates.removeAll()
                            }
                        } label: {
                            Text("Done")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Theme.primaryContainer)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            moveMonth(by: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(Theme.surfaceContainerLow)
                            .clipShape(Circle())
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            moveMonth(by: 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(Theme.surfaceContainerLow)
                            .clipShape(Circle())
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private var monthTitle: String {
        DateHelper.monthYearString(for: displayedMonth)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = cachedCalendarDays

        return VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.onSurfaceVariant)
                        .tracking(1.0)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .background(Theme.surfaceContainerHighest.opacity(0.5))

            // Day rows
            let rows = stride(from: 0, to: days.count, by: 7).map { i in
                Array(days[i..<min(i + 7, days.count)])
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, date in
                        if let date {
                            dayCellView(for: date)
                                .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                    }
                    // Pad incomplete rows
                    if row.count < 7 {
                        ForEach(0..<(7 - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                    }
                }
                .background(
                    rowIndex % 2 == 0
                        ? Theme.surfaceContainerLow.opacity(0.7)
                        : Theme.surfaceContainerLowest
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Day Cell

    private func dayCellView(for date: Date) -> some View {
        let day = viewModel.cachedAttendanceDay(for: date)
        let isToday = DateHelper.isToday(date)
        let isFuture = DateHelper.isFuture(date)
        let isWeekend = !DateHelper.isWeekday(date)
        let dateKey = AttendanceDay.key(for: date)
        let isSelected = multiSelectedDates.contains(dateKey)

        return Button {
            guard DateHelper.isWeekday(date) else { return }

            if isMultiSelectMode {
                toggleSelection(for: dateKey)
            } else if isFuture {
                viewModel.togglePlanned(date: date)
                viewModel.refreshMonthCache(for: displayedMonth)
            } else {
                selectedDate = IdentifiableDate(date: date)
            }
        } label: {
            VStack(spacing: 3) {
                // Date number
                Text(DateHelper.dayOfMonthString(for: date))
                    .font(.system(size: 11, weight: isToday ? .bold : .medium))
                    .foregroundStyle(
                        isSelected ? Theme.accent :
                        isWeekend ? Theme.secondary :
                        isToday ? Theme.accent :
                        Theme.onSurface
                    )

                // Circular indicator
                ZStack {
                    if isSelected {
                        // Multi-select state
                        Circle()
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Circle()
                            .stroke(Theme.accent, lineWidth: 2)
                            .frame(width: 30, height: 30)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    } else if let day {
                        // Logged day - filled circle with letter code
                        Circle()
                            .fill(Theme.color(for: day.dayType))
                            .frame(width: 30, height: 30)
                        Text(day.dayType.letterCode)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else if isWeekend {
                        Color.clear
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .stroke(Theme.outline.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                        Circle()
                            .fill(Theme.outline.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
            .background(
                // Planned day subtle outline
                Group {
                    if day?.dayType == .planned && !isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.planned.opacity(0.4), lineWidth: 1)
                            .padding(2)
                    }
                }
            )
            .overlay(
                // Today indicator
                Group {
                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.accent, lineWidth: 1.5)
                            .padding(1)
                    }
                }
            )
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isWeekend ? 0.35 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel(for: date, day: day, isToday: isToday, isWeekend: isWeekend))
        .accessibilityHint(accessibilityHint(for: date, isFuture: isFuture, isWeekend: isWeekend))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    guard DateHelper.isWeekday(date) else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isMultiSelectMode = true
                        multiSelectedDates.insert(dateKey)
                    }
                }
        )
    }

    // MARK: - Legend

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAY TYPE LEGEND")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.onSurfaceVariant)
                .tracking(1.5)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                legendItem(.office)
                legendItem(.planned)
                legendItem(.vacation)
                legendItem(.holiday)
                legendItem(.freeDay)
                legendItem(.travel)
                legendItem(.remote)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceContainerLowest)
                .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.outlineVariant.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func legendItem(_ type: DayType) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Theme.color(for: type))
                    .frame(width: 20, height: 20)
                Text(type.letterCode)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(type.shortLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.onSurfaceVariant)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Multi-Select Bar

    private var multiSelectBar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text("APPLY TO \(multiSelectedDates.count) DAY\(multiSelectedDates.count == 1 ? "" : "S")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.onSurfaceVariant)
                    .tracking(1.2)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                    batchButton(.office)
                    batchButton(.planned)
                    batchButton(.vacation)
                    batchButton(.holiday)
                    batchButton(.freeDay)
                    batchButton(.travel)
                    batchButton(.remote)
                }

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        selectAllWeekdaysInMonth()
                    }
                } label: {
                    Text("Select all weekdays")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(
            Theme.surfaceContainerLowest
                .shadow(color: .black.opacity(0.03), radius: 1, y: -1)
                .shadow(color: .black.opacity(0.1), radius: 16, y: -6)
        )
    }

    private func batchButton(_ type: DayType) -> some View {
        Button {
            applyBatchType(type)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Theme.color(for: type).opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(type.letterCode)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.color(for: type))
                }
                Text(type.shortLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(multiSelectedDates.isEmpty)
        .opacity(multiSelectedDates.isEmpty ? 0.4 : 1)
    }

    // MARK: - Actions

    private func toggleSelection(for dateKey: String) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            if multiSelectedDates.contains(dateKey) {
                multiSelectedDates.remove(dateKey)
            } else {
                multiSelectedDates.insert(dateKey)
            }
        }
    }

    private func applyBatchType(_ type: DayType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let dates = multiSelectedDates.compactMap { formatter.date(from: $0) }
        viewModel.setDayTypes(dates: dates, type: type)
        viewModel.refreshMonthCache(for: displayedMonth)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            multiSelectedDates.removeAll()
            isMultiSelectMode = false
        }
    }

    private func selectAllWeekdaysInMonth() {
        for date in DateHelper.daysInMonth(for: displayedMonth) where DateHelper.isWeekday(date) {
            multiSelectedDates.insert(AttendanceDay.key(for: date))
        }
    }

    private func moveMonth(by value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    // MARK: - Calendar Days Builder

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
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for date: Date, day: AttendanceDay?, isToday: Bool, isWeekend: Bool) -> String {
        var parts = [DateHelper.fullDateString(for: date)]

        if isWeekend {
            parts.append("Weekend")
        } else if let day {
            parts.append(day.dayType.label)
            if let holidayName = day.holidayName {
                parts.append(holidayName)
            }
            if let officeName = day.officeName {
                parts.append(officeName)
            }
        } else {
            parts.append(DateHelper.isFuture(date) ? "No plan yet" : "Unlogged")
        }

        if isToday {
            parts.append("Today")
        }

        return parts.joined(separator: ", ")
    }

    private func accessibilityHint(for date: Date, isFuture: Bool, isWeekend: Bool) -> String {
        if isWeekend {
            return "Weekends are not editable."
        }
        if isMultiSelectMode {
            return "Double tap to toggle selection."
        }
        if isFuture {
            return "Double tap to toggle a planned office day."
        }
        return "Double tap to edit this day."
    }
}
