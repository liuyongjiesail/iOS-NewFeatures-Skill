# Code-along: Elevate an App with Swift Concurrency

> **适用范围：** Swift 6.2+ / SwiftUI（Xcode 26 新建 App 默认 Approachable Concurrency）
> **来源：** WWDC 2025 Session 270 "Code-along: Elevate an app with Swift concurrency"
> **Sample：** [Code-along: Elevating an app with Swift concurrency](https://developer.apple.com/documentation/Swift/code-along-elevating-an-app-with-swift-concurrency)
> **相关：** 概念路径 → [swift-concurrency.md](swift-concurrency.md)（268）· SwiftUI 注解 → [swiftui-concurrency.md](swiftui-concurrency.md)（266）· [Swift Migration Guide](https://www.swift.org/migration/documentation/migrationguide/)
>
> 用贴纸 App（相册选图 → 抠图/取色 → 轮播/网格导出）演示：**按需**引入 async、`@concurrent`、`async let`、修复 data race、`TaskGroup`。

---

## 目录

1. [演进路径（按需引入）](#演进路径按需引入)
2. [Approachable Concurrency](#approachable-concurrency)
3. [架构概览](#架构概览)
4. [阶段 A：async 加载相册](#阶段-aasync-加载相册)
5. [阶段 B：主线程处理导致 Hang](#阶段-b主线程处理导致-hang)
6. [阶段 C：nonisolated + @concurrent 卸后台](#阶段-cnonisolated--concurrent-卸后台)
7. [阶段 D：async let 并行](#阶段-dasync-let-并行)
8. [阶段 E：修复 Data Race](#阶段-e修复-data-race)
9. [阶段 F：visualEffect 捕获列表](#阶段-fvisualeffect-捕获列表)
10. [阶段 G：TaskGroup 批量处理](#阶段-gtaskgroup-批量处理)
11. [Data Race 决策树](#data-race-决策树)
12. [⚠️ Important Notes](#️-important-notes)

---

## 演进路径（按需引入）

```
Main Actor App（Xcode 26 默认）
    │  SDK async（loadTransferable）
    ▼
async / await + .task（UI 仍响应；处理仍可卡主线程）
    │  Instruments：Severe Hang
    ▼
nonisolated 类型 + @concurrent process（卸计算）
    │  仍慢 → 独立子任务
    ▼
async let 并行（贴纸 + 取色）
    │  编译器报 race → 不共享可变状态
    ▼
本地 ColorExtractor / 捕获列表
    │  N 张图（数量未知）
    ▼
withTaskGroup 批量并行
```

原则：**先 profile，再并发；能优化算法就先优化。**

---

## Approachable Concurrency

- Xcode 26 **新建** App：Main Actor by default + 若干 upcoming features
- Approachable 配置下，Swift 6 可在**你尚未显式引入并发**时仍提供 data-race 安全
- 旧工程启用方式见 Swift Migration Guide

---

## 架构概览

| 组件 | 职责 |
|------|------|
| `StickerCarousel` | 横向 LazyHStack 轮播；占位时 `.task` 加载 |
| `StickerGrid` | 网格预览 + `ShareLink` 导出 |
| `StickerViewModel` | `selection`、`processedPhotos`、`loadPhoto` / `processAllPhotos` |
| `PhotoProcessor` | 抠贴纸 + 主色；最终为 `nonisolated` + `@concurrent` |
| `SelectedPhoto` | `Identifiable`，持有 `PhotosPickerItem` |
| `ProcessedPhoto` | `sticker` + `colorScheme`（渐变） |

昂贵操作：贴纸提取、主色计算 — 二者可并行。

---

## 阶段 A：async 加载相册

`PhotosPickerItem` + `Transferable` → `loadTransferable(type: Data.self)`。

```swift
func loadPhoto(_ item: SelectedPhoto) async {
    var data: Data? = try? await item.loadTransferable(type: Data.self)
    if let cachedData = getCachedData(for: item.id) { data = cachedData }
    guard let data else { return }
    processedPhotos[item.id] = Image(data: data)
    cacheData(item.id, data)
}
```

View 侧用 `.task`（出现时启动，配合 `LazyHStack` 只处理可见项）：

```swift
StickerPlaceholder()
    .task {
        await viewModel.loadPhoto(selectedPhoto)
    }
```

**为何响应变好：** `await` 是挂起点。`loadPhoto` 在主线程启动 → 在 `loadTransferable` 处挂起 → SDK 在后台取数据 → 恢复后回主线程更新 UI。挂起期间主线程可处理滚动等事件。

---

## 阶段 B：主线程处理导致 Hang

同步调用 `PhotoProcessor().process(data:)` 后，滚动卡顿。Instruments 显示 **Severe Hang**，最重栈在 PhotoProcessor，主线程阻塞 **>10s**。

| 步骤 | 能否卸后台 |
|------|------------|
| 取原始图（picker / cache） | 否（与 UI/模型交互） |
| 图像处理（抠图 + 取色） | **是** |
| 写回 `processedPhotos` | 否（Main Actor 状态） |

`loadTransferable` 已替你卸负载；**自己的**重计算不会自动上后台。

---

## 阶段 C：nonisolated + @concurrent 卸后台

Main Actor by default 下，`PhotoProcessor` 隐式 `@MainActor`。要先解绑，再强制后台：

```swift
nonisolated struct PhotoProcessor {
    @concurrent
    func process(data: Data) async -> ProcessedPhoto? {
        let sticker = extractSticker(from: data)
        let colors = extractColors(from: data)
        guard let sticker, let colors else { return nil }
        return ProcessedPhoto(sticker: sticker, colorScheme: colors)
    }
    // extractSticker / extractColors ...
}
```

- **`nonisolated`（类型，Swift 6.1+）：** 成员全部 nonisolated，可从并发上下文调用
- **`@concurrent` + `async`：** 始终切到并发线程池执行

调用方：

```swift
processedPhotos[item.id] = await PhotoProcessor().process(data: data)
```

效果：滚动不再 hang；但单张处理仍可能较慢。

---

## 阶段 D：async let 并行

贴纸提取与取色**互不依赖** → `async let` 并行，利用多核：

```swift
@concurrent
func process(data: Data) async -> ProcessedPhoto? {
    async let sticker = extractSticker(from: data)
    async let colors = extractColors(from: data)
    guard let sticker = await sticker, let colors = await colors else { return nil }
    return ProcessedPhoto(sticker: sticker, colorScheme: colors)
}
```

`async let` 适合**固定少量**子任务；张数不定时用 `TaskGroup`（阶段 G）。

---

## 阶段 E：修复 Data Race

并行后编译器报：`PhotoProcessor` 不能安全跨并发任务共享。

原因：存了共享的 `ColorExtractor`（可变像素缓冲，非并发安全），多任务共用同一实例。

**修复：不共享 — 每次取色在函数内新建实例：**

```swift
private func extractColors(from data: Data) -> PhotoColorScheme? {
    let colorExtractor = ColorExtractor()
    return colorExtractor.extractColors(from: data)
}
```

`Data` 本身是 Sendable 值类型（COW），两路并行读同一 `data` 安全。

---

## 阶段 F：visualEffect 捕获列表

SwiftUI `visualEffect` 闭包是 `@Sendable`，在**后台**计算。直接读 `viewModel.selection`（Main Actor）会报错。

```swift
.visualEffect { [selection = viewModel.selection] content, proxy in
    let frame = proxy.frame(in: .scrollView(axis: .horizontal))
    let distance = min(0, frame.minX)
    let isLast = selectedPhoto.id == selection.last?.id
    return content
        .offset(x: isLast ? 0 : -distance / 1.25)
        .blur(radius: isLast ? 0 : -distance / 50)
        .opacity(isLast ? 1.0 : min(1.0, 1.0 - (-distance / 400)))
}
```

捕获列表拷贝 `selection`；`selection` 变化时 SwiftUI 会重算闭包。细节见 [swiftui-concurrency.md](swiftui-concurrency.md)。

两种 race 场景对比：

| | 自己引入并行 | 框架帮你卸后台 |
|--|-------------|----------------|
| 例子 | `async let` + 共享 `ColorExtractor` | `visualEffect` + Main Actor 状态 |
| 修法 | 不共享 / 局部实例 | 捕获列表拷贝值 |

---

## 阶段 G：TaskGroup 批量处理

张数不定时，`async let` 不够 → `withTaskGroup`：

```swift
func processAllPhotos() async {
    await withTaskGroup { group in
        for item in selection {
            guard processedPhotos[item.id] == nil else { continue }
            group.addTask {
                let data = await self.getData(for: item)
                let photo = await PhotoProcessor().process(data: data)
                return photo.map { ProcessedPhotoResult(id: item.id, processedPhoto: $0) }
            }
        }
        for await result in group {
            if let result {
                processedPhotos[result.id] = result.processedPhoto
            }
        }
    }
}
```

要点：
- 任意数量子任务并行；完成顺序不定（字典存储则无关）
- `TaskGroup` 是 `AsyncSequence`，可边完成边写入
- Main Actor 上的 `viewModel` 可从并发子任务 `await` 访问（隐式 Main Actor 保护）

Grid：

```swift
.task {
    await viewModel.processAllPhotos()
    finishedLoading = true
}
```

---

## Data Race 决策树

1. **可变状态是否必须跨并发共享？** → 多数情况：**不要共享**（局部变量 / 每任务一实例）
2. 必须共享 → 抽出 **Sendable 值类型** 再传递
3. 仍不行 → 隔离到 **actor**（含 Main Actor；默认模式已帮 UI 模型隔离）

Main Actor 模型从 `@concurrent` Task 访问示例：

```swift
Task { @concurrent in
    await viewModel.loadPhoto(selectedPhoto)
}
```

---

## Quick Example（最终形态摘要）

```swift
nonisolated struct PhotoProcessor {
    @concurrent
    func process(data: Data) async -> ProcessedPhoto? {
        async let sticker = extractSticker(from: data)
        async let colors = extractColors(from: data)
        guard let sticker = await sticker, let colors = await colors else { return nil }
        return ProcessedPhoto(sticker: sticker, colorScheme: colors)
    }

    private func extractColors(from data: Data) -> PhotoColorScheme? {
        ColorExtractor().extractColors(from: data)
    }
}

// ViewModel（Main Actor）
func loadPhoto(_ item: SelectedPhoto) async {
    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
    processedPhotos[item.id] = await PhotoProcessor().process(data: data)
}
```

---

## Key APIs

| API | 作用 |
|-----|------|
| `async` / `await` / `.task` | 挂起；UI 响应；按需启动 |
| `loadTransferable` | SDK 已卸后台的相册加载 |
| `nonisolated`（类型） | 整类型脱离 Main Actor（Swift 6.1+） |
| `@concurrent` | 强制线程池执行 |
| `async let` | 固定少量子任务并行 |
| `withTaskGroup` / `addTask` | 动态数量子任务；`AsyncSequence` 收结果 |
| 捕获列表 `[x = ...]` | Sendable 闭包中拷贝 Main Actor 值 |
| Instruments Hang | 决定是否引入下一阶段并发 |

---

## ⚠️ Important Notes

1. **先 Instruments，再 `@concurrent` / 并行**；能无算法优化就先优化。
2. **async ≠ 后台**：`await` SDK 可能已卸负载；自己的重计算要显式 `@concurrent`。
3. Main Actor 默认下重计算类型需 **`nonisolated` + `@concurrent`**。
4. 并行优先 **不共享可变状态**；共享 `ColorExtractor` 是典型 race。
5. **`async let`** = 固定少数任务；**`TaskGroup`** = 动态 N 个。
6. SwiftUI `@Sendable` 闭包（如 `visualEffect`）用捕获列表，勿直接读 View/Model 可变状态。
7. 官方 sample 可下载对照：[documentation](https://developer.apple.com/documentation/Swift/code-along-elevating-an-app-with-swift-concurrency)。
8. TaskGroup 限流、取消、`DiscardingTaskGroup`、`@TaskLocal` 见 [structured-concurrency.md](structured-concurrency.md)。
