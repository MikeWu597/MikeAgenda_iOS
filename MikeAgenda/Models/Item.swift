import Foundation

struct Item: Identifiable, Codable, Equatable {
    let id: Int
    var title: String
    var description: String?
    var deadline: String?
    var plannedTime: String?
    var category: [String]?
    var categoryIDs: [String] { category ?? [] }
    var done: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, deadline, category, done
        case plannedTime = "planned_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Item.decodeInt(from: container, forKey: .id) ?? 0
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        plannedTime = try container.decodeIfPresent(String.self, forKey: .plannedTime)
        category = Item.decodeCategory(from: container)
        done = Item.decodeBool(from: container, forKey: .done)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    private static func decodeInt(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Int? {
        if let intVal = try? container.decode(Int.self, forKey: key) { return intVal }
        if let strVal = try? container.decode(String.self, forKey: key), let intVal = Int(strVal) { return intVal }
        return nil
    }

    private static func decodeBool(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Bool? {
        if let boolVal = try? container.decode(Bool.self, forKey: key) { return boolVal }
        if let intVal = try? container.decode(Int.self, forKey: key) { return intVal != 0 }
        if let strVal = try? container.decode(String.self, forKey: key) {
            if let intVal = Int(strVal) { return intVal != 0 }
            return strVal.lowercased() == "true"
        }
        return nil
    }

    private static func decodeCategory(from container: KeyedDecodingContainer<CodingKeys>) -> [String]? {
        if let ints = try? container.decodeIfPresent([Int].self, forKey: .category) {
            return ints.map(String.init)
        }
        if let strings = try? container.decodeIfPresent([String].self, forKey: .category) {
            return strings
        }
        if let jsonString = try? container.decodeIfPresent(String.self, forKey: .category),
           let data = jsonString.data(using: .utf8) {
            if let ints = try? JSONDecoder().decode([Int].self, from: data) {
                return ints.map(String.init)
            }
            if let strings = try? JSONDecoder().decode([String].self, from: data) {
                return strings
            }
        }
        return nil
    }
}
