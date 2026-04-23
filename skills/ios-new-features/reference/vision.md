# Vision Framework — iOS 18+ Swift-Native API 完整参考

> **适用范围：** iOS 18+ / macOS 15+（新 Swift-native API）
> iOS 26+ 新增 API 单独标注
> 所有 API 均使用 `async/await`，不再需要回调或强制类型转换

---

## 架构入口

### ImageRequestHandler

单张图像分析入口，支持多种图像来源：

```swift
ImageRequestHandler(cgImage: CGImage)
ImageRequestHandler(cvPixelBuffer: CVPixelBuffer)
ImageRequestHandler(url: URL)
ImageRequestHandler(data: Data)
```

**执行方式：**

```swift
// 单个请求
let observations = try await handler.perform(request)

// 多个请求同时执行（参数包语法）
let (r1, r2) = try await handler.perform(request1, request2)

// 流式执行，结果完成一个推一个
for try await result in handler.performAll(request1, request2) {
    // 每个请求完成时立即处理
}
```

---

### SequenceRequestHandler

连续帧 / 视频分析入口，适合与 `AVCaptureSession` 配合使用：

```swift
let handler = SequenceRequestHandler()
// 每帧调用一次
let observations = try await handler.perform(request, on: pixelBuffer)
```

---

## 人脸检测

### DetectFaceRectanglesRequest

检测图像中人脸的矩形边界区域。

**返回：** `[FaceObservation]`

**FaceObservation 属性：**
- `boundingBox: CGRect` — 归一化坐标（0~1），左下角为原点
- `confidence: Float` — 置信度（0~1）
- `uuid: UUID` — 用于跨帧追踪同一张脸

```swift
let request = DetectFaceRectanglesRequest()
let faces = try await ImageRequestHandler(cgImage: image).perform(request)
for face in faces {
    print(face.boundingBox, face.confidence)
}
```

---

### DetectFaceLandmarksRequest

检测面部 76 个关键点，包含眼睛、鼻子、嘴巴、眉毛、脸部轮廓等。

**返回：** `[FaceObservation]`（含 `landmarks` 属性）

**FaceLandmarks2D 子属性（均为可选）：**
- `leftEye` / `rightEye` — 眼睛轮廓点
- `leftEyebrow` / `rightEyebrow` — 眉毛
- `nose` — 鼻子
- `noseCrest` — 鼻梁
- `medianLine` — 面部中轴线
- `outerLips` / `innerLips` — 嘴唇外轮廓 / 内轮廓
- `leftPupil` / `rightPupil` — 瞳孔（仅高质量图像）
- `faceContour` — 脸部轮廓

```swift
let request = DetectFaceLandmarksRequest()
let faces = try await handler.perform(request)
for face in faces {
    if let landmarks = face.landmarks {
        let leftEyePoints = landmarks.leftEye?.normalizedPoints
    }
}
```

---

### DetectFaceCaptureQualityRequest

评估人脸图像的拍摄质量，用于筛选最佳帧。

**返回：** `[FaceObservation]`（含 `faceCaptureQuality` 属性）

**关键属性：**
- `faceCaptureQuality: Float?` — 质量分（0~1，1 最佳）

**典型场景：** 连拍选优、视频流抽帧存储最清晰的人脸。

```swift
let request = DetectFaceCaptureQualityRequest()
let faces = try await handler.perform(request)
let best = faces.max(by: { ($0.faceCaptureQuality ?? 0) < ($1.faceCaptureQuality ?? 0) })
```

---

## 人体 & 姿态

### DetectHumanRectanglesRequest

检测画面中完整人体或上半身的矩形区域。

**返回：** `[HumanObservation]`

**配置属性：**
- `upperBodyOnly: Bool` — 是否仅检测上半身（默认 `false`）

**HumanObservation 属性：**
- `boundingBox: CGRect`
- `confidence: Float`

---

### DetectHumanBodyPoseRequest

检测人体骨骼关键点（17 个关节），**iOS 18 增强版支持同时返回手部数据**。

**返回：** `[HumanBodyPoseObservation]`

**配置属性：**
- `detectsHands: Bool` — 开启后同时检测手部关键点（iOS 18 新增）

