# SwiftData Updates（2024–2026）

> **适用范围：** iOS 17+ 基础；iOS 18+ 索引/历史/自定义 Store；iOS 26+ 模型继承；iOS 27+ sectionBy / Codable 属性 / Observer
> **来源：** [SwiftData updates](https://developer.apple.com/documentation/updates/swiftdata) · WWDC 2026 Session 274
> **框架：** SwiftData
>
> 本文档按时间线整理 SwiftData 重要更新，方便实现查询分段、第三方 Codable 持久化、视图外观察，以及索引 / 历史 / 自定义存储。

---

## 目录

1. [功能概览](#功能概览)
2. [June 2026（iOS 27+）](#june-2026ios-27)
3. [June 2025（iOS 26+）](#june-2025ios-26)
4. [June 2024（iOS 18+）](#june-2024ios-18)
5. [怎么选观察方式](#怎么选观察方式)
6. [⚠️ Important Notes](#️-important-notes)

---

## 功能概览

| 年份 | 能力 | 关键 API |
|------|------|----------|
| 2026 | 查询结果分段 | `@Query(..., sectionBy:)` |
| 2026 | 不掌控的 Codable 类型 | `@Attribute(.codable)` |
| 2026 | 视图外实时观察 fetch | `ResultsObserver` |
| 2026 | 观察持久化历史 | `HistoryObserver` |
| 2025 | 模型继承 | `@Model` inheritance |
| 2025 | 历史排序 | `HistoryDescriptor.sortBy` |
| 2024 | 索引 / 唯一约束 | `@Index` / `@Unique` |
| 2024 | 单向关系 | `inverse: nil` |
| 2024 | 持久化历史 | `fetchHistory` / `deleteHistory` |
| 2024 | 自定义存储 | `DataStore` / `HistoryProviding` |

---

## June 2026（iOS 27+）

### 1. `@Query` + `sectionBy` — 按字段分段

不需要先拉 parent 再遍历关系，可直接按**已持久化**属性把结果分组，适合 `List` + `Section`。

```swift
@Model
final class Expense {
    var name: String
    var amount: Double
    var budgetName: String   // sectionBy 必须是持久化属性，不能用计算属性 / 关系路径

    init(name: String, amount: Double, budgetName: String = "Uncategorized") {
        self.name = name
        self.amount = amount
        self.budgetName = budgetName
    }
}

struct ExpenseListView: View {
    @Query(sort: \Expense.name, sectionBy: \Expense.budgetName)
    private var expenses: [Expense]

    var body: some View {
        List(_expenses.sections) { section in
            Section(section.id) {
                ForEach(section) { expense in
                    Text("\(expense.name) — \(expense.amount)")
                }
            }
        }
    }
}
```

> `sectionBy` 目前要求 key path 指向**存进库里的属性**。`\Expense.budget?.name` 这类关系路径不可用，需要冗余持久化分组字段。

### 2. `@Attribute(.codable)` — 第三方 / 不可拆分类型

SwiftData 默认会尝试把 Codable 值类型拆成列（可过滤、排序）。第三方类型（如含 class 的 `MKMapItem.Identifier`）拆不动会崩溃。用 `.codable` 告诉框架：**整份序列化成 blob 存**。

```swift
import MapKit

@Model
final class FavoritePlace {
    var name: String

    @Attribute(.codable)
    var mapItemIdentifier: MKMapItem.Identifier?

    init(name: String, mapItemIdentifier: MKMapItem.Identifier?) {
        self.name = name
        self.mapItemIdentifier = mapItemIdentifier
    }
}
```

**限制：**
- 内容对 SwiftData **不透明**：不能进 Predicate / SortDescriptor
- 类型形状变化**不会**触发自动迁移；`Codable` 实现需前后兼容
- **自己掌控的类型**优先拆列建模；`.codable` 是逃生舱，不是默认方案

### 3. `ResultsObserver` — 在 `@Observable` / 非 SwiftUI 中观察

类似 `@Query`，但不绑视图：可在服务类里 fetch + Observation，驱动派生状态（仪表盘汇总、地图范围等）。

```swift
@Observable
final class BudgetSummaryStore {
    private let observer: ResultsObserver<Budget, Never>?
    @ObservationIgnored private var token: ObservationTracking.Token?

    var totalBudget: Double = 0
    var totalSpent: Double = 0
    var remaining: Double = 0

    init(modelContext: ModelContext) throws {
        observer = try ResultsObserver(modelContext: modelContext)

        token = withContinuousObservation(options: [.didSet]) { [weak self] _ in
            self?.updateSummary()
        }
        updateSummary()
    }

    private func updateSummary() {
        guard let budgets = observer?.results else { return }
        totalBudget = budgets.reduce(0) { $0 + $1.limit }
        totalSpent = budgets.reduce(0) { sum, b in
            sum + b.expenses.reduce(0) { $0 + $1.amount }
        }
        remaining = totalBudget - totalSpent
    }
}
```

- 第一个泛型：模型类型；第二个：分段 id（不分段用 `Never`）
- **必须持有** observation token，否则观察停止
- 访问到的 `results` / 关联属性都会被 Observation 追踪
- **不替代** `@Query`：UI 列表仍优先 `@Query`

### 4. `HistoryObserver` — 同步 / 远端变更

观察持久化历史；`eventCounter` 增加时用 `ModelContext.fetchHistory` 拉增量，适合与自建后端同步，而不是全表扫描。

```swift
@Observable
final class SyncCoordinator {
    private let historyObserver: HistoryObserver
    private var lastToken: DefaultHistoryToken?

    init(modelContainer: ModelContainer) {
        historyObserver = HistoryObserver(modelContainer: modelContainer)
        // 观察 historyObserver.eventCounter，变化后 fetchHistory 并推送后端
    }

    func processNewHistory(in context: ModelContext) throws {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        // 可结合 HistoryDescriptor.sortBy（iOS 26+）排序
        let transactions = try context.fetchHistory(descriptor)
        // 处理 insert / update / delete，更新 lastToken
    }
}
```

| 需求 | 用什么 |
|------|--------|
| SwiftUI 列表展示 | `@Query` |
| 视图外派生状态 | `ResultsObserver` |
| 与后端增量同步 | `HistoryObserver` + `fetchHistory` |

---

## June 2025（iOS 26+）

### 模型继承

`@Model` 支持 inheritance，可建类型层次（基类 + 子类），共享属性与差异化字段更清晰。

```swift
@Model
class Animal {
    var name: String
    init(name: String) { self.name = name }
}

@Model
class Dog: Animal {
    var breed: String
    init(name: String, breed: String) {
        self.breed = breed
        super.init(name: name)
    }
}
```

### HistoryDescriptor.sortBy

事务历史可按指定方式排序，配合 `fetchHistory` 更灵活地消费变更流。

---

## June 2024（iOS 18+）

### 索引与唯一约束

```swift
@Model
final class Person {
    #Unique<Person>([\.email])
    #Index<Person>([\.lastName, \.firstName], [\.email])

    var email: String
    var firstName: String
    var lastName: String
}
```

- `@Index` / `#Index`：加速排序与 predicate fetch（含复合索引）
- `@Unique` / `#Unique`：单属性或多属性元组唯一

### 单向关系

```swift
@Relationship(inverse: nil)
var notes: [Note]?
```

`inverse: nil` 表示单向关系。

### 持久化历史

```swift
let transactions = try modelContext.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
try modelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>())
```

自定义 store 可实现 `HistoryProviding` 提供变更追踪策略。

### 自定义持久化

实现 `DataStore`（及相关协议）可替换默认存储，把模型落到自有后端 / 文件格式。

---

## 怎么选观察方式

```
只做 UI 列表 / 详情     →  @Query
派生业务状态（可测）    →  ResultsObserver + @Observable
推送/拉取远端增量      →  HistoryObserver + fetchHistory
```

---

## ⚠️ Important Notes

- **`sectionBy`**：只能用持久化属性；分组字段可能需要冗余存储。
- **`.codable`**：不能过滤/排序；自有类型尽量拆列；第三方类型才用 blob。
- **`ResultsObserver`**：保留 token；适合服务层，不要把所有逻辑塞进 Observable。
- **`HistoryObserver`**：配合历史清理（`deleteHistory`）避免历史无限膨胀。
- 部署目标：分段 / Observer / `.codable` 需 **iOS 27+**；继承需 **iOS 26+**；索引/历史需 **iOS 18+**。

---

## 参考资料

- [SwiftData updates](https://developer.apple.com/documentation/updates/swiftdata)
- [WWDC 2026 — What’s new in SwiftData](https://developer.apple.com/videos/play/wwdc2026/274/)
- [Additional Query Macros](https://developer.apple.com/documentation/swiftdata/additionalquerymacros)
- [ModelContext.fetchHistory](https://developer.apple.com/documentation/swiftdata/modelcontext/fetchhistory(_:))
- [DataStore](https://developer.apple.com/documentation/swiftdata/datastore)
