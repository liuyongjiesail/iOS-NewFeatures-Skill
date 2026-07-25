# SwiftUI Concurrency — 在 SwiftUI 中探索并发

> **适用范围：** Swift 6+ / SwiftUI（iOS 17+ 起普遍适用；Swift 6.2 默认 MainActor 模式为增强）
> **来源：** WWDC 2025 Session 266 "Explore concurrency in SwiftUI"
> **框架：** SwiftUI + Swift Concurrency
> **相关：** Session 268 语言级路径 → [swift-concurrency.md](swift-concurrency.md) · Session 270 贴纸 App 实战 → [swift-concurrency-code-along.md](swift-concurrency-code-along.md)
>
> 本文档说明 SwiftUI 如何用 `@MainActor` / `Sendable` 表达运行时语义、哪些 API 会在后台线程调用你的代码、以及如何用「同步 UI + 异步模型」结构避免 data race 与动画卡顿。

---

## 目录

1. [核心心智模型](#核心心智模型)
2. [Main Actor：编译期与运行时默认](#main-actor编译期与运行时默认)
3. [会在后台跑的 API（Sendable）](#会在后台跑的-apisendable)
4. [Sendable 闭包里读 MainActor 状态](#sendable-闭包里读-mainactor-状态)
5. [同步回调 vs 异步工作](#同步回调-vs-异步工作)
6. [推荐架构：用 State 桥接](#推荐架构用-state-桥接)
7. [完整示例](#完整示例)
8. [⚠️ Important Notes](#️-important-notes)

---

## 核心心智模型

| 概念 | 含义 |
|------|------|
| **注解表达运行时语义** | SwiftUI 的 `@MainActor` / `Sendable` 不是装饰，而是告诉编译器框架实际会怎么调度你的代码 |
| **View = MainActor** | `View` 协议带 `@MainActor`；conform 后类型及成员默认主线程隔离 |
| **部分 API 在后台调用** | 动画插值、`Shape.path`、`visualEffect`、`Layout`、`onGeometryChange` 等可能离开主线程 |
| **UI 要同步** | Button / 手势回调是同步的；时间敏感的动画与 loading 状态应同步改 state |
| **async 用 Task 显式进入** | 需要时再 `Task { await ... }`；不要把动画关键路径塞进 `await` 之后 |

**Swift 6.2：** 新语言模式可让模块内类型隐式带 `@MainActor`。Session 内容在开/关该模式时都适用；开启后多数手写 `@MainActor` 可删除。

---

## Main Actor：编译期与运行时默认

### View 隐式隔离

```swift
struct ColorExtractorView: View {
    // View 协议 → 整个类型隐式 @MainActor
    @State private var model = ColorExtractor()

    var body: some View {
        // body、@State、访问 model 都安全（共享 MainActor）
        ColorSchemeView(
            isLoading: model.isExtracting,
            colorScheme: model.scheme
        )
        .onTapGesture {
            // body 在 MainActor → Task 闭包默认也在主线程
            Task {
                await model.extractColorScheme()
            }
        }
    }
}
```

要点：
- 模型类型本身**不必**标 `@MainActor`；在 View 里用 `@State` 创建实例时，Swift 会保证隔离正确
- 多数时候可专注业务，无需手写并发注解

### 与 UIKit / AppKit 互通

`UIViewRepresentable` 继承 `View`，因此也是 `@MainActor`。`makeUIView` 里创建 `UILabel` 等无需再标 `@MainActor`。

```swift
struct FancyUILabel: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        // UILabel.init 要求 MainActor —— 此处已满足
        return label
    }
}
```

---

## 会在后台跑的 API（Sendable）

SwiftUI 是声明式的：你写的 `View` struct 不是固定内存对象；运行时另有 representation，可把高开销计算放到后台，减轻主线程卡顿。

| API | 后台调用的部分 |
|-----|----------------|
| 内置动画 | 帧间插值计算 |
| `Shape` | `path(in:)` |
| `visualEffect` | 效果闭包 |
| `Layout` | 协议要求的布局方法 |
| `onGeometryChange` | 几何变换闭包（第一个参数） |

这些 API 用 **`Sendable`** 标注闭包/要求，向你和编译器声明：「这段可能在后台跑，小心跨线程共享可变状态」。

**最佳策略：** 尽量不在并发任务之间共享可变数据；框架会把多数需要的值作为**函数参数**传入。

```swift
// Layout：只靠传入的参数做计算，不碰外部 MainActor 状态
struct EqualWidthVStack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // 仅使用 proposal / subviews
        ...
    }
}
```

---

## Sendable 闭包里读 MainActor 状态

### 问题

在 `visualEffect` 等 Sendable 闭包里直接读 `self.pulse`（View 的 `@State`）会报 data race：`self` 可 Send（View 受 MainActor 保护），但读其 MainActor 属性不安全。

### 修复：捕获列表拷贝

```swift
struct SchemeContentView: View {
    let isLoading: Bool
    @State private var pulse: Bool = false

    var body: some View {
        Text(isLoading ? "Please wait" : "Extract")
            .visualEffect { [pulse] content, _ in
                // 拷贝的 Bool（值类型）Sendable，无竞态
                content.blur(radius: pulse ? 2 : 0)
            }
            .onChange(of: isLoading) { _, newValue in
                withAnimation(newValue ? .easeInOut.repeatForever() : nil) {
                    pulse = newValue
                }
            }
    }
}
```

另一策略：只读 **nonisolated** 的数据。

---

## 同步回调 vs 异步工作

### 为什么 Button 不是 async 闭包？

1. **先同步改 UI**（loading、动画），再开长任务
2. `await` 是挂起点：恢复时机不确定，可能错过屏幕刷新，动画会「拖拍」

```swift
.onTapGesture {
    guard !model.isExtracting else { return }
    // ✅ 同步触发 loading 动画
    withAnimation { model.isExtracting = true }
    Task {
        await model.extractColorScheme()
        // ✅ 结束后再同步改回
        withAnimation { model.isExtracting = false }
    }
}
```

### 滚动可见性动画：保持同帧同步

```swift
struct SchemeHistoryItemView: View {
    let scheme: ColorScheme
    @State private var isShown: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(scheme.colors) { color in
                color.offset(y: isShown ? 0 : 60)
            }
        }
        .onScrollVisibilityChange(threshold: 0.9) {
            guard !isShown else { return }
            // ✅ 与手势回调同帧改 state，动画不滞后
            withAnimation { isShown = $0 }
            // ❌ 不要在这里 Task { await ...; isShown = true }
        }
    }
}
```

---

## 推荐架构：用 State 桥接

```
┌─────────────┐     同步改 state      ┌──────────────────┐
│  View (UI)  │ ←──────────────────→ │ Model / Service  │
│  MainActor  │   Task 通知 UI 事件   │  async 长任务    │
└─────────────┘                       └──────────────────┘
```

1. **UI 逻辑尽量同步**：observable 属性同步变更 + 同步回调
2. **长任务放模型侧**：与 View 解耦，便于单测（可不 `import SwiftUI`）
3. **State 当桥**：发起 async；完成后同步写回 state，UI 响应变化
4. **View 里的 Task 保持简单**：只告知模型「发生了某 UI 事件」

```swift
@Observable
final class ColorExtractor {
    var imageName: String = "photo"
    var scheme: ColorScheme?
    var isExtracting: Bool = false
    var colorCount: Float = 5

    func extractColorScheme() async {
        // 纯异步逻辑，可单元测试
    }
}

struct ColorExtractorView: View {
    @State private var model = ColorExtractor()

    var body: some View {
        EqualWidthVStack {
            ColorSchemeView(
                isLoading: model.isExtracting,
                colorScheme: model.scheme,
                extractCount: Int(model.colorCount)
            )
            .onTapGesture {
                guard !model.isExtracting else { return }
                withAnimation { model.isExtracting = true }
                Task {
                    await model.extractColorScheme()
                    withAnimation { model.isExtracting = false }
                }
            }
            Slider(value: $model.colorCount, in: 3...10, step: 1)
                .disabled(model.isExtracting)
        }
    }
}
```

---

## 完整示例

```swift
import SwiftUI

struct ColorScheme: Identifiable, Hashable {
    var id = UUID()
    let imageName: String
    var colors: [Color]
}

@Observable
final class ColorExtractor {
    var imageName: String = "sample"
    var scheme: ColorScheme?
    var isExtracting: Bool = false
    var colorCount: Float = 5

    func extractColorScheme() async {
        // 模拟耗时提取
        try? await Task.sleep(for: .seconds(1))
        scheme = ColorScheme(
            imageName: imageName,
            colors: [.red, .orange, .yellow, .green, .blue].prefix(Int(colorCount)).map { $0 }
        )
    }
}

struct ColorExtractorView: View {
    @State private var model = ColorExtractor()

    var body: some View {
        VStack {
            Circle()
                .scaleEffect(model.isExtracting ? 1.5 : 1)
                .animation(.easeInOut, value: model.isExtracting)

            Text(model.isExtracting ? "Please wait" : "Extract")
                .onTapGesture {
                    guard !model.isExtracting else { return }
                    withAnimation { model.isExtracting = true }
                    Task {
                        await model.extractColorScheme()
                        withAnimation { model.isExtracting = false }
                    }
                }

            Slider(value: $model.colorCount, in: 3...10, step: 1)
                .disabled(model.isExtracting)
        }
    }
}
```

---

## ⚠️ Important Notes

- **注解 = 运行时契约**：见 `Sendable` 就要假设可能后台执行；见 `@MainActor` 就要假设主线程默认。
- **Sendable 闭包**：优先用参数；必须读 View 状态时用 `[value]` 捕获拷贝，勿经 `self.` 读 MainActor 属性。
- **动画 / 手势路径避免 await**：挂起会错过帧刷新，动画会卡顿。
- **先同步 loading，再 Task**：长任务前后用 `withAnimation` 同步改 state。
- **Swift 6.2 默认隔离**：试一下模块级默认 `@MainActor`，可删掉大量手写注解。
- **类要跨线程共享**：考虑 `Mutex`（Synchronization）做成 Sendable。
- **测 async 逻辑**：尽量不依赖 SwiftUI，只测模型层。

---

## 参考资料

- [WWDC 2025 Session 266 — Explore concurrency in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/266/)
- [WWDC 2025 Session 268 — Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
- [WWDC 2025 Session 270 — Elevate an app with Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/270/)
- [Mutex](https://developer.apple.com/documentation/Synchronization/Mutex)
- [Swift Concurrency](https://developer.apple.com/documentation/Swift/concurrency)
- [Updating an App to Use Swift Concurrency](https://developer.apple.com/documentation/swift/updating_an_app_to_use_swift_concurrency)