**HumanBodyPoseObservation 关键点（JointName）：**
- 头部：`nose`、`leftEye`、`rightEye`、`leftEar`、`rightEar`
- 上肢：`leftShoulder`、`rightShoulder`、`leftElbow`、`rightElbow`、`leftWrist`、`rightWrist`
- 躯干：`neck`、`root`（髋部中心）
- 下肢：`leftHip`、`rightHip`、`leftKnee`、`rightKnee`、`leftAnkle`、`rightAnkle`
- 手部（需开启 `detectsHands`）：`rightHandObservation`、`leftHandObservation`

```swift
var request = DetectHumanBodyPoseRequest()
request.detectsHands = true
let poses = try await handler.perform(request)
for pose in poses {
    let wrist = try pose.recognizedPoint(.leftWrist)
    print(wrist.location, wrist.confidence)
}
```

---

### DetectHumanHandPoseRequest

专门检测手部 21 个关键点，精度高于 Body Pose 中的手部检测。

**返回：** `[HumanHandPoseObservation]`

**配置属性：**
- `maximumHandCount: Int` — 最多检测几只手（默认 2）

**关键点分组（JointName）：**
- 手腕：`wrist`
- 大拇指：`thumbCMC`、`thumbMP`、`thumbIP`、`thumbTip`
- 食指：`indexMCP`、`indexPIP`、`indexDIP`、`indexTip`
- 中指：`middleMCP`、`middlePIP`、`middleDIP`、`middleTip`
- 无名指：`ringMCP`、`ringPIP`、`ringDIP`、`ringTip`
- 小拇指：`littleMCP`、`littlePIP`、`littleDIP`、`littleTip`

```swift
let request = DetectHumanHandPoseRequest()
let hands = try await handler.perform(request)
for hand in hands {
    let tip = try hand.recognizedPoint(.indexTip)
    print("食指指尖：\(tip.location)")
}
```

---

### DetectHumanBodyPose3DRequest

在三维空间中估计人体骨骼姿态，返回带深度信息的 3D 关节坐标。

**返回：** `[HumanBodyPose3DObservation]`

**关键属性：**
- `recognizedPoints(_ groupName:)` — 按组获取 3D 关节点
- 每个关节包含 `position: simd_float4x4`（世界坐标变换矩阵）

**适用场景：** AR 人体绑定、运动姿态分析、健身 App。

---

### DetectAnimalBodyPoseRequest

检测动物（猫、狗）的骨骼关键点。

**返回：** `[AnimalBodyPoseObservation]`

**支持关键点：**
- `head`、`leftEar`、`rightEar`、`neck`
- `leftFrontPaw`、`rightFrontPaw`、`leftBackPaw`、`rightBackPaw`
- `tailTop`、`tailBottom`

---

## 文字识别

### DetectTextRectanglesRequest

仅检测文字所在的矩形区域，**不识别内容**，速度快适合预处理。

**返回：** `[TextObservation]`

**配置属性：**
- `reportCharacterBoxes: Bool` — 是否返回每个字符的矩形（默认 `false`）

**TextObservation 属性：**
- `boundingBox: CGRect`
- `characterBoxes: [TextObservation]?`

---

### RecognizeTextRequest

完整 OCR，识别文字内容 + 位置，支持 18 种语言。

**返回：** `[RecognizedTextObservation]`

**配置属性：**
- `recognitionLevel: RecognitionLevel` — `.accurate`（精准，慢）或 `.fast`（快速）
- `recognitionLanguages: [String]` — 语言优先级列表，如 `["zh-Hans", "en-US"]`
- `usesLanguageCorrection: Bool` — 是否启用语言纠错（默认 `true`）
- `customWords: [String]` — 自定义词汇，提升识别率
- `minimumTextHeight: Float` — 最小文字高度（相对图像高度，0~1）
- `automaticallyDetectsLanguage: Bool` — 自动检测语言

**RecognizedTextObservation 属性：**
- `topCandidates(_ n: Int) -> [RecognizedText]` — 返回前 N 个候选结果
- `RecognizedText.string: String` — 识别到的文字
- `RecognizedText.confidence: Float`
- `RecognizedText.boundingBox(for range:)` — 特定文字范围的坐标

