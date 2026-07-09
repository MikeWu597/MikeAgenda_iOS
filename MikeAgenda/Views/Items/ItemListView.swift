import SwiftUI

struct ItemListView: View {
    @StateObject private var viewModel = ItemListViewModel()
    @State private var showCreate = false
    @State private var showDone = false
    @State private var editItem: Item?

    var body: some View {
        List {
            if let selected = viewModel.selectedCategory {
                Section {
                    Button("清除分类筛选") {
                        viewModel.selectedCategory = nil
                    }
                }
            }

            if viewModel.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if viewModel.filteredItems.isEmpty {
                EmptyStateView(icon: "tray", message: "暂无待办事项", action: { showCreate = true }, actionLabel: "创建事项")
            } else {
                ForEach(viewModel.pagedItems) { item in
                    itemRow(item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(item) }
                            } label: { Label("删除", systemImage: "trash") }
                            Button {
                                Task { await viewModel.toggleDone(item) }
                            } label: { Label("完成", systemImage: "checkmark") }
                            .tint(.green)
                        }
                        .onTapGesture { editItem = item }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索事项")
        .navigationTitle("所有事项")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button { showDone = true } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showCreate) {
            NavigationStack { ItemFormView(onSaved: { Task { await viewModel.load() } }) }
        }
        .sheet(item: $editItem) { item in
            NavigationStack { ItemFormView(item: item, onSaved: { Task { await viewModel.load() } }) }
        }
        .sheet(isPresented: $showDone) {
            NavigationStack { DoneItemsView() }
        }
    }

    private func itemRow(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let cats = viewModel.categories.filter { c in item.categoryIDs.contains(String(c.id)) }
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
                    .lineLimit(1)
            }
            if let desc = item.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if let deadline = item.deadline {
                Label(String(deadline.prefix(10)), systemImage: "alarm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
