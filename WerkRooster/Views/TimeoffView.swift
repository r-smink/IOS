import SwiftUI

struct TimeoffView: View {
    @EnvironmentObject private var vm: AppViewModel

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedType = "vacation"
    @State private var reason = ""
    @State private var withdrawTarget: TimeoffItem?

    private let typeOptions: [(String, String)] = [
        ("vacation", "Vakantie"),
        ("personal", "Persoonlijk"),
        ("appointment", "Afspraak/dokter"),
        ("other", "Overig")
    ]

    private var duplicateRequestExists: Bool {
        let start = startDate.isoDate
        let end = endDate.isoDate
        return vm.timeoffItems.contains {
            $0.startDate == start && $0.endDate == end &&
                $0.status != "rejected" && !TimeoffItem.withdrawnStatuses.contains($0.status)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Form
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nieuwe verlofaanvraag").font(.headline)

                    DatePicker("Start datum", selection: $startDate, in: Date()..., displayedComponents: .date)
                    DatePicker("Eind datum", selection: $endDate, in: startDate..., displayedComponents: .date)

                    Picker("Type verlof", selection: $selectedType) {
                        ForEach(typeOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }

                    TextField("Reden / Toelichting", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await vm.submitTimeoff(
                                startDate: startDate.isoDate,
                                endDate: endDate.isoDate,
                                type: selectedType,
                                reason: reason.isEmpty ? nil : reason
                            )
                            reason = ""
                        }
                    } label: {
                        Text(vm.loading ? "Verzenden..." : "Verlof Aanvragen")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.loading || duplicateRequestExists)

                    if duplicateRequestExists {
                        Text("Voor deze periode bestaat al een verlofaanvraag.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if let status = vm.timeoffStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                // History
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mijn Verlofaanvragen").font(.headline)
                    if vm.timeoffItems.isEmpty {
                        Text("Je hebt nog geen verlofaanvragen ingediend.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.timeoffItems) { item in
                            TimeoffCard(item: item, withdrawDisabled: vm.loading) {
                                withdrawTarget = item
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .task { await vm.loadTimeoff() }
        .confirmationDialog(
            "Verlofaanvraag intrekken?",
            isPresented: Binding(
                get: { withdrawTarget != nil },
                set: { if !$0 { withdrawTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: withdrawTarget
        ) { item in
            Button("Intrekken", role: .destructive) {
                Task { await vm.withdrawTimeoff(id: item.id) }
            }
            Button("Annuleren", role: .cancel) {}
        } message: { item in
            Text("Weet je zeker dat je je verlofaanvraag van \(TimeoffCard.formatDate(item.startDate)) t/m \(TimeoffCard.formatDate(item.endDate)) wilt intrekken?")
        }
    }
}

extension TimeoffItem {
    static let withdrawnStatuses: Set<String> = ["withdrawn", "cancelled", "canceled"]

    /// Intrekbaar zolang de aanvraag in behandeling is, of goedgekeurd en nog niet begonnen.
    var canWithdraw: Bool {
        switch status {
        case "pending":
            return true
        case "approved":
            return startDate > Date().isoDate
        default:
            return false
        }
    }
}

private struct TimeoffCard: View {
    let item: TimeoffItem
    let withdrawDisabled: Bool
    let onWithdraw: () -> Void

    var statusText: String {
        switch item.status {
        case "pending": return "⏳ In behandeling"
        case "approved": return "✅ Goedgekeurd"
        case "rejected": return "❌ Afgekeurd"
        case _ where TimeoffItem.withdrawnStatuses.contains(item.status): return "↩️ Ingetrokken"
        default: return item.status
        }
    }

    var typeText: String {
        switch item.type {
        case "vacation": return "🏖️ Vakantie"
        case "personal": return "👤 Persoonlijk"
        case "appointment": return "🏥 Afspraak"
        case "other": return "📝 Overig"
        default: return item.type
        }
    }

    var statusColor: Color {
        switch item.status {
        case "pending": return .orange.opacity(0.15)
        case "approved": return .green.opacity(0.15)
        case "rejected": return .red.opacity(0.15)
        default: return Color(.secondarySystemBackground)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(typeText).font(.subheadline.bold())
                Spacer()
                Text(statusText).font(.caption)
            }
            Text("\(Self.formatDate(item.startDate)) t/m \(Self.formatDate(item.endDate)) (\(item.daysRequested ?? 0) dagen)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let reason = item.reason, !reason.isEmpty {
                Text("Reden: \(reason)").font(.caption)
            }
            if let notes = item.adminNotes, !notes.isEmpty {
                Text("Reactie planner: \(notes)").font(.caption).foregroundStyle(.secondary)
            }
            if let requested = item.requestedAt {
                Text("Aangevraagd: \(Self.formatDate(String(requested.prefix(10))))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if item.canWithdraw {
                HStack {
                    Spacer()
                    Button("Aanvraag intrekken", role: .destructive, action: onWithdraw)
                        .font(.caption.bold())
                        .disabled(withdrawDisabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(statusColor, in: RoundedRectangle(cornerRadius: 8))
    }

    static func formatDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.dateFormat = "dd-MM-yyyy"
        guard let date = input.date(from: iso) else { return iso }
        return output.string(from: date)
    }
}
