import SwiftUI

/// Teamleider-only screen: approve or reject swap and time-off requests.
struct TeamleaderView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var rejectTarget: RejectTarget?
    @State private var rejectNotes = ""

    enum RejectTarget: Identifiable {
        case swap(Int)
        case timeoff(Int)

        var id: String {
            switch self {
            case .swap(let id): return "swap-\(id)"
            case .timeoff(let id): return "timeoff-\(id)"
            }
        }
    }

    private var waitingSwaps: [ApprovalSwap] { vm.approvals?.swaps.filter { $0.status == "accepted" } ?? [] }
    private var openSwaps: [ApprovalSwap] { vm.approvals?.swaps.filter { $0.status != "accepted" } ?? [] }
    private var timeoff: [ApprovalTimeoff] { vm.approvals?.timeoff ?? [] }

    var body: some View {
        List {
            if let status = vm.approvalsStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("🔁 Ruilverzoeken (\(waitingSwaps.count))") {
                if waitingSwaps.isEmpty {
                    Text("Geen ruilverzoeken die op jouw goedkeuring wachten.").foregroundStyle(.secondary)
                }
                ForEach(waitingSwaps) { swap in
                    SwapApprovalRow(swap: swap,
                        onApprove: { Task { await vm.decideSwap(id: swap.id, approve: true, notes: nil) } },
                        onReject: { startReject(.swap(swap.id)) }
                    )
                }
            }

            Section("🏖️ Verlofaanvragen (\(timeoff.count))") {
                if timeoff.isEmpty {
                    Text("Geen openstaande verlofaanvragen.").foregroundStyle(.secondary)
                }
                ForEach(timeoff) { item in
                    TimeoffApprovalRow(item: item,
                        onApprove: { Task { await vm.decideTimeoff(id: item.id, approve: true, notes: nil) } },
                        onReject: { startReject(.timeoff(item.id)) }
                    )
                }
            }

            if !openSwaps.isEmpty {
                Section("⏳ Wacht nog op een collega (\(openSwaps.count))") {
                    ForEach(openSwaps) { swap in
                        SwapApprovalRow(swap: swap, onApprove: nil, onReject: { startReject(.swap(swap.id)) })
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.loadApprovals() }
        .task {
            vm.approvalsStatus = nil
            await vm.loadApprovals()
        }
        .sheet(item: $rejectTarget) { target in
            NavigationStack {
                Form {
                    Section("Toelichting voor de medewerker (optioneel)") {
                        TextField("Toelichting", text: $rejectNotes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
                .navigationTitle("Afwijzen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuleren") { rejectTarget = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Afwijzen", role: .destructive) {
                            let notes = rejectNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                            let n = notes.isEmpty ? nil : notes
                            switch target {
                            case .swap(let id): Task { await vm.decideSwap(id: id, approve: false, notes: n) }
                            case .timeoff(let id): Task { await vm.decideTimeoff(id: id, approve: false, notes: n) }
                            }
                            rejectTarget = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func startReject(_ target: RejectTarget) {
        rejectNotes = ""
        rejectTarget = target
    }
}

private struct DecisionButtons: View {
    let onApprove: (() -> Void)?
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let onApprove {
                Button(action: onApprove) {
                    Text("Goedkeuren").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Button(role: .destructive, action: onReject) {
                Text("Afwijzen").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }
}

private struct SwapApprovalRow: View {
    let swap: ApprovalSwap
    let onApprove: (() -> Void)?
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                LocationLogo(locationName: swap.locationName, size: 22)
                Text(swap.shiftName ?? "Dienst").font(.headline)
            }
            Text("\(swap.workDate?.dutchLongDate ?? "") · \(swap.locationName ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let ps = swap.partStart, let pe = swap.partEnd {
                Text("Deel van de dienst: \(ps.hhmm) – \(pe.hhmm)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.teal)
                if let s = swap.startTime, let e = swap.endTime {
                    Text("Hele dienst: \(s.hhmm) – \(e.hhmm)").font(.caption).foregroundStyle(.secondary)
                }
            } else if let s = swap.startTime, let e = swap.endTime {
                Text("\(s.hhmm) – \(e.hhmm)").font(.subheadline).foregroundStyle(.blue)
            }
            Text("Van: \(swap.requesterName ?? "?")").font(.subheadline)
            Text("Naar: \(swap.takerName ?? "nog niemand (open aanbod)")").font(.subheadline.weight(.medium))
            if let reason = swap.reason, !reason.isEmpty {
                Text("Reden: \(reason)").font(.caption).foregroundStyle(.secondary)
            }
            DecisionButtons(onApprove: onApprove, onReject: onReject)
        }
        .padding(.vertical, 4)
    }
}

private struct TimeoffApprovalRow: View {
    let item: ApprovalTimeoff
    let onApprove: () -> Void
    let onReject: () -> Void

    private var typeLabel: String {
        switch item.type {
        case "vacation": return "Vakantie"
        case "personal": return "Persoonlijk"
        case "appointment": return "Afspraak"
        case "sick": return "Ziek"
        case "other": return "Overig"
        default: return item.type
        }
    }

    private var period: String {
        item.startDate == item.endDate
            ? item.startDate.dutchLongDate
            : "\(item.startDate.dutchLongDate) t/m \(item.endDate.dutchLongDate)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.employeeName ?? "Medewerker").font(.headline)
            Text(period).font(.subheadline)
            let days = item.daysRequested ?? 1
            Text("\(typeLabel) · \(days) \(days == 1 ? "dag" : "dagen")")
                .font(.caption)
                .foregroundStyle(.blue)
            if let reason = item.reason, !reason.isEmpty {
                Text("Reden: \(reason)").font(.caption).foregroundStyle(.secondary)
            }
            DecisionButtons(onApprove: onApprove, onReject: onReject)
        }
        .padding(.vertical, 4)
    }
}
