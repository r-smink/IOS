import SwiftUI

struct SwapView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var showRequestDialog: SwapShift?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let status = vm.swapStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Elke ruil moet worden goedgekeurd door een teamleider. Je krijgt een melding zodra dat is gebeurd.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Incoming requests and open offers
                if !vm.swapIncoming.isEmpty {
                    section(title: "📬 Ruilverzoeken voor jou (\(vm.swapIncoming.count))") {
                        ForEach(vm.swapIncoming) { req in
                            IncomingRequestCard(request: req,
                                onAccept: { Task { await vm.respondSwap(swapId: req.id, action: "accept") } },
                                onReject: { Task { await vm.respondSwap(swapId: req.id, action: "reject") } }
                            )
                        }
                    }
                }

                // My shifts
                section(title: "Mijn diensten") {
                    if vm.swapMyShifts.isEmpty {
                        EmptyText("Je hebt geen komende diensten.")
                    } else {
                        ForEach(vm.swapMyShifts) { shift in
                            MyShiftCard(shift: shift,
                                onToggle: { Task { await vm.toggleSwappable(scheduleId: shift.id) } },
                                onRequest: { showRequestDialog = shift }
                            )
                        }
                    }
                }

                // Available shifts
                section(title: "Beschikbare diensten (overnemen)") {
                    if vm.swapAvailable.isEmpty {
                        EmptyText("Er zijn momenteel geen diensten beschikbaar om over te nemen.")
                    } else {
                        ForEach(vm.swapAvailable) { shift in
                            AvailableShiftCard(shift: shift,
                                onClaim: { Task { await vm.claimShift(scheduleId: shift.id) } }
                            )
                        }
                    }
                }

                // My requests history
                if !vm.swapMine.isEmpty {
                    section(title: "Mijn ruilverzoeken") {
                        ForEach(vm.swapMine) { req in
                            MyRequestCard(request: req)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable { await vm.loadSwapData() }
        .task { await vm.loadSwapData() }
        .sheet(item: $showRequestDialog) { shift in
            RequestSwapSheet(shift: shift, colleagues: vm.swapColleagues) { colleagueId, reason, partStart, partEnd in
                Task { await vm.requestSwap(scheduleId: shift.id, colleagueId: colleagueId, reason: reason, partStart: partStart, partEnd: partEnd) }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }
}

private struct ShiftTitle: View {
    let shiftName: String?
    let locationName: String?

    var body: some View {
        HStack(spacing: 6) {
            LocationLogo(locationName: locationName, size: 20)
            Text(shiftName ?? "Dienst").font(.subheadline.bold())
        }
    }
}

private struct MyShiftCard: View {
    let shift: SwapShift
    let onToggle: () -> Void
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShiftTitle(shiftName: shift.shiftName, locationName: shift.locationName)
            Text("\(shift.workDate.dutchLongDate)  \(shift.locationName ?? "")").font(.caption).foregroundStyle(.secondary)
            if let s = shift.startTime, let e = shift.endTime {
                Text("\(s.hhmm) – \(e.hhmm)").font(.caption).foregroundStyle(.blue)
            }
            HStack(spacing: 8) {
                Button(action: onRequest) {
                    Label("Ruilen", systemImage: "arrow.2.squarepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onToggle) {
                    Text(shift.isSwappable == 1 ? "✓ Ruilbaar" : "Ruilbaar maken")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct AvailableShiftCard: View {
    let shift: SwapShift
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShiftTitle(shiftName: shift.shiftName, locationName: shift.locationName)
            Text("\(shift.workDate.dutchLongDate)  \(shift.locationName ?? "")").font(.caption).foregroundStyle(.secondary)
            if let s = shift.startTime, let e = shift.endTime {
                Text("\(s.hhmm) – \(e.hhmm)").font(.caption).foregroundStyle(.blue)
            }
            if let owner = shift.ownerName {
                Text("Van: \(owner)").font(.caption)
            }
            Button(action: onClaim) {
                Text("Overnemen aanvragen").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct IncomingRequestCard: View {
    let request: SwapRequestItem
    let onAccept: () -> Void
    let onReject: () -> Void

    private var isOpen: Bool { request.isOpen == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShiftTitle(shiftName: request.shiftName, locationName: request.locationName)
            Text("\(request.workDate?.dutchLongDate ?? "")  \(request.locationName ?? "")").font(.caption).foregroundStyle(.secondary)
            if let ps = request.partStart, let pe = request.partEnd {
                Text("Deel van de dienst: \(ps.hhmm) – \(pe.hhmm)").font(.caption.bold()).foregroundStyle(.teal)
            } else if let s = request.startTime, let e = request.endTime {
                Text("\(s.hhmm) – \(e.hhmm)").font(.caption).foregroundStyle(.blue)
            }
            if let r = request.requesterName {
                Text(isOpen ? "Aangeboden door: \(r) (open aanbod)" : "Van: \(r)").font(.caption)
            }
            if let reason = request.reason, !reason.isEmpty {
                Text("Reden: \(reason)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Text(isOpen ? "Ik neem het over" : "Accepteren").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if !isOpen {
                    Button(role: .destructive, action: onReject) {
                        Text("Weigeren").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct MyRequestCard: View {
    let request: SwapRequestItem

    var statusText: String {
        switch request.status {
        case "pending": return request.requestedName == nil ? "⏳ Open aanbod, wacht op collega" : "⏳ Wacht op reactie collega"
        case "accepted": return "⏳ Wacht op goedkeuring teamleider"
        case "approved", "completed": return "✓ Goedgekeurd"
        case "rejected": return "✗ Afgewezen"
        default: return request.status
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                LocationLogo(locationName: request.locationName, size: 18)
                Text(request.shiftName ?? "Dienst").font(.subheadline)
            }
            Text("\(request.workDate?.dutchLongDate ?? "") - \(statusText)").font(.caption).foregroundStyle(.secondary)
            if let ps = request.partStart, let pe = request.partEnd {
                Text("Deel: \(ps.hhmm) – \(pe.hhmm)").font(.caption).foregroundStyle(.secondary)
            }
            if let name = request.requestedName {
                Text("Collega: \(name)").font(.caption).foregroundStyle(.secondary)
            }
            if let notes = request.adminNotes, !notes.isEmpty {
                Text("Teamleider: \(notes)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RequestSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shift: SwapShift
    let colleagues: [Colleague]
    let onSubmit: (_ colleagueId: Int?, _ reason: String?, _ partStart: String?, _ partEnd: String?) -> Void

    @State private var selectedColleagueId: Int?
    @State private var reason: String = ""
    @State private var partial = false
    @State private var partStart = Date()
    @State private var partEnd = Date()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private var shiftStart: Date? { shift.startTime.flatMap { Self.timeFormatter.date(from: $0.hhmm) } }
    private var shiftEnd: Date? { shift.endTime.flatMap { Self.timeFormatter.date(from: $0.hhmm) } }

    /// Partial swaps are only possible for shifts with fixed, same-day times.
    private var canSplit: Bool {
        guard let s = shiftStart, let e = shiftEnd else { return false }
        return e > s
    }

    private var partValid: Bool {
        !partial || partEnd > partStart
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 6) {
                        LocationLogo(locationName: shift.locationName, size: 22)
                        Text("\(shift.shiftName ?? "Dienst") op \(shift.workDate.dutchLongDate)")
                    }
                }

                if canSplit, let s = shiftStart, let e = shiftEnd {
                    Section {
                        Toggle("Alleen een deel van de dienst", isOn: $partial)
                        if partial {
                            DatePicker("Van", selection: $partStart, in: s...e, displayedComponents: .hourAndMinute)
                            DatePicker("Tot", selection: $partEnd, in: s...e, displayedComponents: .hourAndMinute)
                            if !partValid {
                                Text("De eindtijd moet na de begintijd liggen.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    } footer: {
                        Text("Dienst: \(Self.timeFormatter.string(from: s)) – \(Self.timeFormatter.string(from: e))")
                    }
                }

                Section("Aan wie?") {
                    Picker("Collega", selection: $selectedColleagueId) {
                        Text("Iedereen op de locatie (open aanbod)").tag(Int?.none)
                        ForEach(colleagues) { c in
                            Text(c.name).tag(Int?.some(c.id))
                        }
                    }
                    // Opens a full, scrollable list instead of a compact menu
                    .pickerStyle(.navigationLink)
                }

                Section("Reden (optioneel)") {
                    TextField("Reden", text: $reason, axis: .vertical)
                }
            }
            .navigationTitle("Dienst ruilen")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let s = shiftStart { partStart = s }
                if let e = shiftEnd { partEnd = e }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Indienen") {
                        onSubmit(
                            selectedColleagueId,
                            reason.isEmpty ? nil : reason,
                            partial ? Self.timeFormatter.string(from: partStart) : nil,
                            partial ? Self.timeFormatter.string(from: partEnd) : nil
                        )
                        dismiss()
                    }
                    .disabled(!partValid)
                }
            }
        }
    }
}

private struct EmptyText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
    }
}
