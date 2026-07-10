import Foundation

struct Cycle: Identifiable, Codable, Equatable {
    let id: Int
    var name: String?
    var title: String?
    var cycle: String?
    var nextTime: String?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, title, cycle
        case nextTime = "next_time"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(Int.self, forKey: .id)) ?? Int((try? container.decode(String.self, forKey: .id)) ?? "") ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        if let str = try? container.decode(String.self, forKey: .cycle) {
            cycle = str
        } else {
            cycle = nil
        }
        nextTime = try container.decodeIfPresent(String.self, forKey: .nextTime)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? ((try? container.decode(Int.self, forKey: .isActive)) != 0)
    }
}
