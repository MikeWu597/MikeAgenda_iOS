import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - 水印样式参数

struct WatermarkStyle {
    var text: String = "仅供验证使用"
    var fontSize: Double = 30
    var spacing: Double = 110
    var angle: Double = -30
    var opacity: Double = 0.4
    var color: Color = .white

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedText.isEmpty }
}

// MARK: - 平铺水印遮罩（预览与图片导出共用）

struct WatermarkTiledOverlay: View {
    let style: WatermarkStyle

    var body: some View {
        Canvas { ctx, size in
            let text = style.trimmedText
            guard !text.isEmpty else { return }

            // 多行水印：逐行 resolve，手动垂直堆叠并居中
            let font = Font.system(size: CGFloat(style.fontSize), weight: .medium)
            let lines = text.components(separatedBy: "\n")
            let resolvedLines = lines.map {
                ctx.resolve(Text($0).font(font).foregroundStyle(style.color.opacity(style.opacity)))
            }
            let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            let lineSizes = resolvedLines.map { $0.measure(in: maxSize) }
            let lineHeight = lineSizes.map(\.height).max() ?? 0
            let lineSpacing = lineHeight * 0.25
            let blockW = lineSizes.map(\.width).max() ?? 0
            let blockH = lineHeight * CGFloat(resolvedLines.count)
                + lineSpacing * CGFloat(max(resolvedLines.count - 1, 0))
            let stepX = blockW + CGFloat(style.spacing)
            let stepY = blockH + CGFloat(style.spacing)
            guard stepX > 1, stepY > 1 else { return }
            let extent = hypot(size.width, size.height) + max(stepX, stepY)

            var layer = ctx
            layer.translateBy(x: size.width / 2, y: size.height / 2)
            layer.rotate(by: .degrees(style.angle))

            var y = -extent / 2
            while y <= extent / 2 {
                var x = -extent / 2
                while x <= extent / 2 {
                    for (i, line) in resolvedLines.enumerated() where !lines[i].isEmpty {
                        let offsetY = -blockH / 2 + lineHeight / 2
                            + CGFloat(i) * (lineHeight + lineSpacing)
                        layer.draw(line, at: CGPoint(x: x, y: y + offsetY), anchor: .center)
                    }
                    x += stepX
                }
                y += stepY
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 水印工具

struct WatermarkToolView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var videoURL: URL?
    @State private var videoAspect: CGFloat = 16.0 / 9.0
    @State private var previewWidth: CGFloat = 0

    @State private var style = WatermarkStyle()

    @State private var isLoadingMedia = false
    @State private var isExporting = false
    @State private var exportProgress: Double?
    @State private var exportedFile: ExportedMediaFile?
    @State private var errorMessage: String?
    @State private var saveNotice: String?

    private var hasMedia: Bool { image != nil || videoURL != nil }
    private var canExport: Bool { hasMedia && style.isValid && !isExporting }

    var body: some View {
        List {
            Section("素材") {
                PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(hasMedia ? "重新选择" : "选择图片或视频")
                            .foregroundStyle(.primary)
                    }
                }

                if isLoadingMedia {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let image {
                    mediaPreview(aspect: image.size.width / max(image.size.height, 1)) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                } else if let videoURL {
                    mediaPreview(aspect: videoAspect) {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                    }
                }
            }

            Section {
                TextField("水印内容", text: $style.text, axis: .vertical)
                    .lineLimit(1...6)
                labeledSlider("字号", value: $style.fontSize, range: 14...96) { "\(Int($0))" }
                labeledSlider("间距", value: $style.spacing, range: 24...320) { "\(Int($0))" }
                labeledSlider("倾斜", value: $style.angle, range: -75...75) { "\(Int($0))°" }
                labeledSlider("透明度", value: $style.opacity, range: 0.05...1) { "\(Int($0 * 100))%" }
                ColorPicker("颜色", selection: $style.color, supportsOpacity: false)
            } header: {
                Text("水印设置")
            } footer: {
                Text("水印会以平铺方式铺满整个画面，导出尺寸与原素材一致。")
            }

            Section {
                Button {
                    Task { await exportCurrent() }
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        if isExporting {
                            if let progress = exportProgress {
                                ProgressView(value: progress)
                                    .frame(width: 100)
                            } else {
                                ProgressView()
                            }
                            Text("正在导出…")
                        } else {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }
                        Spacer()
                    }
                }
                .disabled(!canExport)
            }
        }
        .navigationTitle("水印")
        .onChange(of: pickedItem) { _, item in loadMedia(item) }
        .sheet(item: $exportedFile) { file in
            ActivityView(items: [file.url], isVideo: videoURL != nil) { success, error in
                saveNotice = success ? "已保存到相册" : (error ?? "保存到相册失败")
            }
        }
        .alert("提示", isPresented: Binding(
            get: { saveNotice != nil },
            set: { if !$0 { saveNotice = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveNotice ?? "")
        }
        .alert("导出失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 预览

    @ViewBuilder
    private func mediaPreview<Content: View>(aspect: CGFloat, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .overlay(WatermarkTiledOverlay(style: style))
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 320)
            .clipped()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { previewWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in previewWidth = w }
                }
            )
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    // MARK: - 素材载入

    private func loadMedia(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingMedia = true
        image = nil
        videoURL = nil
        exportedFile = nil

        Task {
            defer { isLoadingMedia = false }
            do {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let video = try await item.loadTransferable(type: PickedVideoFile.self) {
                        videoURL = video.url
                        await loadVideoAspect(video.url)
                    } else {
                        errorMessage = "无法读取所选视频"
                    }
                } else {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        image = img
                    } else {
                        errorMessage = "无法读取所选图片"
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadVideoAspect(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else { return }
        let s = size.applying(transform)
        let w = abs(s.width), h = abs(s.height)
        if w > 0, h > 0 { videoAspect = w / h }
    }

    // MARK: - 导出

    private func exportCurrent() async {
        isExporting = true
        defer {
            isExporting = false
            exportProgress = nil
        }
        do {
            if let image {
                let k = image.size.width / max(previewWidth, 1)
                exportedFile = try ExportedMediaFile(url: exportImage(image, scale: k))
            } else if let videoURL {
                exportedFile = try await ExportedMediaFile(url: exportVideo(videoURL))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportImage(_ image: UIImage, scale k: CGFloat) throws -> URL {
        var s = style
        s.fontSize *= Double(k)
        s.spacing *= Double(k)

        let view = ZStack {
            Image(uiImage: image).resizable()
            WatermarkTiledOverlay(style: s)
        }
        .frame(width: image.size.width, height: image.size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = image.scale
        guard let out = renderer.uiImage, let data = out.pngData() else {
            throw WatermarkExportError.renderFailed
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermark_\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    private func exportVideo(_ url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw WatermarkExportError.noVideoTrack
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let duration = try await asset.load(.duration)

        let transformed = naturalSize.applying(transform)
        let renderSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        let k = renderSize.width / max(previewWidth, 1)

        let composition = AVMutableComposition()
        guard let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw WatermarkExportError.exportFailed
        }
        try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        compVideo.preferredTransform = transform

        if let srcAudio = try? await asset.loadTracks(withMediaType: .audio).first,
           let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudio.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcAudio, at: .zero)
        }

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(makeWatermarkLayer(size: renderSize, scale: k))

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermark_\(UUID().uuidString).mp4")
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw WatermarkExportError.exportFailed
        }
        exporter.videoComposition = videoComposition

        exportProgress = 0
        let progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                exportProgress = Double(exporter.progress)
            }
        }
        defer { progressTask.cancel() }

        try await exporter.export(to: outURL, as: .mp4)
        exportProgress = 1
        return outURL
    }

    /// 生成铺满整个画面的平铺文字水印图层（CALayer 版本，用于视频导出）
    private func makeWatermarkLayer(size: CGSize, scale k: CGFloat) -> CALayer {
        let fontSize = CGFloat(style.fontSize) * k
        let spacing = CGFloat(style.spacing) * k
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let text = style.trimmedText

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let measureAttrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: measureAttrs,
            context: nil
        )
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        let stepX = textSize.width + spacing
        let stepY = textSize.height + spacing
        let extent = hypot(size.width, size.height) + max(stepX, stepY)

        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: size)

        let container = CALayer()
        container.frame = CGRect(
            x: (size.width - extent) / 2,
            y: (size.height - extent) / 2,
            width: extent,
            height: extent
        )
        container.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(style.angle) * .pi / 180))
        container.masksToBounds = false

        var drawAttrs = measureAttrs
        drawAttrs[.foregroundColor] = UIColor(style.color).withAlphaComponent(CGFloat(style.opacity))
        let attributedText = NSAttributedString(string: text, attributes: drawAttrs)
        let tileW = textSize.width + 8
        let tileH = textSize.height + 4

        var y: CGFloat = 0
        while y <= extent {
            var x: CGFloat = 0
            while x <= extent {
                let t = CATextLayer()
                t.string = attributedText
                t.alignmentMode = .center
                t.isWrapped = false
                t.contentsScale = 2
                t.frame = CGRect(x: x - tileW / 2, y: y - tileH / 2, width: tileW, height: tileH)
                container.addSublayer(t)
                x += stepX
            }
            y += stepY
        }

        parent.addSublayer(container)
        return parent
    }
}

// MARK: - 导出结果包装（URL 在 iOS 26 SDK 下不再遵循 Identifiable）

struct ExportedMediaFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - 相册视频导入（复制到临时目录，避免大文件读入内存）

struct PickedVideoFile: Transferable {
    let url: URL

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("wm_src_\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: tmp)
            try FileManager.default.copyItem(at: received.file, to: tmp)
            return PickedVideoFile(url: tmp)
        }
    }
}

private enum WatermarkExportError: LocalizedError {
    case renderFailed
    case noVideoTrack
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: return "图片渲染失败"
        case .noVideoTrack: return "未找到视频轨道"
        case .exportFailed: return "视频导出失败"
        }
    }
}

#Preview {
    NavigationStack { WatermarkToolView() }
}
