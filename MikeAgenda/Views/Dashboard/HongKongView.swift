import SwiftUI

struct HongKongView: View {
    @ObservedObject private var locationService = LocationService.shared

    private var showSZ: Bool { locationService.manualCity == "sz" }

    var body: some View {
        List {
            if showSZ {
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
                    NavigationLink {
                        MTRDoorListView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "door.left.hand.open")
                                .foregroundStyle(.teal)
                                .frame(width: 24)
                            Text("MTR车门管理")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            } else {
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
                    NavigationLink {
                        MTRDoorListView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "door.left.hand.open")
                                .foregroundStyle(.teal)
                                .frame(width: 24)
                            Text("MTR车门管理")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Section("点餐") {
                Button { openURL("https://csd.order.place/store/112871/mode/prekiosk?_aigens_source=scan&onpremise=true") } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("学校点餐")
                            .foregroundStyle(.primary)
                    }
                }
                Button { openURL("https://h5.xiaonoodles.com/materialQrcodeId=1839797535331319808") } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("遇见小面点餐")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(showSZ ? "深圳" : "香港")
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

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack { HongKongView() }
}
