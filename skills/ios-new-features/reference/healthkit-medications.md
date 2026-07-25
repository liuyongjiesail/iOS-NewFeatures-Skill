# HealthKit Medications API — 用药与剂量事件读取

> **适用范围：** iOS 26+ / iPadOS 26+ / visionOS 26+
> **来源：** WWDC 2025 Session 321
> **框架：** HealthKit
>
> 本文档涵盖 HealthKit 全新的 Medications API：读取用户在“健康”App 中管理的药品（HKUserAnnotatedMedication）、剂量事件（HKMedicationDoseEvent），以及按对象授权、锚定对象查询和 RxNorm 临床编码关联。

---

## 目录

1. [功能概览](#功能概览)
2. [核心数据模型](#核心数据模型)
3. [授权（按对象授权）](#授权按对象授权)
4. [查询药品列表](#查询药品列表)
5. [查询剂量事件](#查询剂量事件)
6. [锚定对象查询（实时更新）](#锚定对象查询实时更新)
7. [RxNorm 关联副作用](#rxnorm-关联副作用)
8. [新药品的访问授权](#新药品的访问授权)
9. [完整示例](#完整示例)
10. [最佳实践](#最佳实践)

---

## 功能概览

自 iOS 15 起“健康”App 支持用药跟踪（添加药品、设置提醒、记录剂量），数据安全存储在 HealthKit 中。WWDC 2025 起，第三方 App 首次可以**读取**这些用药数据，用于打造个性化用药管理体验。

| 能力 | API |
|------|-----|
| 表示一款药品（含用户自定信息） | `HKUserAnnotatedMedication` |
| 表示具体药品概念（临床信息） | `HKMedicationConcept` |
| 表示一次剂量记录（新 HKSample） | `HKMedicationDoseEvent` |
| 获取药品列表 | `HKUserAnnotatedMedicationQueryDescriptor` / `HKUserAnnotatedMedicationQuery` |
| 获取剂量事件 | `HKSampleQuery` / `HKAnchoredObjectQuery` / `HKObserverQuery` |
| 按对象授权 | `HKUserAnnotatedMedicationType` + per-object authorization |

**平台：** iOS、iPadOS、visionOS。

---

## 核心数据模型

### HKUserAnnotatedMedication（用户备注药品）

代表一款药品加上用户的自定信息，有 4 个关键属性：

| 属性 | 说明 |
|------|------|
| `isArchived` | 用户已结束用药 / 不再需要，折叠在“存档”区，不出现在活跃列表 |
| `hasSchedule` | 是否设置了定时提醒；设置后系统会定时通知记录用药 |
| `nickname` | 用户自定义的别名（如“抗生素”），比临床名更易记 |
| `medicationConcept` | 关联的 `HKMedicationConcept`，含实际临床信息 |

### HKMedicationConcept（药品概念）

代表药品本身的概念（不是处方记录）：

| 属性 | 说明 |
|------|------|
| `identifier` | 全局唯一标识符，跨设备/时间稳定识别同一药品 |
| `displayText` | 药品显示名称，如 `Amoxicillin Trihydrate 500mg Oral Tablet` |
| `generalForm` | 物理形态：胶囊 / 片剂 / 液体等 |
| `relatedCodings` | 关联的临床编码集合（如 RxNorm），用于互操作与分类 |

### HKMedicationDoseEvent（剂量事件）

一种**新的 HKSample**，代表计划或实际的用药记录：

| 属性 | 说明 |
|------|------|
| `medicationConceptIdentifier` | 关联的药品概念标识符（= `HKMedicationConcept.identifier`） |
| `logStatus` | 记录状态：`.taken` / `.skipped` / `.notInteracted` 等 |
| `scheduledDate` / `scheduledQuantity` | 设定的用药日期与剂量 |
| `doseQuantity` | 实际用药剂量（与 scheduled 不同即表示有偏差；跳过时为 0） |
| `startDate` | 记录时选择的时间 |

---

## 授权（按对象授权）

药品是**对象（object）**而非示例（sample），需要使用**按对象授权**（per-object authorization）。用户在授权表中逐个勾选愿意共享的药品。

```swift
import HealthKit
import SwiftUI

struct MedicationAuthorizationView: View {
    let healthStore = HKHealthStore()
    @State private var requestAuthorization = false

    var body: some View {
        ContentView()
            .healthDataAccessRequestPerObject(
                store: healthStore,
                objectType: HKUserAnnotatedMedicationType(),
                trigger: requestAuthorization
            ) { result in
                switch result {
                case .success:
                    break // 妥善处理成功
                case .failure(let error):
                    print("授权失败: \(error)")
                }
            }
            .onAppear { requestAuthorization = true }
    }
}
```

> 用户授权读取药品后，App **自动获得**读取药品与剂量事件的权限，无需单独申请剂量事件权限。

如果还需要读写“症状”类别示例（如头痛、恶心），用常规的示例类型授权单独请求：

```swift
let symptomTypes: Set<HKSampleType> = [
    HKCategoryType(.headache),
    HKCategoryType(.nausea)
]

try await healthStore.requestAuthorization(
    toShare: symptomTypes,
    read: symptomTypes
)
```

---

## 查询药品列表

使用新的 `HKUserAnnotatedMedicationQueryDescriptor`。不带谓词/限制则同时返回活跃与存档药品。

```swift
func fetchMedications() async throws -> [HKUserAnnotatedMedication] {
    let descriptor = HKUserAnnotatedMedicationQueryDescriptor(
        predicate: nil,   // nil = 活跃 + 存档全部
        limit: nil
    )
    return try await descriptor.result(for: healthStore)
}
```

**可用谓词：**

```swift
// 只要活跃（未存档）的药品
let activeOnly = HKUserAnnotatedMedicationQueryDescriptor(
    predicate: .userAnnotatedMedication(isArchived: false),
    limit: nil
)

// 只要设置了定时提醒的药品
let scheduled = HKUserAnnotatedMedicationQueryDescriptor(
    predicate: .userAnnotatedMedication(hasSchedule: true),
    limit: nil
)
```

App 只能查询到用户已授权共享的药品。

---

## 查询剂量事件

剂量事件是 `HKSample`，可用任意基于示例类型的查询（示例查询、锚定对象查询、观察者查询），示例类型为 `HKSampleType(.medicationDoseEvent)`。最实用的过滤是**按药品**和**按记录状态**。

```swift
func fetchTodayDose(for concept: HKMedicationConcept) async throws -> HKMedicationDoseEvent? {
    // 复合谓词：指定药品 + 当天 + 状态为已用药
    let medicationPredicate = HKQuery.predicateForMedicationDoseEvent(
        medicationConceptIdentifier: concept.identifier
    )
    let today = Calendar.current.startOfDay(for: .now)
    let datePredicate = HKQuery.predicateForSamples(
        withStart: today, end: .now, options: .strictStartDate
    )
    let statusPredicate = HKQuery.predicateForMedicationDoseEvent(logStatus: .taken)

    let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [
        medicationPredicate, datePredicate, statusPredicate
    ])

    let descriptor = HKSampleQueryDescriptor(
        predicates: [.medicationDoseEvent(compound)],
        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
        limit: 1
    )

    return try await descriptor.result(for: healthStore).first
}
```

---

## 锚定对象查询（实时更新）

需要随 HealthKit 数据变化持续更新（如图表）时，用**锚定对象查询**。它先返回现有示例快照，之后持续推送新增和删除。

```swift
func observeDoseEvents(
    for concept: HKMedicationConcept,
    in dateRange: ClosedRange<Date>
) async throws {
    let predicate = HKQuery.predicateForMedicationDoseEvent(
        medicationConceptIdentifier: concept.identifier
    )
    let datePredicate = HKQuery.predicateForSamples(
        withStart: dateRange.lowerBound, end: dateRange.upperBound
    )
    let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])

    let descriptor = HKAnchoredObjectQueryDescriptor(
        predicates: [.medicationDoseEvent(compound)],
        anchor: nil   // nil = 从头开始
    )

    // Swift 异步序列接口，后台线程执行
    for try await result in descriptor.results(for: healthStore) {
        handleResult(added: result.addedSamples, deleted: result.deletedObjects)
        // 使用 result.newAnchor 避免重复处理
    }
}
```

**要点：**
- 用返回的 `newAnchor` 避免重复处理数据；从头查询则设 `anchor: nil`。
- 结果中的 `deletedObjects` 要主动清理（剂量事件可被编辑/删除）。
- 锚定对象查询通常比“观察者查询 + 示例查询”配对更高效。
- 剂量事件可能在几天后补记、被编辑删除、或保存为从未交互的提醒，务必持续同步以与“健康”App 保持一致。

---

## RxNorm 关联副作用

`HKMedicationConcept.relatedCodings` 含临床编码（基于官方 FHIR 术语系统）。RxNorm 用唯一标识符表示临床药物，可用于把药品映射到已知副作用症状。

```swift
enum RxNorm {
    static let system = "http://www.nlm.nih.gov/research/umls/rxnorm"
}

extension HKMedicationConcept {
    /// 从 relatedCodings 中取出 RxNorm 代码
    var rxNormCode: String? {
        relatedCodings.first { $0.system == RxNorm.system }?.code
    }

    /// 用静态字典把药品映射为相关症状类别类型
    func sideEffectTypes() -> [HKCategoryType] {
        guard let code = rxNormCode else { return [] }
        return SideEffects.symptoms(forRxNorm: code)
    }
}
```

记录副作用严重程度（表情符号 → 类别示例）：

```swift
enum SymptomIntensity: Int, CaseIterable {
    case none, mild, moderate, severe, extreme

    var categoryValue: Int {
        // 关联到对应的 HKCategoryValueSeverity
        switch self {
        case .none:     return HKCategoryValueSeverity.notPresent.rawValue
        case .mild:     return HKCategoryValueSeverity.mild.rawValue
        case .moderate: return HKCategoryValueSeverity.moderate.rawValue
        case .severe, .extreme: return HKCategoryValueSeverity.severe.rawValue
        }
    }
}

func saveSymptom(_ type: HKCategoryType, intensity: SymptomIntensity) async throws {
    let sample = HKCategorySample(
        type: type,
        value: intensity.categoryValue,
        start: .now,
        end: .now
    )
    try await healthStore.save(sample)
}
```

---

## 新药品的访问授权

用户在“健康”App 中新增药品时，若你的 App 已请求过用药访问权限，系统会在“健康”App 内弹出一个开关，让用户选择是否把新药品共享给你的 App。整个流程在“健康”App 内完成，**你的 App 无需任何额外代码**。用户返回你的 App 后即可看到新药品。

---

## 完整示例

```swift
import SwiftUI
import HealthKit

@Observable
final class MedicationStore {
    let healthStore = HKHealthStore()
    var medications: [HKUserAnnotatedMedication] = []

    func loadMedications() async {
        do {
            let descriptor = HKUserAnnotatedMedicationQueryDescriptor(
                predicate: nil, limit: nil
            )
            medications = try await descriptor.result(for: healthStore)
        } catch {
            print("查询药品失败: \(error)")
        }
    }

    func latestTakenDose(
        for concept: HKMedicationConcept
    ) async -> HKMedicationDoseEvent? {
        let today = Calendar.current.startOfDay(for: .now)
        let predicates: [NSPredicate] = [
            HKQuery.predicateForMedicationDoseEvent(
                medicationConceptIdentifier: concept.identifier
            ),
            HKQuery.predicateForSamples(withStart: today, end: .now),
            HKQuery.predicateForMedicationDoseEvent(logStatus: .taken)
        ]
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.medicationDoseEvent(compound)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        return try? await descriptor.result(for: healthStore).first
    }
}

struct MedicationListView: View {
    @State private var store = MedicationStore()

    var body: some View {
        List(store.medications, id: \.medicationConcept.identifier) { med in
            VStack(alignment: .leading) {
                Text(med.nickname ?? med.medicationConcept.displayText)
                    .font(.headline)
                Text(med.medicationConcept.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await store.loadMedications() }
    }
}
```

---

## 最佳实践

- **用按对象授权**读取药品（`HKUserAnnotatedMedicationType`），授权后自动获得剂量事件读取权限。
- **剂量事件按药品 + 状态过滤**最实用；用复合谓词精确限定。
- **实时体验用锚定对象查询**：保存 `newAnchor`、处理 `deletedObjects`、优先 Swift 异步序列接口。
- **深入 RxNorm** 等临床编码系统，把药品与副作用、教育内容等关联，打造更完整体验。
- 注意剂量事件可补记/编辑/删除，避免展示过时数据。
- 关注 `logStatus` 的各种含义（已用药 / 已跳过 / 未交互）。

---

## 参考资料

- [WWDC 2025 Session 321 - Explore the Medications API in HealthKit](https://developer.apple.com/videos/play/wwdc2025/321)
- [Authorizing access to health data](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data)
- [requiresPerObjectAuthorization()](https://developer.apple.com/documentation/HealthKit/HKObjectType/requiresPerObjectAuthorization())
- [HKAnchoredObjectQuery](https://developer.apple.com/documentation/HealthKit/HKAnchoredObjectQuery)
- [HKSampleQuery](https://developer.apple.com/documentation/HealthKit/HKSampleQuery)
- [Logging symptoms associated with a medication](https://developer.apple.com/documentation/HealthKit/logging-symptoms-associated-with-a-medication)
