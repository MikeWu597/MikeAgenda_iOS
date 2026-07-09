import SwiftUI

struct RenewalDetailView: View {
    let renewal: Renewal
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("名称") { Text(renewal.name).font(.body) }
                if let expiry = renewal.expiryDate?.prefix(10) {
                    Section("到期日") { Text(String(expiry)) }
                }
                if let days = renewal.reminderDays {
                    Section("提前提醒") { Text("\(days) 天") }
                }
                if let catID = renewal.categoryID {
                    Section("分类ID") { Text("\(catID)") }
                }
            }
            .navigationTitle("续订详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}
