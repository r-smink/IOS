import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            Button("Vernieuw meldingen") {
                Task { await vm.loadNotifications() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            if vm.notifications.isEmpty {
                Text("Geen meldingen").font(.headline)
                Spacer()
            } else {
                List(vm.notifications) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(n.title).font(.headline)
                        if let msg = n.message, !msg.isEmpty {
                            Text(msg)
                        }
                        Text(n.createdAt).font(.caption).foregroundStyle(.secondary)
                        if n.isRead == 0 {
                            Button("Markeer gelezen") {
                                Task { await vm.markNotificationRead(id: n.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .task { await vm.loadNotifications() }
    }
}
