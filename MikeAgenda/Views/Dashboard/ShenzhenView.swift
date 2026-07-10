import SwiftUI

struct ShenzhenView: View {
    var body: some View {
        List {
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
        .navigationTitle("深圳")
    }
}
