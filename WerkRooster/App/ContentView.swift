import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        Group {
            if vm.config == nil {
                LoginView()
            } else if vm.me != nil {
                MainShellView()
            } else {
                ProgressView("Laden...")
            }
        }
        .alert("Fout", isPresented: Binding(get: {
            vm.error != nil
        }, set: { newValue in
            if !newValue { vm.error = nil }
        }), actions: {
            Button("OK") { vm.error = nil }
        }, message: {
            Text(vm.error ?? "")
        })
    }
}

private struct MainShellView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        NavigationStack {
            destinationView
                .navigationTitle(vm.currentDest.title)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(AppViewModel.Dest.allCases) { dest in
                                Button(dest.title, systemImage: dest.symbol) {
                                    vm.destinationChanged(dest)
                                }
                            }
                            Divider()
                            Button("Log uit", role: .destructive) {
                                Task { await vm.logout() }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
        }
        .onChange(of: vm.currentDest) { _, newValue in
            vm.ensureChatConnected()
        }        
    }

    @ViewBuilder
    private var destinationView: some View {
        switch vm.currentDest {
        case .dashboard:
            DashboardView()
        case .schedule:
            ScheduleView()
        case .availability:
            AvailabilityView()
        case .profile:
            ProfileView()
        case .chat:
            ChatView()
        case .sick:
            SickView()
        case .notifications:
            NotificationsView()
        }
    }
}
