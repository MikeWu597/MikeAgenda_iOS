import SwiftUI

struct LoadingOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .foregroundColor(.secondary)
            if let action, let actionLabel {
                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct DateHeader: View {
    @Binding var date: Date
    var onDateChanged: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    onDateChanged?()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderless)

            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .onChange(of: date) { _ in onDateChanged?() }

            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                    onDateChanged?()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
    }
}

struct ColorIndicator: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

/// 服务页通用的「工具」分组（深圳 / 香港均显示）
struct ServiceToolsSection: View {
    var body: some View {
        Section("工具") {
            NavigationLink {
                WatermarkToolView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "text.below.photo.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("水印")
                            .foregroundStyle(.primary)
                        Text("为图片或视频添加平铺水印")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue)
            .clipShape(Capsule())
    }
}