```swift
var request = RecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["zh-Hans", "en-US"]
let observations = try await handler.perform(request)
for obs in observations {
    print(obs.topCandidates(1).first?.string ?? "")
}
```

---

## 文档理解（iOS 26+）

### RecognizeDocumentsRequest

结构化文档识别，不只提取文字，还理解文档的完整语义结构。

**返回：** `[DocumentObservation]`

**支持语言：** 26 种

**DocumentObservation 层级结构：**

```
DocumentObservation
└── document: Container
    ├── text
    │   ├── transcript: String          // 全文纯文字
    │   ├── lines: [Line]               // 按行
    │   ├── paragraphs: [Paragraph]     // 按段落
    │   ├── words: [Word]               // 按词（中/日/韩/泰不支持）
    │   └── detectedData: [DetectedData] // 邮箱、电话、URL 等关键信息
    ├── tables: [Table]
    │   └── rows: [[Cell]]
    │       └── Cell
    │           ├── content: Container  // 单元格内容（递归结构）
    │           ├── row: Range          // 跨行范围
    │           └── column: Range       // 跨列范围
    ├── lists: [List]
    │   └── items: [Item]
    │       └── content: Container
    └── barcodes: [BarcodeObservation]
```

**detectedData 支持类型：**
- `.emailAddress` — 邮箱地址
- `.phoneNumber` — 电话号码
- `.url` — 网址链接
- `.date` — 日期时间
- `.currency` — 金额
- `.measurement` — 度量单位
- `.trackingNumber` — 快递单号
- `.flightNumber` — 航班号

每个元素都有 `boundingRegion` 坐标属性。

```swift
let request = RecognizeDocumentsRequest()
let observations = try await ImageRequestHandler(data: imageData).perform(request)
guard let doc = observations.first?.document else { return }

// 读全文
print(doc.text.transcript)

// 遍历表格
for table in doc.tables {
    for row in table.rows {
        for cell in row {
            print(cell.content.text.transcript)
        }
    }
}

// 提取关键信息
for data in doc.text.detectedData {
    switch data.match.details {
    case .emailAddress(let email): print(email.emailAddress)
    case .phoneNumber(let phone):  print(phone.phoneNumber)
    case .url(let url):            print(url.url)
    default: break
    }
}
```

---

## 条码 & 二维码

### DetectBarcodesRequest

检测并解码图像中的条码，支持 20+ 种格式。

**返回：** `[BarcodeObservation]`

**配置属性：**
- `symbologies: [BarcodeSymbology]` — 指定要检测的格式（不指定则检测所有）

**支持格式（BarcodeSymbology）：**
- 二维码：`qr`、`dataMatrix`、`aztec`、`pdf417`
- 一维码：`ean8`、`ean13`、`upce`、`code39`、`code93`、`code128`、`itf14`
- 其他：`gs1DataBar`、`microQR`、`msiPlessey` 等

**BarcodeObservation 属性：**
- `payloadStringValue: String?` — 解码后的文字内容
- `symbology: BarcodeSymbology` — 条码类型
- `boundingBox: CGRect`
- `isColorInverted: Bool` — 是否为反色码

---

## 图像质量评估

### CalculateImageAestheticsScoresRequest

评估图像的美学质量和实用性，适合照片筛选、相册整理场景。

**返回：** `[ImageAestheticsScoresObservation]`（通常只有一个结果）

**ImageAestheticsScoresObservation 属性：**
- `overallScore: Float` — 综合评分（-1~1，越高越美观）
- `isUtility: Bool` — 是否为功能性图片（截图、收据、文档等）

**评估维度：** 模糊度、曝光、构图、色彩、主体清晰度

**搭配使用建议：**
- 有人脸时 → 配合 `DetectFaceCaptureQualityRequest` 一起用
- 无人脸时 → 单独用此 API

```swift
let request = CalculateImageAestheticsScoresRequest()
let result = try await handler.perform(request)
if let score = result.first {
    if score.isUtility {
        print("功能性图片（截图/文档）")
    } else {
        print("美学评分：\(score.overallScore)")
    }
}
```

