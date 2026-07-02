# Center Stage Front Camera — iPhone 17+ 前置摄像头完整指南

> **适用范围：** iPhone 17 / iPhone Air / iPhone 17 Pro  
> **来源：** WWDC 2026 Session 341  
> **iOS 版本：** iOS 26+
> 
> 本文档涵盖 Center Stage 前置摄像头的方形传感器、动态宽高比、智能构图、视频通话自动居中等功能。

---

## 目录

1. [硬件特性](#硬件特性)
2. [照片拍摄](#照片拍摄)
3. [Dynamic Aspect Ratio（动态宽高比）](#dynamic-aspect-ratio动态宽高比)
4. [Smart Framing Monitor（智能构图监控）](#smart-framing-monitor智能构图监控)
5. [Sensor Orientation Compensation（传感器方向补偿）](#sensor-orientation-compensation传感器方向补偿)
6. [视频录制](#视频录制)
7. [视频通话](#视频通话)
8. [完整示例](#完整示例)

---

## 硬件特性

### 传统前置 vs Center Stage

| 特性 | 传统前置摄像头 | Center Stage 前置 |
|------|----------------|-------------------|
| 传感器形状 | 4:3 矩形 | **1:1 方形** |
| 视场角 | ~78° | **95°**（iPhone 史上最宽）|
| 传感器方向 | Landscape Left | **Portrait**（竖向安装）|
| 动态宽高比 | ❌ | ✅ |
| 智能构图 | ❌ | ✅ |

### 方形传感器的优势

**无需旋转手机即可切换横竖构图：**
- 拍竖向自拍：保持竖握，单手更稳
- 拍横向自拍：无需翻转手机，保持自然视线
- **眼神接触更自然**：摄像头位于中心位置

**95° 超广角视场：**
- 群组自拍自动包含所有人
- 视频通话自动调整画面
- 视频录制更稳定

---

## 照片拍摄

### 基础会话配置

```swift
import AVFoundation

let session = AVCaptureSession()

// 1. 查找 Center Stage 前置摄像头（API 中表示为 .builtInUltraWideCamera）
let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
    deviceTypes: [.builtInUltraWideCamera],
    mediaType: .video,
    position: .front
)

guard let camera = deviceDiscoverySession.devices.first else {
    print("未找到 Center Stage 摄像头")
    return
}

// 2. 创建输入
let input = try AVCaptureDeviceInput(device: camera)
session.addInput(input)

// 3. 添加预览层
let previewLayer = AVCaptureVideoPreviewLayer(session: session)
view.layer.addSublayer(previewLayer)

// 4. 添加照片输出
let photoOutput = AVCapturePhotoOutput()
session.addOutput(photoOutput)
```

---

## Dynamic Aspect Ratio（动态宽高比）

### 核心概念

**传统问题：** 切换横竖构图需要重建整个 capture session（耗时 + 卡顿）  
**iOS 26 解决方案：** `dynamicAspectRatio` 属性 → 无缝切换，无需重建

### 支持的格式与宽高比

| 分辨率 | 支持的宽高比 |
|--------|-------------|
| 1280x1280 | 3:4, 4:3, 9:16, 16:9, 1:1 |
| 2560x2560 | 3:4, 4:3, 9:16, 16:9, 1:1 |
| 3200x3200 | 3:4, 4:3, 9:16, 16:9, 1:1 |
| 4032x4032 | **仅 3:4, 4:3**（最高分辨率照片）|

**⚠️ 限制：**
- 必须使用**方形格式**（如 1280x1280）
- 必须使用 `.builtInUltraWideCamera`（前置）
- 4032 格式仅支持 3:4/4:3（为照片保留最高分辨率）

### 实现：点按旋转按钮

```swift
// 选择支持 4:3 的格式
for format in camera.formats {
    if format.supportedDynamicAspectRatios.contains(.ratio4x3) {
        try camera.lockForConfiguration()
        camera.activeFormat = format
        camera.unlockForConfiguration()
        break
    }
}

// 切换到 4:3（横向）
try camera.lockForConfiguration()

let timestamp = try await camera.setDynamicAspectRatio(.ratio4x3)
print("✅ 宽高比已切换，生效时间戳: \(timestamp)")

camera.unlockForConfiguration()
```

**关键点：**
- `setDynamicAspectRatio(_:)` 返回**第一个生效帧的时间戳**
- 无需 `session.beginConfiguration()` / `commitConfiguration()`
- 切换**无缝**，预览不中断

### 可用的宽高比枚举

```swift
enum AVCaptureDevice.AspectRatio {
    case ratio3x4   // 竖向（传统竖屏照片）
    case ratio4x3   // 横向（传统横屏照片）
    case ratio9x16  // 竖向（手机竖屏视频）
    case ratio16x9  // 横向（宽屏视频）
    case ratio1x1   // 方形（Instagram 风格）
}
```

---

## Smart Framing Monitor（智能构图监控）

### 核心功能

**Auto Zoom & Auto Rotate：** 基于人脸和视线检测自动调整构图

- 单人自拍 → 窄视角
- 两人进入 → 自动 zoom out
- 更多人进入 → 自动旋转到横向 + zoom out

### 完整代码示例

```swift
import AVFoundation

// 1. 选择支持 Smart Framing 的格式
for format in camera.formats {
    if format.isSmartFramingSupported {
        try camera.lockForConfiguration()
        camera.activeFormat = format
        camera.unlockForConfiguration()
        break
    }
}

// 2. 配置监控器
let monitor = camera.smartFramingMonitor!

try camera.lockForConfiguration()
// 启用所有支持的构图组合
monitor.enabledFramings = monitor.supportedFramings
camera.unlockForConfiguration()

// 3. 观察推荐
var observation: NSKeyValueObservation?
observation = monitor.observe(\.recommendedFraming, options: [.new]) { monitor, change in
    guard let framing = monitor.recommendedFraming else { return }
    
    Task {
        try camera.lockForConfiguration()
        
        // 先设置宽高比，再设置变焦（顺序很重要，确保平滑过渡）
        try await camera.setDynamicAspectRatio(framing.aspectRatio)
        camera.videoZoomFactor = CGFloat(framing.zoomFactor)
        
        camera.unlockForConfiguration()
    }
}

// 4. 启动监控
try monitor.startMonitoring()

// 5. 停止监控（用户关闭自动构图时）
observation?.invalidate()
observation = nil
monitor.stopMonitoring()
```

### 使用限制

| 条件 | 要求 |
|------|------|
| 格式 | **仅 4032x4032**（最高分辨率照片格式）|
| 用途 | 照片拍摄（不适用于视频录制）|
| 推荐内容 | `aspectRatio` + `zoomFactor` |

**为什么只支持 4032？**  
智能构图专为照片设计，4032 是最高分辨率的照片格式。

---

## Sensor Orientation Compensation（传感器方向补偿）

### 问题背景

**传统前置摄像头：**
- 传感器安装方向：Landscape Left（横向）
- 竖屏拍照 → 照片带 EXIF Orientation = 270° 旋转标记

**Center Stage 前置：**
- 传感器安装方向：**Portrait**（竖向）
- 如果使用旧的旋转逻辑 → 照片会侧向或倒置

### iOS 26 自动补偿

`AVCapturePhotoOutput` **默认启用**传感器方向补偿：

1. **物理旋转照片像素**
2. **更新 EXIF metadata**
3. **输出的照片保持 Landscape Left 方向**（与旧前置一致）

**结果：** 你的旧代码**无需修改**，照片方向正确。

### 控制补偿行为

```swift
let photoOutput = AVCapturePhotoOutput()

// 默认：启用补偿
photoOutput.cameraSensorOrientationCompensationEnabled = true

// 性能优化：关闭补偿（自己处理旋转）
photoOutput.cameraSensorOrientationCompensationEnabled = false
```

**⚠️ 补偿范围：**
- ✅ HEIC, JPEG, 未压缩处理照片
- ❌ Bayer RAW, Apple ProRAW（永不补偿）

**最佳实践：**
1. 测试关闭补偿（性能更好）
2. 确保你的 App 正确处理照片旋转
3. 参考 [WWDC 2023 — Support external cameras in your iPadOS app](https://developer.apple.com/videos/play/wwdc2023/10106) 了解 `AVCaptureRotationCoordinator`

---

## 视频录制

### 使用 Dynamic Aspect Ratio

```swift
let session = AVCaptureSession()
let camera = // ... 获取 Center Stage 前置摄像头
let input = try AVCaptureDeviceInput(device: camera)
session.addInput(input)

// 使用 Movie File Output
let movieOutput = AVCaptureMovieFileOutput()
session.addOutput(movieOutput)

session.startRunning()
movieOutput.startRecording(to: outputURL, recordingDelegate: self)
```

**⚠️ 限制：** QuickTime 轨道要求所有帧尺寸一致

**如果录制中切换宽高比：**
- 使用 `AVCaptureMovieFileOutput` → **自动停止录制**
- 使用 `AVCaptureVideoDataOutput` + `AVAssetWriter` → 手动处理
  - `setDynamicAspectRatio(_:)` 返回的时间戳
  - 结束当前录制，开启新录制

### 电影稳定模式

Center Stage 前置支持**人脸感知**的电影稳定：

```swift
connection.preferredVideoStabilizationMode = .cinematicExtended
// 或
connection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced
```

**特点：** 优先稳定主体（人脸），而非背景。

---

## 视频通话

### 自动支持（VoIP 模式）

如果你的 App 使用 **Voice over IP background mode**：
- Center Stage **已自动启用**
- 用户通过**控制中心 → 视频效果**开关

无需代码改动。

### 手动启用（非 VoIP 模式）

```swift
// 1. 选择支持 Center Stage 的格式
for format in camera.formats {
    if format.isCenterStageSupported {
        try camera.lockForConfiguration()
        camera.activeFormat = format
        camera.unlockForConfiguration()
        break
    }
}

// 2. 设置控制模式
AVCaptureDevice.centerStageControlMode = .cooperative  // 或 .app
// .cooperative: 用户可通过控制中心 + App UI 控制
// .app: 仅通过 App 控制

// 3. 启用 Center Stage
AVCaptureDevice.isCenterStageEnabled = true
```

**效果：** 画面自动调整，保持所有人居中。

### 低延迟稳定（iOS 26 新增）

```swift
let connection = videoDataOutput.connection(with: .video)
connection?.preferredVideoStabilizationMode = .lowLatency
```

**对比：**

| 模式 | 延迟 | 稳定效果 | 适用场景 |
|------|------|----------|----------|
| `.off` | 0ms | 无 | 无抖动场景 |
| `.lowLatency` | 低 | 中等 | 实时视频通话 |
| `.cinematicExtended` | 中 | 强 | 视频录制 |

**推荐：** 视频通话使用 `.lowLatency`（显著减少抖动，几乎无延迟）。

---

## 完整示例

### 自拍 App with Smart Framing

```swift
import AVFoundation
import Combine

class CenterStageCameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var camera: AVCaptureDevice?
    private var smartFramingObservation: NSKeyValueObservation?
    
    func setupCamera() {
        // 1. 查找 Center Stage 前置
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera],
            mediaType: .video,
            position: .front
        )
        
        guard let camera = discovery.devices.first else {
            print("❌ 未找到 Center Stage 摄像头")
            return
        }
        self.camera = camera
        
        // 2. 配置会话
        captureSession.beginConfiguration()
        
        guard let input = try? AVCaptureDeviceInput(device: camera) else { return }
        captureSession.addInput(input)
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        captureSession.commitConfiguration()
        
        // 3. 设置 4032 格式 + Smart Framing
        setupSmartFraming(for: camera)
        
        // 4. 启动
        captureSession.startRunning()
    }
    
    private func setupSmartFraming(for camera: AVCaptureDevice) {
        // 找到支持 Smart Framing 的 4032 格式
        for format in camera.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if dimensions.width == 4032 && format.isSmartFramingSupported {
                try? camera.lockForConfiguration()
                camera.activeFormat = format
                camera.unlockForConfiguration()
                break
            }
        }
        
        // 配置监控器
        guard let monitor = camera.smartFramingMonitor else { return }
        
        try? camera.lockForConfiguration()
        monitor.enabledFramings = monitor.supportedFramings
        camera.unlockForConfiguration()
        
        // 观察推荐
        smartFramingObservation = monitor.observe(\.recommendedFraming, options: [.new]) { [weak self] monitor, _ in
            guard let self = self,
                  let camera = self.camera,
                  let framing = monitor.recommendedFraming else { return }
            
            Task {
                try? camera.lockForConfiguration()
                try? await camera.setDynamicAspectRatio(framing.aspectRatio)
                camera.videoZoomFactor = CGFloat(framing.zoomFactor)
                camera.unlockForConfiguration()
                
                print("📐 自动调整: \(framing.aspectRatio), zoom: \(framing.zoomFactor)")
            }
        }
        
        try? monitor.startMonitoring()
        print("✅ Smart Framing 已启动")
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CenterStageCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation() else {
            print("❌ 照片拍摄失败")
            return
        }
        
        print("✅ 照片已拍摄: \(imageData.count) bytes")
        // 保存到相册...
    }
}
```

---

## 关键要点总结

### 硬件特性
- **方形传感器 + 95° 视场角** = 最灵活的自拍体验
- **Portrait 传感器方向** = 需要 iOS 26 自动补偿

### Dynamic Aspect Ratio
- **无缝切换 5 种宽高比**，无需重建 session
- **4032 格式仅支持 3:4/4:3**（最高照片分辨率）

### Smart Framing Monitor
- **仅 4032 格式** + 照片拍摄
- 自动推荐 `aspectRatio` + `zoomFactor`
- 基于人脸 + 视线检测

### 视频通话
- VoIP 模式 → 自动支持
- 非 VoIP → 手动启用 `isCenterStageEnabled`
- **低延迟稳定模式** = 实时通话必备

---

## 参考资料

- [WWDC 2026 Session 341 — Support the Center Stage front camera in your iOS app](https://developer.apple.com/videos/play/wwdc2026/341/)
- [WWDC 2023 — Support external cameras in your iPadOS app](https://developer.apple.com/videos/play/wwdc2023/10106)
- [WWDC 2021 — What's new in camera capture](https://developer.apple.com/videos/play/wwdc2021/10047)
- [AVCaptureDevice — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice)

---

## 关键词索引

`Center Stage`, `builtInUltraWideCamera`, `dynamicAspectRatio`, `setDynamicAspectRatio`, `supportedDynamicAspectRatios`, `AVCaptureSmartFramingMonitor`, `recommendedFraming`, `enabledFramings`, `supportedFramings`, `isSmartFramingSupported`, `cameraSensorOrientationCompensationEnabled`, `isCenterStageEnabled`, `centerStageControlMode`, `isCenterStageSupported`, `preferredVideoStabilizationMode`, `lowLatency`, `方形传感器`, `自拍`, `群组照片`, `视频通话`, `自动构图`, `Auto Zoom`, `Auto Rotate`, `iPhone 17`, `iPhone Air`, `前置摄像头`
