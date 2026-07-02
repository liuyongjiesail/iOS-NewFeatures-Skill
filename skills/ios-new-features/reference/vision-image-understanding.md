# Vision 框架图像理解新功能

> **适用范围：** iOS 27+ / macOS 27+ / watchOS 27+ / visionOS 27+  
> **来源：** WWDC 2026 Session 237  
> **框架：** Vision, Foundation Models
> 
> 本文档涵盖 Vision 框架的轻点分割功能、Foundation Models 的图像输入支持、基于图像的工具调用，以及 watchOS 上的 Vision 功能。

---

## 目录

1. [功能概览](#功能概览)
2. [轻点分割 (Tap-to-Segment)](#轻点分割-tap-to-segment)
3. [Foundation Models 图像输入](#foundation-models-图像输入)
4. [基于图像的工具调用](#基于图像的工具调用)
5. [watchOS 上的 Vision](#watchos-上的-vision)
6. [完整示例](#完整示例)
7. [最佳实践](#最佳实践)

---

## 功能概览

### 核心特性

| 特性 | 说明 |
|------|------|
| **轻点分割** | 通过点击、边界框、套索或涂鸦交互式分割图像中的任意对象 |
| **LLM 图像理解** | Foundation Models 支持图像作为输入进行分析 |
| **图像工具调用** | 为 LLM 创建基于图像的工具，结合 Vision 的专业性 |
| **watchOS 支持** | Vision 框架现在可在 Apple Watch 上使用 |
| **Vision 内置工具** | 条形码读取和 OCR 工具可直接供 LLM 使用 |

### 使用场景

**轻点分割：**
- 照片编辑：抠图、背景替换
- 电商：产品图像处理
- 医疗影像：区域标注
- 设计工具：快速选择对象

**LLM 图像理解：**
- 自动生成图像描述
- 冰箱照片生成食谱
- 室内装饰建议
- 文档内容提取

**图像工具调用：**
- 植物识别
- 活动传单信息提取
- 结合条形码/二维码扫描
- 精细文本识别（OCR）

---

## 轻点分割 (Tap-to-Segment)

### 功能说明

轻点分割 API 允许交互式分割图像中的任意对象，支持多种选择方式：

| 选择方式 | 说明 | 适用场景 |
|---------|------|---------|
| **点击 (Tap)** | 在对象上选择一个点 | 简单、边界清晰的对象 |
| **边界框 (Rectangle)** | 绘制矩形框围住对象 | 复杂对象或多个对象 |
| **套索 (Lasso)** | 在对象周围绘制闭合曲线 | 不规则形状对象 |
| **涂鸦 (Scribble)** | 在对象上涂抹 | 同时分割多个对象 |

### 基础使用

```swift
import Vision

// 1. 创建图像请求处理器
let handler = ImageRequestHandler(image)

// 2. 创建分割请求（使用种子点）
let point = CGPoint(x: 0.5, y: 0.5) // 归一化坐标 (0-1)
let request = GenerateIterativeSegmentationRequest(seed: point)

// 3. 执行请求
let observation = try await handler.perform(request)
let mask = observation?.pixelBuffer

// 4. 优化蒙版（添加更多点）
request.addIncludedPoint(newPoint)
let refinedObservation = try await handler.perform(request)
```

### 坐标系统

```swift
// Vision 使用归一化坐标系
// - 原点：左下角 (0, 0)
// - 范围：0.0 到 1.0
// - (0.5, 0.5) = 图像中心

let normalizedPoint = CGPoint(
    x: pixelX / imageWidth,
    y: pixelY / imageHeight
)
```

### 添加和排除点

```swift
// 添加点：扩展选区
request.addIncludedPoint(CGPoint(x: 0.6, y: 0.5))

// 排除点：从选区中移除区域
request.addExcludedPoint(CGPoint(x: 0.7, y: 0.5))
```

### 使用边界框

```swift
let boundingBox = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
let request = GenerateIterativeSegmentationRequest(boundingBox: boundingBox)
```

### 使用套索

```swift
// 套索路径：一系列归一化的点
let lassoPath: [CGPoint] = [
    CGPoint(x: 0.3, y: 0.4),
    CGPoint(x: 0.5, y: 0.3),
    CGPoint(x: 0.7, y: 0.5),
    // ... 更多点
]

let request = GenerateIterativeSegmentationRequest(lasso: lassoPath)
```

### 重要注意事项

```swift
// 1. 套索笔触宽度
// 线条宽度应至少为图像总宽度的 1%
let minimumStrokeWidth = imageWidth * 0.01

// 2. 下载模型（首次使用前）
let request = GenerateIterativeSegmentationRequest()
try await request.downloadAssets()

// 3. 检查模型状态
if request.assetStatus == .ready {
    // 模型已准备好
}
```

---

## Foundation Models 图像输入

### 功能说明

Foundation Models 框架现在支持将图像作为输入传递给大型语言模型，实现强大的视觉理解能力。

### 基础使用

```swift
import FoundationModels

// 1. 创建包含图像的提示
let prompt = Prompt {
    "Generate a caption for this image"
    Attachment(image)
}

// 2. 获取模型响应
let response = try await session.respond(to: prompt)
let caption = response.content
```

### 实际应用示例

#### 示例 1: 图像描述生成

```swift
func generateImageCaption(for image: CGImage) async throws -> String {
    let prompt = Prompt {
        "请为这张图片生成一段详细的描述，包括场景、对象和氛围。"
        Attachment(image)
    }
    
    let response = try await session.respond(to: prompt)
    return response.content
}
```

#### 示例 2: 冰箱食谱生成

```swift
func generateRecipe(from fridgeImage: CGImage) async throws -> String {
    let prompt = Prompt {
        """
        根据这张冰箱照片中的食材，
        生成一个简单易做的食谱，包括：
        1. 菜名
        2. 所需食材列表
        3. 烹饪步骤
        """
        Attachment(fridgeImage)
    }
    
    let response = try await session.respond(to: prompt)
    return response.content
}
```

#### 示例 3: 室内装饰建议

```swift
func getDecorAdvice(for roomImage: CGImage) async throws -> String {
    let prompt = Prompt {
        """
        分析这个房间的照片，提供室内装饰建议：
        - 配色方案
        - 家具布局
        - 装饰元素
        """
        Attachment(roomImage)
    }
    
    let response = try await session.respond(to: prompt)
    return response.content
}
```

### Vision vs Foundation Models

| 特性 | Vision | Foundation Models |
|------|--------|-------------------|
| **能力** | 固定的计算机视觉 API | 通用的图像理解 |
| **任务类型** | 特定任务（人脸、文本、姿势等）| 几乎任何描述性任务 |
| **速度** | 非常快，可实时处理视频 | 较慢，适合单张图像 |
| **准确性** | 特定任务上非常精确 | 通用但不如专用 API 精确 |
| **灵活性** | 受限于预定义 API | 可通过提示自由定制 |

---

## 基于图像的工具调用

### 工具调用概念

工具调用允许 LLM 访问外部代码来完成特定任务：

```
用户提示 → LLM 分析 → 调用工具 → 工具执行 → 返回结果 → LLM 生成回复
```

### 创建图像工具

```swift
import FoundationModels

struct PlantIdentifierTool: Tool {
    @SessionProperty(\.history) var history
    
    @Generable
    struct Arguments {
        var image: ImageReference  // 图像引用，不是实际图像
    }
    
    func call(arguments: Arguments) async throws -> String {
        // 1. 获取图像引用
        let imageReference = arguments.image
        
        // 2. 从历史记录中解析图像
        let transcript = Transcript(history)
        guard let imageAttachment = imageReference.resolve(in: transcript) else {
            throw AppError.imageNotFound
        }
        
        // 3. 转换为 PixelBuffer
        let image = try imageAttachment.pixelBuffer()
        
        // 4. 执行图像分析
        return classifyPlant(image)
    }
}
```

### 使用 Vision 内置工具

Vision 提供两个开箱即用的工具：

#### 1. 条形码读取工具

```swift
import FoundationModels
import Vision

let session = LanguageModelSession(
    model: model,
    tools: [BarcodeReaderTool()]
)

let response = try await session.respond {
    "提取这张传单上的所有信息：日期、地点和网站"
    Attachment(image)
        .label("flyer")  // 重要：为图像添加标签
}
```

#### 2. OCR 工具

```swift
let session = LanguageModelSession(
    model: model,
    tools: [OCRTool()]
)

let response = try await session.respond {
    "读取这张收据上的所有文本"
    Attachment(receiptImage)
        .label("receipt")
}
```

### Vision 工具特性

| 工具 | 功能 | 优势 |
|------|------|------|
| **BarcodeReaderTool** | 扫描条形码和二维码 | 支持多种条形码格式，准确度高 |
| **OCRTool** | 文本识别 | 支持 30+ 种语言，可识别密集或精细文本 |

### 自定义 Vision 工具示例

```swift
struct FaceAnalysisTool: Tool {
    @SessionProperty(\.history) var history
    
    @Generable
    struct Arguments {
        var image: ImageReference
    }
    
    func call(arguments: Arguments) async throws -> String {
        let transcript = Transcript(history)
        guard let imageAttachment = arguments.image.resolve(in: transcript) else {
            throw AppError.imageNotFound
        }
        
        let cgImage = try imageAttachment.cgImage()
        
        // 使用 Vision 进行人脸分析
        let request = DetectFaceLandmarksRequest()
        let handler = ImageRequestHandler(cgImage)
        let observations = try await handler.perform(request)
        
        // 分析结果
        let faceCount = observations.count
        let emotions = observations.map { analyzeFaceEmotion($0) }
        
        return """
        检测到 \(faceCount) 张人脸
        情绪分析：\(emotions.joined(separator: ", "))
        """
    }
}
```

### 工具调用流程图

```
用户：这是什么植物？[附带图片]
  ↓
LLM：我无法直接识别，调用 PlantIdentifierTool
  ↓
工具：解析图像引用 → 转换为 PixelBuffer → Vision 分类 → 返回 "玫瑰"
  ↓
LLM：这是一株玫瑰，属于蔷薇科...
```

---

## watchOS 上的 Vision

### 功能说明

Vision 框架现在可在 watchOS 上使用，为手表应用带来强大的图像分析能力。

### 显著性分析（智能裁剪）

```swift
import Vision

func generateImageCrop(in image: CGImage) async throws -> NormalizedRect? {
    // 1. 创建显著性请求
    let request = GenerateObjectnessBasedSaliencyImageRequest()
    
    // 2. 执行请求
    let observation = try await request.perform(on: image)
    
    // 3. 获取显著对象
    let prominentObjects = observation.salientObjects
    
    // 4. 返回最突出的对象边界框
    return prominentObjects.first
}
```

### 完整 watchOS 应用示例

```swift
import SwiftUI
import Vision

struct WildlifeWatchApp: View {
    @State private var selectedAnimal: Animal?
    @State private var croppedImage: CGImage?
    
    var body: some View {
        NavigationView {
            List(animals) { animal in
                Button(action: {
                    selectedAnimal = animal
                    cropImage(animal.photo)
                }) {
                    Text(animal.name)
                }
            }
            .navigationTitle("本地野生动物")
        }
        .sheet(item: $selectedAnimal) { animal in
            if let croppedImage = croppedImage {
                Image(croppedImage, scale: 1.0, label: Text(animal.name))
                    .resizable()
                    .scaledToFit()
            }
        }
    }
    
    func cropImage(_ image: CGImage) {
        Task {
            do {
                // 使用显著性分析裁剪图像
                let request = GenerateObjectnessBasedSaliencyImageRequest()
                let observation = try await request.perform(on: image)
                
                if let boundingBox = observation.salientObjects.first {
                    // 裁剪到显著区域
                    croppedImage = cropToRect(image, rect: boundingBox)
                }
            } catch {
                print("裁剪失败: \(error)")
            }
        }
    }
    
    func cropToRect(_ image: CGImage, rect: CGRect) -> CGImage? {
        // 转换归一化坐标到像素坐标
        let pixelRect = CGRect(
            x: rect.origin.x * CGFloat(image.width),
            y: rect.origin.y * CGFloat(image.height),
            width: rect.size.width * CGFloat(image.width),
            height: rect.size.height * CGFloat(image.height)
        )
        
        return image.cropping(to: pixelRect)
    }
}
```

### watchOS 上的 Vision 功能

Vision 在 watchOS 上支持 30+ 种图像分析类型：

- ✅ 显著性分析
- ✅ 人脸检测和标志识别
- ✅ 条形码扫描
- ✅ 文本识别 (OCR)
- ✅ 图像分类
- ✅ 对象检测
- ✅ 姿势估计

---

## 完整示例

### 示例 1: 轻点分割照片编辑器

```swift
import SwiftUI
import Vision

class SegmentationViewModel: ObservableObject {
    @Published var segmentedMask: CVPixelBuffer?
    @Published var isProcessing = false
    
    func segmentObject(in image: CGImage, at point: CGPoint) async {
        await MainActor.run { isProcessing = true }
        
        do {
            let handler = ImageRequestHandler(image)
            let request = GenerateIterativeSegmentationRequest(seed: point)
            
            let observation = try await handler.perform(request)
            
            await MainActor.run {
                self.segmentedMask = observation?.pixelBuffer
                self.isProcessing = false
            }
        } catch {
            print("分割失败: \(error)")
            await MainActor.run { isProcessing = false }
        }
    }
    
    func refineSegmentation(includingPoint: CGPoint) async {
        guard let request = currentRequest else { return }
        
        request.addIncludedPoint(includingPoint)
        
        do {
            let observation = try await handler.perform(request)
            await MainActor.run {
                self.segmentedMask = observation?.pixelBuffer
            }
        } catch {
            print("优化失败: \(error)")
        }
    }
}

struct SegmentationEditorView: View {
    @StateObject private var viewModel = SegmentationViewModel()
    let image: CGImage
    
    var body: some View {
        ZStack {
            Image(image, scale: 1.0, label: Text("原始图像"))
                .resizable()
                .scaledToFit()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let normalizedPoint = normalizePoint(value.location)
                            Task {
                                await viewModel.segmentObject(
                                    in: image,
                                    at: normalizedPoint
                                )
                            }
                        }
                )
            
            if let mask = viewModel.segmentedMask {
                MaskOverlayView(mask: mask)
            }
            
            if viewModel.isProcessing {
                ProgressView()
            }
        }
    }
    
    func normalizePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x / CGFloat(image.width),
            y: point.y / CGFloat(image.height)
        )
    }
}
```

### 示例 2: 智能文档扫描器

```swift
import FoundationModels
import Vision

class DocumentScanner {
    let session: LanguageModelSession
    
    init() {
        // 配置带 Vision 工具的会话
        session = LanguageModelSession(
            model: .default,
            tools: [BarcodeReaderTool(), OCRTool()]
        )
    }
    
    func extractInformation(from image: CGImage) async throws -> DocumentInfo {
        let response = try await session.respond(generating: DocumentInfo.self) {
            """
            从这个文档中提取所有信息：
            - 文本内容
            - 条形码/二维码
            - 日期
            - 金额
            """
            Attachment(image)
                .label("document")
        }
        
        return response
    }
}

struct DocumentInfo: Codable {
    let textContent: String
    let barcodes: [String]
    let dates: [String]
    let amounts: [Double]
}
```

### 示例 3: 植物识别应用

```swift
struct PlantRecognitionApp {
    let session: LanguageModelSession
    
    init() {
        session = LanguageModelSession(
            model: .default,
            tools: [PlantIdentifierTool()]
        )
    }
    
    func identifyPlant(_ image: CGImage) async throws -> PlantInfo {
        let response = try await session.respond(generating: PlantInfo.self) {
            """
            识别这种植物并提供以下信息：
            - 植物名称（中文和学名）
            - 科属
            - 生长环境
            - 养护要点
            """
            Attachment(image)
                .label("plant")
        }
        
        return response
    }
}

struct PlantInfo: Codable {
    let chineseName: String
    let scientificName: String
    let family: String
    let habitat: String
    let careInstructions: String
}
```

---

## 最佳实践

### ✅ 推荐做法

1. **轻点分割**
   ```swift
   // 使用合适的笔触宽度
   let strokeWidth = max(imageWidth * 0.01, 5.0)
   
   // 提前下载模型
   try await request.downloadAssets()
   
   // 检查模型状态
   guard request.assetStatus == .ready else {
       // 提示用户下载模型
       return
   }
   ```

2. **Foundation Models 图像输入**
   ```swift
   // 使用清晰的提示
   let prompt = Prompt {
       "请详细描述这张图片，包括..."  // 明确要求
       Attachment(image)
   }
   
   // 压缩大图像以提高性能
   let compressedImage = image.resized(maxDimension: 1024)
   ```

3. **图像工具调用**
   ```swift
   // 为图像添加描述性标签
   Attachment(image)
       .label("product-photo")  // 帮助 LLM 理解上下文
   
   // 组合多个工具
   let session = LanguageModelSession(
       model: model,
       tools: [BarcodeReaderTool(), OCRTool(), CustomTool()]
   )
   ```

4. **watchOS 应用**
   ```swift
   // 使用显著性分析优化小屏幕显示
   let request = GenerateObjectnessBasedSaliencyImageRequest()
   let crop = try await generateImageCrop(in: image)
   
   // 缓存裁剪结果
   ImageCache.shared.store(crop, forKey: imageID)
   ```

### ⚠️ 注意事项

1. **坐标系统**
   ```swift
   // ❌ 错误：使用像素坐标
   let point = CGPoint(x: 100, y: 200)
   
   // ✅ 正确：归一化坐标
   let point = CGPoint(
       x: 100.0 / imageWidth,
       y: 200.0 / imageHeight
   )
   ```

2. **模型下载**
   ```swift
   // 首次使用前检查并下载
   if request.assetStatus != .ready {
       try await request.downloadAssets()
   }
   ```

3. **性能考虑**
   ```swift
   // LLM 图像分析较慢，不适合实时处理
   // 使用 Vision 进行实时视频分析
   
   // ❌ 错误：对视频帧使用 LLM
   for frame in videoFrames {
       await llm.analyze(frame)  // 太慢
   }
   
   // ✅ 正确：使用 Vision
   for frame in videoFrames {
       try await visionRequest.perform(on: frame)  // 快速
   }
   ```

4. **图像引用解析**
   ```swift
   // 图像引用仅在其创建的记录上下文中有效
   func call(arguments: Arguments) async throws -> String {
       let transcript = Transcript(history)
       guard let attachment = arguments.image.resolve(in: transcript) else {
           throw AppError.imageNotFound
       }
       // 使用 attachment...
   }
   ```

### 🚫 避免的做法

1. **不要跳过模型检查**
   ```swift
   // ❌ 错误
   let request = GenerateIterativeSegmentationRequest(seed: point)
   try await handler.perform(request)  // 可能失败，模型未下载
   
   // ✅ 正确
   if request.assetStatus != .ready {
       try await request.downloadAssets()
   }
   try await handler.perform(request)
   ```

2. **不要使用过细的套索笔触**
   ```swift
   // ❌ 错误：笔触太细
   let strokeWidth = 1.0
   
   // ✅ 正确：至少 1% 图像宽度
   let strokeWidth = max(imageWidth * 0.01, 5.0)
   ```

3. **不要混淆用途**
   ```swift
   // ❌ 使用 LLM 做 Vision 擅长的事
   await llm.analyze("检测这张图中的人脸")
   
   // ✅ 使用 Vision
   let request = DetectFaceRectanglesRequest()
   try await handler.perform(request)
   ```

---

## 相关 API 参考

### Vision 轻点分割

```swift
// 创建分割请求
GenerateIterativeSegmentationRequest(seed: CGPoint)
GenerateIterativeSegmentationRequest(boundingBox: CGRect)
GenerateIterativeSegmentationRequest(lasso: [CGPoint])

// 优化蒙版
func addIncludedPoint(_ point: CGPoint)
func addExcludedPoint(_ point: CGPoint)

// 模型管理
func downloadAssets() async throws
var assetStatus: AssetStatus { get }
```

### Foundation Models 图像支持

```swift
// 提示构建器
Prompt {
    "文本提示"
    Attachment(CGImage)
    Attachment(UIImage)
}

// 图像附件
Attachment(image)
    .label("description")

// 会话响应
session.respond(to: Prompt) async throws
session.respond(generating: Codable.Type) async throws
```

### 图像工具

```swift
// 工具协议
protocol Tool {
    associatedtype Arguments
    func call(arguments: Arguments) async throws -> String
}

// 图像引用
struct ImageReference {
    func resolve(in transcript: Transcript) -> ImageAttachment?
}

// Vision 内置工具
BarcodeReaderTool()
OCRTool()
```

### watchOS Vision

```swift
// 显著性分析
GenerateObjectnessBasedSaliencyImageRequest()
struct SaliencyObservation {
    var salientObjects: [NormalizedRect]
}
```

---

## 相关 WWDC Sessions

- **WWDC 2026 Session 237**: 图像理解方面的新动向
- **WWDC 2026 Session 241**: Foundation Models 框架的新功能
- **WWDC 2025 Session 301**: 深入了解 Foundation Models 框架
- **WWDC 2024 Session 10163**: 探索 Vision 框架中的 Swift 增强功能

---

## 额外资源

- [Apple Developer Documentation: Vision](https://developer.apple.com/documentation/vision)
- [Segmenting objects using taps, scribbles or rectangles](https://developer.apple.com/documentation/Vision/segmenting-objects-using-taps-scribbles-or-rectangles)
- [Implementing saliency-based image cropping in iOS and watchOS](https://developer.apple.com/documentation/Vision/implementing-saliency-based-image-cropping-in-iOS-and-watchOS)
- [Foundation Models Framework](https://developer.apple.com/documentation/foundationmodels)

---

## 总结

Vision 框架和 Foundation Models 的图像理解新功能为开发者提供了强大的工具：

1. **轻点分割**：交互式分割任意对象，支持多种选择方式
2. **LLM 图像理解**：使用大型语言模型分析图像，实现通用视觉理解
3. **图像工具调用**：结合 Vision 的专业性和 LLM 的灵活性
4. **watchOS 支持**：在手表上使用 Vision 进行图像分析
5. **内置工具**：条形码读取和 OCR 工具开箱即用

**推荐：** 根据任务选择合适的工具 - Vision 用于快速和专业任务，Foundation Models 用于通用和描述性任务，工具调用用于结合两者的优势。
