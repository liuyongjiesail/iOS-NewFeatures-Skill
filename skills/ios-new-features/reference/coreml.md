# Core ML

Source: [Core ML](https://developer.apple.com/documentation/coreml)

把编译好的模型放进 App，用 `MLModel` 做预测。状态模型、张量和计算计划是 iOS 18 / iOS 17.4 之后文档首页单独列出的部分。图像模型也可以交给 Vision 的 `CoreMLRequest`，见 [vision.md](vision.md)。

## Quick Example

编译后的 `.mlmodelc` 用异步加载，输入是 `MLFeatureProvider`。

```swift
import CoreML

let model = try await MLModel.load(
    contentsOf: compiledModelURL,
    configuration: MLModelConfiguration()
)
let input = try MLDictionaryFeatureProvider(dictionary: features)
let output = try model.prediction(from: input)
```

`MLModel` 从 iOS 11 就有。下面的状态、张量和计算计划分别从 iOS 18、iOS 18、iOS 17.4 开始。

## Key APIs

| API | 版本 | 作用 |
|-----|------|------|
| `MLModel` | iOS 11+ | 加载模型并预测 |
| `MLModelAsset` | iOS 16+ | 已编译模型的抽象，可从 URL 或内存中的规格创建 |
| `MLFeatureProvider` / `MLDictionaryFeatureProvider` | iOS 11+ | 一组输入或输出特征 |
| `MLFeatureValue` | iOS 11+ | 单个特征值 |
| `MLSendableFeatureValue` | 文档首页列出 | 可跨并发域传递的特征值 |
| `MLBatchProvider` / `MLArrayBatchProvider` | iOS 11+ | 一批特征，供 `predictions(fromBatch:)` |
| `MLState` | iOS 18+ | 有状态模型在多次预测之间保留的缓冲 |
| `MLTensor` | iOS 18+ | 在 ML 计算设备上做张量运算 |
| `MLComputePlan` | iOS 17.4+ | 预测前查看每层会用哪台设备、估算代价 |
| `MLComputePolicy` | iOS 18+ | 指定张量运算走 CPU，或 GPU 可用时走 GPU |
| `MLComputeDevice` | 文档首页列出 | `.cpu` / GPU / Neural Engine 的设备枚举 |
| `MLModelCollection` | 文档首页列出 | 一次部署里的一组模型 |
| `MLModelError` | 文档首页列出 | Core ML 错误，域是 `MLModelErrorDomain` |

## 加载和预测

已编译模型：

```swift
let model = try await MLModel.load(
    contentsOf: compiledModelURL,
    configuration: MLModelConfiguration()
)
```

未编译的模型先 `MLModel.compileModel(at:)`，得到设备上的编译结果 URL，再加载。下载到用户设备后再编译，是文档里的单独流程：[Downloading and Compiling a Model on the User’s Device](https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-users-device)。

`MLModelAsset` 从已编译 URL，或从内存中的模型规格创建。文档里的有状态示例用它再加载：

```swift
let modelAsset = try MLModelAsset(url: modelURL)
let model = try await MLModel.load(asset: modelAsset, configuration: MLModelConfiguration())
```

`modelDescription` 给出每个输入输出特征的名字和类型。批量预测用 `predictions(fromBatch:)`。

可用设备：

```swift
let devices = MLModel.availableComputeDevices
```

设备类型是 `MLCPUComputeDevice`、`MLGPUComputeDevice`、`MLNeuralEngineComputeDevice`。

## 有状态模型（iOS 18+）

状态模型把信息留在状态缓冲里，下一次预测接着用。Swift 符号页上的方法是 `makeState()`。文档概览示例写成 `newState()`，那是 Objective-C 选择子。

```swift
let state = model.makeState()

for _ in 0..<42 {
    _ = try await model.prediction(from: inputFeatures, using: state)
}

state.withMultiArray(for: "accumulator") { buffer in
    // 读取或写入这块 MLMultiArray
}
```

`withMultiArray(_:)` 已弃用，按状态名使用 `withMultiArray(for:_:)`。

## 计算计划和张量

预测之前先看代价。`MLComputePlan` 只对 ML Program 给出 `estimatedCost(of:)`；Neural Network 层可以查 `deviceUsage(for:)`。

```swift
let computePlan = try await MLComputePlan.load(
    contentsOf: modelURL,
    configuration: configuration
)
guard case let .program(program) = computePlan.modelStructure else { return }
guard let mainFunction = program.functions["main"] else { return }

for operation in mainFunction.block.operations {
    let usage = computePlan.deviceUsage(for: operation)
    let cost = computePlan.estimatedCost(of: operation)
}
```

`MLTensor`（iOS 18+）是多维数值或布尔数组，运算在 ML 计算设备上完成。读回 Swift 值用 `shapedArray(of:)`。设备由 `MLComputePolicy` 决定：`.cpuOnly`，或 GPU 可用则用 GPU 的 `.cpuAndGPU`。也可以用 `init(MLComputeUnits)`。

```swift
let result = try await withMLTensorComputePolicy(.cpuAndGPU) {
    let scores = MLTensor(linearSpaceFrom: 0, through: 1, count: 4)
    return await scores.softmax(alongAxis: 0).shapedArray(of: Float.self)
}
```

张量还覆盖加减、归约、`argmax`、`reshape`、`split`、填充和 `resized(to:method:)`。完整列表在 [MLTensor](https://developer.apple.com/documentation/coreml/mltensor)。

## 模型包、个性化和加密

文档首页把这些放在文章里，而不是单个预测 API：

- 取得模型、把 `.mlmodel` 更新成 model package、集成进 App：[Getting a Core ML Model](https://developer.apple.com/documentation/coreml/getting-a-core-ml-model)、[Integrating a Core ML Model into Your App](https://developer.apple.com/documentation/coreml/integrating-a-core-ml-model-into-your-app)
- 序列输入（RNN）：[Making Predictions with a Sequence of Inputs](https://developer.apple.com/documentation/coreml/making-predictions-with-a-sequence-of-inputs)
- 加层、用新数据个性化：Model Customization、Model Personalization
- 加密：生成密钥，以及在编译期内置模型。具体编译参数以这两篇文章为准
- 性能：在 Xcode 里对 Mac 或连接的设备生成性能报告

`MLModelCollection` 表示一次模型部署里的一组模型。

## ⚠️ Important Notes

- 预测吃的是**已编译**模型。包进 App 的 `.mlmodel` 由 Xcode 编成 `.mlmodelc`；运行时下载的模型要先 `compileModel(at:)`。
- 同一份 `MLState` 上的有状态预测必须串行。两次同时跑，行为未定义。预测进行中不要读写真状态缓冲。
- `MLComputePlan.estimatedCost(of:)` 针对 ML Program 的 operation。旧的 Neural Network 用 `deviceUsage(for:)` 看层会落在哪台设备。
- 张量运算的设备用 `withMLTensorComputePolicy`，不要和 `MLModelConfiguration` 混成同一个开关。模型本身的设备仍由加载时的 `MLModelConfiguration` 和 `availableComputeDevices` 决定。
- 后台在 Neural Engine 上推理需要文档里的 Background Inference entitlement。
- 图像分类、检测更适合 Vision 的 `CoreMLRequest`：它负责预处理和坐标。直接用 `MLModel` 时，输入特征的形状和类型必须和 `modelDescription` 一致。
