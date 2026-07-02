# AVCapturePhotoOutput — iOS 26+ 高分辨率照片拍摄完整指南

> **适用范围：** iOS 16+ (基础 API) / iOS 26+ (新增优化)
> **来源：** WWDC 2026 Session 304
> 
> 本文档涵盖 12MP/24MP/48MP 高分辨率照片配置、画质优先级、延迟处理和连拍优化。

---

## 目录

1. [高分辨率照片类型](#高分辨率照片类型)
   - [12MP / 24MP / 48MP 对比](#12mp--24mp--48mp-对比)
   - [Photonic Engine 工作原理](#photonic-engine-工作原理)
2. [拍摄类型](#拍摄类型)
3. [配置拍摄会话](#配置拍摄会话)
4. [响应式拍摄最佳实践](#响应式拍摄最佳实践)
   - [重叠拍摄 (Overlapping Captures)](#重叠拍摄-overlapping-captures)
   - [延迟照片处理 (Deferred Photo Processing)](#延迟照片处理-deferred-photo-processing)
   - [快速拍摄优先 (Fast Capture Prioritization)](#快速拍摄优先-fast-capture-prioritization)

---

## 高分辨率照片类型

### 为什么需要高分辨率

**预览流：** 屏幕分辨率，仅适合实时显示  
**高分辨率：** 用于照片裁剪、放大细节、图像分析

### 12MP / 24MP / 48MP 对比

| 分辨率 | 适用机型 | 传感器模式 | 特点 |
|--------|----------|------------|------|
| **12MP** | 所有 iPhone | Quad Pixel 合并模式 | 多帧融合 HDR，低光性能最佳 |
| **24MP** | iPhone 15+ | Photonic Engine 融合 | 平衡细节与文件大小（+50% 体积，2x 分辨率） |
| **48MP** | iPhone 14 Pro+ | Quad Pixel 全分辨率 | 单帧捕获，最高细节，4x 分辨率 |

**支持的摄像头：**
- **Main (主摄)：** iPhone 14 Pro+ 支持 48MP
- **Telephoto (长焦)：** iPhone 16 Pro+ 支持 48MP
- **Ultra Wide (超广角)：** iPhone 17+ 支持 48MP
- **Front (前置 Center Stage)：** iPhone 17+ 支持 18MP

---

### Photonic Engine 工作原理

**24MP 照片生成流程：**

```
步骤 1: Quad Pixel 合并模式 → 12MP 多帧融合 HDR (高动态范围)
       ↓
步骤 2: 与 48MP 全分辨率单帧融合 → 提取细节
       ↓
步骤 3: Photonic Engine 计算成像 → 24MP 最终照片
```

**优势：**
- 兼顾光线（12MP HDR）和细节（48MP 单帧）
- 文件体积仅增加 50%，分辨率翻倍

---

## 拍摄类型

App 可请求 4 种高分辨率拍摄类型：

### 1. 完全处理照片 (Fully Processed Photo)

**最常见场景**，多帧融合 + Photonic Engine 处理。

```swift
let settings = AVCapturePhotoSettings()
// 使用默认处理管线
```

**输出：** HEIF / JPEG，HDR，自动降噪

---

### 2. 曝光包围 (Exposure Brackets)

多个不同曝光的帧，用于手动 HDR 合成或曝光选择。

```swift
let settings = AVCapturePhotoSettings()
settings.isAutoStillImageStabilizationEnabled = false
// 配置多曝光参数
```

**适用场景：** 需要手动控制 HDR 合成的专业 App

---

### 3. Bayer RAW

传感器原始数据，最小化处理。

```swift
let settings = AVCapturePhotoSettings(rawPixelFormatType: format)
settings.photoQualityPrioritization = .quality
```

**适用场景：** 后期编辑、完全自定义处理

---

### 4. Apple ProRAW

RAW + iPhone 图像处理（保留编辑灵活性）。

```swift
guard photoOutput.isAppleProRAWEnabled else { return }
let settings = AVCapturePhotoSettings(rawPixelFormatType: kCVPixelFormatType_14Bayer_GRBG)
settings.rawFileType = .dng
```

**适用场景：** 专业摄影 App，需要 RAW 灵活性 + iPhone 计算摄影

**参考：** [Capture and process ProRAW images (WWDC 2021)](https://developer.apple.com/videos/play/wwdc2021/10160)

---

## 配置拍摄会话

### 步骤 1: 创建会话并设置 Preset

**⚠️ 重要：** 只有 `.photo` preset 支持 24MP 和 48MP。

```swift
import AVFoundation

private let session = AVCaptureSession()
private func configureSession() {
    session.beginConfiguration()
    session.sessionPreset = .photo  // 必须使用 .photo
}
```

---

### 步骤 2: 选择画质优先级

| 优先级 | 处理时间 | 画质 | 适用场景 |
|--------|----------|------|----------|
| `.speed` | 最快 | 基础 | 快速抓拍、扫描 |
| `.balanced` | 中等 | 良好 | 日常拍摄 |
| `.quality` | 最慢 | 最佳 | 专业摄影、细节要求高 |

```swift
private let photoOutput = AVCapturePhotoOutput()
private func configurePhotoOutput() {
    // 设置输出的最大画质优先级
    photoOutput.maxPhotoQualityPrioritization = .quality
}
```

**注意：** `maxPhotoQualityPrioritization` 告诉系统为**所有三个级别**预分配资源。

---

### 步骤 3: 选择最大照片尺寸

```swift
let supportedMaxPhotoDimensions = device?.activeFormat.supportedMaxPhotoDimensions ?? []
if let largestDimension = supportedMaxPhotoDimensions.max(by: { lhs, rhs in
    Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
}) {
    photoOutput.maxPhotoDimensions = largestDimension
}

session.commitConfiguration()
session.startRunning()
```

**⚠️ 最佳实践：**
- 在 `commitConfiguration()` **之前**完成所有配置
- 提交后修改这些设置会触发耗时的管线重新配置

---

### 步骤 4: 拍摄时设置参数

```swift
let settings = AVCapturePhotoSettings()
settings.maxPhotoDimensions = dimension.cmVideoDimensionsValue
settings.photoQualityPrioritization = .quality

var delegate: AVCapturePhotoCaptureDelegate?
// 配置代理...

if let delegate {
    photoOutput.capturePhoto(with: settings, delegate: delegate)
}
```

**关键点：**
- `maxPhotoDimensions` 是**请求**，不是保证
- 实际尺寸在 `AVCaptureResolvedSettings` 中返回
- 可以在每次拍摄时动态调整画质和尺寸

---

### 步骤 5: 预分配资源 (可选但推荐)

**问题：** 如果资源未预分配，拍摄时才分配 → 延迟增加

**解决：** 使用 `setPreparedPhotoSettingsArray` 提前准备。

```swift
let prepareSettings = AVCapturePhotoSettings()
prepareSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
prepareSettings.photoQualityPrioritization = .quality

photoOutput.setPreparedPhotoSettingsArray([prepareSettings]) { prepared, error in
    if let error = error {
        print("Failed to prepare: \(error)")
        return
    }
    print("Pipeline prepared: \(prepared)")
}

// 稍后拍摄时，创建新的 settings 对象（不能重用 prepareSettings）
let captureSettings = AVCapturePhotoSettings()
captureSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
captureSettings.photoQualityPrioritization = .quality
photoOutput.capturePhoto(with: captureSettings, delegate: self)
```

**⚠️ 注意：** 不能重用 `prepareSettings` 对象进行拍摄，必须创建新的。

---

## 响应式拍摄最佳实践

高分辨率照片处理耗时数秒，以下 3 个技术确保 App 保持响应：

### 画质优先级 vs 分辨率支持矩阵

| 分辨率 | Speed | Balanced | Quality | 说明 |
|--------|-------|----------|---------|------|
| 12MP | ✅ | ✅ | ✅ | 所有优先级支持 |
| 48MP | ❌ | ✅ | ✅ | 单帧，需 Balanced 或 Quality |
| 24MP | ❌ | ❌ | ✅ | 多帧融合，仅 Quality |
| 18MP | ❌ | ❌ | ✅ | 多帧融合，仅 Quality (iPhone 17 前置) |

**18MP 说明：** 仅 iPhone 17 Center Stage 前置摄像头支持。参考 [Support Center Stage front camera (WWDC 2026)](https://developer.apple.com/videos/play/wwdc2026/341)

---

### 拍摄流程与代理回调

```
用户按快门
    ↓
捕获阶段 (Capture) → didCapturePhotoFor resolvedSettings
    ↓
处理阶段 (Processing) → 多帧融合、Photonic Engine
    ↓
完成 → didFinishProcessingPhoto
    ↓
didFinishCaptureFor resolvedSettings
```

**处理时间查询：**
```swift
let timeRange = resolvedSettings.photoProcessingTimeRange
// 返回预期处理时间范围
```

---

### Shot-to-Shot Delay (连拍延迟)

**传统模式：** 下一张必须等上一张**处理完成**

```
照片 1: [捕获] → [处理 3s] ← 阻塞
照片 2:                     [捕获] → [处理 3s]
                            ↑
                      延迟 3 秒才能拍
```

---

### 重叠拍摄 (Overlapping Captures)

**启用 Responsive Capture：** 下一张只需等上一张**捕获完成**

```swift
photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
```

**工作流程：**
```
照片 1: [捕获] → [处理 3s]
照片 2:    ↑
          [捕获] → [处理 3s]
          ↑
    捕获完成即可拍下一张
```

**监控可拍摄状态：**
```swift
// 观察 captureReadiness 属性
photoOutput.publisher(for: \.captureReadiness)
    .sink { readiness in
        updateShutterButton(enabled: readiness == .ready)
    }
```

**效果：** 第二张的 shot-to-shot delay 显著降低

---

### 延迟照片处理 (Deferred Photo Processing)

**核心思想：** 先返回轻量代理照片，完整处理延后进行。

#### 工作流程

```
拍摄请求
    ↓
捕获阶段 (快速)
    ↓
返回代理照片 (Proxy) → didFinishCapturingDeferredPhotoProxy
    ↓
用户可继续拍摄 ← 不阻塞
    ↓
完整处理 (后台):
  - 按需处理 (用户从相册打开时)
  - 自动处理 (设备空闲时)
```

#### 代码示例

```swift
let settings = AVCapturePhotoSettings()
settings.photoQualityPrioritization = .quality
settings.maxPhotoDimensions = largestDimension

// 启用延迟处理
settings.isDeferredPhotoDeliveryEnabled = true

photoOutput.capturePhoto(with: settings, delegate: self)
```

**代理回调：**
```swift
extension CameraManager: AVCapturePhotoCaptureDelegate {
    // 接收代理照片 (立即返回)
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?,
                     error: Error?) {
        // 显示给用户，允许继续拍摄
    }
    
    // 最终照片处理完成 (稍后)
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        // 替换为最终版本
    }
}
```

**延迟处理的优势：**
- Shot-to-shot delay 大幅缩短
- 处理阶段不与捕获会话共享内存
- 使 18MP/24MP 多帧融合成为可能

**参考：** [Create a More Responsive Camera Experience (WWDC 2023)](https://developer.apple.com/videos/play/wwdc2023/10105)

---

### 快速拍摄优先 (Fast Capture Prioritization)

**场景：** 用户连续快速拍摄多张照片

**系统行为：** 检测到连拍 → 自动从 `quality` 降级到 `balanced`

#### 启用

```swift
photoOutput.isFastCapturePrioritizationEnabled = true
```

#### 工作原理

```
照片 1: Quality [捕获 500ms] → [处理 3s]
照片 2: Quality [捕获 500ms] → [处理 3s]  ← 检测到连拍
照片 3: Balanced [捕获 300ms] → [处理 1.5s] ← 自动降级
照片 4: Balanced [捕获 300ms] → [处理 1.5s]
照片 5: Balanced [捕获 300ms] → [处理 1.5s]
```

**iOS 27+ 增强 (iPhone 16/17)：**
- Balanced 快速拍摄**也使用延迟处理**
- 进一步减少 shot-to-shot delay

---

### 三种技术综合对比

| 技术 | 减少的延迟 | 适用场景 | iOS 版本 |
|------|------------|----------|----------|
| Responsive Capture (重叠拍摄) | 中等 | 所有高分辨率拍摄 | iOS 26+ |
| Deferred Processing (延迟处理) | 显著 | Quality 优先级 | iOS 26+ |
| Fast Capture Prioritization (连拍优先) | 最大 | 连续快速拍摄 | iOS 26+ |

**推荐组合：** 三者同时启用，系统自动选择最佳策略。

---

## 完整示例：综合应用

```swift
import AVFoundation
import Combine

class HighResPhotoManager: NSObject, AVCapturePhotoCaptureDelegate {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.example.photo.session")
    private var device: AVCaptureDevice?
    private var cancellables = Set<AnyCancellable>()
    
    func setupSession() {
        captureSession.beginConfiguration()
        
        // 1. 使用 .photo preset
        captureSession.sessionPreset = .photo
        
        // 2. 配置输入
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        device = camera
        captureSession.addInput(input)
        
        // 3. 配置照片输出
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            
            // 设置最大画质优先级
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // 选择最大分辨率
            let supportedDimensions = camera.activeFormat.supportedMaxPhotoDimensions
            if let largest = supportedDimensions.max(by: { lhs, rhs in
                Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
            }) {
                photoOutput.maxPhotoDimensions = largest
                print("✅ 支持最大分辨率: \(largest.width)x\(largest.height)")
            }
            
            // 启用响应式拍摄
            if photoOutput.isResponsiveCaptureSupported {
                photoOutput.isResponsiveCaptureEnabled = true
                print("✅ 响应式拍摄已启用")
            }
            
            // 启用快速拍摄优先
            photoOutput.isFastCapturePrioritizationEnabled = true
            print("✅ 快速拍摄优先已启用")
            
            // 观察拍摄就绪状态
            photoOutput.publisher(for: \.captureReadiness)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] readiness in
                    self?.updateShutterButtonState(ready: readiness == .ready)
                }
                .store(in: &cancellables)
        }
        
        captureSession.commitConfiguration()
        
        // 4. 预分配资源
        prepareResources()
        
        // 5. 启动会话
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func prepareResources() {
        let prepareSettings = AVCapturePhotoSettings()
        prepareSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        prepareSettings.photoQualityPrioritization = .quality
        
        photoOutput.setPreparedPhotoSettingsArray([prepareSettings]) { prepared, error in
            if let error = error {
                print("❌ 资源预分配失败: \(error)")
                return
            }
            print("✅ 资源已预分配: \(prepared)")
        }
    }
    
    func captureHighResPhoto(qualityPriority: AVCapturePhotoOutput.QualityPrioritization = .quality) {
        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        settings.photoQualityPrioritization = qualityPriority
        
        // 启用延迟处理
        if photoOutput.isDeferredPhotoDeliverySupported {
            settings.isDeferredPhotoDeliveryEnabled = true
            print("✅ 延迟照片处理已启用")
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func updateShutterButtonState(ready: Bool) {
        // 更新 UI 快门按钮状态
        print("📸 快门按钮状态: \(ready ? "可用" : "处理中")")
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        let dimensions = resolvedSettings.photoDimensions
        print("📸 开始拍摄: \(dimensions.width)x\(dimensions.height)")
        
        let timeRange = resolvedSettings.photoProcessingTimeRange
        print("⏱️ 预计处理时间: \(timeRange)")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?,
                     error: Error?) {
        if let error = error {
            print("❌ 代理照片失败: \(error)")
            return
        }
        
        print("✅ 代理照片已接收 - 用户可以继续拍摄")
        // 显示代理照片给用户
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("❌ 照片处理失败: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ 无法获取照片数据")
            return
        }
        
        let dimensions = photo.resolvedSettings.photoDimensions
        let sizeString = ByteCountFormatter.string(fromByteCount: Int64(imageData.count),
                                                   countStyle: .file)
        print("✅ 最终照片已完成: \(dimensions.width)x\(dimensions.height), \(sizeString)")
        
        // 保存到相册或处理...
    }
}
```

---

## 实战对比：启用前 vs 启用后

### 场景：篮球比赛抓拍

**未启用优化：**
```
拍摄照片 1 → 快门按钮转圈 3 秒 → 才能拍照片 2
结果：只拍到 1 张照片，错过精彩瞬间
```

**启用优化后：**
```swift
photoOutput.isResponsiveCaptureEnabled = true
photoOutput.isFastCapturePrioritizationEnabled = true
settings.isDeferredPhotoDeliveryEnabled = true
```

**启用优化：**
```
拍摄照片 1 (Quality)  → 快门立即可用
拍摄照片 2 (Quality)  → 检测到连拍
拍摄照片 3 (Balanced) → 自动降级，更快
拍摄照片 4 (Balanced)
拍摄照片 5 (Balanced)
结果：5 张照片，捕捉完整动作
```

**效果：** 1 张 vs 5 张，响应式体验质的飞跃

---

## 关键要点总结

### 分辨率选择
- **12MP：** 所有场景通用，低光最佳
- **24MP：** 平衡细节与文件大小，推荐日常使用
- **48MP：** 最高细节，适合需要裁剪/放大的场景

### 画质优先级
- **Speed：** 快速扫描、文档拍摄
- **Balanced：** 日常拍摄
- **Quality：** 专业摄影、最高要求

### 响应式拍摄三件套
```swift
// 1. 重叠拍摄
photoOutput.isResponsiveCaptureEnabled = true

// 2. 延迟处理
settings.isDeferredPhotoDeliveryEnabled = true

// 3. 快速拍摄优先
photoOutput.isFastCapturePrioritizationEnabled = true
```

**不启用这些 = 用户会错过无法重来的瞬间**

---

## 参考资料

- [WWDC 2026 Session 304 — Implement high resolution photo capture](https://developer.apple.com/videos/play/wwdc2026/304/)
- [WWDC 2023 — Create a more responsive camera experience](https://developer.apple.com/videos/play/wwdc2023/10105)
- [WWDC 2021 — Capture high-quality photos using video formats](https://developer.apple.com/videos/play/wwdc2021/10247)
- [WWDC 2021 — Capture and process ProRAW images](https://developer.apple.com/videos/play/wwdc2021/10160)
- [AVCapturePhotoOutput — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)

---

## 版本速查

| iOS 版本 | 新增功能 |
|----------|----------|
| iOS 16 | `supportedMaxPhotoDimensions`, `maxPhotoDimensions` |
| iOS 17 | 24MP 默认模式，Ultra Wide 48MP 支持 |
| iOS 26 | Responsive Capture, Deferred Photo Processing, Fast Capture Prioritization |
| iOS 27 | Balanced 快速拍摄延迟处理增强 |

---

## 关键词索引

`AVCapturePhotoOutput`, `maxPhotoDimensions`, `photoQualityPrioritization`, `supportedMaxPhotoDimensions`, `12MP`, `24MP`, `48MP`, `Photonic Engine`, `Quad Pixel`, `Responsive Capture`, `isResponsiveCaptureEnabled`, `Deferred Photo Processing`, `isDeferredPhotoDeliveryEnabled`, `Fast Capture Prioritization`, `isFastCapturePrioritizationEnabled`, `captureReadiness`, `AVCaptureResolvedPhotoSettings`, `photoProcessingTimeRange`, `shot-to-shot delay`, `高分辨率照片`, `画质优先级`, `延迟处理`, `连拍优化`
