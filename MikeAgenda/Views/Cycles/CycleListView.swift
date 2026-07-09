import SwiftUI

struct CycleListView: View {
    @State private var cycles: [Cycle] = []
    @State private var isLoading = true
    @State private var showForm = false

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if cycles.isEmpty {
                EmptyStateView(icon: "arrow.triangle.2.circlepath", message: "暂无周期任务", action: { showForm = true }, actionLabel: "创建周期")
            } else {
                ForEach(cycles) { cycle in
                    NavigationLink {
                        CycleFormView(cycle: cycle, onSaved: { Task { await load() } })
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cycle.name ?? cycle.title ?? "未命名")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            if let formatted = formatCycle(cycle.cycle) {
                                Text(formatted)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let nextTime = cycle.nextTime {
                                Text("下次: \(String(nextTime.prefix(10)))")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                try? await APIClient.shared.deleteCycle(id: cycle.id)
                                await load()
                            }
                        } label: { Label("删除", systemImage: "trash") }
                        Button {
                            Task {
                                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'00:00:00"
                                try? await APIClient.shared.updateCycleNextTime(id: cycle.id, nexttime: f.string(from: Date()))
                                await load()
                            }
                        } label: { Label("今日执行", systemImage: "checkmark") }
                        .tint(.green)
                        Button {
                            Task {
                                try? await APIClient.shared.delayCycleNextDate(id: cycle.id)
                                await load()
                            }
                        } label: { Label("推迟", systemImage: "forward") }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("周期任务")
        .toolbar { Button { showForm = true } label: { Image(systemName: "plus") } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showForm) {
            NavigationStack { CycleFormView(onSaved: { Task { await load() } }) }
        }
    }

    private func load() async {
        isLoading = true
        cycles = (try? await APIClient.shared.getCycles()) ?? []
        isLoading = false
    }

    private func formatCycle(_ raw: String?) -> String? {
        guard let raw, let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cycleType = json["cycle"] as? String,
              let config = json["config"] as? [String: Any] else { return nil }
        switch cycleType {
        case "weekly":
            let days = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
            let day: Int
            if let s = config["day"] as? String { day = Int(s) ?? 0 } else { day = config["day"] as? Int ?? 0 }
            return "每周 \(days[day])"
        case "monthly":
            let day: Int
            if let s = config["day"] as? String { day = Int(s) ?? 0 } else { day = config["day"] as? Int ?? 0 }
            return "每月第 \(day) 天"
        case "monthly_last":
            let day: Int
            if let s = config["day"] as? String { day = Int(s) ?? 0 } else { day = config["day"] as? Int ?? 0 }
            return "每月倒数第 \(day) 天"
        case "daily": return "每天"
        default: return cycleType
        }
    }
}
