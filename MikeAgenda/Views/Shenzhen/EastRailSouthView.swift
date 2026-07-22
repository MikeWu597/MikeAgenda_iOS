import SwiftUI

// MARK: - Route Config

private let eastRailBlue = Color(red: 0.33, green: 0.72, blue: 0.91)
private let tuenMaBrown = Color(red: 0.57, green: 0.19, blue: 0.07)

struct MTRRouteConfig {
    let lineName: String
    let lineColor: Color
    let direction: String
    let stations: [StationInfo]

    struct StationInfo: Identifiable {
        let id = UUID()
        let name: String
        let nameEn: String
        let doors: [String]
    }

    static let eastRailSouth = MTRRouteConfig(
        lineName: "东铁线",
        lineColor: eastRailBlue,
        direction: "落马洲 → 红磡（南下）",
        stations: [
            StationInfo(name: "落马洲", nameEn: "Lok Ma Chau", doors: []),
            StationInfo(name: "上水", nameEn: "Sheung Shui", doors: ["7-1", "5-5"]),
            StationInfo(name: "红磡", nameEn: "Hung Hom", doors: ["7-2"]),
        ]
    )

    static let tuenMaToSchool = MTRRouteConfig(
        lineName: "屯马线",
        lineColor: tuenMaBrown,
        direction: "柯士甸 → 红磡（上学）",
        stations: [
            StationInfo(name: "柯士甸", nameEn: "Austin", doors: []),
            StationInfo(name: "红磡", nameEn: "Hung Hom", doors: ["3-4"]),
        ]
    )

    static let tuenMaFromSchool = MTRRouteConfig(
        lineName: "屯马线",
        lineColor: tuenMaBrown,
        direction: "红磡 → 柯士甸（放学）",
        stations: [
            StationInfo(name: "红磡", nameEn: "Hung Hom", doors: []),
            StationInfo(name: "柯士甸", nameEn: "Austin", doors: ["5-2"]),
        ]
    )
}

// MARK: - Detail View

struct MTRRouteDetailView: View {
    let config: MTRRouteConfig

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(config.lineName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(config.lineColor))
                    Text(config.direction)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)

                Divider()
                    .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    ForEach(Array(config.stations.enumerated()), id: \.element.id) { index, station in
                        StationRow(
                            station: station,
                            lineColor: config.lineColor,
                            isLast: index == config.stations.count - 1
                        )
                    }
                }
                .padding(.top, 12)
            }
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(config.lineName + config.direction.prefix(4))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Station Row

private struct StationRow: View {
    let station: MTRRouteConfig.StationInfo
    let lineColor: Color
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Circle()
                    .fill(lineColor)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 4)
                    )
                    .shadow(color: lineColor.opacity(0.4), radius: 4)

                if !isLast {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 4)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 36)
            .padding(.leading, 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(station.name)
                    .font(.system(size: 22, weight: .bold))
                Text(station.nameEn)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if station.doors.isEmpty {
                    Text("起点站，任意车门上车")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.square.fill")
                            .font(.title3)
                            .foregroundColor(lineColor)
                        Text("下车门")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(lineColor)
                    }
                    .padding(.top, 4)

                    HStack(spacing: 10) {
                        ForEach(Array(station.doors.enumerated()), id: \.offset) { idx, door in
                            if idx > 0 {
                                Text("或")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            Text(door)
                                .font(.system(size: 26, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(lineColor)
                                )
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.leading, 14)
            .padding(.bottom, 36)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 24)
    }
}

// MARK: - Convenience Views

struct EastRailSouthView: View {
    var body: some View {
        MTRRouteDetailView(config: .eastRailSouth)
    }
}

struct TuenMaLineView: View {
    var body: some View {
        MTRRouteDetailView(config: .tuenMaToSchool)
    }
}

struct TuenMaFromSchoolView: View {
    var body: some View {
        MTRRouteDetailView(config: .tuenMaFromSchool)
    }
}
