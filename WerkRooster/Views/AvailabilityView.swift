import SwiftUI

struct AvailabilityView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var monthDate = Date()
    @State private var editing: AvailabilityEntryRequest?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdays = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    var body: some View {
        VStack(spacing: 10) {
            MonthHeader(monthDate: $monthDate) { changed in
                vm.selectedMonth = changed
                Task { await vm.loadAvailability(for: vm.monthString(from: changed)) }
            }

            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.caption.bold()).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<monthDate.leadingWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(1...monthDate.daysInMonth, id: \.self) { day in
                    let key = monthDate.dateFor(day: day).isoDate
                    let entry = vm.availabilityEntries[key] ?? AvailabilityEntryRequest(date: key, isAvailable: true, shiftPreference: nil, customStart: nil, customEnd: nil, notes: nil)
                    let isSubmitted = vm.availabilitySubmittedDates.contains(key)
                    Button {
                        editing = entry
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(day)").font(.caption.bold())
                            if entry.shiftPreference != nil {
                                Circle().fill(Color.blue).frame(width: 4, height: 4)
                            } else if isSubmitted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(cellColor(entry, isSubmitted: isSubmitted), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button("Alles beschikbaar") {
                    vm.allAvailable()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(vm.loading ? "Opslaan..." : "Opslaan") {
                    Task { await vm.saveAvailability() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.loading)
                .frame(maxWidth: .infinity)
            }

            if let status = vm.availabilityStatus {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                LegendDot(color: Color.green.opacity(0.2), label: "Ingediend")
                LegendDot(color: Color.red.opacity(0.3), label: "Niet beschikbaar")
                LegendDot(color: Color(.secondarySystemBackground).opacity(0.6), label: "Nog doorgeven")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if !vm.hasLocations {
                Text("Geen locatie gekoppeld aan je account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if (vm.me?.locations?.count ?? 0) > 1 {
                Text("Je beschikbaarheid geldt voor al je locaties.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .task {
            monthDate = vm.selectedMonth
            await vm.loadAvailability(for: vm.monthString(from: monthDate))
        }
        .sheet(item: $editing) { item in
            EditAvailabilitySheet(entry: item, shifts: vm.shifts) { updated in
                vm.availabilityEntries[updated.date] = updated
            }
        }
    }

    private func cellColor(_ entry: AvailabilityEntryRequest, isSubmitted: Bool) -> Color {
        if !entry.isAvailable {
            return isSubmitted ? Color.red.opacity(0.3) : Color.red.opacity(0.12)
        }
        if isSubmitted {
            return Color.green.opacity(0.2)
        }
        return Color(.secondarySystemBackground).opacity(0.6)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}

private struct EditAvailabilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: AvailabilityEntryRequest
    let shifts: [Shift]
    let onSave: (AvailabilityEntryRequest) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Beschikbaar", isOn: $entry.isAvailable)
                if entry.isAvailable {
                    Picker("Shift voorkeur", selection: Binding(get: {
                        entry.shiftPreference ?? -1
                    }, set: {
                        entry.shiftPreference = $0 == -1 ? nil : $0
                    })) {
                        Text("Geen voorkeur").tag(-1)
                        ForEach(shifts) { shift in
                            Text(shift.name).tag(shift.id)
                        }
                    }
                    TextField("Start (HH:mm)", text: Binding(get: { entry.customStart ?? "" }, set: { entry.customStart = $0.isEmpty ? nil : $0 }))
                    TextField("Eind (HH:mm)", text: Binding(get: { entry.customEnd ?? "" }, set: { entry.customEnd = $0.isEmpty ? nil : $0 }))
                    TextField("Opmerking", text: Binding(get: { entry.notes ?? "" }, set: { entry.notes = $0.isEmpty ? nil : $0 }), axis: .vertical)
                }
            }
            .navigationTitle("Beschikbaarheid \(entry.date)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Toepassen") {
                        if !entry.isAvailable {
                            entry.shiftPreference = nil
                        }
                        onSave(entry)
                        dismiss()
                    }
                }
            }
        }
    }
}
