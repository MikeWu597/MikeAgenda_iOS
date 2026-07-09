import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .invalidResponse: return "服务器响应异常"
        case .unauthorized: return "登录已过期，请重新登录"
        case .serverError(let msg): return msg
        case .decodingError: return "数据解析失败"
        case .networkError(let err): return err.localizedDescription
        case .notConfigured: return "请先配置服务器连接"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder = { let d = JSONDecoder(); return d }()

    var onUnauthorized: (() -> Void)?
    var suppressUnauthorized = false

    private var baseURL: URL? { ConnectionProfileStore.load().normalizedBaseURL }
    private var sessionToken: String? { SessionService.shared.session }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> String {
        guard let baseURL else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent("login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["username": username, "password": password])
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let result = try decoder.decode(LoginResponse.self, from: data)
        guard result.success, let session = result.session, !session.isEmpty else {
            throw APIError.serverError(result.message ?? "登录失败")
        }
        return session
    }

    // MARK: - Items

    func getItems() async throws -> [Item] {
        let data = try await get("/api/getItems")
        return (try decoder.decode(ItemsResponse.self, from: data)).items ?? []
    }

    func getDoneItems() async throws -> [Item] {
        let data = try await get("/api/getDoneItems")
        return (try decoder.decode(DoneItemsResponse.self, from: data)).items ?? []
    }

    func createItem(title: String, description: String?, deadline: String?, plannedTime: String?, categories: [String]) async throws {
        var body: [String: Any] = ["title": title, "category": categories]
        if let description { body["description"] = description }
        if let deadline { body["deadline"] = deadline }
        if let plannedTime { body["plannedTime"] = plannedTime }
        try await post("/api/createItem", body: body)
    }

    func updateItem(id: Int, title: String, description: String?, deadline: String?, plannedTime: String?, categories: [String]) async throws {
        var body: [String: Any] = ["id": id, "title": title, "category": categories]
        if let description { body["description"] = description }
        if let deadline { body["deadline"] = deadline }
        if let plannedTime { body["planned_time"] = plannedTime }
        try await post("/api/updateItem", body: body)
    }

    func markItemAsDone(id: Int) async throws { try await post("/api/markItemAsDone", body: ["id": id]) }
    func markItemAsUndone(id: Int) async throws { try await post("/api/markItemAsUndone", body: ["id": id]) }
    func deleteItem(id: Int) async throws { try await post("/api/deleteItem", body: ["id": id]) }

    // MARK: - Categories

    func getCategories() async throws -> [Category] {
        let data = try await post("/api/getCategories", body: EmptyBody())
        return (try decoder.decode(CategoriesResponse.self, from: data)).categories ?? []
    }

    func createCategory(name: String, color: String, note: String = "") async throws {
        try await post("/api/createCategory", body: ["name": name, "color": color, "note": note])
    }

    func deleteCategory(id: Int) async throws { try await post("/api/deleteCategory", body: ["id": id]) }

    // MARK: - Projects

    func getProjects() async throws -> [Project] {
        let data = try await get("/api/getProjects")
        return (try decoder.decode(ProjectsResponse.self, from: data)).projects ?? []
    }

    func createProject(name: String, color: String, description: String = "") async throws {
        try await post("/api/createProject", body: ["name": name, "color": color, "description": description])
    }

    func getProjectRecords(projectID: Int) async throws -> [ProjectRecord] {
        let data = try await get("/api/getProjectRecords/\(projectID)")
        return (try decoder.decode(ProjectRecordsResponse.self, from: data)).records ?? []
    }

    func participateInProject(projectID: Int) async throws {
        try await post("/api/participateInProject", body: ["projectId": projectID])
    }

    func deleteProject(id: Int) async throws {
        try await delete("/api/deleteProject/\(id)")
    }

    // MARK: - Courses

    func getCourses() async throws -> [Course] {
        let data = try await get("/api/getCourses")
        return (try decoder.decode(CoursesResponse.self, from: data)).courses ?? []
    }

    func addOrUpdateCourse(_ course: Course) async throws {
        var body: [String: Any] = [
            "course_code": course.courseCode,
            "course_name": course.courseName,
            "day": course.day,
            "start_time": course.startTime,
            "end_time": course.endTime,
            "is_active": course.isActive,
            "venue": course.venue ?? "",
            "course_color": course.courseColor ?? "",
            "instructor_name": ""
        ]
        if let id = course.id { body["id"] = id }
        try await post("/api/addOrUpdateCourse", body: body)
    }

    func deleteCourse(id: Int) async throws {
        try await post("/api/deleteCourse", body: ["id": id])
    }

    // MARK: - Cycles

    func getCycles() async throws -> [Cycle] {
        let data = try await get("/api/getCycles")
        return (try decoder.decode(CyclesResponse.self, from: data)).cycles ?? []
    }

    func getTodayCycles(date: String) async throws -> [Cycle] {
        let data = try await post("/api/getTodayCycles", body: ["date": date])
        return (try decoder.decode(CyclesResponse.self, from: data)).cycles ?? []
    }

    func createCycle(name: String, note: String, cycleType: String, config: String, next: String) async throws {
        try await post("/api/createCycle", body: [
            "name": name, "note": note, "cycle": cycleType, "config": config, "next": next
        ])
    }

    func updateCycle(id: Int, name: String, note: String, cycleType: String, config: String, next: String) async throws {
        try await post("/api/updateCycle", body: [
            "id": id, "name": name, "note": note, "cycle": cycleType, "config": config, "next": next
        ])
    }

    func deleteCycle(id: Int) async throws { try await post("/api/deleteCycle", body: ["id": id]) }

    func updateCycleNextTime(id: Int, nexttime: String) async throws {
        try await post("/api/updateCycleNextTime", body: ["id": id, "nexttime": nexttime])
    }

    func delayCycleNextDate(id: Int) async throws {
        try await post("/api/delayCycleNextDate", body: ["id": id])
    }

    // MARK: - Renewals

    func getAllRenewals() async throws -> [Renewal] {
        let data = try await post("/api/getAllRenewals", body: EmptyBody())
        return (try decoder.decode(RenewalsResponse.self, from: data)).data ?? []
    }

    func createRenewal(name: String, description: String, expiryDate: String, reminderDays: Int, categoryID: Int) async throws {
        try await post("/api/createRenewals", body: [
            "name": name, "description": description,
            "expiryDate": expiryDate, "reminderDays": reminderDays, "categoryId": String(categoryID)
        ])
    }

    func updateRenewal(id: Int, name: String, description: String, expiryDate: String, reminderDays: Int, categoryID: Int) async throws {
        try await put("/api/updateRenewals/\(id)", body: [
            "name": name, "description": description,
            "expiryDate": expiryDate, "reminderDays": String(reminderDays), "categoryId": String(categoryID)
        ])
    }

    func deleteRenewal(id: Int) async throws {
        try await delete("/api/deleteRenewals/\(id)")
    }

    func getAllRenewalCategories() async throws -> [RenewalCategory] {
        let data = try await post("/api/getAllRenewalCategories", body: EmptyBody())
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = json["data"] as? [[String: Any]] {
            return list.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                let id = (item["id"] as? Int) ?? Int(item["id"] as? String ?? "") ?? 0
                return RenewalCategory(id: id, name: name)
            }
        }
        return []
    }

    func createRenewalCategory(name: String, color: String = "#409eff", description: String = "") async throws {
        try await post("/api/createRenewalCategories", body: [
            "name": name, "color": color, "description": description
        ])
    }

    func deleteRenewalCategory(id: Int) async throws {
        try await post("/api/deleteRenewalCategories/\(id)", body: EmptyBody())
    }

    // MARK: - Settings

    func getTeachingStatus() async throws -> Bool {
        let data = try await get("/api/getTeachingStatus")
        return (try decoder.decode(TeachingStatusResponse.self, from: data)).teaching == "1"
    }

    func setTeachingStatus(_ enabled: Bool) async throws {
        try await post("/api/setTeachingStatus", body: ["teaching": enabled ? "1" : "0"])
    }

    func getImageStorageLimit() async throws -> Int {
        let data = try await get("/api/getImageStorageLimit")
        return (try decoder.decode(ImageLimitResponse.self, from: data)).limit ?? 0
    }

    func setImageStorageLimit(bytes: Int) async throws {
        try await post("/api/setImageStorageLimit", body: ["limit": bytes])
    }

    func getSystemStatus() async throws -> String {
        let data = try await get("/api/getSystemStatus")
        return (try decoder.decode(SystemStatusResponse.self, from: data)).message ?? "未知"
    }

    // MARK: - Checklists

    func getChecklists() async throws -> [[String: Any]] {
        let data = try await get("/api/getChecklists")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = json["checklists"] as? [[String: Any]] { return list }
        return []
    }

    func getChecklist(id: Int) async throws -> [String: Any]? {
        let data = try await get("/api/getChecklist/\(id)")
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func createChecklist(name: String) async throws {
        try await post("/api/createChecklist", body: ["name": name, "orderIndex": 0])
    }

    func deleteChecklist(id: Int) async throws { try await delete("/api/deleteChecklist/\(id)") }

    func createChecklistItem(checklistID: Int, name: String) async throws {
        try await post("/api/createChecklistItem", body: ["checklistId": checklistID, "name": name, "orderIndex": 0])
    }

    func updateChecklistItemStatus(id: Int, checked: Bool) async throws {
        try await post("/api/updateChecklistItemStatus", body: ["id": id, "checked": checked])
    }

    func deleteChecklistItem(id: Int) async throws { try await delete("/api/deleteChecklistItem/\(id)") }

    // MARK: - Helpers

    private func applySession(to request: inout URLRequest) {
        guard let token = sessionToken else { return }
        request.setValue(token, forHTTPHeaderField: "session")
        request.setValue("session=\(token)", forHTTPHeaderField: "Cookie")
    }

    private func delete(_ path: String) async throws {
        guard let baseURL else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySession(to: &request)
        if let token = sessionToken {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["session": token])
        }
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func put(_ path: String, body: [String: Any]) async throws {
        guard let baseURL else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySession(to: &request)
        var merged = body
        if let token = sessionToken { merged["session"] = token }
        request.httpBody = try JSONSerialization.data(withJSONObject: merged)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func get(_ path: String) async throws -> Data {
        guard let baseURL else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySession(to: &request)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func post(_ path: String, body: some Encodable) async throws -> Data {
        guard let baseURL else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySession(to: &request)
        var bodyData = try encoder.encode(body)
        if let token = sessionToken,
           var dict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
            dict["session"] = token
            bodyData = try JSONSerialization.data(withJSONObject: dict)
        }
        request.httpBody = bodyData
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        guard let baseURL else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySession(to: &request)
        var merged = body
        if let token = sessionToken { merged["session"] = token }
        request.httpBody = try JSONSerialization.data(withJSONObject: merged)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if httpResponse.statusCode == 401 {
            if !suppressUnauthorized { onUnauthorized?() }
            throw APIError.unauthorized
        }
        if httpResponse.statusCode >= 400 {
            let msg = (try? decoder.decode(SimpleResponse.self, from: data))?.message ?? "请求失败"
            throw APIError.serverError(msg)
        }
    }
}

private struct EmptyBody: Encodable {}
