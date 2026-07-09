import SwiftUI

struct RenewalListView: View {
    @State private var renewals: [Renewal] = []
    @State private var categories: [RenewalCategory] = []
    @State private var isLoading = true
    @State private var showForm = false
    @State private var editRenewal: Renewal?

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if renewals.isEmpty {
                EmptyStateView(icon: "bell", message: "暂无续订提醒", action: { showForm = true }, actionLabel: "创建续订")
            } else {
                ForEach(categories, id: \.id) { cat in
                    let items = renewals.filter { $0.categoryID == cat.id }
                    if !items.isEmpty {
                        Section(cat.name) {
                            ForEach(items) { renewal in
                                Button {
                                    editRenewal = renewal
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(renewal.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        if let expiry = renewal.expiryDate?.prefix(10) {
                                            HStack {
                                                Text("到期: \(String(expiry))")
                                                if let days = renewal.reminderDays {
                                                    Text("(提前\(days)天提醒)")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("续订提醒")
        .toolbar {
            NavigationLink { RenewalCategoryListView() } label: { Image(systemName: "tag") }
            Button { showForm = true } label: { Image(systemName: "plus") }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showForm) {
            NavigationStack { RenewalFormView(onSaved: { Task { await load() } }) }
        }
        .sheet(item: $editRenewal) { renewal in
            RenewalDetailView(renewal: renewal, onUpdate: { Task { await load() } })
        }
    }

    private func load() async {
        isLoading = true
        async let rens = APIClient.shared.getAllRenewals()
        async let cats = APIClient.shared.getAllRenewalCategories()
        renewals = (try? await rens) ?? []
        categories = (try? await cats) ?? []
        isLoading = false
    }
}
