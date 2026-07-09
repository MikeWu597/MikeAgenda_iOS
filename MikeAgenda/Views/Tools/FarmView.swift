import SwiftUI

struct FarmView: View {
    var body: some View {
        List {
            EmptyStateView(icon: "camera.fill", message: "农场监控功能需要原生相机集成")
        }
        .navigationTitle("农场监控")
    }
}