---

### DetectLensSmudgeRequest（iOS 26+）

检测拍摄图像时摄像头镜头是否有污迹，适用于相机 App 质量控制。

**返回：** `LensSmudgeObservation`

**LensSmudgeObservation 属性：**
- `confidence: Float` — 污迹置信度（0~1，越高越脏）

**注意事项：**
- 运动模糊、长曝光、拍摄云雾等场景可能误判为高分
- 建议阈值：`0.9` 以上再提示用户

**实时相机用法：**

```swift
// 在 AVCaptureVideoDataOutputSampleBufferDelegate 中
func captureOutput(_ output: AVCaptureOutput,
                   didOutput sampleBuffer: CMSampleBuffer, ...) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    Task {
        let request = DetectLensSmudgeRequest()
        let obs = try await ImageRequestHandler(cvPixelBuffer: pixelBuffer).perform(request)
        if obs.confidence > 0.9 {
            await MainActor.run { showCleanLensPrompt() }
        }
    }
}
```

---

## 图像分类 & 显著性

### ClassifyImageRequest

使用内置 ML 模型对图像进行语义分类，支持 1000+ 类别。

**返回：** `[ClassificationObservation]`

**ClassificationObservation 属性：**
- `identifier: String` — 类别标识（如 `"cat"`、`"sunset"`）
- `confidence: Float` — 置信度（0~1）

```swift
let request = ClassifyImageRequest()
let classifications = try await handler.perform(request)
let topResults = classifications.prefix(5)
for c in topResults {
    print("\(c.identifier): \(c.confidence)")
}
```

---

### GenerateAttentionBasedSaliencyImageRequest

基于人眼注意力模型生成显著区域热力图，标记人最可能看的区域。

**返回：** `[SaliencyImageObservation]`

**SaliencyImageObservation 属性：**
- `pixelBuffer: CVPixelBuffer` — 热力图（灰度，亮度越高越显著）
- `salientObjects: [ObjectObservation]?` — 显著区域矩形列表

**适用场景：** 自动裁剪、封面图选取、内容感知缩放。

---

### GenerateObjectnessBasedSaliencyImageRequest

基于物体检测模型生成显著区域热力图，标记图中的主要物体位置。

**返回：** `[SaliencyImageObservation]`（结构同上）

**与 Attention 版本的区别：**
- Attention：模拟人眼注意力，对人脸、文字更敏感
- Objectness：纯物体检测导向，更均匀

---

### GenerateImageFeaturePrintRequest

为图像生成高维特征向量（Feature Print），用于图像相似度比较。

**返回：** `[FeaturePrintObservation]`

**FeaturePrintObservation 方法：**
- `computeDistance(_ to: FeaturePrintObservation) throws -> Float` — 计算两张图的距离（越小越相似）

```swift
let request = GenerateImageFeaturePrintRequest()
let print1 = try await handler1.perform(request).first!
let print2 = try await handler2.perform(request).first!
let distance = try print1.computeDistance(print2)
print("相似度距离：\(distance)") // 接近 0 表示非常相似
```

**适用场景：** 图片去重、以图搜图、相似推荐。

---

## 物体 & 轮廓检测

### DetectRectanglesRequest

检测图像中的矩形区域，适用于文档扫描、白板拍摄、卡片识别。

**返回：** `[RectangleObservation]`

**配置属性：**
- `minimumAspectRatio: Float` — 最小宽高比（0~1）
- `maximumAspectRatio: Float` — 最大宽高比
- `minimumSize: Float` — 最小矩形相对面积
- `maximumObservations: Int` — 最多返回几个矩形
- `minimumConfidence: Float` — 置信度阈值
- `quadratureTolerance: Float` — 角点偏离直角的容忍度（度）

**RectangleObservation 属性：**
- `topLeft` / `topRight` / `bottomLeft` / `bottomRight` — 四角归一化坐标

---

### DetectContoursRequest

检测图像中物体的边缘轮廓，返回层级化的轮廓路径树。

**返回：** `[ContoursObservation]`

