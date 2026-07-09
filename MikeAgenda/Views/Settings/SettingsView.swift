import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionService: SessionService
    @StateObject private var settings = SettingsService.shared
    @State private var imageLimitMB = ""
    @State private var isLoading = false
    @State private var isSavingTeaching = false
    @State private var isSavingImage = false
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            Section("连接配置") {
                HStack {
                    Text("服务器地址")
                    Spacer()
                    Text(ConnectionProfileStore.load().domain)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("清除连接", systemImage: "trash")
                }
            }

            Section("外观") {
                Picker("颜色模式", selection: $settings.colorMode) {
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                    Text("适配系统").tag("system")
                }
            }

            Section("客户端") {
                HStack {
                    Text("刷新间隔（秒）")
                    Spacer()
                    TextField("秒", value: Binding(
                        get: { settings.refreshInterval ?? 0 },
                        set: { settings.refreshInterval = $0 > 0 ? $0 : nil }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            }

            Section("授课模式") {
                Toggle("授课模式", isOn: $settings.isTeaching)
                    .onChange(of: settings.isTeaching) { _ in
                        saveTeaching()
                    }
            }

            Section("图片") {
                HStack {
                    Text("图片存储限制（MB）")
                    Spacer()
                    TextField("MB", text: $imageLimitMB)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Button {
                    saveImageLimit()
                } label: {
                    HStack {
                        if isSavingImage {
                            ProgressView()
                        }
                        Text("保存图片限制")
                    }
                }
            }

            Section {
                NavigationLink("关于") {
                    AboutView()
                }
                NavigationLink("系统状态") {
                    SystemStatusView()
                }
            }
        }
        .navigationTitle("设置")
        .task {
            await loadSettings()
        }
        .confirmationDialog("确认清除连接配置？这将返回初始设置页面。", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("确认", role: .destructive) {
                ConnectionProfileStore.clear()
                sessionService.clear()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func loadSettings() async {
        isLoading = true
        do {
            settings.isTeaching = try await APIClient.shared.getTeachingStatus()
        } catch { settings.isTeaching = false }

        do {
            let limit = try await APIClient.shared.getImageStorageLimit()
            let mb = limit / (1024 * 1024)
            imageLimitMB = mb > 0 ? "\(mb)" : ""
        } catch { imageLimitMB = "" }

        isLoading = false
    }

    private func saveTeaching() {
        isSavingTeaching = true
        Task {
            try? await APIClient.shared.setTeachingStatus(settings.isTeaching)
            await MainActor.run { isSavingTeaching = false }
        }
    }

    private func saveImageLimit() {
        guard let mb = Int(imageLimitMB), mb > 0 else { return }
        isSavingImage = true
        Task {
            try? await APIClient.shared.setImageStorageLimit(bytes: mb * 1024 * 1024)
            await MainActor.run { isSavingImage = false }
        }
    }
}
