import WidgetKit
import SwiftUI
import AppIntents
import Security

struct RefreshCoursesIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新课表"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "CourseScheduleWidget")
        return .result()
    }
}

struct CourseScheduleEntry: TimelineEntry {
    let date: Date
    let courses: [WidgetCourse]
}

struct WidgetCourse: Identifiable {
    let id: String
    let code: String
    let name: String
    let venue: String
    let startTime: String
    let endTime: String
    let color: String
    let isEnded: Bool
}

struct CourseScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseScheduleEntry {
        CourseScheduleEntry(date: Date(), courses: [
            WidgetCourse(id: "1", code: "CS101", name: "数据结构", venue: "A301", startTime: "09:00", endTime: "10:30", color: "#409eff", isEnded: true),
            WidgetCourse(id: "2", code: "MATH201", name: "线性代数", venue: "B102", startTime: "14:00", endTime: "15:30", color: "#e6a23c", isEnded: false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseScheduleEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseScheduleEntry>) -> Void) {
        Task {
            let courses = await fetchTodayCourses()
            let entry = CourseScheduleEntry(date: Date(), courses: courses)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchTodayCourses() async -> [WidgetCourse] {
        guard let baseURL = getBaseURL(),
              let session = getSession() else { return [] }

        guard let url = URL(string: "\(baseURL)/api/getCourses") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(session, forHTTPHeaderField: "session")
        request.setValue("session=\(session)", forHTTPHeaderField: "Cookie")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["courses"] as? [[String: Any]] else { return [] }

            let cal = Calendar.current
            let dayOfWeek = cal.component(.weekday, from: Date()) - 1
            let now = Date()

            return list.compactMap { item in
                let isActive: Bool
                if let b = item["is_active"] as? Bool { isActive = b }
                else if let i = item["is_active"] as? Int { isActive = i != 0 }
                else { isActive = true }
                guard isActive else { return nil }

                let day: Int
                if let d = item["day"] as? Int { day = d }
                else if let s = item["day"] as? String { day = Int(s) ?? 0 }
                else { day = 0 }
                guard day == dayOfWeek else { return nil }

                let endTime = item["end_time"] as? String ?? "00:00"
                let endParts = endTime.split(separator: ":").compactMap { Int($0) }
                let ended: Bool
                if endParts.count >= 2,
                   let endDate = cal.date(bySettingHour: endParts[0], minute: endParts[1], second: 0, of: now) {
                    ended = endDate <= now
                } else {
                    ended = false
                }

                let id = (item["id"] as? Int).map(String.init) ?? (item["id"] as? String) ?? UUID().uuidString
                return WidgetCourse(
                    id: id,
                    code: item["course_code"] as? String ?? "",
                    name: item["course_name"] as? String ?? "",
                    venue: item["venue"] as? String ?? "",
                    startTime: item["start_time"] as? String ?? "",
                    endTime: endTime,
                    color: item["course_color"] as? String ?? "#409eff",
                    isEnded: ended
                )
            }.sorted { a, b in
                if a.isEnded != b.isEnded { return !a.isEnded }
                return a.startTime < b.startTime
            }
        } catch {
            return []
        }
    }

    private func getBaseURL() -> String? {
        readKeychain(key: "mikeagenda.baseURL") ?? "https://agenda.hyp.ink"
    }

    private func getSession() -> String? {
        readKeychain(key: "mikeagenda.session")
    }

    private func readKeychain(key: String) -> String? {
        let service = "cn.matrixecho.MikeAgenda"
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: "7T69YP7U49.cn.matrixecho.MikeAgenda",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct CourseScheduleWidgetEntryView: View {
    let entry: CourseScheduleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.courses.isEmpty {
                Text("今天没有课")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(entry.courses.prefix(3).enumerated()), id: \.element.id) { _, course in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(course.isEnded ? Color(hex: course.color).opacity(0.3) : Color(hex: course.color))
                            .frame(width: 5, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(course.code)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(course.isEnded ? Color(hex: course.color).opacity(0.4) : Color(hex: course.color))
                                .lineLimit(1)
                            Text("\(course.startTime)-\(course.endTime)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(course.isEnded ? .secondary.opacity(0.4) : .secondary)
                        }
                    }
                    .opacity(course.isEnded ? 0.5 : 1)
                }
                Spacer(minLength: 0)
                Button(intent: RefreshCoursesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(7)
    }
}

struct CourseScheduleWidget: Widget {
    let kind = "CourseScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseScheduleProvider()) { entry in
            CourseScheduleWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "mikeagenda://refresh"))
        }
        .configurationDisplayName("今日课表")
        .description("显示今天的课程安排")
        .supportedFamilies([.systemSmall])
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