**配置属性：**
- `contrastAdjustment: Float` — 对比度调整（-1~1）
- `contrastPivot: NSNumber?` — 对比度基准值
- `detectsDarkOnLight: Bool` — 检测亮底深色轮廓（默认 `true`）

**ContoursObservation 属性：**
- `contourCount: Int` — 轮廓总数
- `topLevelContours: [VNContour]` — 顶层轮廓列表
- `contour(at index: Int)` — 按索引取轮廓
- 每个 `VNContour`：
  - `normalizedPoints: [CGPoint]`
  - `childContourCount: Int`（内嵌轮廓）
  - `polygonApproximation(epsilon:)` — 多边形近似简化

---

## 物体追踪

### TrackObjectRequest

跨帧追踪任意物体，需先用其他请求获得初始位置。

**返回：** `[DetectedObjectObservation]`

**配置属性：**
- `inputObservation: DetectedObjectObservation` — 上一帧的观察结果（必须提供）
- `trackingLevel: TrackingLevel` — `.accurate` 或 `.fast`

**使用模式（配合 SequenceRequestHandler）：**

```swift
let seqHandler = SequenceRequestHandler()
var lastObservation: DetectedObjectObservation = initialObservation

for pixelBuffer in videoFrames {
    let request = TrackObjectRequest(observation: lastObservation)
    let results = try await seqHandler.perform(request, on: pixelBuffer)
    lastObservation = results.first!
}
```

---

### TrackRectangleRequest

跨帧追踪矩形区域（如文件、卡片），比 TrackObjectRequest 更精确用于矩形目标。

**返回：** `[RectangleObservation]`

**配置属性：**
- `inputObservation: RectangleObservation` — 上一帧矩形结果
- `trackingLevel: TrackingLevel`

---

## 人像 & 前景分割

### GeneratePersonSegmentationRequest

生成人体区域的语义分割 mask，用于人像抠图、背景替换。

**返回：** `[InstanceMaskObservation]`（含 mask 图像）

**配置属性：**
- `qualityLevel: QualityLevel` — `.accurate`、`.balanced`、`.fast`
- `outputPixelFormat: OSType` — mask 输出格式（如 `kCVPixelFormatType_OneComponent8`）

**获取 mask：**

```swift
let request = GeneratePersonSegmentationRequest()
let result = try await handler.perform(request).first!
let maskBuffer = result.pixelBuffer  // 灰度 mask，255=人体，0=背景
```

---

### GeneratePersonInstanceMaskRequest

多人场景下为每个人生成独立 mask，可精确控制每个人。

**返回：** `[InstanceMaskObservation]`

**关键方法：**
- `allInstances: IndexSet` — 所有检测到的人体实例编号
- `generateScaledMaskForImage(forInstances:from:)` — 生成指定实例的 mask

```swift
let result = try await handler.perform(GeneratePersonInstanceMaskRequest()).first!
let allPeople = result.allInstances
// 只保留第一个人
let mask = try result.generateScaledMaskForImage(
    forInstances: IndexSet([allPeople.first!]), from: handler)
```

---

### GenerateForegroundInstanceMaskRequest

检测所有前景物体（不限于人体）并生成 mask，实现通用背景移除。

**返回：** `[InstanceMaskObservation]`（结构同上）

**与 PersonSegmentation 的区别：**
- Person：只分割人体
- ForegroundInstance：分割所有前景物体（人、动物、物品等）

---

## 光流 & 图像配准

### GenerateOpticalFlowRequest

计算两帧之间每个像素的运动向量，生成光流图。

**返回：** `[OpticalFlowObservation]`

**配置属性：**
- `computationAccuracy: ComputationAccuracy` — `.low`、`.medium`、`.high`、`.veryHigh`
- `keepNetworkOutput: Bool` — 是否保留网络原始输出

**OpticalFlowObservation 属性：**
- `pixelBuffer: CVPixelBuffer` — 双通道浮点图（x/y 方向位移）

**适用场景：** 运动检测、视频防抖、动作分析。

---

### TranslationalImageRegistrationRequest

计算两张图像之间的平移偏移量，用于图像稳定和对齐。

