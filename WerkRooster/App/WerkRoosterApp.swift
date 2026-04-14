import SwiftUI

@main
struct WerkRoosterApp: App {
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task { await vm.bootstrap() }
        }
    }
}
