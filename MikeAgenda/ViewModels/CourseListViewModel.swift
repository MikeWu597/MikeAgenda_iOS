import SwiftUI
import Combine

@MainActor
final class CourseListViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var isLoading = false

    var coursesByDay: [(day: Int, label: String, courses: [Course])] {
        let days = [(0, "周日"), (1, "周一"), (2, "周二"), (3, "周三"), (4, "周四"), (5, "周五"), (6, "周六")]
        return days.map { (day, label) in
            (day, label, courses.filter { $0.isActive && $0.day == day }.sorted { $0.startTime < $1.startTime })
        }
    }

    func load() async {
        isLoading = true
        courses = (try? await APIClient.shared.getCourses()) ?? []
        isLoading = false
    }

    func toggleCourse(_ course: Course) async {
        var updated = course
        updated.isActive.toggle()
        try? await APIClient.shared.addOrUpdateCourse(updated)
        await load()
    }

    func delete(_ course: Course) async {
        try? await APIClient.shared.deleteCourse(id: course.id)
        await load()
    }
}
