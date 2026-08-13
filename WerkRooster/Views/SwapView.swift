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

                // Incoming requests
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
        .task { await vm.loadSwapData() }
        .sheet(item: $showRequestDialog) { shift in
            RequestSwapSheet(shift: shift, colleagues: vm.swapColleagues) { colleagueId, reason in
                Task { await vm.requestSwap(scheduleId: shift.id, colleagueId: colleagueId, reason: reason) }
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

private struct MyShiftCard: View {
    let shift: SwapShift
    let onToggle: () -> Void
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shift.shiftName ?? "Dienst").font(.subheadline.bold())
            Text("\(shift.workDate)  \(shift.locationName ?? "")").font(.caption).foregroundStyle(.secondary)
            if let s = shift.startTime, let e = shift.endTime {
                Text("\(s) – \(e)").font(.caption).foregroundStyle(.blue)
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
            Text(shift.shiftName ?? "Dienst").font(.subheadline.bold())
            Text("\(shift.workDate)  \(shift.locationName ?? "")").font(.caption).foregroundStyle(.secondary)
            if let s = shift.startTime, let e = shift.endTime {
                Text("\(s) – \(e)").font(.caption).foregroundStyle(.blue)
            }
            if let owner = shift.ownerName {
                Text("Van: \(owner)").font(.caption)
            }
            Button(action: onClaim) {
                Text("Dienst overnemen").frame(maxWidth: .infinity)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(request.shiftName ?? "Dienst").font(.subheadline.bold())
            Text("\(request.workDate ?? "")  \(request.locationName ?? "")").font(.caption).foregroundStyle(.secondary)
            if let r = request.requesterName { Text("Van: \(r)").font(.caption) }
            if let reason = request.reason, !reason.isEmpty {
                Text("Reden: \(reason)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Text("Accepteren").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive, action: onReject) {
                    Text("Weigeren").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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
        case "pending": return "⏳ In behandeling"
        case "approved", "completed": return "✓ Voltooid"
        case "rejected": return "✗ Afgewezen"
        default: return request.status
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(request.shiftName ?? "Dienst").font(.subheadline)
            Text("\(request.workDate ?? "") - \(statusText)").font(.caption).foregroundStyle(.secondary)
            if let name = request.requestedName {
                Text("Gevraagd aan: \(name)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RequestSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shift: SwapShift
    let colleagues: [Colleague]
    let onSubmit: (Int?, String?) -> Void

    @State private var selectedColleague: Colleague?
    @State private var reason: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(shift.shiftName ?? "Dienst") op \(shift.workDate)")
                }
                Section("Specifieke collega (optioneel)") {
                    Picker("Collega", selection: $selectedColleague) {
                        Text("Iedereen mag reageren").tag(Colleague?.none)
                        ForEach(colleagues) { c in
                            Text(c.name).tag(Colleague?.some(c))
                        }
                    }
                }
                Section("Reden (optioneel)") {
                    TextField("Reden", text: $reason, axis: .vertical)
                }
            }
            .navigationTitle("Dienst ruilen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Indienen") {
                        onSubmit(selectedColleague?.id, reason.isEmpty ? nil : reason)
                        dismiss()
                    }
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
