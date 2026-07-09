import SwiftUI

struct ProjectFormView: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = Color.blue
    @State private var isLoading = false

    init(onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("名称") {
                TextField("请输入项目名称", text: $name)
            }
            Section("颜色") {
                ColorPicker("选择颜色", selection: $color)
            }
            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isLoading { ProgressView() }
                        Text("创建项目")
                        Spacer()
                    }
                }
                .disabled(name.isEmpty || isLoading)
            }
        }
        .navigationTitle("创建项目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        }
    }

    private func save() {
        isLoading = true
        Task {
            try? await APIClient.shared.createProject(name: name, color: color.toHex())
            await MainActor.run {
                onSaved()
                dismiss()
            }
        }
    }
}
