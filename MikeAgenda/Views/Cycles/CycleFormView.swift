import SwiftUI

struct CycleFormView: View {
    let cycle: Cycle?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var cycleType = "weekly"
    @State private var dayConfig = "1"
    @State private var dayInt = 1
    @State private var executeToday = false
    @State private var isLoading = false

    private let cycleTypes = [("daily", "每天"), ("weekly", "每周"), ("monthly", "每月固定日期"), ("monthly_last", "每月倒数")]

    init(cycle: Cycle? = nil, onSaved: @escaping () -> Void) {
        self.cycle = cycle
        self.onSaved = onSaved
    }

    var nextPreview: String {
        guard let d = computeNextDate() else { return "--" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    var body: some View {
        Form {
            Section("名称") { TextField("请输入任务名称", text: $name) }
            Section("备注") { TextField("备注（可选）", text: $note) }
            Section("周期类型") {
                Picker("类型", selection: $cycleType) {
                    ForEach(cycleTypes, id: \.0) { Text($0.1).tag($0.0) }
                }
                .onChange(of: cycleType) { _ in dayInt = 1; dayConfig = "1" }
            }
            if cycleType == "weekly" {
                Section("星期") {
                    Picker("选择星期", selection: $dayConfig) {
                        ForEach([("0","周日"),("1","周一"),("2","周二"),("3","周三"),("4","周四"),("5","周五"),("6","周六")], id: \.0) { v, label in Text(label).tag(v) }
                    }
                }
            } else if cycleType == "monthly" {
                Section("日期") { Stepper("第 \(dayInt) 天", value: $dayInt, in: 1...31) }
            } else if cycleType == "monthly_last" {
                Section("日期") { Stepper("倒数第 \(dayInt) 天", value: $dayInt, in: 1...31) }
            }
            Section("今天执行") { Toggle("今天执行", isOn: $executeToday) }
            Section("下次执行") { Text(nextPreview).foregroundColor(.blue) }
            Section {
                Button {
                    save()
                } label: {
                    HStack { Spacer(); if isLoading { ProgressView() }; Text(cycle == nil ? "创建周期" : "保存修改"); Spacer() }
                }
                .disabled(name.isEmpty || isLoading)
            }
        }
        .navigationTitle(cycle == nil ? "创建周期" : "编辑周期")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        .onAppear {
            if let cycle {
                name = cycle.name ?? cycle.title ?? ""
                if let raw = cycle.cycle, let data = raw.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    cycleType = json["cycle"] as? String ?? "weekly"
                    if let config = json["config"] as? [String: Any] {
                        let day = config["day"]
                        if let s = day as? String { dayConfig = s; dayInt = Int(s) ?? 1 }
                        else if let n = day as? Int { dayConfig = String(n); dayInt = n }
                    }
                }
            } else {
                name = ""; note = ""; cycleType = "weekly"; dayConfig = "1"; dayInt = 1; executeToday = false
            }
        }
    }

    private func computeNextDate() -> Date? {
        let today = Date()
        let cal = Calendar.current
        var startOfDay = cal.startOfDay(for: today)
        if executeToday { return startOfDay }

        switch cycleType {
        case "daily":
            return cal.date(byAdding: .day, value: 1, to: startOfDay)
        case "weekly":
            let target = Int(dayConfig) ?? 1
            let current = cal.component(.weekday, from: today) - 1
            var days = (target - current + 7) % 7
            if days == 0 { days = 7 }
            return cal.date(byAdding: .day, value: days, to: startOfDay)
        case "monthly":
            var comps = cal.dateComponents([.year, .month], from: startOfDay)
            comps.day = dayInt
            var d = cal.date(from: comps)!
            if d <= today { d = cal.date(byAdding: .month, value: 1, to: d)! }
            return cal.startOfDay(for: d)
        case "monthly_last":
            var comps = cal.dateComponents([.year, .month], from: startOfDay)
            comps.day = 1
            let firstOfMonth = cal.date(from: comps)!
            let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth)!
            var d = cal.date(byAdding: .day, value: -(dayInt - 1), to: lastDay)!
            d = cal.startOfDay(for: d)
            if d <= today {
                let nextFirst = cal.date(byAdding: .month, value: 1, to: firstOfMonth)!
                let nextLast = cal.date(byAdding: DateComponents(month: 1, day: -1), to: nextFirst)!
                d = cal.date(byAdding: .day, value: -(dayInt - 1), to: nextLast)!
                d = cal.startOfDay(for: d)
            }
            return d
        default: return nil
        }
    }

    private func save() {
        isLoading = true
        let config: [String: Any] = ["day": cycleType == "weekly" ? dayConfig : String(dayInt)]
        let configStr = (try? String(data: JSONSerialization.data(withJSONObject: config), encoding: .utf8)) ?? "{}"
        let next = computeNextDate()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'00:00:00"
        let nextStr = next.map { f.string(from: $0) } ?? f.string(from: Date())

        Task {
            do {
                if let cycle {
                    try await APIClient.shared.updateCycle(id: cycle.id, name: name, note: note, cycleType: cycleType, config: configStr, next: nextStr)
                } else {
                    try await APIClient.shared.createCycle(name: name, note: note, cycleType: cycleType, config: configStr, next: nextStr)
                }
                await MainActor.run { onSaved(); dismiss() }
            } catch { await MainActor.run { isLoading = false } }
        }
    }
}
