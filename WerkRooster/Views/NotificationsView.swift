import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        Group {
            if vm.notifications.isEmpty {
                Text("Geen meldingen").font(.headline)
            } else {
                List(vm.notifications) { notification in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(notification.title).font(.headline)
                        if let message = notification.message, !message.isEmpty {
                            Text(message)
                        }
                        Text(notification.createdAt.formattedNotificationDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .task {
                        if notification.isRead == 0 {
                            await vm.markNotificationRead(id: notification.id)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.loadNotifications() }
            }
        }
        .task { await vm.loadNotifications() }
    }
}
