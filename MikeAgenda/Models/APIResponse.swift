import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?

    enum CodingKeys: String, CodingKey {
        case success, message, data
    }
}

struct LoginResponse: Decodable {
    let success: Bool
    let message: String?
    let session: String?
}

struct ItemsResponse: Decodable {
    let success: Bool
    let items: [Item]?
}

struct DoneItemsResponse: Decodable {
    let success: Bool
    let items: [Item]?
}

struct CategoriesResponse: Decodable {
    let success: Bool
    let categories: [Category]?
}

struct ProjectsResponse: Decodable {
    let success: Bool
    let projects: [Project]?
}

struct ProjectRecordsResponse: Decodable {
    let success: Bool
    let records: [ProjectRecord]?
}

struct CoursesResponse: Decodable {
    let success: Bool
    let courses: [Course]?
}

struct CyclesResponse: Decodable {
    let success: Bool
    let cycles: [Cycle]?
}

struct RenewalsResponse: Decodable {
    let success: Bool
    let data: [Renewal]?
}

struct RenewalCategoriesResponse: Decodable {
    let success: Bool
    let categories: [RenewalCategory]?
}

struct TeachingStatusResponse: Decodable {
    let success: Bool
    let teaching: String?
}

struct ImageLimitResponse: Decodable {
    let success: Bool
    let limit: Int?
}

struct SystemStatusResponse: Decodable {
    let success: Bool
    let message: String?
    let status: SystemStatusData?
}

struct SystemStatusData: Decodable {
    let memoryUsage: String?
    let systemTime: String?
    let uptime: Int?
}

struct SimpleResponse: Decodable {
    let success: Bool
    let message: String?
}
