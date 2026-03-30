import SwiftUI

struct DayDetailView: View {
    let viewModel: AttendanceViewModel
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: DayType = .remote
    @State private var holidayName = ""
    @State private var notes = ""

    private var existingDay: AttendanceDay? {
        viewModel.attendanceDay(for: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Date Header
                VStack(spacing: 10) {
                    Text(DateHelper.fullDateString(for: date).uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)

                    if let day = existingDay, day.isAutoLogged, let office = day.officeName {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text("Auto-logged at \(office)")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.accent.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // MARK: - Day Type Selector
                VStack(alignment: .leading, spacing: 14) {
                    Text("STATUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)
                        .padding(.horizontal, 4)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                        spacing: 10
                    ) {
                        ForEach(DayType.manualOptions) { type in
                            dayTypeButton(type)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // MARK: - Text Input
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedType == .holiday ? "HOLIDAY NAME" : "NOTES")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .tracking(1.5)
                        .padding(.horizontal, 4)

                    TextField(
                        selectedType == .holiday ? "Holiday name" : "Optional note",
                        text: selectedType == .holiday ? $holidayName : $notes
                    )
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.outlineVariant.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)

                // Summary hint
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.color(for: selectedType))
                            .frame(width: 10, height: 10)
                        Text("This day will be logged as \(selectedType.label)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if selectedType.countsTowardTarget {
                        Text("Counts toward your quarterly target")
                            .font(.caption2)
                            .foregroundStyle(Theme.vacation)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                Spacer()

                // MARK: - Save Button
                Button {
                    save()
                } label: {
                    Text("SAVE")
                        .font(.subheadline.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.accent)
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Theme.surfaceContainerLowest)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 30, height: 30)
                            .background(Theme.surfaceContainerLow)
                            .clipShape(Circle())
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .onAppear {
                if let day = existingDay {
                    selectedType = day.dayType
                    holidayName = day.holidayName ?? ""
                    notes = day.notes ?? ""
                }
            }
        }
    }

    // MARK: - Day Type Button

    private func dayTypeButton(_ type: DayType) -> some View {
        let isSelected = selectedType == type
        let typeColor = Theme.color(for: type)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? typeColor : .clear)
                        .frame(width: 40, height: 40)

                    Circle()
                        .strokeBorder(
                            isSelected ? typeColor : Theme.outlineVariant,
                            lineWidth: isSelected ? 0 : 1.5
                        )
                        .frame(width: 40, height: 40)

                    Text(type.letterCode)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                }
                .frame(minWidth: 44, minHeight: 44)

                Text(type.shortLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? typeColor.opacity(0.06) : .clear)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(type.label)
    }

    // MARK: - Save

    private func save() {
        if selectedType == .holiday {
            viewModel.addHoliday(date: date, name: holidayName.isEmpty ? "Holiday" : holidayName)
        } else {
            viewModel.setDayType(date: date, type: selectedType, notes: notes.isEmpty ? nil : notes)
        }
        dismiss()
    }
}
