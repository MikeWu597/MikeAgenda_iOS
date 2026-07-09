import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var color: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int((try? container.decode(String.self, forKey: .id)) ?? "") ?? 0
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(String.self, forKey: .color)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct ProjectRecord: Identifiable, Codable, Equatable {
    let id: Int
    var projectID: Int
    var timestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int((try? container.decode(String.self, forKey: .id)) ?? "") ?? 0
        projectID = (try? container.decode(Int.self, forKey: .projectID)) ?? Int((try? container.decode(String.self, forKey: .projectID)) ?? "") ?? 0
        timestamp = try container.decode(String.self, forKey: .timestamp)
    }
}
