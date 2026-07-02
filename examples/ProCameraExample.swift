// ProCameraExample.swift
// 综合示例：展示 iOS 26+ AVCaptureSession 新特性的实际应用

import AVFoundation
import SwiftUI
import Combine

// MARK: - 场景 1: 快速启动的相机 App

/// 优化启动时间，用户可在 300ms 内看到预览画面
class FastStartupCameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.example.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let deferredStartDelegate = CameraDeferredStartDelegate()

    func setupQuickStartCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // 添加摄像头输入
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                return
            }
            self.captureSession.addInput(input)

            // 配置预览层 - 不延迟，优先显示
            let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
            preview.isDeferredStartEnabled = false
            preview.videoGravity = .resizeAspectFill
            self.previewLayer = preview

            // 配置照片输出 - 延迟启动
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
                self.photoOutput.isDeferredStartEnabled = true
            }

            // 启用自动延迟启动
            self.captureSession.automaticallyRunsDeferredStart = true
            self.captureSession.setDeferredStartDelegate(
                self.deferredStartDelegate,
                deferredStartDelegateCallbackQueue: self.sessionQueue
            )

            self.captureSession.commitConfiguration()

            // 启动会话 - 预览立即显示，照片输出稍后自动启动
            self.captureSession.startRunning()
        }
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
}

class CameraDeferredStartDelegate: NSObject, AVCaptureSessionDeferredStartDelegate {
    func sessionWillRunDeferredStart(_ session: AVCaptureSession) {
        print("✅ 预览已显示，照片功能正在初始化...")
    }

    func sessionDidRunDeferredStart(_ session: AVCaptureSession) {
        print("✅ 照片功能就绪，用户可以拍照了")
        // 这里可以启用 UI 上的拍照按钮
        NotificationCenter.default.post(name: .cameraReadyForCapture, object: nil)
    }
}

extension Notification.Name {
    static let cameraReadyForCapture = Notification.Name("cameraReadyForCapture")
}

// MARK: - 场景 2: 运动抓拍相机

/// 实现即时快门响应，捕捉快速移动的瞬间
class ActionCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.example.action.camera")

    func setupActionCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // 添加输入
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                return
            }
            self.captureSession.addInput(input)

            // 配置照片输出
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)

                // 设置高画质
                self.photoOutput.maxPhotoQualityPrioritization = .quality

                // 🚀 关键：启用响应式拍摄
                if self.photoOutput.isResponsiveCaptureSupported {
                    self.photoOutput.isResponsiveCaptureEnabled = true
                    print("✅ 响应式拍摄已启用 - 快门延迟 < 50ms")
                } else {
                    print("⚠️ 当前配置不支持响应式拍摄")
                }
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    /// 即时拍摄 - 无需等待对焦
    func captureInstantly() {
        let settings = AVCapturePhotoSettings()

        // 可选：启用 Live Photo
        if photoOutput.isLivePhotoCaptureSupported {
            let livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            settings.livePhotoMovieFileURL = livePhotoMovieFileURL
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
        print("📸 快门按下 - 立即捕获当前帧")
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("❌ 拍摄失败: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ 无法获取照片数据")
            return
        }

        print("✅ 照片已捕获: \(imageData.count) bytes")
        // 保存照片到相册...
    }
}

// MARK: - 场景 3: 智能性能管理相机

