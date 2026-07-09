import Foundation

struct Checklist: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var items: [ChecklistItem]?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, items
        case createdAt = "created_at"
    }
}

struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: Int?
    var content: String
    var checked: Bool?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, content, checked
        case sortOrder = "sort_order"
    }
}
