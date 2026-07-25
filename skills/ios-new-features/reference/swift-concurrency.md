# Embracing Swift Concurrency — 拥抱 Swift 并发

> **适用范围：** Swift 6.2+（含 Approachable Concurrency / Default Actor Isolation；概念亦适用于更早的 async/await）
> **来源：** WWDC 2025 Session 268 "Embracing Swift concurrency"
> **相关：** Session 266 → [swiftui-concurrency.md](swiftui-concurrency.md) · Session 270 实战 → [swift-concurrency-code-along.md](swift-concurrency-code-along.md) · Session 10170 进阶 → [structured-concurrency.md](structured-concurrency.md) · [Swift Migration Guide](https://www.swift.org/migration/documentation/migrationguide/)
>
> 本文档给出从**单线程 → 异步 → 后台并发 → Actor** 的演进路径，以及何时用 `async`/`@concurrent`/`nonisolated`/`actor`、如何安全共享数据。

---

## 目录

1. [核心心智模型](#核心心智模型)
2. [推荐构建设置](#推荐构建设置)
3. [阶段 1：单线程 / Main Actor 默认](#阶段-1单线程--main-actor-默认)
4. [阶段 2：异步任务（不必引入并发）](#阶段-2异步任务不必引入并发)
5. [阶段 3：@concurrent 真正上后台](#阶段-3concurrent-真正上后台)
6. [nonisolated vs @concurrent](#nonisolated-vs-concurrent)
7. [共享数据与 Sendable](#共享数据与-sendable)
8. [阶段 4：自定义 Actor 卸主线程状态](#阶段-4自定义-actor-卸主线程状态)
9. [⚠️ Important Notes](#️-important-notes)

---

## 核心心智模型

| 原则 | 说明 |
|------|------|
| **按需引入** | 并发比单线程复杂；多数 App 只需少量并发，有的完全不需要 |
| **先主线程** | 从 Main Actor 起步；响应性问题再用 async；主线程仍卡再用后台 |
| **显式引入并发** | Swift 让「何时并发、共享了什么」可见，并在编译期抓 data race |
| **演进路径** | 单线程 → 异步（隐藏延迟）→ `@concurrent`（卸计算）→ `actor`（卸共享可变状态） |

```
Main Actor（UI + 默认代码）
    │  await 网络等
    ▼
异步 Task（仍可留在主线程，靠 interleaving）
    │  @concurrent / 线程池
    ▼
后台计算（解码、缩放等）
    │  主 Actor 争用过多时
    ▼
自定义 Actor（如 NetworkManager）
```

---

## 推荐构建设置

Session 明确推荐：

| Xcode 设置 | Build Setting | 建议 |
|------------|---------------|------|
| **Approachable Concurrency** | `SWIFT_APPROACHABLE_CONCURRENCY = YES` | **所有工程**都开 |
| **Default Actor Isolation** | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | **主 App / 偏 UI 的模块** |

- Xcode 26 **新建** App 工程默认已开 Main Actor 模式
- **旧工程**默认仍是 `nonisolated`，需手动改为 `MainActor`
- SPM：

```swift
.target(
    name: "MyUIModule",
    swiftSettings: [
        .defaultIsolation(MainActor.self)
        // Approachable Concurrency 对应 upcoming feature，按 Xcode/工具链文档启用
    ]
)
```

主 Actor 模式 ≈ 编译器给模块内声明隐式加 `@MainActor`：可自由访问 static / 共享状态，直到你**显式**引入并发。

---

## 阶段 1：单线程 / Main Actor 默认

主线程 = Main Actor；Main Actor 上**没有**并发（只有一条主线程）。

```swift
// Default Actor Isolation = MainActor 时，以下隐式在 Main Actor
final class ImageModel {
    var imageCache: [URL: Image] = [:]
    let view = View()

    func fetchAndDisplayImage(url: URL) throws {
        let data = try Data(contentsOf: url)
        let image = decodeImage(data)
        view.displayImage(image)
    }

    func decodeImage(_ data: Data) -> Image { Image() }
}
```

只要操作足够快，全部留在主线程完全合理。

---

## 阶段 2：异步任务（不必引入并发）

网络等会卡住主线程 → 用 `async` / `await` **挂起**，让 UI 保持响应。

```swift
func fetchAndDisplayImage(url: URL) async throws {
    let (data, _) = try await URLSession.shared.data(from: url)
    let image = decodeImage(data)
    view.displayImage(image)
}
```

要点：
- `await` = 可能挂起点；函数被切成「挂起前 / 恢复后」两段，中间主线程可跑别的工作
- `URLSession` 等库 API 会在**内部**做后台工作；你的代码仍可留在 Main Actor
- **此时尚未把业务逻辑迁到后台**——只是变成异步单线程

### Task 与 Interleaving

```swift
func onTapEvent() {
    Task {
        do {
            try await fetchAndDisplayImage(url: url)
        } catch {
            displayError(error)
        }
    }
}
```

- 一个 `async` 函数跑在一个 **Task** 里；任务彼此独立
- 多任务在主线程上**交错（interleaving）**执行就绪片段，提高资源利用率
- **有序工作放同一 Task**；独立操作才拆多个 Task

异步单线程往往够用。卡顿先用 Instruments 看瓶颈；能加速就先优化，再谈并发。

---

## 阶段 3：@concurrent 真正上后台

主线程解码大图仍卡 → 用 `@concurrent` 明确要求在后台跑：

```swift
func fetchAndDisplayImage(url: URL) async throws {
    if let image = cachedImage[url] {
        view.displayImage(image)
        return  // 同步命中缓存，不挂起
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    let image = await decodeImage(data)
    view.displayImage(image)
}

@concurrent
func decodeImage(_ data: Data) async -> Image {
    // 只做解码；不要碰 Main Actor 上的 cache
    Image()
}
```

### 脱离 Main Actor 的三种策略

编译器会标出 `@concurrent` 函数里非法的 Main Actor 访问。可选：

1. **把 Main Actor 逻辑上移到调用方**（推荐缓存检查）：调用方同步读 cache，失败再 `await` 后台
2. **`await` 异步访问 Main Actor**
3. **`nonisolated`**：声明与任何 actor 无关（见下一节）

错误示例（在 `@concurrent` 里碰 cache）：

```swift
@concurrent
func decodeImage(_ data: Data, at url: URL) async -> Image {
    if let image = cachedImage[url] { return image } // ❌ Main Actor 状态
    let image = Image()
    cachedImage[url] = image // ❌
    return image
}
```

---

## nonisolated vs @concurrent

| | `@concurrent` | `nonisolated` |
|--|---------------|---------------|
| 行为 | **总是**切到并发线程池执行 | **留在调用方所在 actor**（主线程调就在主线程） |
| 用途 | App 内明确要卸掉的重活 | 库 / 通用 API：让客户端决定是否卸负载 |
| 示例 | `decodeImage` 大图解码 | `JSONDecoder` 风格 API |

```swift
// 库侧：提供 nonisolated，别替客户端强制 @concurrent
nonisolated
public class JSONDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T { ... }
}
```

后台由系统 **concurrent thread pool** 调度；挂起后再恢复可能换到池中另一条线程。

---

## 共享数据与 Sendable

跨 Main Actor ↔ 线程池传递的值必须在并发下安全。

### 值类型 / Sendable

`URL`、`String`、`Data`、`Date`、元素为 Sendable 的集合、字段皆 Sendable 的 struct/enum → 拷贝独立，可标 `Sendable`。

```swift
struct ImageRequest: Sendable {
    var url: URL
}

@MainActor class ImageModel {} // Main Actor 类型隐式 Sendable
```

### 引用类型 / 非 Sendable class

class 是引用语义：多线程同时改同一对象 = data race。编译器会在跨 actor/task 共享非 Sendable 时报错。

```swift
nonisolated class MyImage {
    var width: Int
    var height: Int
    var pixels: [Color]
    func scaleImage(by factor: Double) { }
}

// ❌ 一边缩放一边 display → race
func scaleAndDisplay(imageName: String) {
    let image = loadImage(imageName)
    Task { @concurrent in
        image.scaleImage(by: 0.5)
    }
    view.displayImage(image)
}

// ✅ 同一 Task 内顺序：改完再交给 Main Actor
@concurrent
func scaleAndDisplay(imageName: String) async {
    let image = loadImage(imageName)
    image.scaleImage(by: 0.5)
    image.applyAnotherEffect()
    await view.displayImage(image) // 送出后再改会报错
}
```

### 模型 class 建议

| 场景 | 建议 |
|------|------|
| UI 模型 | 留在 Main Actor |
| 需在后台用 | `nonisolated`，但**通常不要** `Sendable` |
| 强制 Sendable class | 往往要锁等低层同步，尽量避免 |

闭包捕获可变状态同理：只有在需要跨并发共享时才把函数类型标成 `Sendable`。

---

## 阶段 4：自定义 Actor 卸主线程状态

后台任务若频繁 `await` 主线程上的子系统（连接池等），会争用 Main Actor、造成卡顿。把非 UI 可变状态迁到自己的 `actor`：

```swift
actor NetworkManager {
    var openConnections: [URL: Connection] = [:]

    func openConnection(for url: URL) async -> Connection {
        if let connection = openConnections[url] { return connection }
        let connection = Connection()
        openConnections[url] = connection
        return connection
    }

    func closeConnection(_ connection: Connection, for url: URL) async {
        openConnections.removeValue(forKey: url)
    }
}

final class ImageModel {
    var cachedImage: [URL: MyImage] = [:]
    let view = View()
    let networkManager = NetworkManager()

    func fetchAndDisplayImage(url: URL) async throws {
        if let image = cachedImage[url] {
            view.displayImage(image)
            return
        }

        let connection = await networkManager.openConnection(for: url)
        let data = try await connection.data(from: url)
        await networkManager.closeConnection(connection, for: url)

        let image = await decodeImage(data)
        view.displayImage(image)
    }

    @concurrent
    func decodeImage(_ data: Data) async -> MyImage {
        MyImage()
    }
}
```

要点：
- `actor` 隔离自身状态，一次只允许一个任务访问；类型本身 Sendable
- 不绑死在主线程，可在后台执行
- **不要**把多数 UI / 模型 class 改成 actor；UI 留 Main Actor，模型 Main Actor 或非 Sendable

---

## Quick Example（端到端）

```swift
final class ImageModel {
    var cachedImage: [URL: Image] = [:]
    let view = View()

    func onTap(url: URL) {
        Task {
            try? await fetchAndDisplayImage(url: url)
        }
    }

    func fetchAndDisplayImage(url: URL) async throws {
        if let image = cachedImage[url] {
            view.displayImage(image)
            return
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let image = await decodeImage(data)
        cachedImage[url] = image
        view.displayImage(image)
    }

    @concurrent
    func decodeImage(_ data: Data) async -> Image {
        Image() // 重计算放这里
    }
}
```

---

## Key APIs / 关键词

| API / 设置 | 作用 |
|------------|------|
| `SWIFT_APPROACHABLE_CONCURRENCY` | 开启更易用的并发语言行为套件 |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | 模块默认 `MainActor` 或 `nonisolated` |
| `async` / `await` / `Task` | 异步与任务；主线程可 interleaving |
| `@concurrent` | 强制在并发线程池执行 |
| `nonisolated` | 不绑定 actor；随调用方执行 |
| `Sendable` | 可安全跨并发边界传递 |
| `actor` | 隔离可变状态，卸主线程争用 |
| `@MainActor` | 显式主线程隔离（默认模式下常可省略） |

---

## ⚠️ Important Notes

1. **先异步、后并发**：网络用 `await` 即可；主线程仍卡再 `@concurrent`。
2. **缓存放 Main Actor 调用方**：在挂起前同步查 cache，避免后台碰 UI 状态。
3. **库用 `nonisolated`**：别在通用库里滥用 `@concurrent`。
4. **非 Sendable 对象「改完再送」**：送进 Main Actor / 另一 Task 后不要再改。
5. **模型少做 Sendable class**：防主线程与后台同时改模型。
6. **Actor 用于非 UI 子系统**：NetworkManager 等；UI 类留 Main Actor。
7. **用 Instruments 决策**：确认瓶颈再引入下一阶段并发。
8. SwiftUI 侧注解与动画细节见 [swiftui-concurrency.md](swiftui-concurrency.md)。
