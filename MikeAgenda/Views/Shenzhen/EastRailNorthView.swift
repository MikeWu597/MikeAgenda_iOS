import SwiftUI

// MARK: - Route Config

private let eastRailBlue = Color(red: 0.33, green: 0.72, blue: 0.91)

private let config = MTRRouteConfig(
    lineName: "东铁线",
    lineColor: eastRailBlue,
    direction: "红磡 → 落马洲（北上）",
    stations: [
        MTRRouteConfig.StationInfo(name: "红磡", nameEn: "Hung Hom", doors: []),
        MTRRouteConfig.StationInfo(name: "上水", nameEn: "Sheung Shui", doors: ["3-5"]),
        MTRRouteConfig.StationInfo(name: "落马洲", nameEn: "Lok Ma Chau", doors: ["5-1"]),
    ]
)

struct EastRailNorthView: View {
    var body: some View {
        MTRRouteDetailView(config: config)
    }
}

#Preview {
    NavigationStack { EastRailNorthView() }
}
