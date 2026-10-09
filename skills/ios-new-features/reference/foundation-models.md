# Foundation Models (iOS 26+)

Source: [Foundation Models](https://developer.apple.com/documentation/foundationmodels)

在设备上做语言理解、结构化输出和工具调用。图像附件、Private Cloud Compute、动态 profile 和 watchOS 上的会话从 iOS 27 / watchOS 27 开始。图像工具的具体写法见 [vision-image-understanding.md](vision-image-understanding.md)。

设备上的模型适合摘要、抽实体、改写、分类、短文和标签。文档明确不适合的请求包括基础算术、写代码、以及需要大量世界知识的逻辑推理。复杂任务拆成多步，或改用 guided generation、工具调用、Private Cloud Compute。

## Quick Example

先看模型是否可用，再用独立的 instructions 建会话。

```swift
import FoundationModels

let model = SystemLanguageModel.default
guard case .available = model.availability else { return }

let session = LanguageModelSession(instructions: """
You are a motivational workout coach that provides quotes to inspire \
and motivate athletes.
""")
let response = try await session.respond(to: "Generate a motivational quote for my next workout.")
let quote = response.content
```

单轮交互每次新建 `LanguageModelSession()`。多轮要保留上文时，复用同一个 session。

## Key APIs

| API | 版本 | 作用 |
|-----|------|------|
| `SystemLanguageModel` | iOS 26+ | 设备上的 Apple 基础模型。`default` 是基础版本 |
| `LanguageModelSession` | iOS 26+ / watchOS 27+ | 一轮轮对话。`respond` 出全文，`streamResponse` 出增量 |
| `Instructions` / `Prompt` | iOS 26+ | 行为说明和当次提问分开。模型更听从 instructions |
| `GenerationOptions` | iOS 26+ | `temperature`、`sampling`、`maximumResponseTokens`、`toolCallingMode` |
| `ContextOptions` | 文档首页列出 | `includeSchemaInPrompt`、`reasoningLevel` |
| `@Generable` / `@Guide` | iOS 26+ | 让模型按 Swift 类型输出 |
| `Tool` | iOS 26+ / watchOS 27+ | 模型在生成过程中调用的外部代码 |
| `Attachment` | iOS 27+ | 提示里的图像等资产。工具调用前用 `label(_:)` |
| `ImageReference` | iOS 27+ | 工具参数里对会话记录中某张图的引用 |
| `PrivateCloudComputeLanguageModel` | iOS 27+ | 32K token 上下文，请求走 Private Cloud Compute |
| `LanguageModel` | 文档首页列出 | 自定义模型协议，可接 Core AI 导出的开源模型 |

## 可用性

设备能否用模型，取决于设备和地区是否支持 Apple Intelligence。打开 Apple Intelligence 后，模型下载完成前也不可用。先判断，再准备降级界面。

```swift
switch SystemLanguageModel.default.availability {
case .available:
    break
case .unavailable(.appleIntelligenceNotEnabled):
    break
case .unavailable(.deviceNotEligible):
    break
case .unavailable(.modelNotReady):
    break
case .unavailable(let other):
    break
}
```

`UnavailableReason` 有三种：`appleIntelligenceNotEnabled`、`deviceNotEligible`、`modelNotReady`。`isAvailable` 表示系统是否已经完全就绪。

`contextSize` 是模型能接受的最大 token 数。`supportedLanguages` 和 `supportsLocale(_:)` 看语言；文档示例直接写 `SystemLanguageModel.default.supportsLocale()`。`tokenCount(for:)` 用来估 instructions 的 token。

按场景创建模型：

```swift
let tagging = SystemLanguageModel(useCase: .contentTagging)
let general = SystemLanguageModel(useCase: .general, guardrails: .default)
```

`UseCase` 有 `.general` 和 `.contentTagging`。`Guardrails.default` 拦截不安全的输入和输出。`permissiveContentTransformations` 允许把可能不安全的输入改写成文本回复，用在需要转换原文的场景。

## 会话

`Instructions` 定义角色、任务、文风和拒绝方式。`Prompt` 是这一次的问题。提示用直接的命令，一次只做一件事，并用 “in a single sentence” 这类短语限制长度。角色用 “You are ...” 来写。

```swift
let options = GenerationOptions(temperature: 1.0)
let response = try await session.respond(to: prompt, options: options)
```

`temperature` 越高，文档示例越把它用于更有创造性的输出。采样用 `GenerationOptions.SamplingMode`：

- `.greedy` 每次选概率最高的 token
- `.random(top:seed:)` 在固定数量的高概率 token 里抽
- `.random(probabilityThreshold:seed:)` 按概率阈值决定候选数量

`prewarm(promptPrefix:)` 提前把资源载入内存。上下文管理文章里的示例调用的是 `prewarm()`。`isResponding` 表示正在生成。`usage` 累计各次回复用掉的 token。

流式输出是 `ResponseStream`，元素是尚未完成的快照：

```swift
let stream = session.streamResponse(
    to: prompt,
    options: GenerationOptions(temperature: 1.0)
)
for try await snapshot in stream {
    print(snapshot.content)
}
```

`ContextOptions(reasoningLevel:)` 控制回答前可以输出多少推理。级别是 `.light`、`.moderate`、`.deep`，以及 `.custom(String)`。带 `contextOptions` 和 `metadata` 的 `respond` 重载用来附加这些上下文。

会话历史在 `transcript` 里。条目有 `.instructions`、`.prompt`、`.toolCalls`、`.toolOutput`、`.response`、`.reasoning`。可以用 `LanguageModelSession(transcript:)` 从记录恢复。

## 上下文窗口

长文按段切开，每段用新的 session，并把上一段摘要带进下一段，最后再合并。超出窗口会抛 `LanguageModelError.contextSizeExceeded`。

压缩历史时，文档示例只保留第一条和最后一条：

```swift
func newContextualSession(with originalSession: LanguageModelSession) -> LanguageModelSession {
    let allEntries = originalSession.transcript
    let condensedEntries = [allEntries.first, allEntries.last].compactMap { $0 }
    let condensedTranscript = Transcript(entries: condensedEntries)
    let newSession = LanguageModelSession(transcript: condensedTranscript)
    newSession.prewarm()
    return newSession
}
```

模型版本变化后，用 `#available` 从新到旧选择提示。文档示例把 iOS 26.4 及以后和 26.0–26.3 分成两套提示。

## 结构化输出

```swift
@Generable(description: "Basic profile information about a cat")
struct CatProfile {
    var name: String

    @Guide(description: "The age of the cat", .range(0...20))
    var age: Int
}

let response = try await session.respond(
    to: "Generate a cute rescue cat",
    generating: CatProfile.self
)
let profile = response.content
```

内置类型也可以：`respond(to:generating: Float.self)`、`generating: [String].self`。`@Generable` 枚举用来把答案限制在固定 case 里。

文档示例里出现过的 `@Guide` 约束：`description`、`.range`、`.minimum`、`.maximum`、`.minimumCount`、`.maximumCount`。属性名已经清楚时可以不加 description。类型名、属性名和 Guide 文案都会被当成模型输入，多语言时也要写成模型支持的语言。

运行时拼 schema：

```swift
let menuSchema = DynamicGenerationSchema(
    name: "Menu",
    properties: [
        DynamicGenerationSchema.Property(
            name: "dailySoup",
            schema: DynamicGenerationSchema(
                name: "dailySoup",
                anyOf: ["Tomato", "Chicken Noodle", "Clam Chowder"]
            )
        )
    ]
)
let schema = try GenerationSchema(root: menuSchema, dependencies: [])
let response = try await session.respond(to: prompt, schema: schema)
```

`includeSchemaInPrompt` 决定要不要把 schema 写进提示。动态 schema 的结果是 `GeneratedContent`。

## 工具

`call(arguments:)` 的返回值要能放回提示。文档示例返回 `@Generable` 结构体，或 `Encodable` 的 `Forecast`。

```swift
let session = LanguageModelSession(tools: [BreadDatabaseTool()])
let response = try await session.respond(
    to: "What's a good sourdough recipe?",
    options: GenerationOptions(toolCallingMode: .required)
)
```

`GenerationOptions.ToolCallingMode`：

- `.allowed`：可以调用，也可以不调用
- `.required`：必须调用一个或多个工具
- `.disallowed`：禁止调用

失败时捕获 `LanguageModelSession.ToolCallError`。`error.tool.name` 是工具名，`error.underlyingError` 是工具自己抛出的错误。

## 动态会话（iOS 27+）

静态 session 的 instructions 在初始化时定下来。`DynamicInstructions` 和 `LanguageModelSession.DynamicProfile` 会在每次调用前按 App 状态重新求值，只带上当前需要的说明、工具和采样参数。

```swift
struct PresentationInstructions: DynamicInstructions {
    var isEditingImage = true

    var body: some DynamicInstructions {
        Instructions {
            "Help people improve their presentation."
        }
        if isEditingImage {
            ImageEditingInstructions()
        }
    }
}

let session = LanguageModelSession(dynamicInstructions: PresentationInstructions())
```

`Profile` 上可以改 `.model`、`.temperature`、`.reasoningLevel`、`.toolCallingMode`。内层 modifier 覆盖外层。工具调用次数这类状态用 `@SessionPropertyEntry` 加在 `SessionPropertyValues` 上，再用 `@SessionProperty` 读。出错后要保留记录时用 `.transcriptErrorHandlingPolicy(.preserveTranscript)`。

## 内容标签

`.contentTagging` 不是聊天模型。它根据输入给出一到几个小写词的标签，适合动作、物体、情绪、主题。社交标签这类生成仍用 `.general`。

```swift
let model = SystemLanguageModel(useCase: .contentTagging)
let session = LanguageModelSession(model: model, instructions: """
    Provide the two tags that are most significant in the context of topics.
    """)
let response = try await session.respond(
    to: prompt,
    generating: ContentTaggingResult.self
)
```

工具调用产出的文本要再打标签时，先用 `.general` 跑工具，再把工具输出交给 content tagging 模型。

## 语言

同一套设备模型能理解 Apple Intelligence 支持的多种语言。提示、instructions、`@Generable` 属性名和 `@Guide` 描述都要使用支持的语言。

指定用户语言时，文档要求使用固定句式，美式英语可以省略：

```swift
func localeInstructions(for locale: Locale = Locale.current) -> String {
    if Locale.Language(identifier: "en_US").isEquivalent(to: locale.language) {
        return ""
    } else {
        return "The person's locale is \(locale.identifier)."
    }
}
```

强制输出语言时写进 instructions，例如 `"You MUST respond in U.S. English."`。不支持的语言会抛 `LanguageModelError.unsupportedLanguageOrLocale`。

## 图像（iOS 27+）

`Attachment` 把图像和文字放在同一个提示里。要让模型把某一张图传给工具，必须加标签。

```swift
let response = try await session.respond {
    "Describe this image:"
    Attachment(image)
}

let prompt = Prompt {
    "Compare these two images:"
    Attachment(firstImage).label("image-0")
    Attachment(secondImage).label("image-1")
}
```

也可以从文件 URL 创建：`Attachment(imageURL:orientation:)`。工具参数里的图像是 `ImageReference`，只在生成它的那条记录里有效。解析步骤见 [vision-image-understanding.md](vision-image-understanding.md)。

## Private Cloud Compute（iOS 27+）

需要 entitlement `com.apple.developer.private-cloud-compute`。文档给出的上下文是 32K token，推理比设备模型强，不需要自管 API key。设备要支持 Apple Intelligence，并且受每日请求额度限制；iCloud+ 可以增加额度。先用设备模型评估，不够再用 PCC。

```swift
let model = PrivateCloudComputeLanguageModel()
switch model.availability {
case .available:
    break
case .unavailable(.deviceNotEligible):
    break
case .unavailable(.systemNotReady):
    break
case .unavailable(let other):
    break
}

let session = LanguageModelSession(model: model)
let response = try await session.respond(
    to: "What are the tradeoffs in this architecture?",
    contextOptions: ContextOptions(reasoningLevel: .deep)
)
```

额度：`quotaUsage.isLimitReached`、`quotaUsage.status` 的 `.belowLimit`，以及其中的 `isApproachingLimit`。`quotaUsage.limitIncreaseSuggestion?.show()` 打开升级选项。PCC 的 `supportsLocale` 是 `async throws`。设备上的 `SystemLanguageModel.supportsLocale` 是同步的。PCC 也有 guardrails，策略不能像设备模型那样直接配置。

## 安全与错误

框架有内置安全层，App 仍要按自己的场景加限制：封闭主题、`@Generable` 枚举、以及 instructions 里的拒绝句。

```swift
do {
    let response = try await session.respond(to: prompt)
} catch LanguageModelError.guardrailViolation {
    // 输入或输出触发了安全护栏
} catch LanguageModelError.refusal(let refusal) {
    let explanation = try await refusal.explanation.content
}
```

`LanguageModelError` 的 case：`contextSizeExceeded`、`rateLimited`、`refusal`、`timeout`、`guardrailViolation`、`unsupportedCapability`、`unsupportedTranscriptContent`、`unsupportedGenerationGuide`、`unsupportedLanguageOrLocale`。

## 自定义模型

`LanguageModel`、`LanguageModelExecutor` 和 `LanguageModelCapabilities` 用来把 Core AI 导出的开源模型接进同一个会话 API。键值缓存的用法在 [Optimizing key-value caching in language model sessions](https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions)。

## ⚠️ Important Notes

- 调用前看 `availability`，并准备模型不可用时的界面。`.modelNotReady` 是设备上的模型还没就绪。PCC 对应的是 `.systemNotReady`。
- instructions 比 prompt 优先级高。只把可信内容放进 instructions。用 `tokenCount(for:)` 和 `contextSize` 控制长度。
- 提示要短、一次一件事。设备模型上下文小，长提示会变慢，输出也不稳定。
- 模型版本更新后用 `#available` 分提示，新版本写在前面。
- 图像工具调用依赖 `Attachment.label`。没有标签时，模型无法指出要把哪张图交给工具。
- 反馈用 `logFeedbackAttachment(sentiment:issues:desiredOutput:)`，结果可以交给 Feedback Assistant。提示评估用 Evaluations 框架，耗时和 token 用 Instruments。
