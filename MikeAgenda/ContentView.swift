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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad：固定左侧边栏菜单
                SidebarView()
            } else {
                // iPhone：底部标签栏
                tabView
            }
        }
        .onAppear { locationService.requestLocation() }
    }

    private var tabView: some View {
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
                    servicesView
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
    }

    @ViewBuilder
    private var servicesView: some View {
        if locationService.manualCity == "hk" || (locationService.manualCity == nil && locationService.isInHongKong) {
            HongKongView()
        } else {
            ShenzhenView()
        }
    }
}

/// iPad 专用：左侧固定边栏菜单 + 右侧内容区
struct SidebarView: View {
    @ObservedObject private var locationService = LocationService.shared
    @State private var selection: SidebarItem? = .dashboard

    private enum SidebarItem: Hashable {
        case dashboard, items, courses, services
        case cycles, renewals, projects, checklists
        case settings
    }

    private var showServices: Bool {
        locationService.isInShenzhen || locationService.isInHongKong || locationService.manualCity != nil
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label("首页", systemImage: "house.fill").tag(SidebarItem.dashboard)
                    Label("事项", systemImage: "checklist").tag(SidebarItem.items)
                    Label("课表", systemImage: "calendar").tag(SidebarItem.courses)
                    if showServices {
                        Label("服务", systemImage: "building.2.fill").tag(SidebarItem.services)
                    }
                }
                Section("管理") {
                    Label("周期任务", systemImage: "arrow.triangle.2.circlepath").tag(SidebarItem.cycles)
                    Label("续订提醒", systemImage: "bell").tag(SidebarItem.renewals)
                    Label("项目", systemImage: "folder").tag(SidebarItem.projects)
                    Label("检查清单", systemImage: "checklist").tag(SidebarItem.checklists)
                }
                Section {
                    Label("设置", systemImage: "gear").tag(SidebarItem.settings)
                }
            }
            .navigationTitle("MikeAgenda")
        } detail: {
            NavigationStack {
                detailView
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .dashboard {
        case .dashboard:
            DashboardView()
        case .items:
            ItemListView()
        case .courses:
            CourseListView()
        case .services:
            if locationService.manualCity == "hk" || (locationService.manualCity == nil && locationService.isInHongKong) {
                HongKongView()
            } else {
                ShenzhenView()
            }
        case .cycles:
            CycleListView()
        case .renewals:
            RenewalListView()
        case .projects:
            ProjectListView()
        case .checklists:
            ChecklistListView()
        case .settings:
            SettingsView()
        }
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
