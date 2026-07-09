import SwiftUI

struct SystemStatusView: View {
    @State private var status = "加载中..."
    @State private var isLoading = true

    var body: some View {
        List {
            Section("服务器状态") {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("加载中...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(status)
                }
            }
        }
        .navigationTitle("系统状态")
        .task {
            do {
                status = try await APIClient.shared.getSystemStatus()
            } catch {
                status = "无法连接: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
