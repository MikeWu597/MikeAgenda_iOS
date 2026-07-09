import Foundation

struct Renewal: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var description: String?
    var expiryDate: String?
    var reminderDays: Int?
    var categoryID: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case expiryDate = "expiry_date"
        case reminderDays = "reminder_days"
        case categoryID = "category_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int((try? container.decode(String.self, forKey: .id)) ?? "") ?? 0
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        expiryDate = try container.decodeIfPresent(String.self, forKey: .expiryDate)
        reminderDays = try? container.decode(Int.self, forKey: .reminderDays)
        if reminderDays == nil, let str = try? container.decode(String.self, forKey: .reminderDays) { reminderDays = Int(str) }
        categoryID = try? container.decode(Int.self, forKey: .categoryID)
        if categoryID == nil, let str = try? container.decode(String.self, forKey: .categoryID) { categoryID = Int(str) }
    }
}

struct RenewalCategory: Identifiable, Codable, Equatable {
    let id: Int
    var name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int((try? container.decode(String.self, forKey: .id)) ?? "") ?? 0
        name = try container.decode(String.self, forKey: .name)
    }

    init(id: Int, name: String) { self.id = id; self.name = name }

    enum CodingKeys: String, CodingKey { case id, name }
}
