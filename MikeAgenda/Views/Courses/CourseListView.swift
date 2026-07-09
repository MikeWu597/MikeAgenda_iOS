import SwiftUI

struct CourseListView: View {
    @StateObject private var viewModel = CourseListViewModel()
    @State private var showForm = false
    @State private var editCourse: Course?

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if viewModel.courses.isEmpty {
                EmptyStateView(icon: "calendar", message: "暂无课程", action: { showForm = true }, actionLabel: "添加课程")
            } else {
                ForEach(viewModel.coursesByDay, id: \.day) { group in
                    if !group.courses.isEmpty {
                        Section(group.label) {
                            ForEach(group.courses) { course in
                                courseRow(course)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.delete(course) }
                                        } label: { Label("删除", systemImage: "trash") }
                                    }
                                    .onTapGesture { editCourse = course }
                            }
                        }
                    }
                }
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

    private func courseRow(_ course: Course) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: course.courseColor ?? "#409eff"))
                .frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(course.courseCode)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: course.courseColor ?? "#409eff"))
                        .clipShape(Capsule())
                    Text(course.courseName)
                        .font(.subheadline)
                }
                HStack(spacing: 8) {
                    Text("\(course.startTime)-\(course.endTime)")
                    if let venue = course.venue, !venue.isEmpty {
                        Label(venue, systemImage: "mappin")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}
