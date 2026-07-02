# Core Image RAW Processing — RAW 9 完整指南

> **适用范围：** iOS 27+ / iPadOS 27+ / macOS 27+ / visionOS 27+  
> **来源：** WWDC 2026 Session 305  
> **框架：** Core Image
> 
> 本文档涵盖 RAW 9 处理引擎、CIRAWFilter API、性能优化、CIImageProcessor 新增功能。

---

## 目录

1. [RAW 处理流程](#raw-处理流程)
2. [RAW 9 新特性](#raw-9-新特性)
3. [启用 RAW 9](#启用-raw-9)
4. [CIRAWFilter 编辑属性](#cirawfilter-编辑属性)
5. [性能优化：交互式编辑](#性能优化交互式编辑)
6. [性能优化：批量导出](#性能优化批量导出)
7. [CIImageProcessor 新增功能](#ciimageprocessor-新增功能)
8. [完整示例](#完整示例)

---

## RAW 处理流程

### 传统 RAW 处理的 5 个阶段

```
1. 解析元数据 + 解包传感器数据
   ↓ (Bayer 马赛克图案: R-G-G-B)
   
2. 去马赛克 (Demosaicing)
   ↓ (每个像素现在有 RGB 三通道)
   
3. 降噪 (Noise Reduction)
   ↓ (消除光子噪声、读取噪声、热噪声)
   
4. 锐化 + 局部对比度
   ↓ (卷积运算)
   
5. 白平衡 + 曝光 + 色彩 + 色调
   ↓
   最终图像
```

**关键点：**
- RAW 文件不能直接显示（需要特殊处理）
- 每个像素位置只有 **一个颜色值**（R/G/B）
- iOS/macOS 内置算法，系统应用（照片、预览、Finder）自动支持

---

## RAW 9 新特性

### 与 RAW 8 的对比

| 特性 | RAW 8 (旧) | RAW 9 (新) |
|------|-----------|-----------|
| 去马赛克算法 | 传统算法 | **CoreML 分块模型** |
| 降噪 | 分离的亮度/色度降噪 | **联合去马赛克 + 降噪** |
| 计算单元 | CPU/GPU | **Apple 神经引擎 (ANE)** |
| 质量提升 | 基准 | **显著改善（尤其高 ISO）** |
| 支持相机 | 784 款 | **数百款（持续增长）** |

### 质量改进示例

**场景 1: 低噪点图像（Sony Alpha 7 II，老式表盘）**
- RAW 8: 效果不错
- RAW 9: **更清晰、更明朗、细小文字更易阅读**

**场景 2: 高噪点图像（Canon 5D Mark III，ISO 51,200 蜡笔）**
- RAW 数据: 无法辨别颜色
- RAW 8: 还原了实际色彩
- RAW 9: **色彩准确、定义清晰、镜面反射清晰可见**

**场景 3: 非传统传感器（Fujifilm X-T5，ISO 12,800 刺绣）**
- RAW 8: 色彩伪影 + 细节丢失
- RAW 9: **小文字清晰可读、毛线纹理清晰**

---

## 启用 RAW 9

### 基础代码

```swift
import CoreImage

// 1. 加载 RAW 文件
guard let rawFilter = CIRAWFilter(imageURL: fileURL) else {
    print("❌ 无法加载 RAW 文件")
    return
}

// 2. 检查是否支持 RAW 9
if rawFilter.supportedDecoderVersions.contains(.version9) {
    // 3. 启用 RAW 9（默认未启用）
    rawFilter.decoderVersion = .version9
    print("✅ RAW 9 已启用")
} else {
    print("⚠️ 此文件不支持 RAW 9")
}

// 4. 获取处理后的图像
guard let outputImage = rawFilter.outputImage else { return }
```

### 查询支持的相机型号

```swift
// 查询 RAW 9 支持的所有相机型号
let supportedModels = CIRAWFilter.supportedCameraModels(for: .version9)

print("✅ RAW 9 支持 \(supportedModels.count) 款相机")
// iOS/iPadOS/macOS/visionOS 27 发布时：数百款
// 涵盖所有主要专业相机厂商（Canon、Nikon、Sony、Fujifilm 等）

// 检查特定型号
if supportedModels.contains("Canon EOS R5") {
    print("✅ Canon EOS R5 支持 RAW 9")
}
```

**⚠️ 重要：**
- RAW 9 **默认未启用**（需要手动设置 `decoderVersion`）
- **自动支持 DNG 格式**（如 iPhone ProRAW）
- 相机列表通过 **OTA 系统更新持续增长**

---

## CIRAWFilter 编辑属性

### 核心属性（20 个可调整参数）

#### 1. 曝光控制

```swift
// 曝光（EV）
rawFilter.exposure = 0.5  // 范围: -10.0 ~ +10.0

// 白平衡（色温）
rawFilter.temperature = 5500  // 开尔文
rawFilter.tint = 0  // 色调偏移
```

#### 2. 降噪与锐化

```swift
// 亮度降噪（RAW 9 效果更好）
rawFilter.luminanceNoiseReductionAmount = 0.4  // 范围: 0.0 ~ 1.0

// ⚠️ 色度降噪在 RAW 9 中**无效**（自动处理）
// rawFilter.colorNoiseReductionAmount = 0.0  // RAW 9 忽略此参数

// 锐化
rawFilter.sharpnessAmount = 0.5  // 范围: 0.0 ~ 1.0

// 局部对比度
rawFilter.contrastAmount = 1.0  // 范围: 0.0 ~ 2.0
```

#### 3. RAW 9 中废弃的属性

```swift
// ❌ 以下属性在 RAW 9 中不再有效
// rawFilter.colorNoiseReductionAmount = 0.0
// rawFilter.detailAmount = 0.0
// rawFilter.moireReductionAmount = 0.0

// ✅ 使用 isSupported 检查属性是否有效
if rawFilter.colorNoiseReductionAmount.isSupported {
    // 此代码在 RAW 9 中不会执行
}
```

#### 4. 其他重要属性

```swift
// 色彩饱和度
rawFilter.saturationAmount = 1.0

// 高光/阴影恢复
rawFilter.highlightAmount = 1.0
rawFilter.shadowAmount = 0.0

// 裁剪 + 缩放
rawFilter.scaleFactor = 0.5  // 性能优化关键（见下文）
```

---

## 性能优化：交互式编辑

### 使用场景

**交互式编辑 = 一个 RAW 文件以屏幕分辨率多次渲染**

例如：用户拖动曝光滑块 → 实时预览

### 最佳实践

```swift
import CoreImage
import MetalKit

class RAWEditor {
    private let context: CIContext
    private let rawFilter: CIRAWFilter
    
    init(rawURL: URL) {
        // 1. ✅ 每个视图使用一个 CIContext
        self.context = CIContext(options: [
            .cacheIntermediates: true  // 🔑 关键：缓存中间结果
        ])
        
        self.rawFilter = CIRAWFilter(imageURL: rawURL)!
        rawFilter.decoderVersion = .version9
    }
    
    func render(to view: MTKView, exposure: Float) {
        rawFilter.exposure = exposure
        
        // 2. ✅ 使用 scaleFactor（渲染分辨率 = 显示分辨率）
        let displayScale = view.bounds.size.width / rawFilter.outputImage!.extent.width
        rawFilter.scaleFactor = displayScale
        
        // 3. ✅ 直接渲染到 Metal 视图
        let outputImage = rawFilter.outputImage!
        
        guard let drawable = view.currentDrawable else { return }
        context.render(outputImage,
                      to: drawable.texture,
                      commandBuffer: nil,
                      bounds: outputImage.extent,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        drawable.present()
    }
}
```

### 性能提升策略

| 策略 | 说明 | 效果 |
|------|------|------|
| **cacheIntermediates: true** | 缓存 CoreML 模型的中间结果 | 🔥 跳过密集的 CoreML 计算 |
| **scaleFactor** | 只渲染需要的像素 | 减少不必要的计算 |
| **Metal 直接渲染** | 渲染到 MTKView | 上一帧未完成时可开始下一帧 |
| **扩展虚拟地址权限** | 允许更多缓存内存 | 更流畅的交互式编辑 |

### 扩展虚拟地址权限

```xml
<!-- Info.plist 或 Entitlements -->
<key>com.apple.developer.kernel.extended-virtual-addressing</key>
<true/>
```

**说明：** 允许 Core Image 使用更多内存缓存中间结果。

**参考文档：** [Extended Virtual Addressing Entitlement](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.kernel.extended-virtual-addressing)

---

## 性能优化：批量导出

### 使用场景

**批量导出 = 多个 RAW 文件各自以全分辨率渲染一次**

例如：导出 100 张 RAW 为 JPEG

### 最佳实践

```swift
import CoreImage

class RAWExporter {
    private let exportContext: CIContext
    
    init() {
        // ✅ 导出时 cacheIntermediates = false
        self.exportContext = CIContext(options: [
            .cacheIntermediates: false,  // 🔑 不缓存（单次渲染）
            .memoryLimit: 512  // 🔑 增加内存限制（MB）
        ])
    }
    
    func export(rawURL: URL, to outputURL: URL) throws {
        guard let rawFilter = CIRAWFilter(imageURL: rawURL) else { return }
        
        rawFilter.decoderVersion = .version9
        // ⚠️ 不设置 scaleFactor（全分辨率导出）
        
        guard let outputImage = rawFilter.outputImage else { return }
        
        // ✅ 使用 CIContext 的 heifRepresentation（节省内存）
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let heifData = exportContext.heifRepresentation(
            of: outputImage,
            format: .RGBA8,
            colorSpace: colorSpace,
            options: [:]
        )
        
        try heifData?.write(to: outputURL)
    }
}
```

### 性能提升策略

| 策略 | 说明 | iOS 默认 | 推荐值 |
|------|------|----------|--------|
| **cacheIntermediates: false** | 不缓存（单次渲染） | - | false |
| **memoryLimit** | 每次导出的内存限制 | 256 MB | **512 或 1024 MB** |
| **heifRepresentation** | 直接编码（不经过 Image IO） | - | ✅ 推荐 |

**对比 Image IO：**

```swift
// ❌ 旧方式（通过 Image IO，占用更多内存）
let cgImage = exportContext.createCGImage(outputImage, from: outputImage.extent)
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, kUTTypeJPEG, 1, nil)
CGImageDestinationAddImage(destination!, cgImage!, nil)
CGImageDestinationFinalize(destination!)

// ✅ 新方式（直接编码，节省内存）
let heifData = exportContext.heifRepresentation(of: outputImage, ...)
try heifData?.write(to: outputURL)
```

---

## CIImageProcessor 新增功能

### 1. 显式输出分块大小

**问题：** Core Image 默认自动决定分块大小 → 不可预测

**iOS 27 新功能：** 手动控制输出分块大小

#### 完整代码示例

```swift
import CoreImage

class MyProcessor: CIImageProcessorKernel {
    override class func roi(forInput input: Int32,
                            arguments: [String: Any]?,
                            outputRect: CGRect) -> CGRect {
        return outputRect  // 1:1 映射
    }
    
    override class func process(with inputs: [CIImageProcessorInput]?,
                                arguments: [String: Any]?,
                                output: CIImageProcessorOutput) throws {
        guard let input = inputs?.first,
              let iBuffer = input.pixelBuffer,
              let oBuffer = output.pixelBuffer else { return }
        
        let iRegion = input.region
        let oRegion = output.region  // ⚠️ 由 Core Image 控制
        
        // 处理这个分块
        // MyCopyBuffer(iBuffer, iRegion, oBuffer, oRegion)
    }
}

// ✅ 手动控制分块大小
let extent = inputImage.extent
let tileSize = 512.0  // 每个分块 512x512 像素
var tiles: [CIVector] = []

for y in stride(from: extent.minY, to: extent.maxY, by: tileSize) {
    for x in stride(from: extent.minX, to: extent.maxX, by: tileSize) {
        let tile = CGRect(
            x: x, y: y,
            width: min(tileSize, extent.maxX - x),
            height: min(tileSize, extent.maxY - y)
        )
        tiles.append(CIVector(cgRect: tile))
    }
}

// 应用处理器（显式分块）
let result = try MyProcessor.apply(
    withTiledExtent: tiles,
    inputs: [inputImage],
    arguments: [:]
)
```

**关键点：**
- **无需修改处理器类代码**
- 分块大小完全由你控制
- 适用于需要精确内存管理的场景

---

### 2. 临时缓冲区功能

**问题：** 调用 CoreML 时需要临时缓冲区 → 反复创建/销毁影响性能

**iOS 27 新功能：** Core Image 自动管理临时缓冲区生命周期

#### 完整代码示例

```swift
import CoreImage

class MyProcessor: CIImageProcessorKernel {
    override class func process(with inputs: [CIImageProcessorInput]?,
                                arguments: [String: Any]?,
                                output: CIImageProcessorOutput) throws {
        guard let input = inputs?.first,
              let srcPixelBuffer = input.pixelBuffer,
              let dstPixelBuffer = output.pixelBuffer else { return }
        
        // ✅ 请求一个临时缓冲区
        guard let scratch = output.temporaryPixelBuffer(
            identifier: "myScratch",  // 🔑 多个缓冲区时用不同 ID
            format: kCVPixelFormatType_64RGBAHalf,
            width: Int(output.region.width),
            height: Int(output.region.height),
            pixelBufferAttributes: nil
        ) else { return }
        
        // Step 1: 复制输入 → 临时缓冲区
        copyPixels(from: srcPixelBuffer, to: scratch)
        
        // Step 2: 就地处理临时缓冲区
        processPixels(in: scratch)
        
        // Step 3: 复制临时缓冲区 → 输出
        copyPixels(from: scratch, to: dstPixelBuffer)
        
        // ✅ 无需手动释放（Core Image 自动管理）
    }
}
```

**关键点：**
- 临时缓冲区**自动回收**（下一个分块调用时复用）
- 支持**多个临时缓冲区**（用不同 `identifier`）
- 生命周期由 Core Image 管理

---

## 完整示例

### 照片编辑 App

```swift
import UIKit
import CoreImage
import MetalKit

class RAWPhotoEditorViewController: UIViewController {
    private var context: CIContext!
    private var rawFilter: CIRAWFilter!
    private var metalView: MTKView!
    
    // MARK: - Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetal()
        loadRAW()
    }
    
    private func setupMetal() {
        metalView = MTKView(frame: view.bounds, device: MTLCreateSystemDefaultDevice())
        metalView.framebufferOnly = false
        view.addSubview(metalView)
        
        // ✅ 交互式编辑配置
        context = CIContext(mtlDevice: metalView.device!, options: [
            .cacheIntermediates: true,
            .workingColorSpace: CGColorSpaceCreateDeviceRGB()
        ])
    }
    
    private func loadRAW() {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "dng") else { return }
        guard let filter = CIRAWFilter(imageURL: url) else { return }
        
        rawFilter = filter
        
        // ✅ 启用 RAW 9
        if filter.supportedDecoderVersions.contains(.version9) {
            filter.decoderVersion = .version9
            print("✅ RAW 9 已启用")
        }
        
        // ✅ 设置 scaleFactor
        let displayWidth = metalView.bounds.width * UIScreen.main.scale
        let imageWidth = filter.outputImage!.extent.width
        filter.scaleFactor = displayWidth / imageWidth
        
        render()
    }
    
    // MARK: - Editing
    
    @IBAction func exposureChanged(_ slider: UISlider) {
        rawFilter.exposure = slider.value
        render()
    }
    
    @IBAction func sharpnessChanged(_ slider: UISlider) {
        rawFilter.sharpnessAmount = slider.value
        render()
    }
    
    @IBAction func noiseReductionChanged(_ slider: UISlider) {
        rawFilter.luminanceNoiseReductionAmount = slider.value
        render()
    }
    
    // MARK: - Rendering
    
    private func render() {
        guard let outputImage = rawFilter.outputImage else { return }
        guard let drawable = metalView.currentDrawable else { return }
        
        let commandBuffer = metalView.device!.makeCommandQueue()!.makeCommandBuffer()!
        
        context.render(
            outputImage,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: outputImage.extent,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Export
    
    @IBAction func exportButtonTapped() {
        // ✅ 导出时切换到导出专用 context
        let exportContext = CIContext(options: [
            .cacheIntermediates: false,
            .memoryLimit: 1024  // 1GB
        ])
        
        // 移除 scaleFactor（全分辨率导出）
        let originalScale = rawFilter.scaleFactor
        rawFilter.scaleFactor = 1.0
        
        guard let outputImage = rawFilter.outputImage else { return }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let heifData = exportContext.heifRepresentation(
            of: outputImage,
            format: .RGBA8,
            colorSpace: colorSpace,
            options: [:]
        ) else { return }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")
        
        try? heifData.write(to: outputURL)
        print("✅ 已导出: \(outputURL)")
        
        // 恢复 scaleFactor
        rawFilter.scaleFactor = originalScale
    }
}
```

---

## 关键要点总结

### RAW 9 特性
- **CoreML 分块模型** - 联合去马赛克 + 降噪
- **Apple 神经引擎** - 利用 ANE 硬件加速
- **显著质量提升** - 尤其高 ISO 图像

### 启用 RAW 9
- **手动启用** - `decoderVersion = .version9`（默认未启用）
- **检查支持** - `supportedDecoderVersions.contains(.version9)`
- **查询相机** - `supportedCameraModels(for: .version9)`

### 性能优化
- **交互式编辑** - `cacheIntermediates: true` + `scaleFactor` + Metal 直接渲染
- **批量导出** - `cacheIntermediates: false` + `memoryLimit: 512/1024` + `heifRepresentation`

### CIImageProcessor
- **显式分块** - `apply(withTiledExtent:)` 精确控制分块大小
- **临时缓冲区** - `temporaryPixelBuffer(identifier:)` 自动管理生命周期

---

## 参考资料

- [WWDC 2026 Session 305 — Enhance RAW image processing with Core Image](https://developer.apple.com/videos/play/wwdc2026/305/)
- [WWDC 2021 — Capture and process ProRAW images](https://developer.apple.com/videos/play/wwdc2021/10160)
- [WWDC 2022 — Display EDR content with Core Image, Metal, and SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10114)
- [CIRAWFilter — Apple Developer Documentation](https://developer.apple.com/documentation/coreimage/cirawfilter)
- [CIImageProcessor — Apple Developer Documentation](https://developer.apple.com/documentation/coreimage/ciimageprocessorkernel)

---

## 关键词索引

`RAW 9`, `CIRAWFilter`, `decoderVersion`, `supportedDecoderVersions`, `supportedCameraModels`, `Core Image`, `CoreML`, `Apple Neural Engine`, `去马赛克`, `降噪`, `demosaicing`, `noise reduction`, `exposure`, `luminanceNoiseReductionAmount`, `sharpnessAmount`, `contrastAmount`, `scaleFactor`, `cacheIntermediates`, `memoryLimit`, `heifRepresentation`, `CIImageProcessor`, `CIImageProcessorKernel`, `temporaryPixelBuffer`, `apply(withTiledExtent:)`, `显式分块`, `临时缓冲区`, `RAW processing`, `photo editing`, `Lightroom`, `Pixelmator`, `照片编辑`, `批量导出`, `交互式编辑`
