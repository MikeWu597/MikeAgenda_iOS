import SwiftUI

struct RenewalFormView: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var expiryDate = Date()
    @State private var reminderDays = 7
    @State private var selectedCategoryID = 0
    @State private var categories: [RenewalCategory] = []
    @State private var isLoading = false

    init(onSaved: @escaping () -> Void) { self.onSaved = onSaved }

    var body: some View {
        Form {
            Section("名称") { TextField("请输入名称", text: $name) }
            Section("描述") { TextField("描述（可选）", text: $description) }
            Section("到期日") { DatePicker("到期日期", selection: $expiryDate, displayedComponents: .date) }
            Section("提前提醒天数") {
                TextField("天数", value: $reminderDays, format: .number)
                    .keyboardType(.numberPad)
            }
            Section("分类") {
                if categories.isEmpty { Text("暂无分类").foregroundColor(.secondary) }
                else {
                    Picker("分类", selection: $selectedCategoryID) {
                        ForEach(categories) { Text($0.name).tag($0.id) }
                    }
                }
            }
            Section {
                Button {
                    save()
                } label: {
                    HStack { Spacer(); if isLoading { ProgressView() }; Text("创建续订"); Spacer() }
                }
                .disabled(name.isEmpty || isLoading)
            }
        }
        .navigationTitle("创建续订")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        .task {
            categories = (try? await APIClient.shared.getAllRenewalCategories()) ?? []
            selectedCategoryID = categories.first?.id ?? 0
        }
    }

    private func save() {
        isLoading = true
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        Task {
            do {
                try await APIClient.shared.createRenewal(
                    name: name, description: description, expiryDate: f.string(from: expiryDate),
                    reminderDays: reminderDays, categoryID: selectedCategoryID
                )
                await MainActor.run { onSaved(); dismiss() }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
