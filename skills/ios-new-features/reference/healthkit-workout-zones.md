# HealthKit 体能训练区间 — 心率区间与骑行功率区间

> **适用范围：** iOS 27+ / watchOS 27+  
> **来源：** WWDC 2026 Session 207  
> **框架：** HealthKit
> 
> 本文档涵盖 HealthKit 体能训练区间功能，包括心率区间和骑行功率区间的获取、实时更新、首选区间配置和自定义区间设置。

---

## 目录

1. [功能概览](#功能概览)
2. [核心概念](#核心概念)
3. [获取区间数据](#获取区间数据)
4. [实时区间更新](#实时区间更新)
5. [首选区间配置](#首选区间配置)
6. [自定义区间](#自定义区间)
7. [完整示例](#完整示例)
8. [最佳实践](#最佳实践)

---

## 功能概览

### 核心特性

| 特性 | 说明 |
|------|------|
| **心率区间** | 基于个人年龄和静息心率的个性化训练区间 |
| **骑行功率区间** | 基于功能性阈值功率 (FTP) 的骑行功率区间 |
| **自动计算** | HealthKit 自动计算每个区间花费的时间 |
| **实时更新** | 锻炼期间区间变化的实时通知 |
| **多区间支持** | 支持 3-9 个区间配置 |
| **跨设备同步** | 首选区间通过 HealthKit 在设备间同步 |

### 使用场景

**训练指导：**
- 耐力训练：保持在特定阈值以下
- 间歇训练：保持在特定水平或以上一段时间
- 恢复和负荷平衡：分析锻炼强度分布

**应用功能：**
- 锻炼后摘要：显示各区间花费时间
- 实时教练：显示当前区间并在变化时通知
- 长期训练仪表盘：跨锻炼比较强度分布

---

## 核心概念

### 心率区间

**定义：** 基于个人年龄和静息心率计算的训练强度区间

**典型 5 区间模型：**

| 区间 | 强度 | 占最大心率 | 典型用途 |
|------|------|-----------|---------|
| 区间 1 | 非常轻松 | 50-60% | 热身、恢复 |
| 区间 2 | 轻松 | 60-70% | 有氧基础、脂肪燃烧 |
| 区间 3 | 中等 | 70-80% | 有氧耐力 |
| 区间 4 | 困难 | 80-90% | 乳酸阈值训练 |
| 区间 5 | 最大 | 90-100% | 最大强度、无氧训练 |

**个性化计算：**
```
最大心率 (MHR) = 220 - 年龄
储备心率 (HRR) = 最大心率 - 静息心率
目标心率 = (HRR × 强度%) + 静息心率
```

### 骑行功率区间

**定义：** 基于功能性阈值功率 (FTP) 的训练区间

**典型 6 区间模型：**

| 区间 | 强度 | 占 FTP | 典型用途 |
|------|------|--------|---------|
| 区间 1 | 主动恢复 | <55% | 恢复骑行 |
| 区间 2 | 耐力 | 55-75% | 长距离有氧 |
| 区间 3 | 节奏 | 75-90% | 稳定节奏骑行 |
| 区间 4 | 乳酸阈值 | 90-105% | 阈值训练 |
| 区间 5 | VO2 Max | 105-120% | 高强度间歇 |
| 区间 6 | 无氧 | >120% | 冲刺、最大功率 |

### 区间数据结构

```
HKWorkout 或 HKWorkoutActivity
   ↓
zoneGroupsByType[HKQuantityType]
   ↓
HKWorkoutZoneGroup
   ├── configuration: HKWorkoutZoneConfiguration
   │      ├── quantityType: HKQuantityType (心率或功率)
   │      ├── source: 来源 (系统/用户/自定义)
   │      └── zones: [HKWorkoutZone]
   │             ├── index: Int
   │             ├── minimumQuantity: HKQuantity?
   │             └── maximumQuantity: HKQuantity?
   └── zoneDurations: [HKWorkoutZoneDuration]
          ├── zone: HKWorkoutZone
          └── duration: TimeInterval
```

---

## 获取区间数据

### 授权

在访问区间数据前，需要请求相关权限：

```swift
import HealthKit

let healthStore = HKHealthStore()

let typesToRead: Set<HKObjectType> = [
    HKObjectType.workoutType(),
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .cyclingPower)!
]

healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
    if success {
        // 已授权，可以访问区间数据
    }
}
```

### 从已完成的锻炼读取心率区间

```swift
import HealthKit

func readHeartRateZones(from workout: HKWorkout) {
    // 获取心率区间组
    if let heartRateZoneGroup = workout.zoneGroupsByType?[HKQuantityType(.heartRate)] {
        
        // 获取区间配置
        let configuration = heartRateZoneGroup.configuration
        print("区间数量: \(configuration.zones.count)")
        print("来源: \(configuration.source)")
        
        // 遍历每个区间
        for zone in configuration.zones {
            print("区间 \(zone.index):")
            
            if let min = zone.minimumQuantity {
                let bpm = min.doubleValue(for: .beatsPerMinute())
                print("  最小值: \(bpm) bpm")
            } else {
                print("  最小值: 无下界")
            }
            
            if let max = zone.maximumQuantity {
                let bpm = max.doubleValue(for: .beatsPerMinute())
                print("  最大值: \(bpm) bpm")
            } else {
                print("  最大值: 无上界")
            }
        }
        
        // 获取每个区间的时长
        for zoneDuration in heartRateZoneGroup.zoneDurations {
            let zoneIndex = zoneDuration.zone.index
            let duration = zoneDuration.duration
            print("区间 \(zoneIndex): \(Int(duration / 60)) 分 \(Int(duration.truncatingRemainder(dividingBy: 60))) 秒")
        }
    }
}
```

### 从锻炼活动读取区间

对于多运动锻炼，可以从单个活动获取区间：

```swift
func readZonesFromActivity(_ activity: HKWorkoutActivity) {
    if let heartRateZoneGroup = activity.zoneGroupsByType?[HKQuantityType(.heartRate)] {
        // 处理该活动的心率区间
        processZoneGroup(heartRateZoneGroup)
    }
}

func readZonesFromWorkout(_ workout: HKWorkout) {
    // 选项 1: 获取整个锻炼的区间
    if let overallZones = workout.zoneGroupsByType?[HKQuantityType(.heartRate)] {
        print("整体锻炼区间:")
        processZoneGroup(overallZones)
    }
    
    // 选项 2: 获取每个活动的区间
    for activity in workout.workoutActivities {
        if let activityZones = activity.zoneGroupsByType?[HKQuantityType(.heartRate)] {
            print("\(activity.workoutConfiguration.activityType) 区间:")
            processZoneGroup(activityZones)
        }
    }
}
```

### 读取骑行功率区间

```swift
func readCyclingPowerZones(from workout: HKWorkout) {
    // 获取骑行功率区间组
    if let powerZoneGroup = workout.zoneGroupsByType?[HKQuantityType(.cyclingPower)] {
        
        let configuration = powerZoneGroup.configuration
        print("骑行功率区间数量: \(configuration.zones.count)")
        
        // 遍历功率区间
        for zoneDuration in powerZoneGroup.zoneDurations {
            let zone = zoneDuration.zone
            let duration = zoneDuration.duration
            
            var minWatts = "无下界"
            if let min = zone.minimumQuantity {
                minWatts = "\(Int(min.doubleValue(for: .watt()))) W"
            }
            
            var maxWatts = "无上界"
            if let max = zone.maximumQuantity {
                maxWatts = "\(Int(max.doubleValue(for: .watt()))) W"
            }
            
            print("区间 \(zone.index): \(minWatts) - \(maxWatts), 时长: \(Int(duration)) 秒")
        }
    }
}
```

---

## 实时区间更新

### 实现委托

使用 `HKLiveWorkoutBuilderDelegate` 接收实时区间变化：

```swift
import HealthKit

class WorkoutManager: NSObject, HKLiveWorkoutBuilderDelegate {
    let healthStore = HKHealthStore()
    var workoutBuilder: HKLiveWorkoutBuilder?
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        workoutBuilder = HKLiveWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration
        )
        
        workoutBuilder?.delegate = self
        
        // 开始数据收集
        let startDate = Date()
        workoutBuilder?.beginCollection(at: startDate) { success, error in
            if success {
                print("开始追踪锻炼")
            }
        }
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    
    // 处理区间变化
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate
    ) {
        guard let zoneGroup = zoneUpdate.zoneGroup else { return }
        
        // 当前区间
        if let currentZone = zoneUpdate.currentZoneDuration {
            print("当前区间: \(currentZone.zone.index)")
            print("当前区间时长: \(currentZone.duration) 秒")
        }
        
        // 上一个区间
        if let previousZone = zoneUpdate.previousZoneDuration {
            print("从区间 \(previousZone.zone.index) 变化")
        }
        
        // 最后处理样本的时间戳
        let timestamp = zoneUpdate.lastSampleDate
        print("更新时间: \(timestamp)")
        
        // 更新 UI
        Task { @MainActor in
            updateZoneUI(with: zoneGroup, currentIndex: currentZone?.zone.index)
        }
    }
    
    // 处理其他更新
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // 处理其他数据类型更新
    }
    
    @MainActor
    func updateZoneUI(with zoneGroup: HKWorkoutZoneGroup, currentIndex: Int?) {
        // 更新 UI 以显示当前区间
        // 例如高亮显示当前区间，显示各区间时长
    }
}
```

### 完整实时更新示例

```swift
import HealthKit
import Combine

class LiveWorkoutViewModel: NSObject, ObservableObject {
    @Published var currentZoneIndex: Int?
    @Published var zoneDurations: [TimeInterval] = []
    @Published var isWorkoutActive = false
    
    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    func startWorkout(activityType: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        
        workoutBuilder = HKLiveWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration
        )
        workoutBuilder?.delegate = self
        
        Task {
            do {
                try await workoutBuilder?.beginCollection(at: Date())
                await MainActor.run {
                    isWorkoutActive = true
                }
            } catch {
                print("开始锻炼失败: \(error)")
            }
        }
    }
    
    func endWorkout() {
        Task {
            do {
                try await workoutBuilder?.endCollection(at: Date())
                let workout = try await workoutBuilder?.finishWorkout()
                await MainActor.run {
                    isWorkoutActive = false
                }
                print("锻炼已完成")
            } catch {
                print("结束锻炼失败: \(error)")
            }
        }
    }
}

extension LiveWorkoutViewModel: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate
    ) {
        guard let zoneGroup = zoneUpdate.zoneGroup else { return }
        
        let currentIndex = zoneUpdate.currentZoneDuration?.zone.index
        let durations = zoneGroup.zoneDurations.map(\.duration)
        
        Task { @MainActor in
            self.currentZoneIndex = currentIndex
            self.zoneDurations = durations
        }
    }
    
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // 处理其他数据更新
    }
}
```

---

## 首选区间配置

### 查询首选区间

```swift
import HealthKit

func checkPreferredZoneConfiguration() async throws {
    let healthStore = HKHealthStore()
    
    // 从 HKHealthStore 查询
    let heartRateType = HKQuantityType(.heartRate)
    if let preferredConfig = try await healthStore.zoneConfiguration(for: heartRateType) {
        print("首选心率区间已配置")
        print("来源: \(preferredConfig.source)")
        print("区间数量: \(preferredConfig.zones.count)")
    } else {
        print("未配置首选心率区间")
    }
}

func checkPreferredZoneFromBuilder(_ builder: HKWorkoutBuilder) async throws {
    let heartRateType = HKQuantityType(.heartRate)
    
    // 从 HKWorkoutBuilder 查询
    if let config = try await builder.zoneConfiguration(for: heartRateType) {
        print("构建器使用的区间配置:")
        for zone in config.zones {
            print("区间 \(zone.index): \(zone.minimumQuantity) - \(zone.maximumQuantity)")
        }
    }
}
```

### 区间来源类型

```swift
enum HKWorkoutZoneSource {
    case system      // 由系统自动计算（基于年龄、静息心率等）
    case user        // 用户在健康设置中手动配置
    case custom      // 应用在锻炼时自定义提供
}

func describeZoneSource(_ source: HKWorkoutZoneSource) -> String {
    switch source {
    case .system:
        return "系统自动计算"
    case .user:
        return "用户手动设置"
    case .custom:
        return "应用自定义"
    }
}
```

### 何时使用首选区间

**优点：**
- ✅ 跨应用和设备一致
- ✅ 通过 HealthKit 自动同步
- ✅ 基于用户个人数据计算（系统区间）
- ✅ 用户可在健康设置中管理

**适用场景：**
- 通用训练应用
- 遵循标准训练模型
- 希望与其他健康应用保持一致

---

## 自定义区间

### 何时使用自定义区间

**适用场景：**
- 训练平台有专有区间模型
- 特定训练计划需要特殊区间划分
- 用户未配置首选区间时提供默认值
- 需要不同于标准的区间数量（如 7 区间模型）

### 创建自定义区间配置

```swift
import HealthKit

func createCustomHeartRateZones() throws -> HKWorkoutZoneConfiguration {
    // 1. 定义区间阈值（边界值）
    let thresholds = [91.0, 114.0, 136.0, 158.0] // 5 个区间需要 4 个边界
    
    // 2. 创建 HKQuantity 边界
    let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    let boundaries = thresholds.map { HKQuantity(unit: bpmUnit, doubleValue: $0) }
    
    // 3. 创建区间配置
    let heartRateType = HKQuantityType(.heartRate)
    let configuration = try HKWorkoutZoneConfiguration(
        quantityType: heartRateType,
        zoneBoundaries: boundaries
    )
    
    return configuration
}

func createCustomCyclingPowerZones(ftp: Double) throws -> HKWorkoutZoneConfiguration {
    // 基于 FTP 计算功率区间
    let thresholds = [
        ftp * 0.55,  // 区间 1-2 边界
        ftp * 0.75,  // 区间 2-3 边界
        ftp * 0.90,  // 区间 3-4 边界
        ftp * 1.05,  // 区间 4-5 边界
        ftp * 1.20   // 区间 5-6 边界
    ]
    
    let wattUnit = HKUnit.watt()
    let boundaries = thresholds.map { HKQuantity(unit: wattUnit, doubleValue: $0) }
    
    let powerType = HKQuantityType(.cyclingPower)
    return try HKWorkoutZoneConfiguration(
        quantityType: powerType,
        zoneBoundaries: boundaries
    )
}
```

### 将自定义区间应用到锻炼

```swift
func startWorkoutWithCustomZones() async throws {
    let healthStore = HKHealthStore()
    
    // 1. 创建锻炼配置
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .running
    
    // 2. 创建构建器
    let builder = HKLiveWorkoutBuilder(
        healthStore: healthStore,
        configuration: configuration
    )
    
    // 3. 检查是否已有首选区间
    let heartRateType = HKQuantityType(.heartRate)
    if try await builder.zoneConfiguration(for: heartRateType) == nil {
        // 4. 如果没有，设置自定义区间
        let customConfig = try createCustomHeartRateZones()
        try await builder.setCustomZoneConfiguration(customConfig, for: heartRateType)
        print("已应用自定义心率区间")
    } else {
        print("使用首选心率区间")
    }
    
    // 5. 开始数据收集
    // ⚠️ 必须在 beginCollection 之前设置自定义区间
    try await builder.beginCollection(at: Date())
}
```

### 完整自定义区间示例

```swift
class CustomZoneWorkoutManager: NSObject {
    let healthStore = HKHealthStore()
    var workoutBuilder: HKLiveWorkoutBuilder?
    
    func startWorkoutWithFallbackZones() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        
        let builder = HKLiveWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration
        )
        self.workoutBuilder = builder
        builder.delegate = self
        
        // 检查并设置区间
        try await setupZoneConfiguration(builder: builder)
        
        // 开始收集数据
        try await builder.beginCollection(at: Date())
    }
    
    private func setupZoneConfiguration(builder: HKLiveWorkoutBuilder) async throws {
        let heartRateType = HKQuantityType(.heartRate)
        
        // 检查是否已配置首选区间
        if try await builder.zoneConfiguration(for: heartRateType) == nil {
            print("未配置首选区间，使用自定义默认值")
            
            // 创建默认区间
            let defaultThresholds = [91.0, 114.0, 136.0, 158.0]
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let boundaries = defaultThresholds.map { 
                HKQuantity(unit: bpmUnit, doubleValue: $0) 
            }
            
            let customConfig = try HKWorkoutZoneConfiguration(
                quantityType: heartRateType,
                zoneBoundaries: boundaries
            )
            
            // 设置自定义区间
            try await builder.setCustomZoneConfiguration(customConfig, for: heartRateType)
        } else {
            print("使用用户的首选区间配置")
        }
    }
}

extension CustomZoneWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate
    ) {
        // 处理区间更新
    }
    
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // 处理数据收集
    }
}
```

### 自定义区间的重要注意事项

```swift
// ⚠️ 区间数量限制
let validZoneCounts = 3...9  // 必须在 3-9 之间

// ⚠️ 边界单位必须匹配
let correctWay = HKQuantity(unit: .beatsPerMinute(), doubleValue: 120.0)
// ❌ 错误：let wrongWay = HKQuantity(unit: .watt(), doubleValue: 120.0)  // 心率用瓦特

// ⚠️ 边界顺序必须递增
let correctBoundaries = [100.0, 120.0, 140.0, 160.0]  // ✅ 递增
// ❌ 错误：let wrongBoundaries = [160.0, 140.0, 120.0, 100.0]  // 递减

// ⚠️ 自定义区间仅保存在锻炼上下文中
// 应用负责保存和同步自定义区间配置
```


---

## 完整示例

### 示例 1: 带区间追踪的锻炼应用

```swift
import HealthKit
import SwiftUI

class WorkoutZoneManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isWorkoutActive = false
    @Published var currentZoneIndex: Int?
    @Published var zoneDurations: [TimeInterval] = []
    @Published var totalElapsedTime: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    
    // MARK: - Start Workout
    
    func startWorkout(activityType: HKWorkoutActivityType) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        let builder = HKLiveWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration
        )
        self.workoutBuilder = builder
        builder.delegate = self
        
        // 检查并设置区间配置
        try await setupZoneConfiguration(builder: builder)
        
        // 开始收集数据
        let date = Date()
        self.startDate = date
        try await builder.beginCollection(at: date)
        
        await MainActor.run {
            self.isWorkoutActive = true
        }
    }
    
    // MARK: - End Workout
    
    func endWorkout() async throws {
        guard let builder = workoutBuilder else { return }
        
        try await builder.endCollection(at: Date())
        let workout = try await builder.finishWorkout()
        
        await MainActor.run {
            self.isWorkoutActive = false
        }
        
        // 显示摘要
        displayWorkoutSummary(workout: workout)
    }
    
    // MARK: - Setup Zone Configuration
    
    private func setupZoneConfiguration(builder: HKLiveWorkoutBuilder) async throws {
        let heartRateType = HKQuantityType(.heartRate)
        
        if try await builder.zoneConfiguration(for: heartRateType) == nil {
            // 创建默认区间
            let defaultZones = try createDefaultHeartRateZones()
            try await builder.setCustomZoneConfiguration(defaultZones, for: heartRateType)
            print("使用自定义默认区间")
        } else {
            print("使用首选区间配置")
        }
    }
    
    private func createDefaultHeartRateZones() throws -> HKWorkoutZoneConfiguration {
        let thresholds = [91.0, 114.0, 136.0, 158.0]
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let boundaries = thresholds.map { HKQuantity(unit: bpmUnit, doubleValue: $0) }
        
        return try HKWorkoutZoneConfiguration(
            quantityType: HKQuantityType(.heartRate),
            zoneBoundaries: boundaries
        )
    }
    
    // MARK: - Display Summary
    
    private func displayWorkoutSummary(workout: HKWorkout) {
        if let heartRateZoneGroup = workout.zoneGroupsByType?[HKQuantityType(.heartRate)] {
            print("\n=== 锻炼摘要 ===")
            print("总时长: \(Int(workout.duration / 60)) 分钟")
            print("\n心率区间分布:")
            
            for zoneDuration in heartRateZoneGroup.zoneDurations {
                let zone = zoneDuration.zone
                let duration = zoneDuration.duration
                let percentage = (duration / workout.duration) * 100
                
                print("区间 \(zone.index): \(Int(duration / 60)) 分钟 (\(Int(percentage))%)")
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutZoneManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate
    ) {
        guard let zoneGroup = zoneUpdate.zoneGroup else { return }
        
        let currentIndex = zoneUpdate.currentZoneDuration?.zone.index
        let durations = zoneGroup.zoneDurations.map(\.duration)
        
        Task { @MainActor in
            self.currentZoneIndex = currentIndex
            self.zoneDurations = durations
            
            // 计算总时长
            if let start = startDate {
                self.totalElapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // 处理其他数据类型
    }
}
```

### 示例 2: SwiftUI 锻炼视图

```swift
import SwiftUI

struct WorkoutZoneView: View {
    @StateObject private var manager = WorkoutZoneManager()
    
    var body: some View {
        VStack(spacing: 20) {
            if manager.isWorkoutActive {
                // 当前区间
                if let currentZone = manager.currentZoneIndex {
                    VStack {
                        Text("当前区间")
                            .font(.headline)
                        Text("区间 \(currentZone + 1)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(zoneColor(currentZone))
                    }
                }
                
                // 区间分布
                ZoneDistributionChart(
                    zoneDurations: manager.zoneDurations,
                    currentZone: manager.currentZoneIndex
                )
                
                // 总时长
                Text(formatTime(manager.totalElapsedTime))
                    .font(.title2)
                    .monospacedDigit()
                
                // 结束按钮
                Button("结束锻炼") {
                    Task {
                        try? await manager.endWorkout()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                // 开始按钮
                Button("开始跑步") {
                    Task {
                        try? await manager.startWorkout(activityType: .running)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    func zoneColor(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .yellow, .orange, .red]
        return colors[safe: index] ?? .gray
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ZoneDistributionChart: View {
    let zoneDurations: [TimeInterval]
    let currentZone: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("区间分布")
                .font(.headline)
            
            ForEach(Array(zoneDurations.enumerated()), id: \.offset) { index, duration in
                HStack {
                    Text("区间 \(index + 1)")
                        .frame(width: 60, alignment: .leading)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                            
                            Rectangle()
                                .fill(zoneColor(index))
                                .frame(width: barWidth(duration, maxWidth: geometry.size.width))
                        }
                    }
                    .frame(height: 20)
                    .cornerRadius(4)
                    
                    Text(formatDuration(duration))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
                .opacity(currentZone == index ? 1.0 : 0.6)
            }
        }
    }
    
    func barWidth(_ duration: TimeInterval, maxWidth: CGFloat) -> CGFloat {
        let maxDuration = zoneDurations.max() ?? 1
        return maxWidth * CGFloat(duration / maxDuration)
    }
    
    func zoneColor(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .yellow, .orange, .red]
        return colors[safe: index] ?? .gray
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```

### 示例 3: 比较不同锻炼的区间数据

```swift
import HealthKit

class WorkoutZoneAnalyzer {
    let healthStore = HKHealthStore()
    
    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            // 处理结果
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var query: HKSampleQuery?
            query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = samples as? [HKWorkout] ?? []
                    continuation.resume(returning: workouts)
                }
            }
            healthStore.execute(query!)
        }
    }
    
    func analyzeZoneDistribution(workouts: [HKWorkout]) {
        for workout in workouts {
            if let zoneGroup = workout.zoneGroupsByType?[HKQuantityType(.heartRate)] {
                print("\n锻炼日期: \(workout.startDate)")
                print("活动类型: \(workout.workoutActivityType)")
                print("时长: \(Int(workout.duration / 60)) 分钟")
                
                // 计算区间分布
                let totalTime = zoneGroup.zoneDurations.reduce(0) { $0 + $1.duration }
                
                for zoneDuration in zoneGroup.zoneDurations {
                    let percentage = (zoneDuration.duration / totalTime) * 100
                    print("区间 \(zoneDuration.zone.index): \(Int(percentage))%")
                }
            }
        }
    }
    
    func normalizeZonesForComparison(_ workout: HKWorkout, targetZones: Int = 5) async throws -> [TimeInterval] {
        // ⚠️ 重要：不同数量的区间不能直接比较
        // 需要标准化到相同数量的区间
        
        guard let zoneGroup = workout.zoneGroupsByType?[HKQuantityType(.heartRate)] else {
            return []
        }
        
        let config = zoneGroup.configuration
        
        if config.zones.count == targetZones {
            // 已经是目标区间数，直接返回
            return zoneGroup.zoneDurations.map(\.duration)
        }
        
        // 否则需要从原始样本重新计算
        // 1. 获取锻炼的心率样本
        let samples = try await fetchHeartRateSamples(for: workout)
        
        // 2. 创建目标区间配置
        let targetConfig = try createStandardZoneConfig(zoneCount: targetZones)
        
        // 3. 将样本分配到新区间
        return distributesamplesToZones(samples, configuration: targetConfig)
    }
    
    private func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let heartRateSamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: heartRateSamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func createStandardZoneConfig(zoneCount: Int) throws -> HKWorkoutZoneConfiguration {
        // 创建标准区间配置
        let thresholds: [Double]
        switch zoneCount {
        case 5:
            thresholds = [91.0, 114.0, 136.0, 158.0]
        case 7:
            thresholds = [80.0, 95.0, 110.0, 125.0, 140.0, 155.0]
        default:
            throw NSError(domain: "ZoneAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "不支持的区间数量"])
        }
        
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let boundaries = thresholds.map { HKQuantity(unit: bpmUnit, doubleValue: $0) }
        
        return try HKWorkoutZoneConfiguration(
            quantityType: HKQuantityType(.heartRate),
            zoneBoundaries: boundaries
        )
    }
    
    private func distributesamplesToZones(
        _ samples: [HKQuantitySample],
        configuration: HKWorkoutZoneConfiguration
    ) -> [TimeInterval] {
        var zoneDurations = Array(repeating: 0.0, count: configuration.zones.count)
        
        for sample in samples {
            let bpm = sample.quantity.doubleValue(for: .beatsPerMinute())
            let zoneIndex = findZoneIndex(for: bpm, in: configuration.zones)
            let sampleDuration = sample.endDate.timeIntervalSince(sample.startDate)
            
            if zoneIndex < zoneDurations.count {
                zoneDurations[zoneIndex] += sampleDuration
            }
        }
        
        return zoneDurations
    }
    
    private func findZoneIndex(for value: Double, in zones: [HKWorkoutZone]) -> Int {
        for zone in zones {
            let minValue = zone.minimumQuantity?.doubleValue(for: .beatsPerMinute()) ?? 0
            let maxValue = zone.maximumQuantity?.doubleValue(for: .beatsPerMinute()) ?? Double.infinity
            
            if value >= minValue && value < maxValue {
                return zone.index
            }
        }
        return zones.count - 1 // 默认返回最后一个区间
    }
}
```

---

## 最佳实践

### ✅ 推荐做法

1. **优先使用首选区间**
   ```swift
   // 检查首选区间，仅在不存在时使用自定义
   if try await builder.zoneConfiguration(for: heartRateType) == nil {
       let custom = try createCustomZones()
       try await builder.setCustomZoneConfiguration(custom, for: heartRateType)
   }
   ```

2. **在 beginCollection 前设置自定义区间**
   ```swift
   // ✅ 正确顺序
   try await builder.setCustomZoneConfiguration(config, for: heartRateType)
   try await builder.beginCollection(at: Date())
   
   // ❌ 错误：太晚了
   // try await builder.beginCollection(at: Date())
   // try await builder.setCustomZoneConfiguration(config, for: heartRateType)
   ```

3. **提供用户友好的区间标签**
   ```swift
   func zoneLabel(for index: Int) -> String {
       let labels = [
           "恢复区间",
           "脂肪燃烧",
           "有氧耐力",
           "乳酸阈值",
           "最大强度"
       ]
       return labels[safe: index] ?? "区间 \(index + 1)"
   }
   ```

4. **显示区间百分比**
   ```swift
   func displayZonePercentages(zoneDurations: [TimeInterval]) {
       let total = zoneDurations.reduce(0, +)
       for (index, duration) in zoneDurations.enumerated() {
           let percentage = (duration / total) * 100
           print("区间 \(index + 1): \(Int(percentage))%")
       }
   }
   ```

5. **处理边界情况**
   ```swift
   // 检查区间数据是否可用
   guard let zoneGroup = workout.zoneGroupsByType?[HKQuantityType(.heartRate)],
         !zoneGroup.zoneDurations.isEmpty else {
       print("此锻炼没有区间数据")
       return
   }
   ```

### ⚠️ 注意事项

1. **不同区间数量不能直接比较**
   ```swift
   // ❌ 错误：5 区间的"区间 3"与 7 区间的"区间 3"含义不同
   let workout1Zone3 = workout1.zoneGroupsByType?[...]?.zoneDurations[2].duration
   let workout2Zone3 = workout2.zoneGroupsByType?[...]?.zoneDurations[2].duration
   
   // ✅ 正确：标准化到相同区间数再比较
   let normalized1 = try await normalizeZones(workout1, targetZones: 5)
   let normalized2 = try await normalizeZones(workout2, targetZones: 5)
   ```

2. **自定义区间不会同步**
   ```swift
   // ⚠️ 自定义区间仅保存在锻炼上下文中
   // 应用负责保存和跨设备同步
   
   // 保存配置以便后续使用
   func saveCustomConfiguration(_ config: HKWorkoutZoneConfiguration) {
       let boundaries = config.zones.compactMap { $0.minimumQuantity?.doubleValue(for: .beatsPerMinute()) }
       UserDefaults.standard.set(boundaries, forKey: "customHeartRateZones")
   }
   ```

3. **区间数量限制**
   ```swift
   // ✅ 有效：3-9 个区间
   let valid3Zones = try HKWorkoutZoneConfiguration(quantityType: heartRateType, zoneBoundaries: [100, 140])
   let valid9Zones = try HKWorkoutZoneConfiguration(quantityType: heartRateType, zoneBoundaries: [80, 95, 110, 125, 140, 155, 170, 185])
   
   // ❌ 无效：少于 3 个或多于 9 个区间会抛出错误
   ```

4. **单位必须匹配**
   ```swift
   // ✅ 心率使用 bpm
   let bpmUnit = HKUnit.count().unitDivided(by: .minute())
   let heartRateBoundary = HKQuantity(unit: bpmUnit, doubleValue: 140.0)
   
   // ✅ 功率使用瓦特
   let wattUnit = HKUnit.watt()
   let powerBoundary = HKQuantity(unit: wattUnit, doubleValue: 200.0)
   ```

5. **处理实时更新性能**
   ```swift
   // 使用防抖避免过于频繁的 UI 更新
   private var updateTask: Task<Void, Never>?
   
   func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate) {
       updateTask?.cancel()
       updateTask = Task { @MainActor in
           try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒延迟
           if !Task.isCancelled {
               updateUI(with: zoneUpdate)
           }
       }
   }
   ```

### 🚫 避免的做法

1. **不要假设区间总是可用**
   ```swift
   // ❌ 错误：可能崩溃
   let duration = workout.zoneGroupsByType![HKQuantityType(.heartRate)]!.zoneDurations[0].duration
   
   // ✅ 正确：安全解包
   guard let zoneGroup = workout.zoneGroupsByType?[HKQuantityType(.heartRate)],
         let firstDuration = zoneGroup.zoneDurations.first?.duration else {
       return
   }
   ```

2. **不要在高频率回调中执行耗时操作**
   ```swift
   // ❌ 错误：在委托方法中执行耗时操作
   func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate) {
       let samples = try await fetchAllSamples() // 耗时操作
       // ...
   }
   
   // ✅ 正确：只更新必要的 UI 状态
   func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate) {
       Task { @MainActor in
           self.currentZone = zoneUpdate.currentZoneDuration?.zone.index
       }
   }
   ```

3. **不要硬编码区间标签**
   ```swift
   // ❌ 错误：假设总是 5 个区间
   let labels = ["区间 1", "区间 2", "区间 3", "区间 4", "区间 5"]
   
   // ✅ 正确：根据实际区间数量动态生成
   let zoneCount = configuration.zones.count
   let labels = (1...zoneCount).map { "区间 \($0)" }
   ```

---

## 相关 API 参考

### HKWorkout / HKWorkoutActivity

```swift
// 获取区间组
var zoneGroupsByType: [HKQuantityType: HKWorkoutZoneGroup]? { get }
```

### HKWorkoutZoneGroup

```swift
struct HKWorkoutZoneGroup {
    var configuration: HKWorkoutZoneConfiguration  // 区间配置
    var zoneDurations: [HKWorkoutZoneDuration]    // 各区间时长
}
```

### HKWorkoutZoneConfiguration

```swift
class HKWorkoutZoneConfiguration {
    var quantityType: HKQuantityType    // 心率或功率
    var source: HKWorkoutZoneSource     // 来源（系统/用户/自定义）
    var zones: [HKWorkoutZone]          // 区间数组
    
    init(quantityType: HKQuantityType, zoneBoundaries: [HKQuantity]) throws
}
```

### HKWorkoutZone

```swift
struct HKWorkoutZone {
    var index: Int                          // 区间索引（从 0 开始）
    var minimumQuantity: HKQuantity?        // 最小值（第一个区间为 nil）
    var maximumQuantity: HKQuantity?        // 最大值（最后一个区间为 nil）
}
```

### HKWorkoutZoneDuration

```swift
struct HKWorkoutZoneDuration {
    var zone: HKWorkoutZone      // 区间
    var duration: TimeInterval   // 在该区间的时长（秒）
}
```

### HKLiveWorkoutBuilder

```swift
class HKLiveWorkoutBuilder {
    // 查询首选区间配置
    func zoneConfiguration(for quantityType: HKQuantityType) async throws -> HKWorkoutZoneConfiguration?
    
    // 设置自定义区间配置（必须在 beginCollection 前调用）
    func setCustomZoneConfiguration(_ configuration: HKWorkoutZoneConfiguration, for quantityType: HKQuantityType) async throws
}
```

### HKHealthStore

```swift
class HKHealthStore {
    // 查询首选区间配置
    func zoneConfiguration(for quantityType: HKQuantityType) async throws -> HKWorkoutZoneConfiguration?
}
```

### HKLiveWorkoutBuilderDelegate

```swift
protocol HKLiveWorkoutBuilderDelegate {
    // 区间变化时调用
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate
    )
}
```

### HKLiveWorkoutZoneUpdate

```swift
struct HKLiveWorkoutZoneUpdate {
    var currentZoneDuration: HKWorkoutZoneDuration?   // 当前区间及时长
    var previousZoneDuration: HKWorkoutZoneDuration?  // 上一个区间及时长
    var zoneGroup: HKWorkoutZoneGroup?                // 完整区间组
    var lastSampleDate: Date                          // 最后处理样本的时间
}
```

---

## 相关 WWDC Sessions

- **WWDC 2026 Session 207**: 利用 HealthKit 体能训练区间提供健身洞察
- **WWDC 2024 Session 10071**: What's new in HealthKit
- **WWDC 2023 Session 10063**: Build custom workouts with WorkoutKit
- **WWDC 2022 Session 10005**: Explore health data with HealthKit

---

## 额外资源

- [Apple Developer Documentation: HealthKit](https://developer.apple.com/documentation/healthkit)
- [Tracking heart rate zones for workouts](https://developer.apple.com/documentation/HealthKit/tracking-heart-rate-zones-for-workouts)
- [Accessing workout zone data](https://developer.apple.com/documentation/HealthKit/accessing-workout-zone-data)
- [Human Interface Guidelines: Health and Fitness](https://developer.apple.com/design/human-interface-guidelines/health-and-fitness)

---

## 总结

HealthKit 体能训练区间功能为健身应用提供了强大的训练洞察能力：

1. **心率区间和骑行功率区间**：基于个人数据的个性化训练区间
2. **自动计算**：HealthKit 自动计算每个区间的时长
3. **实时更新**：锻炼期间接收区间变化通知
4. **首选区间**：跨应用和设备的一致体验
5. **自定义区间**：支持专有训练模型和特殊需求
6. **多区间支持**：3-9 个区间的灵活配置

**推荐：** 优先使用首选区间配置，仅在必要时提供自定义区间作为后备方案。

**关键注意事项：** 不同数量的区间不能直接比较，需要标准化后再分析。
