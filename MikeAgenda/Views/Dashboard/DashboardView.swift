import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DateHeader(date: $viewModel.selectedDate, onDateChanged: { viewModel.loadAll() })
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                if viewModel.isLoading {
                    LoadingOverlay()
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                        courseSection
                        todoSection
                        cycleSection
                        renewalSection
                        projectSection
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadAll()
            viewModel.startAutoRefresh()
            CourseActivityService.shared.start()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .refreshable {
            viewModel.loadAll()
        }
    }

    @ViewBuilder
    private var courseSection: some View {
        if viewModel.teachingStatus && !viewModel.filteredCourses.isEmpty {
            SectionCard(title: "课表", icon: "calendar", count: viewModel.filteredCourses.count) {
                ForEach(viewModel.filteredCourses) { course in
                    courseRow(course)
                }
            }
        }
    }

    @ViewBuilder
    private var todoSection: some View {
        SectionCard(title: "待办事项", icon: "checkmark.circle", count: viewModel.sortedItems.count) {
            if viewModel.sortedItems.isEmpty {
                EmptyStateView(icon: "tray", message: "今天没有待办事项")
            } else {
                ForEach(viewModel.sortedItems) { item in
                    itemRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private var cycleSection: some View {
        if !viewModel.formattedCycles.isEmpty {
            SectionCard(title: "周期任务", icon: "arrow.triangle.2.circlepath", count: viewModel.formattedCycles.count) {
                ForEach(viewModel.formattedCycles) { cycle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cycle.name ?? cycle.title ?? "")
                            .font(.system(size: 16, weight: .medium))
                        if let formatted = cycle.cycle, !formatted.isEmpty {
                            Text(formatted)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var renewalSection: some View {
        if !viewModel.filteredRenewals.isEmpty {
            SectionCard(title: "续订提醒", icon: "bell", count: viewModel.filteredRenewals.count) {
                ForEach(viewModel.filteredRenewals) { renewal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(renewal.name)
                            .font(.system(size: 16, weight: .medium))
                        if let expiry = renewal.expiryDate?.prefix(10) {
                            Text("到期: \(String(expiry))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        if !viewModel.projects.isEmpty {
            SectionCard(title: "项目", icon: "folder", count: viewModel.projects.count) {
                ForEach(viewModel.projects) { project in
                    HStack {
                        ColorIndicator(color: Color(hex: project.color))
                        Text(project.name)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(viewModel.projectParticipation[project.id] == true ? Color.blue.opacity(0.1) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func courseRow(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(course.startTime) - \(course.endTime)")
                    .font(.system(size: 14, weight: .semibold))
                if !course.courseCode.isEmpty {
                    Text(course.courseCode)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: course.courseColor ?? "#409eff"))
                        .clipShape(Capsule())
                }
            }
            HStack {
                Text(course.courseName)
                    .font(.caption)
                if let venue = course.venue, !venue.isEmpty {
                    Text("·")
                    Label(venue, systemImage: "mappin")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func itemRow(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let cats = viewModel.categories.filter { c in item.categoryIDs.contains(String(c.id)) }
                ForEach(cats) { cat in
                    Text(cat.name)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: cat.color))
                        .clipShape(Capsule())
                }
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            if let deadline = item.deadline {
                Label(String(deadline.prefix(10)), systemImage: "alarm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                CountBadge(count: count)
                Spacer()
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 网格同一行内卡片高度不一致时，靠上对齐而不是被拉伸
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

extension Color {
    /// 解析后端保存的颜色字符串。
    /// 后端 course_color 等字段是自由文本：网页端 Element Plus 取色器开启
    /// show-alpha 时会保存为 rgba(r, g, b, a)，因此除十六进制外还需兼容
    /// CSS rgb()/rgba() 写法。
    init(hex: String) {
        let input = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        if let rgba = Color.parseRGBFunction(input) {
            self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
            return
        }

        let digits = input.hasPrefix("#") ? String(input.dropFirst()) : input
        var int: UInt64 = 0
        guard Scanner(string: digits).scanHexInt64(&int) else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }
        let a, r, g, b: UInt64
        switch digits.count {
        case 3: // #rgb
            r = ((int >> 8) & 0xF) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17
            a = 255
        case 4: // #rgba
            r = ((int >> 12) & 0xF) * 17
            g = ((int >> 8) & 0xF) * 17
            b = ((int >> 4) & 0xF) * 17
            a = (int & 0xF) * 17
        case 6: // #rrggbb
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // #rrggbbaa（CSS hex8，alpha 在末尾）
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    /// 解析 CSS rgb()/rgba() 函数，兼容逗号分隔与空格/斜杠分隔、百分比分量。
    private static func parseRGBFunction(_ input: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        let lower = input.lowercased()
        guard lower.hasPrefix("rgb"),
              let open = lower.firstIndex(of: "("),
              let close = lower.lastIndex(of: ")"),
              open < close else { return nil }
        let inner = lower[lower.index(after: open)..<close]
        let tokens = inner
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)
        guard tokens.count >= 3,
              let r = colorComponent(tokens[0]),
              let g = colorComponent(tokens[1]),
              let b = colorComponent(tokens[2]) else { return nil }
        let a = tokens.count >= 4 ? (alphaComponent(tokens[3]) ?? 1) : 1
        return (r, g, b, a)
    }

    private static func colorComponent(_ token: String) -> Double? {
        if token.hasSuffix("%"), let value = Double(token.dropLast()) {
            return min(max(value / 100, 0), 1)
        }
        guard let value = Double(token) else { return nil }
        return min(max(value / 255, 0), 1)
    }

    private static func alphaComponent(_ token: String) -> Double? {
        if token.hasSuffix("%"), let value = Double(token.dropLast()) {
            return min(max(value / 100, 0), 1)
        }
        guard let value = Double(token) else { return nil }
        return min(max(value, 0), 1)
    }
}
