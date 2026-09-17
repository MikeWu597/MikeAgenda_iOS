import SwiftUI
import Photos

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
                CheckInToolView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("打卡")
                            .foregroundStyle(.primary)
                        Text("拍照并叠加时间地点水印")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
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

// MARK: - 系统分享面板（含水印工具 / 打卡共用的「保存到相册」动作）

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let isVideo: Bool
    var onSaveToPhotos: ((Bool, String?) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let save = SaveToPhotosActivity()
        save.isVideo = isVideo
        save.onResult = onSaveToPhotos
        let vc = UIActivityViewController(activityItems: items, applicationActivities: [save])
        if let popover = vc.popoverPresentationController {
            popover.sourceView = vc.view
            popover.sourceRect = CGRect(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 2,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 分享面板中的自定义「保存到相册」动作
final class SaveToPhotosActivity: UIActivity {
    var isVideo = false
    var onResult: ((Bool, String?) -> Void)?
    private var fileURL: URL?

    override var activityTitle: String? { "保存到相册" }

    override var activityImage: UIImage? {
        UIImage(systemName: "square.and.arrow.down")
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("cn.matrixecho.MikeAgenda.saveToPhotos")
    }

    override class var activityCategory: UIActivity.Category { .action }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is URL }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        fileURL = activityItems.compactMap { $0 as? URL }.first
    }

    override func perform() {
        guard let fileURL else {
            activityDidFinish(false)
            return
        }
        PHPhotoLibrary.shared().performChanges {
            if self.isVideo {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                self.activityDidFinish(success)
                // 等分享面板完全关闭后再回调，避免结果提示被吞掉
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.onResult?(success, error?.localizedDescription)
                }
            }
        }
    }
}
