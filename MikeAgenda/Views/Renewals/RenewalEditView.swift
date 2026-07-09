import SwiftUI

struct RenewalEditView: View {
    let renewal: Renewal
    let categories: [RenewalCategory]
    let onSaved: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var expiryDate = Date()
    @State private var reminderDays = 7
    @State private var selectedCategoryID = 0
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("名称") { TextField("请输入名称", text: $name) }
            Section("描述") { TextField("描述（可选）", text: $description) }
            Section("到期日") { DatePicker("到期日期", selection: $expiryDate, displayedComponents: .date) }
            Section("提前提醒天数") {
                TextField("天数", value: $reminderDays, format: .number).keyboardType(.numberPad)
            }
            Section("分类") {
                Picker("分类", selection: $selectedCategoryID) {
                    ForEach(categories) { Text($0.name).tag($0.id) }
                }
            }
            Section {
                Button {
                    save()
                } label: {
                    HStack { Spacer(); if isLoading { ProgressView() }; Text("保存修改"); Spacer() }
                }
            }
        }
        .navigationTitle("编辑续订")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = renewal.name
            description = renewal.description ?? ""
            if let exp = renewal.expiryDate, exp.count >= 10 {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                expiryDate = f.date(from: String(exp.prefix(10))) ?? Date()
            }
            reminderDays = renewal.reminderDays ?? 7
            selectedCategoryID = renewal.categoryID ?? (categories.first?.id ?? 0)
        }
    }

    private func save() {
        isLoading = true
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        Task {
            do {
                try await APIClient.shared.updateRenewal(
                    id: renewal.id, name: name, description: description,
                    expiryDate: f.string(from: expiryDate),
                    reminderDays: reminderDays, categoryID: selectedCategoryID
                )
                await MainActor.run { isLoading = false; onSaved() }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
