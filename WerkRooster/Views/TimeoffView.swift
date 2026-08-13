import SwiftUI

struct TimeoffView: View {
    @EnvironmentObject private var vm: AppViewModel

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedType = "vacation"
    @State private var reason = ""

    private let typeOptions: [(String, String)] = [
        ("vacation", "Vakantie"),
        ("personal", "Persoonlijk"),
        ("appointment", "Afspraak/dokter"),
        ("other", "Overig")
    ]

    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
                                startDate: isoFormatter.string(from: startDate),
                                endDate: isoFormatter.string(from: endDate),
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
                    .disabled(vm.loading)

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
                            TimeoffCard(item: item)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .task { await vm.loadTimeoff() }
    }
}

private struct TimeoffCard: View {
    let item: TimeoffItem

    var statusText: String {
        switch item.status {
        case "pending": return "⏳ In behandeling"
        case "approved": return "✅ Goedgekeurd"
        case "rejected": return "❌ Afgekeurd"
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
            Text("\(formatDate(item.startDate)) t/m \(formatDate(item.endDate)) (\(item.daysRequested ?? 0) dagen)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let reason = item.reason, !reason.isEmpty {
                Text("Reden: \(reason)").font(.caption)
            }
            if let notes = item.adminNotes, !notes.isEmpty {
                Text("Reactie planner: \(notes)").font(.caption).foregroundStyle(.secondary)
            }
            if let requested = item.requestedAt {
                Text("Aangevraagd: \(formatDate(String(requested.prefix(10))))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(statusColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.dateFormat = "dd-MM-yyyy"
        guard let date = input.date(from: iso) else { return iso }
        return output.string(from: date)
    }
}
