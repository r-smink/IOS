import SwiftUI

@main
struct WerkRoosterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task { await vm.bootstrap() }
                .onReceive(NotificationCenter.default.publisher(for: .fcmTokenReceived)) { notification in
                    if let token = notification.object as? String {
                        Task { await vm.registerFCMToken(token) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .notificationTapped)) { notification in
                    if let type = notification.object as? String {
                        vm.handleNotificationTap(type: type)
                    }
                }
        }
    }
}
