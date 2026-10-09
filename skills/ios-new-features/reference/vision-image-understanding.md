# Vision 图像理解 (iOS 27+)

Source: [WWDC 2026 Session 237 — 图像理解方面的新动向](https://developer.apple.com/videos/play/wwdc2026/237/)

框架：Vision、Foundation Models。轻点分割与显著性裁剪同时覆盖 watchOS。

## Overview

用 Vision 的轻点分割交互式隔离图像中的任意对象；把图像作为 Foundation Models 的输入做描述类理解；再用带 `ImageReference` 的工具把 Vision 的专用能力（条形码、OCR 等）交给模型。Vision 今年也可在 watchOS 上做显著性裁剪。

## Quick Example

```swift
import Vision

let handler = ImageRequestHandler(image)
let request = GenerateIterativeSegmentationRequest(
    seedPoint: NormalizedPoint(x: 0.5, y: 0.5)
)
let observation = try await handler.perform(request)
let mask = observation?.pixelBuffer

try request.addIncludedPoint(NormalizedPoint(x: 0.62, y: 0.48))
let refinedObservation = try await handler.perform(request)
```

`NormalizedPoint` 的 x、y 在 0...1，原点在左下角。蒙版是灰度图，标出属于被分割对象的像素。WWDC 幻灯片写成 `GenerateIterativeSegmentationRequest(seed:)`；文档里的初始化方法是 `seedPoint`、`seedBox`、`seedScribbleBuffer`。

## Key APIs

| API | 作用 |
|-----|------|
| `GenerateIterativeSegmentationRequest(seedPoint:)` | 用对象内部的种子点生成分割蒙版 |
| `init(seedBox:)` | 用 `NormalizedRect` 一次围住要分割的区域 |
| `init(seedScribbleBuffer:)` | 用涂鸦像素缓冲作为种子 |
| `addIncludedPoint` / `addExcludedPoint` | 把点并入或排除出同一请求，再 `perform` |
| `DownloadableAssetsRequest` | `assetStatus` 与 `downloadAssets()`，iOS 27+ |
| `Prompt` + `Attachment` | 把图像附在提示里交给 Foundation Models |
| `Tool` + `ImageReference` | 工具参数是会话中已有图像的引用，不是整张图 |
| `BarcodeReaderTool` / `OCRTool` | Vision 提供给 `LanguageModelSession` 的两个工具 |
| `GenerateObjectnessBasedSaliencyImageRequest` | 找出显著物体边界框，用于小屏幕裁剪 |

交互说明：[Segmenting objects using taps, scribbles or rectangles](https://developer.apple.com/documentation/Vision/segmenting-objects-using-taps-scribbles-or-rectangles)

## 轻点分割

人物分割只能隔离人。`GenerateIterativeSegmentationRequest` 可以分割任意对象：花瓶、棋盘、衣服、地板、杯子和盘子。

| 选择方式 | 会话中的用法 |
|---------|----------------|
| 点 | 简单、边界清楚的对象。一个点不够时再加点 |
| 边界框 | 一次围住多个对象，例如杯子和盘子 |
| 套索 | 沿不规则轮廓圈选，例如牛角面包 |
| 涂鸦 | 在多个对象上涂抹，一次分割它们 |

拿到蒙版后对**同一个** `request` 调用 `addIncludedPoint` 或 `addExcludedPoint`，再 `perform` 一次。两点都会抛错：种子是点或涂鸦时，追加点一共不能超过 13 个；种子是框时不能超过 11 个。`qualityLevel` 控制蒙版分辨率。

`GenerateIterativeSegmentationRequest` 遵循 `DownloadableAssetsRequest`。第一次执行前看 `assetStatus`：

```swift
if request.assetStatus == .notReady {
    try await request.downloadAssets()
}
```

状态还有 `.downloading`、`.ready`、`.error`。要进度时用 `downloadAssets(progress:)`，参数是 `Subprogress`。

## Foundation Models 图像输入

```swift
import FoundationModels

let prompt = Prompt {
    "Generate a caption for this image"
    Attachment(image)
}
let response = try await session.respond(to: prompt)
let caption = response.content
```

提示构建器里先写指令，再放 `Attachment`。会话里的用法包括：便利贴照片生成议程、图像描述、室内装饰建议、冰箱照片生成食谱。描述类任务适合模型；固定、要快的视觉任务仍用 Vision。

| | Vision | Foundation Models |
|--|--------|-------------------|
| 能力 | 固定的计算机视觉 API | 按提示做几乎任意描述 |
| 调优 | 人脸、文本、姿势等专项任务很准 | 通用，专项精度不如对应 Vision API |
| 速度 | 通常快到可以逐帧分析视频 | 适合单张图像，不适合实时视频 |

两者可以同时用：把 Vision 包成模型可调用的工具。

## 基于图像的工具调用

模型调用工具时生成参数、运行你的代码，再把返回值写进回复。今年工具参数可以是图像。模型传的是 `ImageReference`，不是像素本身。引用只在生成它的那条记录里有效，用会话的 `history` 取回记录。

```swift
import FoundationModels

struct PlantIdentifierTool: Tool {
    @SessionProperty(\.history) var history

    @Generable
    struct Arguments {
        var image: ImageReference
    }

    func call(arguments: Arguments) async throws -> String {
        let imageReference = arguments.image
        let transcript = Transcript(history)
        guard let imageAttachment = imageReference.resolve(in: transcript) else {
            throw AppError.imageNotFound
        }
        let image = try imageAttachment.pixelBuffer()
        return classifyPlant(image)
    }
}
```

`resolve(in:)` 得到 `imageAttachment`，再转成 `pixelBuffer` 做分析。

Vision 自带两个工具，都在 iOS 27+，模拟器里不可用。返回的是字符串或条码结果，由模型写进回复。可以用 `init(name:description:)` 改工具名和说明，方便模型挑选。

- `BarcodeReaderTool`：扫描条形码和二维码，返回解码内容和码制。传单示例里，模型自己能读出地点和日期，读不出二维码里的网址。
- `OCRTool`：把图中识别到的文字收成一个字符串，适合精细或密集的文本。会话说它支持 30 多种语言。

```swift
import FoundationModels
import Vision

let session = LanguageModelSession(
    model: model,
    tools: [BarcodeReaderTool(), OCRTool()]
)
let response = try await session.respond(generating: EventInfo.self) {
    "Get the date, location, and website from this flyer"
    Attachment(image)
        .label("flyer")
}
```

希望模型把图像传给工具时，必须给附件加 `.label(_:)`。标签是模型识别「把哪张图交给工具」的方式。

也可以用 Vision 的其他请求自己写工具。会话提到的方向：图像分割、面部分析、姿势估计、检测、图像分类、轨迹分析、对象跟踪。完整列表见 [WWDC 2024 Session 10163](https://developer.apple.com/videos/play/wwdc2024/10163/)。本仓库的 Swift API 对照在 [vision.md](vision.md)。

## watchOS 上的显著性裁剪

Vision 今年可以跑在 watchOS 上。手表屏幕小，用物体显著性找出主体边界框再裁剪。

```swift
import Vision

func generateImageCrop(in image: CGImage) async throws -> NormalizedRect? {
    let request = GenerateObjectnessBasedSaliencyImageRequest()
    let observation = try await request.perform(on: image)
    let prominentObjects = observation.salientObjects
    return prominentObjects.first
}
```

`salientObjects` 是检测到的对象边界框。会话取最突出的一个（`first`）作为裁剪区域。示例与说明：

[Implementing saliency-based image cropping in iOS and watchOS](https://developer.apple.com/documentation/Vision/implementing-saliency-based-image-cropping-in-iOS-and-watchOS)

## ⚠️ Important Notes

- 坐标是归一化的，原点在**左下角**，不要传入像素坐标。
- 套索笔触要够粗。细线效果差；线宽至少为图像宽度的 1%。
- 分割请求遵循 `DownloadableAssetsRequest`。`assetStatus == .notReady` 时先 `downloadAssets()`，等到 `.ready` 再 `perform`。追加点超过 13（种子框是 11）会抛错。
- `ImageReference` 不能跨记录使用。`call` 里用 `@SessionProperty(\.history)` 取出记录，再 `resolve(in:)`。解析失败就不要继续分析。
- 图像工具调用依赖附件标签。没有 `.label(_:)` 时，模型无法把对应图像交给工具。
- 实时视频帧用 Vision。Foundation Models 的图像理解留给单张、描述性任务。
- 条形码和密集小字是模型的弱项，优先交给 Vision 工具，而不是只靠图像提示。
