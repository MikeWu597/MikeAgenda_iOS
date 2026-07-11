import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionService: SessionService
    @EnvironmentObject private var settingsService: SettingsService

    @State private var profile = ConnectionProfileStore.load()
    @State private var needsSetup = false

    var body: some View {
        Group {
            if needsSetup || !profile.isComplete {
                SetupView()
            } else if !sessionService.isAuthenticated {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            profile = ConnectionProfileStore.load()
            needsSetup = !profile.isComplete
        }
        .onChange(of: sessionService.isAuthenticated) { _, _ in
            profile = ConnectionProfileStore.load()
            needsSetup = !profile.isComplete
        }
        .onChange(of: sessionService.profileVersion) { _, _ in
            profile = ConnectionProfileStore.load()
            needsSetup = !profile.isComplete
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var locationService = LocationService.shared

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }

            NavigationStack {
                ItemListView()
            }
            .tabItem {
                Label("事项", systemImage: "checklist")
            }

            NavigationStack {
                CourseListView()
            }
            .tabItem {
                Label("课表", systemImage: "calendar")
            }

            if locationService.isInShenzhen || locationService.isInHongKong || locationService.manualCity != nil {
                NavigationStack {
                    if locationService.manualCity == "hk" || (locationService.manualCity == nil && locationService.isInHongKong) {
                        HongKongView()
                    } else {
                        ShenzhenView()
                    }
                }
                .tabItem {
                    Label("服务", systemImage: "building.2.fill")
                }
            }

            NavigationStack {
                MoreView()
            }
            .tabItem {
                Label("更多", systemImage: "ellipsis")
            }
        }
        .onAppear { locationService.requestLocation() }
    }
}

struct MoreView: View {
    var body: some View {
        List {
            Section("管理") {
                NavigationLink { CycleListView() } label: { Label("周期任务", systemImage: "arrow.triangle.2.circlepath") }
                NavigationLink { RenewalListView() } label: { Label("续订提醒", systemImage: "bell") }
                NavigationLink { ProjectListView() } label: { Label("项目", systemImage: "folder") }
                NavigationLink { ChecklistListView() } label: { Label("检查清单", systemImage: "checklist") }
            }

            Section {
                NavigationLink { SettingsView() } label: { Label("设置", systemImage: "gear") }
            }
        }
        .navigationTitle("更多")
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
