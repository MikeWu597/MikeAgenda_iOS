#if !targetEnvironment(macCatalyst)
import SwiftUI
import AVFoundation

struct WakeTaskRunner: View {
    let task: WakeTaskConfiguration
    let initialCount: Int
    let onProgress: (Int) -> Void
    let onComplete: () -> Void
    @Environment(\.scenePhase) private var phase
    @StateObject private var speech = WakeSpeechDetector()
    @State private var count = 0
    @State private var question = MathQuestion.make(difficulty: 1)
    @State private var answer = ""
    @State private var camera = false
    @State private var busy = false
    @State private var message = ""
    @State private var finished = false
    @State private var phraseAccepted = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: task.kind.symbol).font(.system(size: 42)).foregroundStyle(.orange)
                Text("已完成 \(count) / \(task.repetitions)")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                ProgressView(value: Double(count), total: Double(task.repetitions))
                switch task.kind {
                case .math:
                    Text(question.text + " = ?")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .padding(.vertical, 12)
                    TextField("答案", text: $answer).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Button("确认答案") {
                        guard let value = Int(answer.trimmingCharacters(in: .whitespaces)) else { message = "请输入整数答案"; return }
                        if value == question.answer { advance(); message = "回答正确" }
                        else {
                            message = task.consecutive ? "回答错误，连续计数已重置" : "回答错误，请继续"
                            if task.consecutive { count = 0; onProgress(0) }
                        }
                        answer = ""; question = .make(difficulty: task.difficulty)
                    }.buttonStyle(.borderedProminent)
                case .qr:
                    Text("请拍摄配置时绑定的二维码")
                    Button("扫描二维码") { openCamera() }.buttonStyle(.borderedProminent)
                case .scene:
                    Text("请到参考场景前，保持接近的取景角度拍摄")
                    if let bytes = task.referenceImages.first, let image = UIImage(data: bytes) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button("拍摄并比对") { openCamera() }.buttonStyle(.borderedProminent)
                case .phrase:
                    Text(task.target).font(.title2)
                    Text(speech.message).font(.subheadline).foregroundStyle(.secondary)
                    if !speech.transcript.isEmpty { Text("已识别：" + speech.transcript) }
                    Button(speech.running ? "停止识别" : "开始说话") {
                        if speech.running { speech.stop() }
                        else { phraseAccepted = false; Task { await speech.start(locale: task.locale) } }
                    }.buttonStyle(.borderedProminent)
                    Text("每次点击开始完成一遍句子，识别在设备上进行。").font(.caption).foregroundStyle(.secondary)
                }
                if busy { ProgressView("正在本机识别…") }
                if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
            }.padding(24)
        }
        .navigationTitle(task.kind.title)
        .disabled(busy || finished)
        .onAppear { count = initialCount; question = .make(difficulty: task.difficulty); checkComplete() }
        .sheet(isPresented: $camera) { WakeCamera { process($0) }.ignoresSafeArea() }
        .onChange(of: speech.transcript) { _, text in
            guard task.kind == .phrase, !phraseAccepted, !finished else { return }
            let actual = normalizedWakePhrase(text), expected = normalizedWakePhrase(task.target)
            guard !expected.isEmpty else { return }
            if task.strictPhrase ? actual == expected : actual.contains(expected) {
                phraseAccepted = true; speech.stop(); advance(); message = "句子匹配成功"
            }
        }
        .onChange(of: phase) { _, phase in
            if phase != .active { speech.stop(); message = "识别已暂停，返回后请点击开始" }
        }
        .onDisappear { speech.stop() }
    }
    private func advance() { guard !finished else { return }; count = min(task.repetitions, count + 1); onProgress(count); checkComplete() }
    private func checkComplete() {
        if count >= task.repetitions {
            finished = true; speech.stop(); onComplete()
        }
    }
    private func openCamera() {
        Task {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message = "此设备没有可用相机"; return }
            guard await AVCaptureDevice.requestAccess(for: .video) else { message = "请在系统设置中允许相机"; return }
            camera = true
        }
    }
    private func process(_ image: UIImage) {
        guard let data = wakeJPEG(image) else { message = "照片处理失败"; return }
        busy = true
        Task {
            do {
                if task.kind == .qr {
                    let codes = try await WakeImageVerifier().qr(data)
                    if codes.contains(task.target) { message = "二维码匹配成功"; advance() }
                    else { message = "二维码不匹配，请拍摄绑定的二维码" }
                } else {
                    let distance = try await WakeImageVerifier().distance(data, references: task.referenceImages)
                    if distance <= Float(task.imageDistance) { message = "场景匹配成功"; advance() }
                    else { message = String(format: "场景未匹配（距离 %.2f，要求 ≤ %.2f），请调整角度或光线", distance, task.imageDistance) }
                }
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}
#endif
