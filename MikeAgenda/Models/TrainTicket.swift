import Foundation

struct TrainTicket: Identifiable, Codable {
    var id: String { "\(trainNo)_\(fromTime)_\(toTime)" }

    let trainNo: String
    let fromStation: String
    let toStation: String
    let fromTime: String
    let toTime: String
    let runTime: String
    let canBook: Bool

    let swzNum: String    // 商务座
    let ydzNum: String    // 一等座
    let edzNum: String    // 二等座
    let gjrwNum: String   // 高级软卧
    let rwNum: String     // 软卧
    let ywNum: String     // 硬卧
    let rzNum: String     // 软座
    let yzNum: String     // 硬座
    let wzNum: String     // 无座

    let swzPrice: String
    let ydzPrice: String
    let edzPrice: String
    let gjrwPrice: String
    let rwPrice: String
    let ywPrice: String
    let rzPrice: String
    let yzPrice: String
}
