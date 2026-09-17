import SwiftUI

struct ShenzhenView: View {
    @ObservedObject private var locationService = LocationService.shared

    private var showHK: Bool { locationService.manualCity == "hk" }

    var body: some View {
        List {
            if showHK {
                Section("交通") {
                    NavigationLink {
                        ShenzhenTrainListView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("去深圳")
                                    .foregroundStyle(.primary)
                                Text("香港西九龙 → 深圳北")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Section("交通") {
                    NavigationLink {
                        HongKongTrainListView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("去香港")
                                    .foregroundStyle(.primary)
                                Text("深圳北 → 香港西九龙")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            ServiceToolsSection()
        }
        .navigationTitle(showHK ? "香港" : "深圳")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        locationService.manualCity = nil
                    } label: {
                        HStack {
                            Text("自动（定位）")
                            if locationService.manualCity == nil { Image(systemName: "checkmark") }
                        }
                    }
                    Button {
                        locationService.manualCity = "sz"
                    } label: {
                        HStack {
                            Text("深圳")
                            if locationService.manualCity == "sz" { Image(systemName: "checkmark") }
                        }
                    }
                    Button {
                        locationService.manualCity = "hk"
                    } label: {
                        HStack {
                            Text("香港")
                            if locationService.manualCity == "hk" { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ShenzhenView() }
}
