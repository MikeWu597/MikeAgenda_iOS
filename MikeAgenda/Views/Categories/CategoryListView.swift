import SwiftUI

struct CategoryListView: View {
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var showForm = false

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if categories.isEmpty {
                EmptyStateView(icon: "tag", message: "暂无分类", action: { showForm = true }, actionLabel: "创建分类")
            } else {
                ForEach(categories) { cat in
                    HStack {
                        ColorIndicator(color: Color(hex: cat.color))
                        Text(cat.name)
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                try? await APIClient.shared.deleteCategory(id: cat.id)
                                await load()
                            }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("分类")
        .toolbar {
            Button { showForm = true } label: { Image(systemName: "plus") }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showForm) {
            NavigationStack { CategoryFormView(onSaved: { Task { await load() } }) }
        }
    }

    private func load() async {
        isLoading = true
        categories = (try? await APIClient.shared.getCategories()) ?? []
        isLoading = false
    }
}

struct CategoryFormView: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = Color.blue
    @State private var isLoading = false

    init(onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("名称") {
                TextField("请输入分类名称", text: $name)
            }
            Section("颜色") {
                ColorPicker("选择颜色", selection: $color)
            }
            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isLoading { ProgressView() }
                        Text("创建分类")
                        Spacer()
                    }
                }
                .disabled(name.isEmpty || isLoading)
            }
        }
        .navigationTitle("创建分类")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        }
    }

    private func save() {
        isLoading = true
        Task {
            try? await APIClient.shared.createCategory(name: name, color: color.toHex())
            await MainActor.run {
                onSaved()
                dismiss()
            }
        }
    }
}
