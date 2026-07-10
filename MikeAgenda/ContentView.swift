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

            if locationService.isInShenzhen {
                NavigationStack {
                    ShenzhenView()
                }
                .tabItem {
                    Label("深圳", systemImage: "building.2.fill")
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

            Section("点餐") {
                Button { openURL("https://csd.order.place/store/112871/mode/prekiosk?_aigens_source=scan&onpremise=true") } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("学校点餐")
                            .foregroundStyle(.primary)
                    }
                }
                Button { openURL("https://h5.xiaonoodles.com/materialQrcodeId=1839797535331319808") } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("遇见小面点餐")
                            .foregroundStyle(.primary)
                    }
                }
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
