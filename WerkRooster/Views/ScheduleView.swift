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

    private var activeSchedules: [ScheduleItem] {
        vm.scheduleFilter == .full ? vm.fullSchedules : vm.schedules
    }

    private var monthString: String {
        vm.monthString(from: monthDate)
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Filter", selection: $vm.scheduleFilter) {
                ForEach(AppViewModel.ScheduleFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if vm.scheduleFilter == .full, let locations = vm.me?.locations, locations.count > 1 {
                Picker("Locatie", selection: $vm.selectedScheduleLocationId) {
                    ForEach(locations) { location in
                        Text(location.name).tag(Optional(location.id))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.selectedScheduleLocationId) { _ in
                    Task { await reload() }
                }
            }

            Picker("Mode", selection: $mode) {
                Text("Lijst").tag(Mode.list)
                Text("Kalender").tag(Mode.calendar)
            }
            .pickerStyle(.segmented)

            MonthHeader(monthDate: $monthDate) { _ in
                Task { await reload() }
            }

            if vm.scheduleFilter == .full, !(vm.monthStatus?.isFinalized ?? false) {
                NotFinalizedCard(month: monthString)
            } else if mode == .list {
                List(activeSchedules) { item in
                    ScheduleCard(item: item)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            } else {
                ScheduleCalendar(monthDate: monthDate, schedules: activeSchedules)
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
        .task {
            await reload()
        }
        .onChange(of: vm.scheduleFilter) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        let month = monthString
        if vm.scheduleFilter == .full {
            await vm.loadMonthStatus(month: month)
            if vm.monthStatus?.isFinalized == true {
                await vm.loadFullSchedules(month: month)
            } else {
                vm.fullSchedules = []
            }
        } else {
            let start = monthDate.startOfMonth.isoDate
            let end = monthDate.endOfMonth.isoDate
            await vm.loadSchedules(start: start, end: end)
        }
    }
}

private struct NotFinalizedCard: View {
    let month: String

    var body: some View {
        VStack(spacing: 8) {
            Label("Rooster nog niet definitief", systemImage: "hourglass")
                .font(.headline)
            Text("Het rooster voor \(month) is nog niet definitief gemaakt door de planner.")
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
    }
}

private struct ScheduleCard: View {
    let item: ScheduleItem

    private var effectiveStart: String { item.startTime ?? item.shiftStartTime ?? "" }
    private var effectiveEnd: String { item.endTime ?? item.shiftEndTime ?? "" }
    private var isCustomTime: Bool {
        (item.startTime != nil && item.startTime != item.shiftStartTime) ||
        (item.endTime != nil && item.endTime != item.shiftEndTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.shiftName ?? "Dienst").font(.headline)
            if let employee = item.employeeName, !employee.isEmpty {
                Text(employee).font(.subheadline).fontWeight(.medium)
            }
            Text(item.locationName ?? "").font(.subheadline)
            Text(item.workDate).font(.caption)
            if !effectiveStart.isEmpty && !effectiveEnd.isEmpty {
                Text("\(effectiveStart.hhmm) - \(effectiveEnd.hhmm)").foregroundStyle(.blue)
            } else {
                Text("Flexibel").font(.subheadline).foregroundStyle(.secondary)
            }
            if isCustomTime && !effectiveStart.isEmpty && !effectiveEnd.isEmpty {
                Text("Aangepast: \(effectiveStart.hhmm) - \(effectiveEnd.hhmm)")
                    .font(.caption)
                    .foregroundStyle(.teal)
                    .fontWeight(.medium)
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
