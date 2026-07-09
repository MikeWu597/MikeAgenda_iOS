import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var items: [Item] = []
    @Published var cycles: [Cycle] = []
    @Published var renewals: [Renewal] = []
    @Published var projects: [Project] = []
    @Published var courses: [Course] = []
    @Published var categories: [Category] = []
    @Published var teachingStatus = false
    @Published var projectParticipation: [Int: Bool] = [:]
    @Published var isLoading = false

    private var refreshTimer: Timer?
    private let settings = SettingsService.shared

    var sortedItems: [Item] {
        items.sorted { a, b in
            let aDeadline = a.deadline ?? "9999"
            let bDeadline = b.deadline ?? "9999"
            if aDeadline != bDeadline { return aDeadline < bDeadline }
            return a.title < b.title
        }
    }

    var formattedCycles: [Cycle] {
        cycles.map { cycle in
            var c = cycle
            c.cycle = formatCycleDescription(cycle.cycle)
            return c
        }
    }

    var filteredCourses: [Course] {
        let dayOfWeek = Calendar.current.component(.weekday, from: selectedDate) - 1
        let isToday = Calendar.current.isDateInToday(selectedDate)
        return courses
            .filter { $0.isActive && $0.day == dayOfWeek }
            .filter { course in
                guard isToday else { return true }
                let parts = course.endTime.split(separator: ":").compactMap { Int($0) }
                guard parts.count >= 2 else { return true }
                let now = Date()
                let endDate = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) ?? now
                return endDate > now
            }
            .sorted { $0.startTime < $1.startTime }
    }

    var filteredRenewals: [Renewal] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let selected = formatter.string(from: selectedDate)

        return renewals.filter { renewal in
            guard let expiry = renewal.expiryDate?.prefix(10).description,
                  let expiryDate = formatter.date(from: expiry),
                  let selectedDate = formatter.date(from: selected) else { return false }
            let reminderDays = renewal.reminderDays ?? 0
            let startDate = Calendar.current.date(byAdding: .day, value: -reminderDays, to: expiryDate) ?? expiryDate
            return selectedDate >= startDate && selectedDate <= expiryDate
        }
    }

    func loadAll() {
        isLoading = true
        Task {
            async let cats = try? APIClient.shared.getCategories()
            async let its = try? APIClient.shared.getItems()
            async let cycs = try? APIClient.shared.getTodayCycles(date: dateString)
            async let rens = try? APIClient.shared.getAllRenewals()
            async let projs = try? APIClient.shared.getProjects()
            async let crs = try? APIClient.shared.getCourses()
            async let teach = try? APIClient.shared.getTeachingStatus()

            categories = (await cats) ?? []
            items = (await its) ?? []
            cycles = (await cycs) ?? []
            renewals = (await rens) ?? []
            projects = (await projs) ?? []
            courses = (await crs) ?? []
            teachingStatus = (await teach) ?? false

            // Load project participation
            await loadProjectParticipation()

            isLoading = false
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        guard let interval = settings.refreshInterval, interval > 0 else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.loadAll()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: selectedDate)
    }

    private func loadProjectParticipation() async {
        var result: [Int: Bool] = [:]
        let dateString = formattedYMD

        for project in projects {
            guard let records = try? await APIClient.shared.getProjectRecords(projectID: project.id) else {
                result[project.id] = false
                continue
            }
            let has = records.contains { record in
                let ts = record.timestamp.prefix(10)
                return String(ts) == dateString
            }
            result[project.id] = has
        }
        projectParticipation = result
    }

    private var formattedYMD: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }

    private func formatCycleDescription(_ raw: String?) -> String {
        guard let raw, let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cycleType = json["cycle"] as? String,
              let config = json["config"] as? [String: Any] else { return "" }

        switch cycleType {
        case "weekly":
            let days = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
            if let day = config["day"] as? Int { return "每周 \(days[day])" }
            if let dayStr = config["day"] as? String, let day = Int(dayStr) { return "每周 \(days[day])" }
            return "每周"
        case "monthly":
            if let day = config["day"] as? Int { return "每月第 \(day) 天" }
            return "每月"
        case "monthly_last":
            if let day = config["day"] as? Int { return "每月倒数第 \(day) 天" }
            return "每月倒数"
        case "daily":
            return "每天"
        default:
            return ""
        }
    }
}
