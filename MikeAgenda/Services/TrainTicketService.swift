import Foundation
import Combine

@MainActor
final class TrainTicketService: ObservableObject {
    static let shared = TrainTicketService()

    @Published var tickets: [TrainTicket] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    private let fromStation = "IOQ"
    private let toStation = "XJA"

    private var cookiesReady = false
    private var trainCodeMap: [String: String] = [:]
    private var trainCodeMapDate: String?

    func fetchTickets(for date: Date = Date()) async {
        isLoading = true
        errorMessage = nil
        tickets = []

        defer { isLoading = false }

        do {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let dateKey = df.string(from: date)

            if !cookiesReady {
                try await obtainCookies()
                cookiesReady = true
            }

            if trainCodeMapDate != dateKey {
                try? await loadTrainCodeMap(dateKey: dateKey)
            }

            let tickets = try await queryTickets(date: date)
            self.tickets = tickets
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func obtainCookies() async throws {
        let url = URL(string: "https://kyfw.12306.cn/otn/leftTicket/init")!
        var request = URLRequest(url: url)
        request.setValue("https://www.12306.cn", forHTTPHeaderField: "Referer")
        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TrainServiceError.cookieFailed
        }
    }

    private func loadTrainCodeMap(dateKey: String) async throws {
        let url = URL(string: "https://kyfw.12306.cn/otn/resources/js/query/train_list.js")!
        var request = URLRequest(url: url)
        request.setValue("https://kyfw.12306.cn/otn/leftTicket/init", forHTTPHeaderField: "Referer")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, _) = try await session.data(for: request)
        guard var text = String(data: data, encoding: .utf8) else { return }

        // Strip "var train_list =" prefix
        if let range = text.range(of: "=") {
            text = String(text[text.index(after: range.lowerBound)...]).trimmingCharacters(in: .whitespaces)
        }

        guard let json = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: [String: [[String: String]]]] else { return }
        guard let dayData = json[dateKey] else { return }

        var map: [String: String] = [:]
        for (_, trainList) in dayData {
            for train in trainList {
                guard let code = train["station_train_code"],
                      let no = train["train_no"] else { continue }
                // Strip "(深圳北-香港西九龙)" suffix
                let display = code.components(separatedBy: "(").first ?? code
                map[no] = display
            }
        }

