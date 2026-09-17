import SwiftUI
import MapKit
import Photos
import CoreLocation

// MARK: - 系统相机包装

private struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.cameraCaptureMode = .photo
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 打卡合成图（预览与导出共用，所有尺寸按画布宽度等比缩放）

struct CheckInComposedView: View {
    let image: UIImage
    let capturedAt: Date
    let address: String
    let width: CGFloat

    private var height: CGFloat { width * image.size.height / max(image.size.width, 1) }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: capturedAt)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: capturedAt)
    }

    var body: some View {
        let timeFont = width * 0.058
        let dateFont = width * 0.020
        let titleFont = width * 0.024
        let addrFont = width * 0.021

        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

            HStack(alignment: .center, spacing: width * 0.022) {
                VStack(alignment: .leading, spacing: width * 0.004) {
                    Text(timeText)
                        .font(.system(size: timeFont, weight: .bold))
                    Text(dateText)
                        .font(.system(size: dateFont, weight: .medium))
                }

                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: max(width * 0.0015, 1.5), height: timeFont * 1.25)

                VStack(alignment: .leading, spacing: width * 0.008) {
                    Text("签到打卡")
                        .font(.system(size: titleFont, weight: .semibold))
                    HStack(alignment: .top, spacing: width * 0.006) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: addrFont))
                        Text(address.isEmpty ? "定位中…" : address)
                            .font(.system(size: addrFont, weight: .medium))
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: width * 0.002, y: width * 0.001)
            .padding(.horizontal, width * 0.045)
            .padding(.bottom, width * 0.05)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - 打卡工具

struct CheckInToolView: View {
    @ObservedObject private var locationService = LocationService.shared

    @State private var photo: UIImage?
    @State private var capturedAt = Date()
    @State private var address = ""
    @State private var showCamera = false
    @State private var cameraUnavailable = false
    @State private var autoPresented = false
    @State private var isSaving = false
    @State private var saveNotice: String?
    @State private var exportedFile: ExportedMediaFile?
    @State private var lastGeocodedLocation: CLLocation?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let photo {
                    GeometryReader { geo in
                        CheckInComposedView(
                            image: photo,
                            capturedAt: capturedAt,
                            address: address,
                            width: geo.size.width
                        )
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                } else {
                    ContentUnavailableView(
                        "还没有打卡照片",
                        systemImage: "camera",
                        description: Text("拍摄后将自动叠加时间与地点水印")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.05))

            HStack(spacing: 12) {
                Button { openCamera() } label: {
                    Label(photo == nil ? "拍照" : "重拍", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button { saveToPhotos() } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("保存到相册", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(photo == nil || isSaving)

                Button { sharePhoto() } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(photo == nil || isSaving)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("打卡")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationService.requestLocation()
            locationService.startTracking()
            if photo == nil && !autoPresented {
                autoPresented = true
                openCamera()
            }
        }
        .onDisappear {
            locationService.stopTracking()
        }
        .onChange(of: locationService.currentLocation) { _, location in
            guard let location else { return }
            // 位置移动超过 50 米才重新逆地理编码，避免频繁请求
            if let last = lastGeocodedLocation, location.distance(from: last) < 50 { return }
            lastGeocodedLocation = location
            Task { await reverseGeocode(location) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                photo = image
                capturedAt = Date()
            }
            .ignoresSafeArea()
        }
        .sheet(item: $exportedFile) { file in
            ActivityView(items: [file.url], isVideo: false) { success, error in
                saveNotice = success ? "已保存到相册" : (error ?? "保存到相册失败")
            }
        }
        .alert("提示", isPresented: Binding(
            get: { cameraUnavailable },
            set: { if !$0 { cameraUnavailable = false } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text("此设备不支持相机，请在真机上使用打卡功能")
        }
        .alert("提示", isPresented: Binding(
            get: { saveNotice != nil },
            set: { if !$0 { saveNotice = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveNotice ?? "")
        }
    }

    // MARK: - 相机

    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCamera = true
        } else {
            cameraUnavailable = true
        }
    }

    // MARK: - MapKit 逆地理编码

    private func reverseGeocode(_ location: CLLocation) async {
        guard let request = MKReverseGeocodingRequest(location: location) else { return }
        request.preferredLocale = Locale(identifier: "zh_CN")
        do {
            let items = try await request.mapItems
            guard let item = items.first else { return }
            let full = item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true) ?? ""
            var result = full
            if let poi = item.name, !poi.isEmpty, !full.contains(poi) {
                result = full.isEmpty ? poi : "\(full) · \(poi)"
            }
            if result.isEmpty {
                result = String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
            }
            address = result
        } catch {
            // 编码失败时保留现有地址，静默降级
        }
    }

    // MARK: - 导出

    private func renderImage() -> Data? {
        guard let photo else { return nil }
        let view = CheckInComposedView(
            image: photo,
            capturedAt: capturedAt,
            address: address,
            width: photo.size.width
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = photo.scale
        return renderer.uiImage?.pngData()
    }

    private func saveToPhotos() {
        guard let data = renderImage() else { return }
        isSaving = true
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        } completionHandler: { success, error in
            Task { @MainActor in
                isSaving = false
                saveNotice = success ? "已保存到相册" : (error?.localizedDescription ?? "保存失败")
            }
        }
    }

    private func sharePhoto() {
        guard let data = renderImage() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("checkin_\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            exportedFile = ExportedMediaFile(url: url)
        } catch {
            saveNotice = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { CheckInToolView() }
}
