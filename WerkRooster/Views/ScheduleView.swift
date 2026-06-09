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
            let range = "\(item.startTime?.hhmm ?? "") - \(item.endTime?.hhmm ?? "")"
            if !range.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(range).foregroundStyle(.blue)
            }
            if let notes = item.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScheduleCalendar: View {
    let monthDate: Date
    let schedules: [ScheduleItem]
    @State private var selected: [ScheduleItem] = []
    @State private var selectedDate = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdays = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

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
                                    ForEach(0..<min(daySchedules.count, 3), id: \.self) { _ in
                                        Circle().fill(Color.blue).frame(width: 4, height: 4)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(daySchedules.isEmpty ? Color(.secondarySystemBackground).opacity(0.5) : Color.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
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
