import Foundation

struct Course: Identifiable, Codable, Equatable {
    var id: Int?
    var courseCode: String
    var courseName: String
    var courseColor: String?
    var venue: String?
    var day: Int
    var startTime: String
    var endTime: String
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case courseCode = "course_code"
        case courseName = "course_name"
        case courseColor = "course_color"
        case venue, day
        case startTime = "start_time"
        case endTime = "end_time"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int((try? container.decode(String.self, forKey: .id)) ?? "")
        courseCode = try container.decode(String.self, forKey: .courseCode)
        courseName = try container.decode(String.self, forKey: .courseName)
        courseColor = try container.decodeIfPresent(String.self, forKey: .courseColor)
        venue = try container.decodeIfPresent(String.self, forKey: .venue)
        day = (try? container.decode(Int.self, forKey: .day)) ?? Int((try? container.decode(String.self, forKey: .day)) ?? "") ?? 0
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? ((try? container.decode(Int.self, forKey: .isActive)) != 0)
    }

    init(id: Int?, courseCode: String, courseName: String, courseColor: String?, venue: String?, day: Int, startTime: String, endTime: String, isActive: Bool) {
        self.id = id
        self.courseCode = courseCode
        self.courseName = courseName
        self.courseColor = courseColor
        self.venue = venue
        self.day = day
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
    }
}
