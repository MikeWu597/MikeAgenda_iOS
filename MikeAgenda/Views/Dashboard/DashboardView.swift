import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showPlusMenu = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    DateHeader(date: $viewModel.selectedDate, onDateChanged: { viewModel.loadAll() })
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)

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

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Menu {
                        Button { /* navigate to items */ } label: { Label("事项", systemImage: "list.bullet") }
                        Button { /* navigate to courses */ } label: { Label("课程表", systemImage: "calendar") }
                        Button { /* navigate to cycles */ } label: { Label("周期", systemImage: "arrow.triangle.2.circlepath") }
                        Button { /* navigate to renewals */ } label: { Label("续订", systemImage: "bell") }
                        Divider()
                        Button { /* navigate to settings */ } label: { Label("设置", systemImage: "gear") }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                            .frame(width: 56, height: 56)
                            .background(.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
