# Beyond the Basics of Structured Concurrency — 结构化并发进阶

> **适用范围：** Swift 5.5+（`DiscardingTaskGroup` 需 Swift 5.9+；SwiftLog MetadataProvider 需 1.5+）
> **来源：** WWDC 2023 Session 10170 "Beyond the basics of structured concurrency"
> **前置：** WWDC21 *Explore structured concurrency* / *Swift concurrency: Behind the scenes*
> **相关：** [swift-concurrency.md](swift-concurrency.md) · [swift-concurrency-code-along.md](swift-concurrency-code-along.md) · [Swift Distributed Tracing](https://github.com/apple/swift-distributed-tracing)
>
> 核心是 **task tree**：自动取消、优先级传播、`@TaskLocal`，以及 TaskGroup 限流、`DiscardingTaskGroup`、服务端日志与分布式 tracing。

---

## 目录

1. [结构化 vs 非结构化](#结构化-vs-非结构化)
2. [Task Tree](#task-tree)
3. [任务取消（cooperative）](#任务取消cooperative)
4. [withTaskCancellationHandler](#withtaskcancellationhandler)
5. [优先级与反转](#优先级与反转)
6. [TaskGroup 限流模式](#taskgroup-限流模式)
7. [DiscardingTaskGroup（Swift 5.9）](#discardingtaskgroupswift-59)
8. [@TaskLocal](#tasklocal)
9. [SwiftLog MetadataProvider](#swiftlog-metadataprovider)
10. [Distributed Tracing / withSpan](#distributed-tracing--withspan)
11. [⚠️ Important Notes](#️-important-notes)

---

## 结构化 vs 非结构化

| | 结构化 | 非结构化 |
|--|--------|----------|
| 创建 | `async let`、TaskGroup | `Task { }`、`Task.detached` |
| 生命周期 | 随声明作用域结束 | 需显式管理 |
| 出作用域 | **自动 cancel** | 需 `cancel()` |
| 建议 | **优先使用** | 仅在无法结构化时 |

```swift
// ❌ 非结构化（不推荐作为默认写法）
func makeSoup(order: Order) async throws -> Soup {
    let boilingPot = Task { try await stove.boilBroth() }
    let choppedIngredients = Task { try await chopIngredients(order.ingredients) }
    let meat = Task { await marinate(meat: .chicken) }
    let soup = await Soup(meat: meat.value, ingredients: choppedIngredients.value)
    return await stove.cook(pot: boilingPot.value, soup: soup, duration: .minutes(10))
}

// ✅ 结构化：已知子任务数量 → async let
func makeSoup(order: Order) async throws -> Soup {
    async let pot = stove.boilBroth()
    async let choppedIngredients = chopIngredients(order.ingredients)
    async let meat = marinate(meat: .chicken)
    let soup = try await Soup(meat: meat, ingredients: choppedIngredients)
    return try await stove.cook(pot: pot, soup: soup, duration: .minutes(10))
}
```

并发在 `async let` / group / Task 处分叉，在 `await` 处汇合（类似同步控制流的块结构）。

---

## Task Tree

`makeSoup` → 子任务：chop / marinate / boil；`chopIngredients` 再用 TaskGroup 为每种原料建子任务 → 形成 **parent → child** 树。

树带来：
- 取消向下传播
- 优先级继承与 escalate
- Task-local 沿树查找 / 继承（`detached` 除外）

---

## 任务取消（cooperative）

| 触发 | 行为 |
|------|------|
| 结构化任务出作用域 | 隐式 cancel |
| `group.cancelAll()` | 取消进行中 + **未来**子任务 |
| 父任务 cancel | 所有子任务被标 cancel |
| `Task.cancel()` | 显式取消非结构化任务 |

取消**不会立刻停代码**，只设 `isCancelled`；由你轮询或 handler 响应。取消与检查存在 **race**：检查后再被 cancel 则可能继续跑完。

```swift
guard !Task.isCancelled else { throw SoupCancellationError() }

// 要抛 CancellationError 时：
try Task.checkCancellation()  // 昂贵工作前检查；sync/async 均可
```

---

## withTaskCancellationHandler

任务**已挂起**（如等 AsyncSequence 下一元素）时无法轮询 → 用 handler：

```swift
public func next() async -> Order? {
    await withTaskCancellationHandler {
        let result = await kitchen.generateOrder()
        guard state.isRunning else { return nil }
        return result
    } onCancel: {
        state.cancel()  // 同步；勿在此开非结构化 Task
    }
}
```

`onCancel` 与 body **可并发** → 状态机是共享可变状态。Actor 不适合（要改单个字段、且无法保证 cancel 先执行）→ 用 **Atomics / lock / queue**：

```swift
private final class OrderState: Sendable {
    let protectedIsRunning = ManagedAtomic<Bool>(true)
    var isRunning: Bool {
        get { protectedIsRunning.load(ordering: .acquiring) }
        set { protectedIsRunning.store(newValue, ordering: .relaxed) }
    }
    func cancel() { isRunning = false }
}
```

---

## 优先级与反转

- 子任务默认继承父优先级
- 高优先级任务 `await` 低优先级结果 → **escalate 整棵子树**（避免 priority inversion）
- `await group.next()` 会 escalate **组内全部**子任务（不知谁先完成）
- escalate **不可撤销**，持续到任务结束
- 运行时用优先级队列调度

---

## TaskGroup 限流模式

不要一次 `addTask` 全部（task explosion）。先开满 `maxConcurrentTasks`，每完成一个再补一个：

```swift
func chopIngredients(_ ingredients: [any Ingredient]) async -> [any ChoppedIngredient] {
    await withTaskGroup(of: (ChoppedIngredient?).self,
                        returning: [any ChoppedIngredient].self) { group in
        let maxChopTasks = min(3, ingredients.count)
        for ingredientIndex in 0..<maxChopTasks {
            group.addTask { await chop(ingredients[ingredientIndex]) }
        }

        var choppedIngredients: [any ChoppedIngredient] = []
        var nextIngredientIndex = maxChopTasks
        for await choppedIngredient in group {
            if nextIngredientIndex < ingredients.count {
                group.addTask { await chop(ingredients[nextIngredientIndex]) }
                nextIngredientIndex += 1
            }
            if let choppedIngredient {
                choppedIngredients.append(choppedIngredient)
            }
        }
        return choppedIngredients
    }
}
```

通用骨架：

```swift
withTaskGroup(of: Something.self) { group in
    for _ in 0..<maxConcurrentTasks {
        group.addTask { /* work */ }
    }
    while let _ = await group.next() {
        if !shouldStop {
            group.addTask { /* more work */ }
        }
    }
}
```

---

## DiscardingTaskGroup（Swift 5.9）

不需要子任务返回值时用 `withThrowingDiscardingTaskGroup` / `withDiscardingTaskGroup`：
- 完成后**立即释放**资源（普通 group 需收集结果才释放）
- 任一子任务 **throw → 自动取消兄弟**
- 适合请求流、班次等 fire-and-forget

```swift
func run() async throws {
    try await withThrowingDiscardingTaskGroup { group in
        for cook in staff.keys {
            group.addTask { try await cook.handleShift() }
        }
        group.addTask {
            try await Task.sleep(for: shiftDuration)
            throw TimeToCloseError()  // 触发兄弟取消
        }
    }
}
```

对比旧写法：`group.next()` + `cancelAll()`。

---

## @TaskLocal

挂在 **task hierarchy** 上的上下文（非真正全局）：

```swift
actor Kitchen {
    @TaskLocal static var orderID: Int?
    @TaskLocal static var cook: String?

    func logStatus() {
        print("Current cook: \(Kitchen.cook ?? "none")")
    }
}

await Kitchen.$cook.withValue("Sakura") {
    await kitchen.logStatus()  // Sakura
}
```

要点：
- 用 `static` + `@TaskLocal`；**建议 Optional**（未绑定 = 默认 nil）
- **不能直接赋值**，只能 `.$x.withValue(...) { }` 绑定作用域
- 值存在绑定的那一层；读时沿父链查找（运行时有优化）
- 可 **shadow**：内层绑定覆盖外层，出作用域恢复
- 除 `Task.detached` 外，子任务继承 task-local

---

## SwiftLog MetadataProvider

Apple 平台继续用 **OSLog**；服务端用 [SwiftLog](https://github.com/apple/swift-log)。1.5+ `MetadataProvider` 从 TaskLocal 自动注入元数据，避免手写字典拼错：

```swift
let orderMetadataProvider = Logger.MetadataProvider {
    var metadata: Logger.Metadata = [:]
    if let orderID = Kitchen.orderID {
        metadata["orderID"] = "\(orderID)"
    }
    return metadata
}

let metadataProvider = Logger.MetadataProvider.multiplex([
    orderMetadataProvider, chefMetadataProvider
])
LoggingSystem.bootstrap(StreamLogHandler.standardOutput, metadataProvider: metadataProvider)

logger.info("Preparing soup order")  // 自动带 orderID 等
```

---

## Distributed Tracing / withSpan

| 场景 | 工具 |
|------|------|
| Apple 本机 | Instruments · Swift Concurrency / HTTP Traffic |
| 服务端 / 跨机 | [Swift Distributed Tracing](https://github.com/apple/swift-distributed-tracing)（OpenTelemetry → Zipkin / Jaeger） |

```swift
func makeSoup(order: Order) async throws -> Soup {
    try await withSpan(#function) { span in
        span.attributes["kitchen.order.id"] = order.id
        async let pot = stove.boilWater()
        async let choppedIngredients = chopIngredients(order.ingredients)
        async let meat = marinate(meat: .chicken)
        let soup = try await Soup(meat: meat, ingredients: choppedIngredients)
        return try await stove.cook(pot: pot, soup: soup, duration: .minutes(10))
    }
}
```

- Span 名宜短；元数据放 `attributes`，勿塞进名字
- 失败 / throw 会记入 span；可查时序 race
- 拆服务到多机时，同一套 instrumentation 可跨节点关联（靠 TaskLocal 传播 trace ID）
- HTTP client / server / RPC 全开 tracing 效果最好

---

## Quick Example

```swift
func makeSoup(order: Order) async throws -> Soup {
    try Task.checkCancellation()
    async let pot = stove.boilBroth()
    async let choppedIngredients = chopIngredients(order.ingredients)
    async let meat = marinate(meat: .chicken)
    let soup = try await Soup(meat: meat, ingredients: choppedIngredients)
    return try await stove.cook(pot: pot, soup: soup, duration: .minutes(10))
}
```

---

## Key APIs

| API | 作用 |
|-----|------|
| `async let` / `withTaskGroup` | 结构化子任务 |
| `Task.isCancelled` / `checkCancellation()` | 协作式取消轮询 |
| `group.cancelAll()` | 取消组内现有与未来任务 |
| `withTaskCancellationHandler` | 挂起时响应 cancel |
| `withThrowingDiscardingTaskGroup` | 无返回值、立即释放、兄弟自动 cancel |
| `@TaskLocal` / `.$x.withValue` | 任务树上下文 |
| `Logger.MetadataProvider` | 日志自动带 TaskLocal |
| `withSpan` | 分布式 tracing 标注 |

---

## ⚠️ Important Notes

1. **优先结构化任务**；非结构化拿不到完整的取消 / 优先级 / TaskLocal 行为。
2. 取消是 **cooperative + race**；昂贵工作前检查。
3. `onCancel` 里同步更新状态，用 atomics/locks，**别**开非结构化 Task。
4. TaskGroup **限流**：完成一个再 `addTask`，避免爆炸。
5. 无返回值长生命周期任务用 **DiscardingTaskGroup**。
6. `@TaskLocal` 用 Optional + `withValue`；`detached` 不继承。
7. iOS 日志用 OSLog；服务端用 SwiftLog + MetadataProvider / Distributed Tracing。
