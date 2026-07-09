import Foundation
import ActivityKit

final class CourseActivityService {
    static let shared = CourseActivityService()

    private var courseTimer: Timer?

    private init() {}

    func start() {
        #if targetEnvironment(simulator)
        return
        #endif
        fetchAndStart()
    }

    func stop() {
        courseTimer?.invalidate()
        courseTimer = nil
        endAllActivities()
    }

    private func fetchAndStart() {
        Task {
            guard let courses = try? await APIClient.shared.getCourses() else { return }

            let now = Date()
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: now) - 1

            let todayCourses: [(code: String, name: String, venue: String, start: String, end: String, endDate: Date)] = courses
                .filter { $0.isActive && $0.day == dayOfWeek }
                .compactMap { course in
                    let endParts = course.endTime.split(separator: ":").compactMap { Int($0) }
                    guard endParts.count >= 2,
                          let endDate = calendar.date(bySettingHour: endParts[0], minute: endParts[1], second: 0, of: now),
                          endDate > now else { return nil }
                    return (course.courseCode, course.courseName, course.venue ?? "", course.startTime, course.endTime, endDate)
                }
                .sorted { $0.start < $1.start }

            await MainActor.run {
                applyCourseActivity(todayCourses)
            }
        }
    }

    private func applyCourseActivity(_ courses: [(code: String, name: String, venue: String, start: String, end: String, endDate: Date)]) {
        courseTimer?.invalidate()
        courseTimer = nil

        guard !courses.isEmpty,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            endAllActivities()
            return
        }

        let current = courses[0]
        let remaining = Array(courses.dropFirst())

        let state = CourseActivityAttributes.ContentState(
            courseCode: current.code,
            courseName: current.name,
            venue: current.venue,
            startTime: current.start,
            endTime: current.end
        )

        let existingActivities = Activity<CourseActivityAttributes>.activities
        if let existing = existingActivities.first {
            Task {
                await existing.update(ActivityContent(state: state, staleDate: current.endDate))
            }
        } else {
            let attributes = CourseActivityAttributes()
            let content = ActivityContent(state: state, staleDate: current.endDate)
            do {
                _ = try Activity.request(attributes: attributes, content: content)
            } catch {
                print("Failed to start course activity: \(error)")
            }
        }

        courseTimer = Timer.scheduledTimer(withTimeInterval: current.endDate.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            guard let self else { return }
            if remaining.isEmpty {
                self.endAllActivities()
            } else {
                self.applyCourseActivity(remaining)
            }
        }
    }

    private func endAllActivities() {
        courseTimer?.invalidate()
        courseTimer = nil
        for activity in Activity<CourseActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
