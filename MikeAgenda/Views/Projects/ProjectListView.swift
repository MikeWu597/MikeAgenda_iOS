import SwiftUI

struct ProjectListView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var showForm = false

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if projects.isEmpty {
                EmptyStateView(icon: "folder", message: "暂无项目", action: { showForm = true }, actionLabel: "创建项目")
            } else {
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        HStack {
                            ColorIndicator(color: Color(hex: project.color))
                            Text(project.name)
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                try? await APIClient.shared.deleteProject(id: project.id)
                                await load()
                            }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("项目")
        .toolbar {
            Button { showForm = true } label: { Image(systemName: "plus") }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showForm) {
            NavigationStack { ProjectFormView(onSaved: { Task { await load() } }) }
        }
    }

    private func load() async {
        isLoading = true
        projects = (try? await APIClient.shared.getProjects()) ?? []
        isLoading = false
    }
}
