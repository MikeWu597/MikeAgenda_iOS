import SwiftUI

struct ChecklistDetailView: View {
    let checklist: [String: Any]
    let onUpdate: () -> Void

    @State private var items: [[String: Any]] = []
    @State private var editItems: [String] = []
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showAdd = false
    @State private var newItemContent = ""
    @State private var showCompletedAlert = false

    var allChecked: Bool {
        !items.isEmpty && items.allSatisfy { ($0["checked"] as? Bool) == true }
    }

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if items.isEmpty && !isEditing {
                EmptyStateView(icon: "checklist", message: "暂无项目", action: { isEditing = true }, actionLabel: "编辑清单")
            } else if isEditing {
                ForEach(editItems.indices, id: \.self) { i in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        TextField("项目内容", text: $editItems[i])
                    }
                }
                .onDelete { idx in editItems.remove(atOffsets: idx) }
                .onMove { from, to in editItems.move(fromOffsets: from, toOffset: to) }

                Button { showAdd = true } label: {
                    Label("添加项目", systemImage: "plus")
                }
            } else {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    HStack {
                        Button { toggleItem(at: i) } label: {
                            Image(systemName: (item["checked"] as? Bool) == true ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle((item["checked"] as? Bool) == true ? .green : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        Text(item["name"] as? String ?? "")
                            .strikethrough((item["checked"] as? Bool) == true)
                            .foregroundColor((item["checked"] as? Bool) == true ? .secondary : .primary)
                    }
                }
            }
        }
        .navigationTitle(checklist["name"] as? String ?? "清单详情")
        .toolbar {
            if isEditing {
                Button("保存") { saveEdits() }
            } else {
                Button("编辑") { startEditing() }
            }
        }
        .task { await refresh() }
        .alert("添加项目", isPresented: $showAdd) {
            TextField("内容", text: $newItemContent)
            Button("取消", role: .cancel) { newItemContent = "" }
            Button("添加") { editItems.append(newItemContent); newItemContent = "" }
        }
        .alert("已完成", isPresented: $showCompletedAlert) {
            Button("清空勾选") { clearAllChecks() }
            Button("确定", role: .cancel) {}
        } message: {
            Text("所有项目已完成！")
        }
        .onChange(of: allChecked) { _, new in
            if new { showCompletedAlert = true }
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

    private func clearAllChecks() {
        Task {
            for item in items {
                let id = (item["id"] as? Int) ?? Int(item["id"] as? String ?? "") ?? 0
                try? await APIClient.shared.updateChecklistItemStatus(id: id, checked: false)
            }
            await refresh()
        }
    }

    private func startEditing() {
        editItems = items.map { $0["name"] as? String ?? "" }
        isEditing = true
    }

    private func saveEdits() {
        let clID = (checklist["id"] as? Int) ?? Int(checklist["id"] as? String ?? "") ?? 0
        guard clID > 0 else { return }
        Task {
            APIClient.shared.suppressUnauthorized = true
            for item in items {
                let id = (item["id"] as? Int) ?? Int(item["id"] as? String ?? "") ?? 0
                try? await APIClient.shared.deleteChecklistItem(id: id)
            }
            for name in editItems where !name.isEmpty {
                try? await APIClient.shared.createChecklistItem(checklistID: clID, name: name)
            }
            APIClient.shared.suppressUnauthorized = false
            isEditing = false
            await refresh()
        }
    }
}
