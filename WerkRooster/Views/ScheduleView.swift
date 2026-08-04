import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var mode: Mode = .list
    @State private var monthDate = Date()

    enum Mode: String, CaseIterable, Identifiable {
        case list
        case calendar
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                Text("Lijst").tag(Mode.list)
                Text("Kalender").tag(Mode.calendar)
            }
            .pickerStyle(.segmented)

            if mode == .list {
                Button("Vernieuw rooster") {
                    Task { await vm.refreshSchedules() }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                List(vm.schedules) { item in
                    ScheduleCard(item: item)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            } else {
                MonthHeader(monthDate: $monthDate) { changed in
                    let start = changed.startOfMonth.isoDate
                    let end = changed.endOfMonth.isoDate
                    Task { await vm.loadSchedules(start: start, end: end) }
                }
                ScheduleCalendar(monthDate: monthDate, schedules: vm.schedules)
                    .task {
                        let start = monthDate.startOfMonth.isoDate
                        let end = monthDate.endOfMonth.isoDate
                        await vm.loadSchedules(start: start, end: end)
                    }
                HStack(spacing: 10) {
                    ScheduleLegendDot(color: .blue, label: "Gepland")
                    ScheduleLegendDot(color: .green, label: "Voltooid")
                    ScheduleLegendDot(color: .orange, label: "In wachting")
                    ScheduleLegendDot(color: .red, label: "Geannuleerd")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

private struct ScheduleCard: View {
    let item: ScheduleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.shiftName ?? "Dienst").font(.headline)
            Text(item.locationName ?? "").font(.subheadline)
            Text(item.workDate).font(.caption)
            if let start = item.startTime, let end = item.endTime {
                Text("\(start.hhmm) - \(end.hhmm)").foregroundStyle(.blue)
            }
            if let notes = item.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
            if item.status != "scheduled" {
                StatusBadge(status: item.status)
            }
        }
        .padding(12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var cardBackground: Color {
        switch item.status {
        case "cancelled": return Color.red.opacity(0.12)
        case "completed": return Color.green.opacity(0.12)
        case "pending", "provisional": return Color.orange.opacity(0.12)
        default: return Color(.secondarySystemBackground)
        }
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(statusLabel)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor, in: Capsule())
            .foregroundStyle(.white)
    }

    private var statusLabel: String {
        switch status {
        case "cancelled": return "GEANNULEERD"
        case "completed": return "VOLTOOID"
        case "pending", "provisional": return "IN WACHTING"
        case "swapped": return "GERUILD"
        default: return status.uppercased()
        }
    }

    private var badgeColor: Color {
        switch status {
        case "cancelled": return .red
        case "completed": return .green
        case "pending", "provisional": return .orange
        case "swapped": return .purple
        default: return .gray
        }
    }
}

private struct ScheduleCalendar: View {
    let monthDate: Date
    let schedules: [ScheduleItem]
    @State private var selected: [ScheduleItem] = []
    @State private var selectedDate = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdays = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    private func statusDotColor(_ status: String) -> Color {
        switch status {
        case "cancelled": return .red
        case "completed": return .green
        case "pending", "provisional": return .orange
        case "swapped": return .purple
        default: return .blue
        }
    }

    private func dayCellBackground(_ daySchedules: [ScheduleItem]) -> Color {
        if daySchedules.isEmpty { return Color(.secondarySystemBackground).opacity(0.5) }
        let hasCancelled = daySchedules.contains { $0.status == "cancelled" }
        let hasCompleted = daySchedules.contains { $0.status == "completed" }
        let hasPending = daySchedules.contains { $0.status == "pending" || $0.status == "provisional" }
        if hasCancelled && !daySchedules.allSatisfy({ $0.status == "cancelled" }) { return Color.orange.opacity(0.2) }
        if hasCancelled { return Color.red.opacity(0.15) }
        if hasCompleted { return Color.green.opacity(0.15) }
        if hasPending { return Color.orange.opacity(0.15) }
        return Color.blue.opacity(0.2)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<monthDate.leadingWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 38)
                }
                ForEach(1...monthDate.daysInMonth, id: \.self) { day in
                    let date = monthDate.dateFor(day: day).isoDate
                    let daySchedules = schedules.filter { $0.workDate == date }
                    Button {
                        if !daySchedules.isEmpty {
                            selected = daySchedules
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(day)")
                                .font(.caption)
                                .fontWeight(daySchedules.isEmpty ? .regular : .bold)
                            if !daySchedules.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(0..<min(daySchedules.count, 3), id: \.self) { i in
                                        Circle().fill(statusDotColor(daySchedules[i].status)).frame(width: 4, height: 4)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(dayCellBackground(daySchedules), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: Binding(get: {
            !selected.isEmpty
        }, set: { newValue in
            if !newValue { selected = [] }
        }), onDismiss: { selected = [] }) {
            NavigationStack {
                List(selected) { item in
                    ScheduleCard(item: item)
                        .listRowSeparator(.hidden)
                }
                .navigationTitle("Diensten op \(selectedDate)")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Sluiten") { selected = [] } } }
            }
        }
    }
}

private struct ScheduleLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}
