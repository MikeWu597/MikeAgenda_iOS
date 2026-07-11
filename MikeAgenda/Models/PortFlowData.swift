import Foundation

struct PortFlowData {
    let datetime: String
    let departureTransitTime: Int  // 出境通关耗时 (秒)
    let arrivalTransitTime: Int    // 入境通关耗时 (秒)
    let departureTransitSmooth: String  // 出境畅通度: "畅通" etc
    let arrivalTransitSmooth: String    // 入境畅通度

    var departureMinutes: Int { departureTransitTime / 60 }
    var arrivalMinutes: Int { arrivalTransitTime / 60 }
}