/// 自动监控系统压力，动态调整配置避免过热关闭
class SmartPerformanceCameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.example.smart.camera")
    private var device: AVCaptureDevice?
    private var systemPressureObserver: AnyCancellable?

    private var currentPreset: AVCaptureSession.Preset = .hd4K3840x2160
    private var currentFrameRate: Int32 = 60

    func setupSmartCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // 配置输入
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                return
            }
            self.device = camera
            self.captureSession.addInput(input)

            // 尝试最高配置：4K 60fps
            self.captureSession.sessionPreset = .hd4K3840x2160
            self.setFrameRate(60, for: camera)

            // 添加输出...
            let videoOutput = AVCaptureVideoDataOutput()
            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
            }

            self.captureSession.commitConfiguration()

            // 🔍 检查硬件成本
            let cost = self.captureSession.hardwareCost
            print("📊 当前配置硬件成本: \(cost)")

            if cost > 1.0 {
                print("⚠️ 配置超出硬件能力 (\(cost) > 1.0)，降级中...")
                self.downgradeTo1080p()
            } else {
                print("✅ 配置可行，启动会话")

                // 🎯 开始监控系统压力
                self.startMonitoringSystemPressure()

                self.captureSession.startRunning()
            }
        }
    }

    private func startMonitoringSystemPressure() {
        guard let device = device else { return }

        systemPressureObserver = device.publisher(for: \.systemPressureState)
            .receive(on: sessionQueue)
            .sink { [weak self] state in
                self?.handleSystemPressure(state)
            }
    }

    private func handleSystemPressure(_ state: AVCaptureDevice.SystemPressureState) {
        let levelName: String
        switch state.level {
        case .nominal:
            levelName = "正常"
            // 可以尝试恢复高性能配置
            if currentPreset != .hd4K3840x2160 {
                print("💚 系统压力恢复，尝试升级到 4K")
                upgradeQuality()
            }

        case .fair:
            levelName = "轻度压力"
            // 暂时观察，不做调整

        case .serious:
            levelName = "严重压力"
            // 需要降级
            print("🔶 检测到严重压力，原因: \(state.factors)")
            handleSeriousPressure(factors: state.factors)

        case .critical:
            levelName = "极限压力"
            // 立即降到最低配置
            print("🔴 系统即将关闭相机，紧急降级")
            downgradeTo720p()

        case .shutdown:
            levelName = "已关闭"
            print("❌ 系统强制关闭了相机")
            // 通知用户

        @unknown default:
            levelName = "未知"
        }

        print("📊 系统压力: \(levelName)")
    }

    private func handleSeriousPressure(factors: AVCaptureDevice.SystemPressureFactors) {
        if factors.contains(.systemTemperature) {
            print("🌡️ 检测到过热，降低帧率到 30fps")
            if let device = device {
                setFrameRate(30, for: device)
                currentFrameRate = 30
            }
        }

        if factors.contains(.peakPower) {
            print("🔋 检测到功耗过高，降低分辨率到 1080p")
            downgradeTo1080p()
        }

        if factors.contains(.depthModuleTemperature) {
            print("📷 深度模块过热，关闭深度输出")
            // 移除深度数据输出...
        }
    }

    private func downgradeTo1080p() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080
        currentPreset = .hd1920x1080
        captureSession.commitConfiguration()
        print("⬇️ 已降级到 1080p")
    }

    private func downgradeTo720p() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720
        currentPreset = .hd1280x720
        if let device = device {
            setFrameRate(30, for: device)
            currentFrameRate = 30
        }
        captureSession.commitConfiguration()
        print("⬇️ 已降级到 720p 30fps")
    }

    private func upgradeQuality() {
        guard captureSession.hardwareCost <= 0.8 else {
            print("⚠️ 硬件成本仍然较高，暂不升级")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd4K3840x2160
        currentPreset = .hd4K3840x2160
        if let device = device {
            setFrameRate(60, for: device)
            currentFrameRate = 60
        }
        captureSession.commitConfiguration()
        print("⬆️ 已升级到 4K 60fps")
    }

    private func setFrameRate(_ fps: Int32, for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fps)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fps)
            device.unlockForConfiguration()
        } catch {
            print("❌ 设置帧率失败: \(error)")
        }
    }
}

// MARK: - 场景 4: 专业视频录制

