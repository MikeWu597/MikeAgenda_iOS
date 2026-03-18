import ActivityKit
import Foundation

struct CourseActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var courseCode: String
        var courseName: String
        var venue: String
        var startTime: String
        var endTime: String
    }
}
