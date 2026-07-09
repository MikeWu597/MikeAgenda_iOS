import SwiftUI

struct ChecklistListView: View {
    @State private var checklists: [[String: Any]] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if checklists.isEmpty {
                EmptyStateView(icon: "checklist", message: "暂无检查清单", action: { showCreate = true }, actionLabel: "创建清单")
            } else {
                ForEach(checklists.indices, id: \.self) { i in
                    let cl = checklists[i]
                    NavigationLink {
                        ChecklistDetailView(checklist: cl, onUpdate: { Task { await load() } })
                    } label: {
                        HStack {
                            Image(systemName: "checklist")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cl["name"] as? String ?? "未命名")
                                    .font(.system(size: 15, weight: .medium))
                                if let items = cl["items"] as? [[String: Any]] {
                                    let done = items.filter { ($0["checked"] as? Bool) == true }.count
                                    Text("\(done)/\(items.count) 已完成")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                let id = (cl["id"] as? Int) ?? Int(cl["id"] as? String ?? "") ?? 0
                                try? await APIClient.shared.deleteChecklist(id: id)
                                await load()
                            }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("检查清单")
        .toolbar {
            Button { showCreate = true } label: { Image(systemName: "plus") }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("创建清单", isPresented: $showCreate) {
            TextField("名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                Task {
                    try? await APIClient.shared.createChecklist(name: newName)
                    newName = ""
                    await load()
                }
            }
        } message: {
            Text("请输入检查清单名称")
        }
    }

    private func load() async {
        isLoading = true
        checklists = (try? await APIClient.shared.getChecklists()) ?? []
        isLoading = false
    }
}