        trainCodeMap = map
        trainCodeMapDate = dateKey
    }

    private func queryTickets(date: Date) async throws -> [TrainTicket] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)

        var components = URLComponents(string: "https://kyfw.12306.cn/otn/leftTicket/queryX")!
        components.queryItems = [
            URLQueryItem(name: "leftTicketDTO.train_date", value: dateStr),
            URLQueryItem(name: "leftTicketDTO.from_station", value: fromStation),
            URLQueryItem(name: "leftTicketDTO.to_station", value: toStation),
            URLQueryItem(name: "purpose_codes", value: "ADULT"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("https://kyfw.12306.cn/otn/leftTicket/init", forHTTPHeaderField: "Referer")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw TrainServiceError.queryFailed
        }

        return try parseResponse(data: data)
    }

    private func parseResponse(data: Data) throws -> [TrainTicket] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rootData = json["data"] as? [String: Any],
              let results = rootData["result"] as? [String],
              let seatMap = rootData["map"] as? [String: String] else {
            throw TrainServiceError.parseFailed
        }

        let seatTypes = parseSeatTypes(from: seatMap)

        let tickets = results.compactMap { resultStr in
            parseTicket(from: resultStr, seatTypes: seatTypes)
        }

        return tickets.filter { ticket in
            (ticket.fromStation.contains("深圳北") || ticket.fromStation == "IOQ") &&
            (ticket.toStation.contains("香港西九龙") || ticket.toStation.contains("西九龙") || ticket.toStation == "XJA")
        }
    }

    private struct SeatTypeInfo {
        let swz: (numIdx: Int, priceIdx: Int)?
        let ydz: (numIdx: Int, priceIdx: Int)?
        let edz: (numIdx: Int, priceIdx: Int)?
        let gjrw: (numIdx: Int, priceIdx: Int)?
        let rw: (numIdx: Int, priceIdx: Int)?
        let yw: (numIdx: Int, priceIdx: Int)?
        let rz: (numIdx: Int, priceIdx: Int)?
        let yz: (numIdx: Int, priceIdx: Int)?
        let wz: (numIdx: Int, priceIdx: Int)?
    }

    private func parseSeatTypes(from map: [String: String]) -> SeatTypeInfo {
        var numMap: [String: Int] = [:]
        var priceMap: [String: Int] = [:]

        for (idxStr, name) in map {
            guard let idx = Int(idxStr) else { continue }
            if name.hasSuffix("_num") || name.contains("_num") {
                let key = name.replacingOccurrences(of: "_num", with: "")
                numMap[key] = idx
            } else if name.hasSuffix("_price") || name.contains("_price") {
                let key = name.replacingOccurrences(of: "_price", with: "")
                priceMap[key] = idx
            }
        }

        func pair(_ key: String) -> (Int, Int)? {
            guard let n = numMap[key], let p = priceMap[key] else { return nil }
            return (n, p)
        }

        return SeatTypeInfo(
            swz: pair("swz") ?? pair("SWZ") ?? pair("tz") ?? pair("TZ"),
            ydz: pair("ydz") ?? pair("YDZ") ?? pair("zy") ?? pair("ZY"),
            edz: pair("edz") ?? pair("EDZ") ?? pair("ze") ?? pair("ZE"),
            gjrw: pair("gjrw") ?? pair("GJRW"),
            rw: pair("rw") ?? pair("RW"),
            yw: pair("yw") ?? pair("YW"),
            rz: pair("rz") ?? pair("RZ"),
            yz: pair("yz") ?? pair("YZ"),
            wz: pair("wz") ?? pair("WZ")
        )
    }

    private func normalizeStation(_ name: String) -> String {
        switch name {
        case "IOQ": return "深圳北"
        case "XJA": return "香港西九龙"
        case "IZQ": return "广州南"
        case "SZQ": return "深圳"
        case "NFZ": return "福田"
        default: return name
        }
    }

    private func parseTicket(from raw: String, seatTypes: SeatTypeInfo) -> TrainTicket? {
        let fields = raw.components(separatedBy: "|")
        guard fields.count > 35 else { return nil }

        let rawTrainNo = fields[2]
        guard !rawTrainNo.isEmpty else { return nil }

        let displayCode = trainCodeMap[rawTrainNo] ?? fields[3]

        func seat(_ pair: (Int, Int)?) -> (num: String, price: String) {
            guard let p = pair, fields.count > max(p.0, p.1) else { return ("", "") }
            let num = fields[p.0] == "" ? "--" : fields[p.0]
            let price = fields[p.1] == "" ? "" : fields[p.1]
            return (num, price)
        }

        let swz = seat(seatTypes.swz)
        let ydz = seat(seatTypes.ydz)
        let edz = seat(seatTypes.edz)
        let gjrw = seat(seatTypes.gjrw)
        let rw = seat(seatTypes.rw)
        let yw = seat(seatTypes.yw)
        let rz = seat(seatTypes.rz)
        let yz = seat(seatTypes.yz)
        let wz = seat(seatTypes.wz)

        return TrainTicket(
            trainNo: displayCode,
            fromStation: normalizeStation(fields[6]),
            toStation: normalizeStation(fields[7]),
            fromTime: fields[8],
            toTime: fields[9],
            runTime: fields[10],
            canBook: fields[11] == "Y",
            swzNum: swz.num,
            ydzNum: ydz.num,
            edzNum: edz.num,
            gjrwNum: gjrw.num,
            rwNum: rw.num,
            ywNum: yw.num,
            rzNum: rz.num,
            yzNum: yz.num,
            wzNum: wz.num,
            swzPrice: swz.price,
            ydzPrice: ydz.price,
            edzPrice: edz.price,
            gjrwPrice: gjrw.price,
            rwPrice: rw.price,
            ywPrice: yw.price,
            rzPrice: rz.price,
            yzPrice: yz.price
        )
    }
}

enum TrainServiceError: LocalizedError {
    case cookieFailed
    case queryFailed
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .cookieFailed: return "连接12306失败"
        case .queryFailed: return "查询车票失败"
        case .parseFailed: return "解析车票数据失败"
        }
    }
}
