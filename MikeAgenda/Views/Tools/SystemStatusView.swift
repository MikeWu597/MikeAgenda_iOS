import SwiftUI

struct SystemStatusView: View {
    @State private var status: SystemStatusData?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let err = error {
                Text(err)
                    .foregroundColor(.red)
            } else if let status {
                Section {
                    HStack {
                        Text("内存占用")
                        Spacer()
                        Text("\(status.memoryUsage ?? "--") MB")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("系统时钟")
                        Spacer()
                        Text(status.systemTime ?? "--")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("运行时间")
                        Spacer()
                        Text(formatUptime(status.uptime ?? 0))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("系统状态")
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        do {
            status = try await APIClient.shared.getSystemStatus()
        } catch let e {
            error = e.localizedDescription
        }
        isLoading = false
    }

    private func formatUptime(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        return "\(days)天 \(hours)小时 \(minutes)分钟"
    }
}
