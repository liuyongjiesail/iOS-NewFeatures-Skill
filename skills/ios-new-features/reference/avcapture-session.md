# AVCaptureSession — iOS 26+ 相机性能优化新特性

> **适用范围：** iOS 26+
> **来源：** WWDC 2026 Session 303
> 
> 本文档涵盖 AVCaptureSession 的启动优化、响应式拍摄、系统压力监控和专业视频存储功能。

---

## 目录

1. [Deferred Start（延迟启动）](#deferred-start延迟启动)
   - [自动模式](#自动模式)
   - [手动模式](#手动模式)
2. [Responsive Capture（响应式拍摄）](#responsive-capture响应式拍摄)
3. [System Pressure（系统压力监控）](#system-pressure系统压力监控)
4. [Pro Video Storage（专业视频存储）](#pro-video-storage专业视频存储)

---

## Deferred Start（延迟启动）

**核心目标：** 优化相机启动时间，优先显示预览画面，延后非关键输出的启动。

**使用场景：**
- 相机 App 启动时快速显示预览
- 视频通话需要先展示画面，录制功能稍后启动
- 复杂相机配置（多路出）的启动优化

---

### 自动模式

系统自动管理延迟启动的时机，适合大多数场景。

#### Deferred Start Delegate

```swift
import AVFoundation

class DeferredStartDelegate: NSObject, AVCaptureSessionDeferredStartDelegate {
    func sessionWillRunDeferredStart(_ session: AVCaptureSession) {
        // 延迟启动即将开始（在延迟输出启动前调用）
        print("Deferred start will begin")
    }

    func sessionDidRunDeferredStart(_ session: AVCaptureSession) {
        // 所有延迟输出已完成启动
        print("Deferred start completed")
    }
}
```

#### 启用自动延迟启动

```swift
import AVFoundation

let captureSession = AVCaptureSession()
captureSession.beginConfiguration()

// 开启自动延迟启动
captureSession.automaticallyRunsDeferredStart = true

// 配置预览层：不延迟（优先显示）
let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
videoPreviewLayer.isDeferredStartEnabled = false

// 配置照片输出：延迟启动
let photoOutput = AVCapturePhotoOutput()
photoOutput.isDeferredStartEnabled = true
captureSession.addOutput(photoOutput)

// 设置代理
captureSession.setDeferredStartDelegate(deferredStartDelegate, 
                                       deferredStartDelegateCallbackQueue: sessionQueue)

captureSession.commitConfiguration()
captureSession.startRunning()
```

**关键属性：**
- `captureSession.automaticallyRunsDeferredStart: Bool` — 是否自动管理延迟启动
- `output.isDeferredStartEnabled: Bool` — 该输出是否参与延迟启动
- `layer.isDeferredStartEnabled: Bool` — 预览层是否参与延迟启动

**工作流程：**
1. `startRunning()` 被调用
2. 非延迟输出（预览层）立即启动 → 用户快速看到画面
3. 系统自动在合适时机调用 `sessionWillRunDeferredStart(_:)`
4. 延迟输出开始启动
5. 完成后调用 `sessionDidRunDeferredStart(_:)`

---

### 手动模式

开发者精确控制延迟启动的时机，适合复杂 UI 同步场景。

#### 配置手动延迟启动

```swift
import AVFoundation

let captureSession = AVCaptureSession()
captureSession.beginConfiguration()

// 关闭自动延迟启动
captureSession.automaticallyRunsDeferredStart = false

// 视频输出：不延迟
let videoOutput = AVCaptureVideoDataOutput()
captureSession.addOutput(videoOutput)
videoOutput.isDeferredStartEnabled = false

// 照片输出：延迟
let photoOutput = AVCapturePhotoOutput()
photoOutput.isDeferredStartEnabled = true
captureSession.addOutput(photoOutput)

captureSession.setDeferredStartDelegate(deferredStartDelegate, 
                                       deferredStartDelegateCallbackQueue: sessionQueue)

captureSession.commitConfiguration()
captureSession.startRunning()

// 注意：此时延迟输出不会自动启动，需要手动调用 runDeferredStartWhenNeeded()
```

#### 手动触发延迟启动

典型场景：在第一帧画面渲染完成后再启动照片输出。

```swift
import AVFoundation
import QuartzCore

private var firstFramePresented = false

guard let drawable = layer.nextDrawable()
if (!firstFramePresented) {
    drawable.addPresentedHandler({ drawable in
        // 第一帧已呈现给用户，现在可以启动延迟输出
        // 此时可以同步设置其他 UI 元素（拍照按钮、设置面板等）
        captureSession.runDeferredStartWhenNeeded()
    })
    firstFramePresented = true
}
```

**关键方法：**
- `captureSession.runDeferredStartWhenNeeded()` — 手动触发延迟启动
  - 如果延迟输出已经启动，调用无效（幂等）
  - 建议在首帧呈现后调用，确保用户体验流畅

---

### 延迟启动最佳实践

| 场景 | 模式选择 | 配置建议 |
|------|----------|----------|
| 普通相机 App | 自动模式 | 预览层不延迟，照片/视频输出延迟 |
| 视频通话 | 自动模式 | 预览不延迟，录制输出延迟 |
| 自定义渲染管线 | 手动模式 | 在首帧渲染完成后调用 `runDeferredStartWhenNeeded()` |
| 多输出复杂场景 | 手动模式 | 根据 UI 就绪状态精确控制 |

**注意事项：**
- 至少有一个输出/预览层设置为不延迟，否则无法快速显示画面
- 延迟启动不影响功能，只是延后时机
- 代理回调在指定的 `callbackQueue` 上执行，注意线程安全

---

## Responsive Capture（响应式拍摄）

**核心目标：** 在用户按下快门按钮时立即捕获，无需等待自动对焦/曝光稳定。

**解决的问题：**
- 传统模式下，`capturePhoto(with:delegate:)` 会等待 AF/AE 锁定后才拍摄，可能延迟数百毫秒
- 抓拍快速移动物体时，延迟导致错失瞬间

**适用场景：**
- 运动摄影
- 街拍抓拍
- 儿童/宠物拍摄
- 需要「所见即所得」的即时拍摄体验

---

### 启用响应式拍摄

```swift
import AVFoundation

func configurePhotoOutput(for session: AVCaptureSession, device: AVCaptureDevice) {
    let photoOutput = AVCapturePhotoOutput()

    guard session.canAddOutput(photoOutput) else { return }
    session.addOutput(photoOutput)

    // 设置最高画质优先级
    photoOutput.maxPhotoQualityPrioritization = .quality
    
    // 启用响应式拍摄（如果设备支持）
    photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
}
```

**关键属性：**
- `photoOutput.isResponsiveCaptureSupported: Bool` — 当前设备和配置是否支持
- `photoOutput.isResponsiveCaptureEnabled: Bool` — 是否启用响应式拍摄

---

### 工作原理

**传统拍摄流程：**
```
用户按下快门 → 等待 AF/AE 稳定 → 捕获画面 → 返回照片
                  ↑ 延迟 200-500ms
```

**响应式拍摄流程：**
```
用户按下快门 → 立即捕获当前帧 → 后处理优化（AF/AE 信息回溯应用） → 返回照片
                  ↑ 延迟 < 50ms
```

---

### 使用限制

响应式拍摄在以下配置下**不可用**（`isResponsiveCaptureSupported` 返回 `false`）：
- `maxPhotoQualityPrioritization` 设为 `.speed`（低画质模式）
- 使用 ProRAW 格式
- 启用零快门延迟（Zero Shutter Lag）
- 部分旧设备不支持

**检测支持性：**
```swift
if photoOutput.isResponsiveCaptureSupported {
    photoOutput.isResponsiveCaptureEnabled = true
} else {
    print("当前配置不支持响应式拍摄")
}
```

---

### 与其他功能的配合

| 功能 | 兼容性 | 说明 |
|------|--------|------|
| Live Photo | ✅ 兼容 | 可同时启用 |
| 闪光灯 | ✅ 兼容 | 系统自动处理时机 |
| HDR | ✅ 兼容 | 后处理阶段应用 |
| ProRAW | ❌ 不兼容 | 需禁用响应式拍摄 |
| 人像模式 | ✅ 兼容 | 深度信息在后处理阶段处理 |

---

## System Pressure（系统压力监控）

**核心目标：** 实时监控相机系统的资源压力，避免热量、性能、电量问题导致的强制降级。

**压力来源：**
- CPU/GPU 过载
- 热量积累（Thermal Throttling）
- 多路高分辨率输出
- 复杂图像处理管线

---

### 监控系统压力

```swift
import AVFoundation

let captureSession = AVCaptureSession()
let device = activeVideoInput?.device
captureSession.beginConfiguration()
// 配置输入输出...
captureSession.commitConfiguration()

// 启动前检查硬件成本
guard captureSession.hardwareCost <= 1.0 else {
    print("hardwareCost \(captureSession.hardwareCost) — 配置超出硬件能力，无法启动")
    setupLowCostConfiguration()  // 降级到低成本配置
    return
}

captureSession.startRunning()

// 运行时监控系统压力状态
let systemPressureObserver = device?.observe(\.systemPressureState,
                                               options: [.initial, .new],
                                               changeHandler: { device, change in
    handleSystemPressureChange(device.systemPressureState)
})
```

---

### 关键指标

#### hardwareCost

表示当前配置相对于设备性能的资源占用比率。

**取值范围：**
- `<= 1.0` — 可以正常运行
- `> 1.0` — 超出硬件能力，**无法启动**，必须降级配置

**影响因素：**
- 分辨率（4K vs 1080p）
- 帧率（60fps vs 30fps）
- 输出路数（同时录制+预览+照片）
- 图像处理（深度、语义分割）

**降级策略示例：**
```swift
func setupLowCostConfiguration() {
    captureSession.beginConfiguration()
    
    // 降低分辨率
    if captureSession.canSetSessionPreset(.high) {
        captureSession.sessionPreset = .high  // 从 4K 降到 1080p
    }
    
    // 降低帧率
    if let device = activeDevice {
        try? device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)  // 30fps
        device.unlockForConfiguration()
    }
    
    captureSession.commitConfiguration()
}
```

---

#### systemPressureState

运行时系统压力的实时状态。

**AVCaptureDevice.SystemPressureState 属性：**
- `level: SystemPressureLevel` — 压力等级
  - `.nominal` — 正常
  - `.fair` — 轻度压力
  - `.serious` — 严重压力
  - `.critical` — 极限压力（即将强制关闭）
  - `.shutdown` — 系统强制关闭
  
- `factors: SystemPressureFactors` — 压力来源（可组合）
  - `.systemTemperature` — 热量
  - `.peakPower` — 峰值功耗
  - `.depthModuleTemperature` — 深度模块过热

**响应策略：**
```swift
func handleSystemPressureChange(_ state: AVCaptureDevice.SystemPressureState) {
    switch state.level {
    case .nominal:
        // 恢复正常配置
        enableAllFeatures()
        
    case .fair:
        // 关闭非关键功能
        disableNonEssentialFeatures()
        
    case .serious:
        // 大幅降级
        if state.factors.contains(.systemTemperature) {
            reduceFrameRate()
            disableDepthOutput()
        }
        
    case .critical:
        // 准备关闭
        showWarningToUser()
        gracefulShutdown()
        
    case .shutdown:
        // 系统已强制关闭
        handleForcedShutdown()
        
    @unknown default:
        break
    }
}
```

---

### 最佳实践

| 阶段 | 检查内容 | 处理方式 |
|------|----------|----------|
| 配置阶段 | `hardwareCost` | 超过 1.0 时提前降级配置 |
| 运行阶段 | `systemPressureState.level` | 动态调整帧率、分辨率、功能开关 |
| 压力来源 | `systemPressureState.factors` | 针对性优化（热量→降帧率，功耗→关闭深度） |

**KVO 注意事项：**
- 使用 `[.initial, .new]` 选项立即获取初始状态
- 在 `changeHandler` 中避免耗时操作
- 保持对 observer 的强引用，否则监听失效

---

## Pro Video Storage（专业视频存储）

**核心目标：** 为高码率专业视频录制提供确定性写入速度保障。

**解决的问题：**
- 普通文件系统写入速度不稳定，可能导致掉帧或录制中断
- 4K 60fps ProRes 等高码率格式对存储带宽要求极高
- 后台任务、其他 App 的 I/O 竞争影响录制稳定性

**适用场景：**
- 专业视频录制 App（ProRes、Log 格式）
- 高帧率长时间录制
- 需要稳定写入速度的场景

---

### 检查支持性

```swift
import AVFoundation

func configureProVideoStorage() {
    // 检查设备是否支持
    guard AVProVideoStorage.isSupported else { 
        print("当前设备不支持 Pro Video Storage")
        return 
    }
    
    let storage = AVProVideoStorage.shared
    
    // 检查剩余容量
    guard storage.remainingCapacity != 0 else {
        // 容量不足，打开系统设置页面让用户分配空间
        storage.openSettings()
        return
    }
    
    print("Pro Video Storage 剩余容量: \(storage.remainingCapacity) bytes")
}
```

---

### 启用 Pro Video Storage

#### 使用 AVCaptureMovieFileOutput

```swift
import AVFoundation

guard AVProVideoStorage.isSupported else { return }
guard let pvs = AVProVideoStorage.shared else { return }

// 配置 AVCaptureSession、连接和格式...
let movieOutput = AVCaptureMovieFileOutput()

// 检查输出是否支持
guard movieOutput.isProVideoStorageSupported else { 
    print("当前配置不支持 Pro Video Storage")
    return 
}

// 检查存储是否空闲（同一时间只能有一个录制任务使用）
guard !pvs.isBusy else {
    print("Pro Video Storage 正忙，请稍后重试")
    return
}

let movieFileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("mov")

// 启用 Pro Video Storage
movieOutput.usesProVideoStorage = true

movieOutput.startRecording(to: movieFileURL, recordingDelegate: delegate)
```

---

#### 使用 AVAssetWriter

```swift
import AVFoundation

guard AVProVideoStorage.isSupported else { return }
guard let pvs = AVProVideoStorage.shared, !pvs.isBusy else { return }

let outputURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("mov")

let assetWriter = try AVAssetWriter(url: outputURL, fileType: .mov)

// 启用 Pro Video Storage
assetWriter.usesProVideoStorage = true

// 配置视频输入...
let videoInput = AVAssetWriterInput(
    mediaType: .video,
    outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.proRes422,
        AVVideoWidthKey: 3840,
        AVVideoHeightKey: 2160
    ]
)
assetWriter.add(videoInput)

assetWriter.startWriting()
```

---

### 关键属性

| 属性 | 说明 |
|------|------|
| `AVProVideoStorage.isSupported: Bool` | 当前设备是否支持（仅特定 Pro 机型） |
| `AVProVideoStorage.shared: AVProVideoStorage?` | 单例对象（不支持时返回 `nil`） |
| `remainingCapacity: Int64` | 剩余可用空间（字节），`0` 表示未分配或已满 |
| `isBusy: Bool` | 是否正在被其他录制任务占用 |
| `openSettings()` | 打开系统设置页面，让用户分配/调整 Pro Video Storage 空间 |
| `movieOutput.isProVideoStorageSupported: Bool` | 当前输出配置是否支持使用 Pro Video Storage |
| `movieOutput.usesProVideoStorage: Bool` | 是否启用 Pro Video Storage（录制前设置） |
| `assetWriter.usesProVideoStorage: Bool` | AVAssetWriter 是否启用 Pro Video Storage |

---

### 使用限制

**只能同时有一个录制任务使用 Pro Video Storage**
- 录制前检查 `isBusy`，如果为 `true` 需等待或提示用户
- 录制结束后资源自动释放

**容量管理**
- 用户需在系统设置中预先分配 Pro Video Storage 空间
- 空间不足时调用 `openSettings()` 引导用户
- 空间与普通存储隔离，不影响其他 App

**设备支持**
- 仅特定 Pro 机型支持（如 iPhone 16 Pro / Pro Max）
- 调用前务必检查 `isSupported`

---

### 最佳实践

```swift
func startProVideoRecording() {
    // 1. 检查设备支持
    guard AVProVideoStorage.isSupported else {
        fallbackToNormalStorage()
        return
    }
    
    // 2. 检查容量
    guard let pvs = AVProVideoStorage.shared,
          pvs.remainingCapacity > requiredSpace else {
        AVProVideoStorage.shared?.openSettings()
        return
    }
    
    // 3. 检查是否空闲
    guard !pvs.isBusy else {
        showBusyAlert()
        return
    }
    
    // 4. 检查输出支持
    guard movieOutput.isProVideoStorageSupported else {
        fallbackToNormalStorage()
        return
    }
    
    // 5. 启用并开始录制
    movieOutput.usesProVideoStorage = true
    movieOutput.startRecording(to: outputURL, recordingDelegate: self)
}
```

---

## 完整示例：综合应用

以下示例展示如何综合使用上述所有功能：

```swift
import AVFoundation
import Combine

class ProCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var device: AVCaptureDevice?
    private var systemPressureObserver: AnyCancellable?
    
    private let deferredStartDelegate = DeferredStartDelegate()
    
    func setupSession() {
        captureSession.beginConfiguration()
        
        // 配置输入设备
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                    for: .video, 
                                                    position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        device = camera
        captureSession.addInput(input)
        
        // 配置预览层（不延迟）
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.isDeferredStartEnabled = false
        
        // 配置照片输出（延迟 + 响应式拍摄）
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            photoOutput.isDeferredStartEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
        }
        
        // 配置视频输出（Pro Video Storage）
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            if AVProVideoStorage.isSupported,
               let pvs = AVProVideoStorage.shared,
               !pvs.isBusy,
               movieOutput.isProVideoStorageSupported {
                movieOutput.usesProVideoStorage = true
            }
        }
        
        // 启用自动延迟启动
        captureSession.automaticallyRunsDeferredStart = true
        captureSession.setDeferredStartDelegate(deferredStartDelegate, 
                                                deferredStartDelegateCallbackQueue: sessionQueue)
        
        captureSession.commitConfiguration()
        
        // 检查硬件成本
        guard captureSession.hardwareCost <= 1.0 else {
            print("配置超出硬件能力，降级中...")
            setupLowCostConfiguration()
            return
        }
        
        // 监控系统压力
        systemPressureObserver = device?.publisher(for: \.systemPressureState)
            .sink { [weak self] state in
                self?.handleSystemPressure(state)
            }
        
        // 启动
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func handleSystemPressure(_ state: AVCaptureDevice.SystemPressureState) {
        switch state.level {
        case .serious, .critical:
            // 降级处理
            reduceFrameRate()
        default:
            break
        }
    }
    
    private func setupLowCostConfiguration() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        captureSession.commitConfiguration()
    }
    
    private func reduceFrameRate() {
        guard let device = device else { return }
        try? device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.unlockForConfiguration()
    }
}

// Deferred Start Delegate
class DeferredStartDelegate: NSObject, AVCaptureSessionDeferredStartDelegate {
    func sessionWillRunDeferredStart(_ session: AVCaptureSession) {
        print("延迟输出即将启动")
    }
    
    func sessionDidRunDeferredStart(_ session: AVCaptureSession) {
        print("延迟输出启动完成")
    }
}
```

---

## 参考资料

- [WWDC 2026 Session 303 — What's new in AVFoundation camera features](https://developer.apple.com/videos/play/wwdc2026/303/)
- [AVCaptureSession — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession)
- [AVCapturePhotoOutput — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)
- [AVProVideoStorage — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avprovideostorage)

---

## 版本速查

| iOS 版本 | 新增功能 |
|----------|----------|
| iOS 26 | Deferred Start、Responsive Capture、Pro Video Storage、System Pressure API 增强 |

---

## 关键词索引

`AVCaptureSession`, `Deferred Start`, `automaticallyRunsDeferredStart`, `isDeferredStartEnabled`, `runDeferredStartWhenNeeded`, `AVCaptureSessionDeferredStartDelegate`, `Responsive Capture`, `isResponsiveCaptureEnabled`, `System Pressure`, `hardwareCost`, `systemPressureState`, `AVProVideoStorage`, `usesProVideoStorage`, `相机优化`, `启动时间`, `响应式拍摄`, `系统压力监控`, `专业视频存储`, `性能优化`
