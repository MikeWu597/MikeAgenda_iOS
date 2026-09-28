#if !targetEnvironment(macCatalyst)
import SwiftUI
import Combine
import AVFoundation
import Vision
import Speech

struct WakeCamera: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: WakeCamera
        init(_ parent: WakeCamera) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

actor WakeImageVerifier {
    func qr(_ data: Data) throws -> [String] {
        let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]
        try VNImageRequestHandler(data: data).perform([request])
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }
    func distance(_ data: Data, references: [Data]) throws -> Float {
        func feature(_ bytes: Data) throws -> VNFeaturePrintObservation {
            let request = VNGenerateImageFeaturePrintRequest()
            request.revision = VNGenerateImageFeaturePrintRequestRevision2
            try VNImageRequestHandler(data: bytes).perform([request])
            guard let result = request.results?.first as? VNFeaturePrintObservation else { throw WakeError.message("无法识别这张图片，请重新拍摄") }
            return result
        }
        let candidate = try feature(data)
        var distances: [Float] = []
        for reference in references {
            let other = try feature(reference)
            var distance: Float = 0
            try candidate.computeDistance(&distance, to: other)
            distances.append(distance)
        }
        return distances.min() ?? .infinity
    }
}

func wakeJPEG(_ image: UIImage) -> Data? {
    let scale = min(1, 1000 / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.8)
}

@MainActor
final class WakeSpeechDetector: ObservableObject {
    @Published var transcript = ""
    @Published var message = "点击开始，再说出指定句子"
    @Published var running = false
    private let engine = AVAudioEngine()
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled = false
    private var timeout: Task<Void, Never>?
    private var generation = UUID()
    func start(locale: String) async {
        stop(); transcript = ""
        let runID = generation
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard runID == generation else { return }
        guard authorization == .authorized else { message = "请在系统设置中允许语音识别"; return }
        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard runID == generation else { return }
        guard microphoneAllowed else { message = "请在系统设置中允许麦克风"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            message = "此设备或语言暂不支持本地识别，请检查系统语言资源或使用其他任务"; return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw WakeError.message("麦克风暂不可用") }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            tapInstalled = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.generation == runID else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if let error { self.message = "识别结束：" + error.localizedDescription; self.stop() }
                    else if result?.isFinal == true { self.message = "识别完成"; self.stop() }
                }
            }
            engine.prepare(); try engine.start(); running = true; message = "正在本机识别，请说话（最长 20 秒）"
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch { message = error.localizedDescription; stop() }
    }
    func stop() {
        generation = UUID()
        timeout?.cancel(); timeout = nil
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
