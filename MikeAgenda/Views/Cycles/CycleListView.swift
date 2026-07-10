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
                                await executeToday(cycle)
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

    private func executeToday(_ cycle: Cycle) async {
        guard let baseURL = ConnectionProfileStore.load().normalizedBaseURL,
              let session = SessionService.shared.session else { return }
        let url = baseURL.appendingPathComponent("/api/updateCycleNextTime")
        let nexttime = computeNextNextDate(cycle: cycle)
        let body: [String: Any] = ["id": String(cycle.id), "nexttime": nexttime, "session": session]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(session, forHTTPHeaderField: "session")
        request.setValue("session=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let _ = try? await URLSession.shared.data(for: request)
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

    private func computeNextNextDate(cycle: Cycle) -> String {
        guard let raw = cycle.cycle, let data = raw.data(using: .utf8),
              let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cycleType = outer["cycle"] as? String else {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'00:00:00"
            return f.string(from: Date())
        }

        let config: [String: Any]
        if let dict = outer["config"] as? [String: Any] {
            config = dict
        } else if let configStr = outer["config"] as? String,
                  let configData = configStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            config = parsed
        } else {
            config = [:]
        }

        let cal = Calendar.current
        let dayConfig: Int
        if let s = config["day"] as? String { dayConfig = Int(s) ?? 0 }
        else { dayConfig = config["day"] as? Int ?? 0 }

        let nextRaw = cycle.nextTime ?? ""
        let baseStr = String(nextRaw.prefix(10))
        let baseF = DateFormatter(); baseF.dateFormat = "yyyy-MM-dd"
        var base = baseF.date(from: baseStr) ?? Date()
        base = cal.startOfDay(for: base)
        var next = cal.date(byAdding: .day, value: 1, to: base)!
        var count = 0

        while count <= 365 {
            let ymd = ymdString(next)
            if isCycleMatch(type: cycleType, day: dayConfig, ymd: ymd) {
                let outF = DateFormatter(); outF.dateFormat = "yyyy-MM-dd'T'00:00:00"
                return outF.string(from: next)
            }
            next = cal.date(byAdding: .day, value: 1, to: next)!
            count += 1
        }

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'00:00:00"
        return f.string(from: Date())
    }

    private func ymdString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private func isCycleMatch(type: String, day: Int, ymd: String) -> Bool {
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        guard let date = f.date(from: ymd) else { return false }
        switch type {
        case "daily": return true
        case "weekly":
            return cal.component(.weekday, from: date) - 1 == day
        case "monthly":
            return cal.component(.day, from: date) == day
        case "monthly_last":
            let range = cal.range(of: .day, in: .month, for: date)!
            return range.count - cal.component(.day, from: date) + 1 == day
        default: return false
        }
    }
}