**返回：** `[ImageTranslationAlignmentObservation]`

**属性：**
- `alignmentTransform: CGAffineTransform` — 平移变换矩阵

---

### HomographicImageRegistrationRequest

计算两张图像之间的单应性矩阵，支持旋转、缩放、透视变换，精度更高。

**返回：** `[ImageHomographicAlignmentObservation]`

**属性：**
- `warpTransform: matrix_float3x3` — 3x3 单应性变换矩阵

---

## 动物 & 场景

### RecognizeAnimalsRequest

识别图像中的动物种类。

**返回：** `[RecognizedObjectObservation]`

**当前支持：** 猫（`cat`）、狗（`dog`）

**获取支持的动物列表：**

```swift
let supported = try RecognizeAnimalsRequest.supportedIdentifiers()
print(supported) // ["dog", "cat"]
```

---

### DetectHorizonRequest

检测图像中地平线的角度，用于图像纠偏、水平校正。

**返回：** `[HorizonObservation]`

**HorizonObservation 属性：**
- `angle: CGFloat` — 地平线与水平线的偏转角度（弧度）
- `transform(for size:)` — 返回将图像纠正为水平的仿射变换

```swift
let obs = try await handler.perform(DetectHorizonRequest()).first!
let correctionTransform = obs.transform(for: imageSize)
```

---

### DetectDocumentSegmentationRequest

检测图像中文档的边缘，用于扫描仪、文档矫正场景。

**返回：** `[RectangleObservation]`（文档四角坐标）

---

## Core ML 集成

### CoreMLRequest

将自定义 Core ML 模型嵌入 Vision 管线，自动处理图像预处理和坐标转换。

**返回：** `[CoreMLFeatureValueObservation]` 或 `[RecognizedObjectObservation]`（取决于模型输出类型）

**初始化：**

```swift
let model = try MLModel(contentsOf: modelURL)
let visionModel = try VNCoreMLModel(for: model)
let request = CoreMLRequest(model: visionModel)
let results = try await handler.perform(request)
```

**支持的模型输出类型：**
- 分类器（Classifier）→ `ClassificationObservation`
- 目标检测（Object Detector）→ `RecognizedObjectObservation`
- 通用特征（Feature Value）→ `CoreMLFeatureValueObservation`

---

## 坐标系工具

Vision 使用归一化坐标（0~1），原点在**左下角**，与 UIKit 方向相反。iOS 18 新增统一转换方法：

```swift
// 将 Vision 坐标转为 UIKit / SwiftUI 坐标
let imageCoord = observation.boundingBox.toImageCoordinates(
    in: imageSize,
    origin: .upperLeft  // UIKit 原点
)
```

---

## 性能建议

| 建议 | 说明 |
|------|------|
| 并发上限 | 最多同时跑 **5 个** Vision 请求，避免内存压力 |
| 神经网络引擎 | 在搭载 Neural Engine 的设备上，Vision 会自动选用 ANE，无需手动配置 |
| 实时场景 | 使用 `SequenceRequestHandler`，避免重复初始化 `ImageRequestHandler` |
| 多请求 | 用 `handler.perform(r1, r2)` 参数包语法，比分开调用更高效 |
| 选择精度 | `.fast` 适合实时预览，`.accurate` 适合最终处理 |

---

## 版本速查

| 版本 | 新增 / 变化 |
|------|------------|
| iOS 18 / macOS 15 | 全部 API Swift-native 化（去 VN 前缀），async/await，`CalculateImageAestheticsScoresRequest`，`DetectHumanBodyPoseRequest` 支持 `detectsHands` |
| iOS 26 / macOS 26 | `RecognizeDocumentsRequest`（结构化文档）、`DetectLensSmudgeRequest`（镜头污迹检测） |

---

## 参考资料

- [Vision Framework — Apple Developer Documentation](https://developer.apple.com/documentation/vision)
- [WWDC24 — Discover Swift enhancements in the Vision framework](https://developer.apple.com/videos/play/wwdc2024/10163/)
- [WWDC25 — Read documents using the Vision framework](https://developer.apple.com/videos/play/wwdc2025/272/)
