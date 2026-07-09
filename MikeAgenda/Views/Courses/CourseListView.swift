import SwiftUI

struct CourseListView: View {
    @StateObject private var viewModel = CourseListViewModel()
    @State private var showForm = false
    @State private var editCourse: Course?

    private let hourHeight: CGFloat = 60
    private let timeColWidth: CGFloat = 52
    private let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let dayIndices = [1, 2, 3, 4, 5, 6, 0]

    private var effectiveStartHour: Int {
        guard !viewModel.courses.isEmpty else { return 8 }
        let minHour = viewModel.courses.compactMap { course -> Int? in
            let parts = course.startTime.split(separator: ":").compactMap { Int($0) }
            return parts.first
        }.min() ?? 8
        return max(0, minHour - 1)
    }

    private var effectiveEndHour: Int {
        guard !viewModel.courses.isEmpty else { return 22 }
        let maxHour = viewModel.courses.compactMap { course -> Int? in
            let parts = course.endTime.split(separator: ":").compactMap { Int($0) }
            return parts.first
        }.max() ?? 22
        return min(24, maxHour + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.courses.isEmpty {
                Spacer()
                EmptyStateView(icon: "calendar", message: "暂无课程", action: { showForm = true }, actionLabel: "添加课程")
                Spacer()
            } else {
                scheduleGrid
            }
        }
        .navigationTitle("课程表")
        .toolbar {
            Button { showForm = true } label: { Image(systemName: "plus") }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showForm) {
            NavigationStack { CourseFormView(onSaved: { Task { await viewModel.load() } }) }
        }
        .sheet(item: $editCourse) { course in
            NavigationStack { CourseFormView(course: course, onSaved: { Task { await viewModel.load() } }) }
        }
    }

    private var scheduleGrid: some View {
        let allCourses = viewModel.courses
        let totalHours = effectiveEndHour - effectiveStartHour
        let totalHeight = CGFloat(totalHours) * hourHeight
        let availableWidth = UIScreen.main.bounds.width - timeColWidth - 24
        let dayColWidth = availableWidth / 7

        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(.clear).frame(width: timeColWidth)
                    ForEach(Array(zip(days, dayIndices)), id: \.1) { label, _ in
                        Text(label)
                            .font(.caption.bold())
                            .frame(width: dayColWidth, height: 28)
                            .background(.regularMaterial)
                            .overlay(Divider(), alignment: .trailing)
                    }
                }
                .overlay(Divider(), alignment: .bottom)

                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(effectiveStartHour..<effectiveEndHour, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: timeColWidth, height: hourHeight)
                                .overlay(Divider(), alignment: .bottom)
                        }
                    }
                    .overlay(Divider(), alignment: .trailing)

                    ForEach(Array(zip(days, dayIndices)), id: \.1) { _, dayIdx in
                        let dayCourses = allCourses.filter { $0.day == dayIdx }
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                ForEach(0..<totalHours, id: \.self) { _ in
                                    Color.clear
                                        .frame(height: hourHeight)
                                        .overlay(Divider(), alignment: .bottom)
                                }
                            }

                            ForEach(dayCourses) { course in
                                let top = offset(for: course.startTime)
                                let h = offset(for: course.endTime) - top
                                if h > 0 {
                                    courseCard(course)
                                        .frame(height: max(h, 20))
                                        .offset(y: top)
                                        .padding(.horizontal, 3)
                                        .frame(width: dayColWidth, alignment: .leading)
                                }
                            }
                        }
                        .frame(width: dayColWidth, height: totalHeight)
                        .overlay(Divider(), alignment: .trailing)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if let (yOffset, colX) = currentTimeMarker {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: dayColWidth - 6, height: 2)
                        .offset(x: timeColWidth + colX * dayColWidth + 3, y: 29 + yOffset)
                }
            }
        }
        .padding(12)
    }

    private func offset(for time: String) -> CGFloat {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        let minutes = (parts[0] - effectiveStartHour) * 60 + parts[1]
        return CGFloat(minutes) / 60 * hourHeight
    }

    private var currentTimeMarker: (y: CGFloat, col: CGFloat)? {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let weekday = cal.component(.weekday, from: now) - 1
        guard hour >= effectiveStartHour && hour < effectiveEndHour else { return nil }
        guard let col = dayIndices.firstIndex(of: weekday) else { return nil }
        let minutes = (hour - effectiveStartHour) * 60 + minute
        return (CGFloat(minutes) / 60 * hourHeight, CGFloat(col))
    }

    private func courseCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(course.courseCode)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(course.isActive ? .white : .secondary)
                .lineLimit(1)
            Text(course.courseName)
                .font(.system(size: 9))
                .foregroundColor(course.isActive ? .white.opacity(0.9) : .secondary)
                .lineLimit(2)
            if let venue = course.venue, !venue.isEmpty {
                Text(venue)
                    .font(.system(size: 8))
                    .foregroundColor(course.isActive ? .white.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(course.isActive ? Color(hex: course.courseColor ?? "#409eff") : .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(course.isActive ? .clear : Color(hex: course.courseColor ?? "#409eff").opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture { editCourse = course }
    }
}
