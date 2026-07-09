import SwiftUI

struct DoneItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Item] = []
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var searchText = ""

    var filteredItems: [Item] {
        let sorted = items.sorted { a, b in
            let aTime = a.updatedAt ?? a.createdAt ?? ""
            let bTime = b.updatedAt ?? b.createdAt ?? ""
            return aTime > bTime
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if filteredItems.isEmpty {
                EmptyStateView(icon: "checkmark.circle", message: searchText.isEmpty ? "暂无已完成事项" : "无匹配结果")
            } else {
                ForEach(filteredItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            let cats = categories.filter { c in item.categoryIDs.contains(String(c.id)) }
                            ForEach(cats) { cat in
                                Text(cat.name)
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: cat.color))
                                    .clipShape(Capsule())
                            }
                            Text(item.title)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(2)
                        }
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        HStack(spacing: 12) {
                            if let deadline = item.deadline {
                                Label(String(deadline.prefix(10)), systemImage: "calendar")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let planned = item.plannedTime {
                                Label(formatPlannedTime(planned), systemImage: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let updated = item.updatedAt {
                                Label("完成于 \(String(updated.prefix(10)))", systemImage: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                try? await APIClient.shared.deleteItem(id: item.id)
                                items.removeAll { $0.id == item.id }
                            }
                        } label: { Label("删除", systemImage: "trash") }
                        Button {
                            Task {
                                try? await APIClient.shared.markItemAsUndone(id: item.id)
                                items.removeAll { $0.id == item.id }
                            }
                        } label: { Label("恢复", systemImage: "arrow.uturn.backward") }
                        .tint(.orange)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索已完成事项")
        .navigationTitle("已完成事项")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
        }
        .task {
            async let its = APIClient.shared.getDoneItems()
            async let cats = APIClient.shared.getCategories()
            items = (try? await its) ?? []
            categories = (try? await cats) ?? []
            isLoading = false
        }
    }

    private func formatPlannedTime(_ raw: String) -> String {
        if raw.count >= 16 {
            return String(raw.prefix(16))
        }
        return String(raw.prefix(10))
    }
}