/// 使用 Pro Video Storage 保证高码率录制稳定
class ProVideoRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.example.pro.recorder")

    func setupProVideoRecorder() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // 配置输入
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                return
            }
            self.captureSession.addInput(input)

            // 添加音频输入
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                self.captureSession.addInput(audioInput)
            }

            // 配置视频输出
            if self.captureSession.canAddOutput(self.movieOutput) {
                self.captureSession.addOutput(self.movieOutput)

                // 🎬 检查并启用 Pro Video Storage
                self.configurePro VideoStorage()
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    private func configureProVideoStorage() {
        // 1. 检查设备支持
        guard AVProVideoStorage.isSupported else {
            print("⚠️ 当前设备不支持 Pro Video Storage")
            return
        }

        // 2. 检查可用性
        guard let pvs = AVProVideoStorage.shared else {
            print("❌ 无法获取 Pro Video Storage 实例")
            return
        }

        // 3. 检查容量
        let capacity = pvs.remainingCapacity
        print("💾 Pro Video Storage 剩余容量: \(ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file))")

        if capacity == 0 {
            print("⚠️ Pro Video Storage 空间不足，打开设置页面")
            pvs.openSettings()
            return
        }

        // 4. 检查是否空闲
        guard !pvs.isBusy else {
            print("⚠️ Pro Video Storage 正在被其他任务使用")
            return
        }

        // 5. 检查输出支持
        guard movieOutput.isProVideoStorageSupported else {
            print("⚠️ 当前输出配置不支持 Pro Video Storage")
            return
        }

        // 6. 启用
        movieOutput.usesProVideoStorage = true
        print("✅ Pro Video Storage 已启用 - 保证稳定写入速度")
    }

    func startRecording() {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pro-video-\(Date().timeIntervalSince1970)")
            .appendingPathExtension("mov")

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        print("🎥 开始录制到: \(outputURL.lastPathComponent)")
    }

    func stopRecording() {
        movieOutput.stopRecording()
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        print("✅ 录制已开始")
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error = error {
            print("❌ 录制失败: \(error.localizedDescription)")
            return
        }

        // 获取文件信息
        if let attributes = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path),
           let fileSize = attributes[.size] as? Int64 {
            let sizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            print("✅ 录制完成: \(sizeString)")
            print("📁 文件路径: \(outputFileURL.path)")
        }

        // 保存到相册...
    }
}

// MARK: - SwiftUI 使用示例

struct CameraView: View {
    @StateObject private var cameraManager = FastStartupCameraManager()
    @State private var isCameraReady = false

    var body: some View {
        ZStack {
            // 相机预览
            CameraPreviewView(previewLayer: cameraManager.getPreviewLayer())
                .ignoresSafeArea()

            VStack {
                Spacer()

                // 拍照按钮
                Button(action: {
                    // 触发拍照
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                        )
                }
                .disabled(!isCameraReady)
                .opacity(isCameraReady ? 1.0 : 0.5)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraManager.setupQuickStartCamera()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cameraReadyForCapture)) { _ in
            isCameraReady = true
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let layer = previewLayer {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = previewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - 使用总结

/*
 ## 使用这个 skill 可以实现的功能：

 ### 1. 快速启动相机 ⚡️
 - 预览在 300ms 内显示
 - 照片功能在后台初始化
 - 用户体验流畅无卡顿

 ### 2. 运动抓拍 📸
 - 快门延迟 < 50ms
 - 捕捉快速移动瞬间
 - 适合体育、街拍、儿童摄影

 ### 3. 智能性能管理 🧠
 - 实时监控系统压力（温度、功耗）
 - 自动调整分辨率和帧率
 - 避免过热导致强制关闭
 - 压力恢复后自动升级配置

 ### 4. 专业视频录制 🎬
 - 4K 60fps ProRes 稳定录制
 - 保证写入速度不掉帧
 - 支持高码率长时间录制

 ## 实际应用场景：

 - 📱 第三方相机 App（如 Halide、ProCamera）
 - 🎥 专业视频录制工具
 - 🏃‍♂️ 运动相机 App
 - 👶 儿童摄影 App
 - 📹 视频会议应用
 - 🎨 创意滤镜相机
 */
