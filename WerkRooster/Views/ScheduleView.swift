import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var mode: Mode = .calendar
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
                ScheduleCalendar(
                    monthDate: monthDate,
                    schedules: activeSchedules,
                    showEmployees: vm.scheduleFilter == .full,
                    currentEmployeeId: vm.currentEmployeeId
                )
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
            HStack(spacing: 6) {
                LocationLogo(locationName: item.locationName, size: 22)
                Text(item.shiftName ?? "Dienst").font(.headline)
            }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let showEmployees: Bool
    let currentEmployeeId: Int
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
                ForEach((0..<monthDate.leadingWeekdayOffset).map { "empty-\($0)" }, id: \.self) { _ in
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
                Group {
                    if showEmployees {
                        DayOverview(schedules: selected, currentEmployeeId: currentEmployeeId)
                    } else {
                        List(selected) { item in
                            ScheduleCard(item: item)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .navigationTitle(selectedDate.dutchLongDate)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Sluiten") { selected = [] } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Compact "who works today" view: one section per shift, one line per employee.
private struct DayOverview: View {
    let schedules: [ScheduleItem]
    let currentEmployeeId: Int

    private struct ShiftGroup: Identifiable {
        let id: String
        let first: ScheduleItem
        let items: [ScheduleItem]
    }

    private var groups: [ShiftGroup] {
        let sorted = schedules.sorted {
            let a = ($0.shiftStartTime ?? $0.startTime ?? "99", $0.shiftName ?? "", $0.employeeName ?? "")
            let b = ($1.shiftStartTime ?? $1.startTime ?? "99", $1.shiftName ?? "", $1.employeeName ?? "")
            return a < b
        }
        var order: [String] = []
        var byKey: [String: [ScheduleItem]] = [:]
        for item in sorted {
            let key = "\(item.locationName ?? "")|\(item.shiftName ?? "")|\(item.shiftId ?? 0)"
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(item)
        }
        return order.compactMap { key in
            guard let items = byKey[key], let first = items.first else { return nil }
            return ShiftGroup(id: key, first: first, items: items)
        }
    }

    private var peopleCount: Int {
        Set(schedules.compactMap(\.employeeId)).count
    }

    private func range(_ start: String?, _ end: String?) -> String {
        guard let start, let end else { return "" }
        return "\(start.hhmm)–\(end.hhmm)"
    }

    var body: some View {
        List {
            Text("\(peopleCount) \(peopleCount == 1 ? "medewerker" : "medewerkers") aan het werk")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)

            ForEach(groups) { group in
                let shiftRange = range(group.first.shiftStartTime ?? group.first.startTime, group.first.shiftEndTime ?? group.first.endTime)
                Section {
                    ForEach(group.items) { item in
                        let isMe = item.employeeId == currentEmployeeId
                        let ownRange = range(item.startTime, item.endTime)
                        HStack {
                            Text((item.employeeName ?? "Onbekend") + (isMe ? " (jij)" : ""))
                                .fontWeight(isMe ? .bold : .regular)
                                .foregroundStyle(isMe ? Color.accentColor : Color.primary)
                            Spacer()
                            // Only show times when they differ from the shift's default
                            if !ownRange.isEmpty && ownRange != shiftRange {
                                Text(ownRange).font(.caption).foregroundStyle(.teal)
                            }
                        }
                        .font(.subheadline)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: group.first.color) ?? .blue)
                            .frame(width: 10, height: 10)
                        LocationLogo(locationName: group.first.locationName, size: 18)
                        Text(group.first.shiftName ?? "Dienst")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(shiftRange.isEmpty ? "Flexibel" : shiftRange)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 30)
    }
}

private extension Color {
    /// "#3b82f6" -> Color
    init?(hex: String?) {
        guard var value = hex?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
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
