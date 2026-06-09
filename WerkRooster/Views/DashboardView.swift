import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var vm: AppViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                nextShiftCard
                if let me = vm.me, !me.locations.isEmpty {
                    Text("Locaties: \(me.locations.map(\.name).joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppViewModel.Dest.allCases.filter { $0 != .dashboard }) { dest in
                        Button {
                            vm.destinationChanged(dest)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: dest.symbol)
                                    .font(.system(size: 24))
                                Text(dest.title)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welkom,")
                Text(vm.me?.user.displayName ?? "")
                    .font(.title2.bold())
            }
            Spacer()
            Button("Log uit", role: .destructive) {
                Task { await vm.logout() }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var nextShiftCard: some View {
        if let shift = vm.nextShift {
            Button {
                vm.destinationChanged(.schedule)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Volgende dienst").font(.caption).foregroundStyle(.secondary)
                    Text(shift.shiftName ?? "Dienst").font(.headline)
                    if let start = shift.startTime, let end = shift.endTime {
                        Text("\(shift.workDate) • \(start.hhmm) - \(end.hhmm)")
                    } else {
                        Text(shift.workDate)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else {
            Text("Geen geplande diensten gevonden voor de komende tijd.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
