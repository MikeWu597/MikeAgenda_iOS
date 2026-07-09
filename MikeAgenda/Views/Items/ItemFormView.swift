import SwiftUI

struct ItemFormView: View {
    let item: Item?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var hasDeadline = false
    @State private var deadlineDate = Date()
    @State private var hasPlannedTime = false
    @State private var plannedDate = Date()
    @State private var selectedCategoryIDs: Set<String> = []
    @State private var categories: [Category] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(item: Item? = nil, onSaved: @escaping () -> Void) {
        self.item = item
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                TextField("请输入事项标题", text: $title)
                    .font(.system(size: 16))
            } header: {
                Text("标题")
            }

            Section {
                TextField("请输入事项描述（可选）", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("描述")
            }
            Section("截止日期") {
                if hasDeadline {
                    DatePicker("截止日期", selection: $deadlineDate, displayedComponents: .date)
                        .labelsHidden()
                    Button("清除截止日期") { hasDeadline = false }
                        .foregroundColor(.red)
                } else {
                    Button("设置截止日期") { hasDeadline = true; deadlineDate = Date() }
                }
            }
            Section("计划时间") {
                if hasPlannedTime {
                    DatePicker("计划时间", selection: $plannedDate)
                        .labelsHidden()
                    Button("清除计划时间") { hasPlannedTime = false }
                        .foregroundColor(.red)
                } else {
                    Button("设置计划时间") { hasPlannedTime = true; plannedDate = Date() }
                }
            }
            Section("分类") {
                if categories.isEmpty {
                    Text("暂无分类")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(categories) { cat in
                        HStack {
                            ColorIndicator(color: Color(hex: cat.color))
                            Text(cat.name)
                            Spacer()
                            if selectedCategoryIDs.contains(String(cat.id)) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let id = String(cat.id)
                            if selectedCategoryIDs.contains(id) {
                                selectedCategoryIDs.remove(id)
                            } else {
                                selectedCategoryIDs.insert(id)
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isLoading { ProgressView() }
                        Text(item == nil ? "创建事项" : "保存修改")
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || isLoading)
            }
        }
        .navigationTitle(item == nil ? "新建事项" : "编辑事项")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        }
        .task {
            categories = (try? await APIClient.shared.getCategories()) ?? []
            if let item {
                title = item.title
                description = item.description ?? ""
                if let dl = item.deadline, let d = parseDate(dl) {
                    hasDeadline = true
                    deadlineDate = d
                }
                if let pt = item.plannedTime, let d = parseDate(pt) {
                    hasPlannedTime = true
                    plannedDate = d
                }
                selectedCategoryIDs = Set(item.categoryIDs)
            } else {
                title = ""; description = ""; hasDeadline = false; hasPlannedTime = false
                selectedCategoryIDs = []
            }
        }
    }

    private func save() {
        isLoading = true
        errorMessage = nil
        let cats = Array(selectedCategoryIDs)
        let dl = hasDeadline ? formatDate(deadlineDate) : nil
        let pt = hasPlannedTime ? formatDateTime(plannedDate) : nil

        Task {
            do {
                if let item {
                    try await APIClient.shared.updateItem(
                        id: item.id,
                        title: title,
                        description: description.isEmpty ? nil : description,
                        deadline: dl,
                        plannedTime: pt,
                        categories: cats
                    )
                } else {
                    try await APIClient.shared.createItem(
                        title: title,
                        description: description.isEmpty ? nil : description,
                        deadline: dl,
                        plannedTime: pt,
                        categories: cats
                    )
                }
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func formatDateTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    private func parseDate(_ s: String) -> Date? {
        let fmts = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        for fmt in fmts {
            let f = DateFormatter()
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
            if let d = f.date(from: String(s.prefix(fmt.count))) { return d }
        }
        return nil
    }
}
