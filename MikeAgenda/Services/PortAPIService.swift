import Foundation

final class PortAPIService {
    static let shared = PortAPIService()

    private let crypto = PortCrypto()
    private let baseURL = "https://iport.ka.sz.gov.cn"
    private let encryptHeader = "cprams-encrypt-key"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// Query clearance info for 西九龙站口岸 (clearanceType=4)
    func queryMyClearanceInfo() async throws -> [String: Any] {
        let body: [String: Any] = ["data": ["condition": ["clearanceType": 4]]]
        return try await encryptedPost("/szface/staticCon/queryMyClearanceInfoList", body: body)
    }

    /// Query real-time port flow for 西九龙 (departure/arrival transit time & smoothness)
    func queryClearanceFlowToXJL() async throws -> PortFlowData {
        let result = try await encryptedPost("/szface/staticCon/queryMyClearanceInfoToXJL", body: [:])
        guard let raw = result["data"] as? String,
              let rawData = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let inner = json["data"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return PortFlowData(
            datetime: inner["datetime"] as? String ?? "",
            departureTransitTime: inner["departure_transit_time"] as? Int ?? 0,
            arrivalTransitTime: inner["arrival_transit_time"] as? Int ?? 0,
            departureTransitSmooth: inner["departure_transit_smooth"] as? String ?? "",
            arrivalTransitSmooth: inner["arrival_transit_smooth"] as? String ?? ""
        )
    }

    /// POST with automatic response decryption
    func encryptedPost(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)

        guard let httpResp = response as? HTTPURLResponse,
              httpResp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Decrypt response if encrypted
        guard let respEncryptedKey = httpResp.value(forHTTPHeaderField: encryptHeader) else {
            return try parseJSON(data)
        }

        guard let bodyString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        let aesKey = try crypto.decryptAESKeyWithClientPrivateKey(respEncryptedKey)
        let decryptedText = try crypto.aesDecrypt(bodyString, key: aesKey)

        guard let decryptedData = decryptedText.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return try parseJSON(decryptedData)
    }

    private func parseJSON(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }
}
