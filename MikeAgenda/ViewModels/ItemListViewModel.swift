import SwiftUI
import Combine

@MainActor
final class ItemListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedCategory: Int?
    @Published var currentPage = 1
    @Published var pageSize = 20

    var filteredItems: [Item] {
        var result = items
        if let catID = selectedCategory {
            result = result.filter { $0.categoryIDs.contains(String(catID)) }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var pagedItems: [Item] {
        let start = (currentPage - 1) * pageSize
        guard start < filteredItems.count else { return [] }
        let end = min(start + pageSize, filteredItems.count)
        return Array(filteredItems[start..<end])
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(filteredItems.count) / Double(pageSize))))
    }

    func load() async {
        isLoading = true
        async let cats = APIClient.shared.getCategories()
        async let its = APIClient.shared.getItems()
        categories = (try? await cats) ?? []
        items = (try? await its) ?? []
        currentPage = 1
        isLoading = false
    }

    func toggleDone(_ item: Item) async {
        do {
            try await APIClient.shared.markItemAsDone(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {}
    }

    func delete(_ item: Item) async {
        do {
            try await APIClient.shared.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {}
    }
}
