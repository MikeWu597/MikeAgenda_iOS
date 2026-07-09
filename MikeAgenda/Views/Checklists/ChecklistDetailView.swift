import SwiftUI

struct ChecklistDetailView: View {
    let checklist: [String: Any]
    let onUpdate: () -> Void

    @State private var items: [[String: Any]] = []
    @State private var isLoading = true
    @State private var newItemContent = ""
    @State private var showAdd = false

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if items.isEmpty {
                EmptyStateView(icon: "checklist", message: "暂无项目", action: { showAdd = true }, actionLabel: "添加项目")
            } else {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    HStack {
                        Button {
                            toggleItem(at: i)
                        } label: {
                            Image(systemName: (item["checked"] as? Bool) == true ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle((item["checked"] as? Bool) == true ? .green : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Text(item["name"] as? String ?? "")
                            .strikethrough((item["checked"] as? Bool) == true)
                            .foregroundColor((item["checked"] as? Bool) == true ? .secondary : .primary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                let id = item["id"] as? Int ?? 0
                                try? await APIClient.shared.deleteChecklistItem(id: id)
                                await refresh()
                            }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle(checklist["name"] as? String ?? "清单详情")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .task { await refresh() }
        .alert("添加项目", isPresented: $showAdd) {
            TextField("内容", text: $newItemContent)
            Button("取消", role: .cancel) { newItemContent = "" }
            Button("添加") {
                Task {
                    let clID = (checklist["id"] as? Int) ?? Int(checklist["id"] as? String ?? "") ?? 0
                    try? await APIClient.shared.createChecklistItem(checklistID: clID, name: newItemContent)
                    newItemContent = ""
                    await refresh()
                }
            }
        } message: {
            Text("请输入项目内容")
        }
    }

    private func refresh() async {
        let id = (checklist["id"] as? Int) ?? Int(checklist["id"] as? String ?? "") ?? 0
        if let data = try? await APIClient.shared.getChecklist(id: id),
           let cl = data["checklist"] as? [String: Any] {
            items = cl["items"] as? [[String: Any]] ?? []
        }
        isLoading = false
        onUpdate()
    }

    private func toggleItem(at index: Int) {
        let item = items[index]
        let checked = (item["checked"] as? Bool) == true
        let id = (item["id"] as? Int) ?? Int(item["id"] as? String ?? "") ?? 0
        Task {
            try? await APIClient.shared.updateChecklistItemStatus(id: id, checked: !checked)
            await refresh()
        }
    }
}
