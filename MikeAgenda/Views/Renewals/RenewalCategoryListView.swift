import SwiftUI

struct RenewalCategoryListView: View {
    @State private var categories: [RenewalCategory] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newColor = "#409eff"

    var body: some View {
        List {
            if isLoading { HStack { Spacer(); ProgressView(); Spacer() } }
            else if categories.isEmpty { EmptyStateView(icon: "tag", message: "暂无续费分类", action: { showCreate = true }, actionLabel: "创建分类") }
            else {
                ForEach(categories) { cat in
                    Text(cat.name)
                }
            }
        }
        .navigationTitle("续费分类")
        .toolbar { Button { showCreate = true } label: { Image(systemName: "plus") } }
        .task { await load() }
        .refreshable { await load() }
        .alert("创建续费分类", isPresented: $showCreate) {
            TextField("名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                Task {
                    try? await APIClient.shared.createRenewalCategory(name: newName, color: newColor)
                    newName = ""
                    await load()
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        categories = (try? await APIClient.shared.getAllRenewalCategories()) ?? []
        isLoading = false
    }
}
