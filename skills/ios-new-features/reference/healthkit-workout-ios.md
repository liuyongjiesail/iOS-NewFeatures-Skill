# HealthKit Workouts on iOS & iPadOS — 在 iPhone/iPad 上跟踪体能训练

> **适用范围：** iOS 26+ / iPadOS 26+
> **来源：** WWDC 2025 Session 322 "Track workouts with HealthKit on iOS and iPadOS"
> **框架：** HealthKit + SiriKit（Intents）+ ActivityKit（Live Activity）
>
> WWDC 2025 起，Apple Watch 上成熟的 workout session API（`HKWorkoutSession` + `HKLiveWorkoutBuilder`）扩展到 iPhone 和 iPad。已有 Watch 代码只需极小改动即可复用。本文档覆盖会话生命周期、指标采集、锁屏 Live Activity 与 Siri、崩溃恢复及最佳实践。

---

## 目录

1. [功能概览](#功能概览)
2. [会话生命周期](#会话生命周期)
3. [与 Apple Watch 的关键差异](#与-apple-watch-的关键差异)
4. [采集指标（生成类型 vs 采集类型）](#采集指标生成类型-vs-采集类型)
5. [保存后读取指标](#保存后读取指标)
6. [锁屏 Live Activity 与 Siri](#锁屏-live-activity-与-siri)
7. [崩溃恢复](#崩溃恢复)
8. [最佳实践](#最佳实践)

---

## 功能概览

| 能力 | API |
|------|-----|
| 描述活动类型 | `HKWorkoutConfiguration` |
| 运行会话 | `HKWorkoutSession` |
| 实时采集与保存 | `HKLiveWorkoutBuilder` |
| 数据源（自动采集样本） | `HKLiveWorkoutDataSource` |
| 崩溃恢复 | `store.recoverActiveWorkoutSession` + Scene Delegate |
| 锁屏语音控制 | SiriKit Intents（Start/Pause/Resume/End WorkoutIntent） |
| 锁屏实时指标 | ActivityKit Live Activity |

**核心优势：** 已有 Apple Watch 的 workout 代码可几乎原样复用到 iPhone/iPad，为无 Apple Watch 的用户开拓新市场。

---

## 会话生命周期

会话从 setup → start → 采集指标 → end，分几个步骤。

### 1. 配置并创建会话（Session + Builder + DataSource）

```swift
// 创建 workout 配置
let configuration = HKWorkoutConfiguration()
configuration.activityType = .running
configuration.locationType = .outdoor

// 创建 workout 会话
let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
session.delegate = self

// 从会话拿到关联的 builder，并挂上数据源
let builder = session.associatedWorkoutBuilder()
builder.delegate = self
builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                             workoutConfiguration: configuration)
```

### 2. 准备并启动

调用 `prepare()` 后建议显示 3 秒倒计时，给设备传感器开启或外接心率带连接留出时间，确保活动开始时指标即刻可用。

```swift
session.prepare()

// 倒计时结束后，启动会话与 builder 采集
session.startActivity(with: startDate)
try await builder.beginCollection(at: startDate)
```

> 无需用锚定对象查询来更新 UI —— builder 的 delegate 会在采集到新数据时通知你，并在保存时自动保持指标同步。

### 3. 结束会话

用户结束训练时，先 `stopActivity` 让 live builder 采集最后的指标，会话转到 `.stopped` 状态后再 `endCollection` → `finishWorkout` → `session.end()`。

```swift
session.stopActivity(with: .now)

// 会话转到 stopped 后再收尾
func workoutSession(_ workoutSession: HKWorkoutSession,
                    didChangeTo toState: HKWorkoutSessionState,
                    from fromState: HKWorkoutSessionState,
                    date: Date) {
    guard toState == .stopped, let builder else { return }

    Task {
        try await builder.endCollection(at: date)
        let finishedWorkout = try await builder.finishWorkout()
        session.end()
        // 展示训练总结
    }
}
```

---

## 与 Apple Watch 的关键差异

| 差异点 | 说明 |
|--------|------|
| **传感器** | iPhone/iPad **没有心率传感器**。可配对支持 heart rate GATT profile 的外接设备（心率带、Powerbeats Pro 2 等）。配对后 HealthKit 自动获取心率并存为样本。 |
| **锁屏** | iPhone 训练时大概率锁屏；出于隐私，锁屏时健康数据默认不可读。首次启动会话时系统会提示「训练数据即使锁屏也对 App 可用」。 |
| **崩溃恢复** | Watch 早已支持；iOS/iPadOS 新增 Scene Delegate 机制。 |
| **活动类型** | 所有 workout 活动类型在 iPhone/iPad 均可用。 |

---

## 采集指标（生成类型 vs 采集类型）

- **生成类型（generated types）**：系统在训练中自动生成的数据类型，如卡路里、距离。
- **采集类型（collected types）**：你想实时观察并加入 workout 样本的指标。

在 iPhone/iPad 上初始化时，data source 的 `typesToCollect` 会包含当前活动所有可能的样本类型（例如即使没有外接心率带，heart rate 也会被列入）。data source 会观察所有「系统生成」或「你的 App 保存」的样本并传给 live builder。

### 处理采集到的指标

```swift
func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
    for type in collectedTypes {
        guard let quantityType = type as? HKQuantityType else { return }

        let statistics = workoutBuilder.statistics(for: quantityType)

        // 更新已发布的值（驱动 UI）
        updateForStatistics(statistics)
    }
}
```

### 修改默认采集类型

想增删采集类型，在 data source 上调用 enable / disable collection。例如训练中记录饮水：调用 enable collection，训练进行中把测量值作为样本存入健康数据库，data source 会自动把这些样本传给 live builder。

---

## 保存后读取指标

- **总结统计**：用 workout 对象的 `statistics` 展示汇总。
- **按时间画图**：用 statistics collection query，指定所需时间间隔。
- **细粒度数据**：如果 workout 关联的 quantity sample 的 `count` 大于 1，说明有更细粒度数据，改用 `HKQuantitySeriesSampleQuery` 获取。（历史 Apple Watch 训练如此，iOS 保存的训练同样如此。）

---

## 锁屏 Live Activity 与 Siri

锁屏时可展示 Live Activity（用 ActivityKit）显示最关键指标，用户无需解锁即可看到实时更新。

> 注意隐私提示：若锁屏时无数据访问权限，UI 应只显示训练时长；若心率数据不可用，则完全不显示该指标。

### Siri 支持（锁屏启动/暂停/继续/取消）

Siri 支持扩展到锁屏，可无需解锁完成 start / pause / resume / cancel。解锁后 HealthKit 保存训练并通过 Health Store 提供给 App。

**1) 在主 App 内定义 Intent Handler（必须在 App 内处理才能锁屏工作）：**

```swift
// 在主 App 内创建 INExtension
public class IntentHandler: INExtension {
}

// 声明支持的 intents
extension IntentHandler: INStartWorkoutIntentHandling { }
extension IntentHandler: INPauseWorkoutIntentHandling { }
extension IntentHandler: INResumeWorkoutIntentHandling { }
extension IntentHandler: INEndWorkoutIntentHandling { }
```

**2) 处理具体 intent：**

```swift
public func handle(intent: INStartWorkoutIntent) async -> INStartWorkoutIntentResponse {
    let state = await WorkoutManager.shared.state

    // 已有进行中的训练则返回失败
    switch state {
    case .running, .paused, .prepared, .stopped:
        return INStartWorkoutIntentResponse(code: .failureOngoingWorkout,
                                            userActivity: nil)
    default:
        break
    }

    Task {
        await MainActor.run {
            WorkoutManager.shared.setWorkoutConfiguration(activityType: .running,
                                                          location: .outdoor)
        }
    }
    return INStartWorkoutIntentResponse(code: .success, userActivity: nil)
}
```

**3) 注册 App Delegate 响应 intent：**

```swift
class WorkoutsOniOSSampleAppDelegate: NSObject, UIApplicationDelegate {
    let handler = IntentHandler()

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        return handler
    }
}

struct WorkoutsOniOSSampleApp: App {
    @UIApplicationDelegateAdaptor(WorkoutsOniOSSampleAppDelegate.self) var appDelegate
    // ...
}
```

---

## 崩溃恢复

三个要点：
1. 系统在崩溃后会**自动重新启动**你的 App。
2. workout session 和 builder 会**恢复到之前的状态**。
3. 但你需要**重新设置 live data source**。

**1) 在 App Delegate 里检查恢复选项并取回会话：**

```swift
func application(_ application: UIApplication,
                 configurationForConnecting connectingSceneSession: UISceneSession,
                 options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    if options.shouldHandleActiveWorkoutRecovery {
        let store = HKHealthStore()
        store.recoverActiveWorkoutSession { workoutSession, error in
            // 处理 error
            Task {
                await WorkoutManager.shared.recoverWorkout(recoveredSession: workoutSession)
            }
        }
    }
    let configuration = UISceneConfiguration(name: "Default Configuration",
                                             sessionRole: connectingSceneSession.role)
    configuration.delegateClass = WorkoutsOniOSSampleAppSceneDelegate.self
    return configuration
}
```

**2) 在 WorkoutManager 里恢复会话（只需重建 dataSource）：**

```swift
func recoverWorkout(recoveredSession: HKWorkoutSession) {
    session = recoveredSession
    builder = recoveredSession.associatedWorkoutBuilder()
    session?.delegate = self
    builder?.delegate = self
    workoutConfiguration = recoveredSession.workoutConfiguration

    let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                             workoutConfiguration: workoutConfiguration)
    builder?.dataSource = dataSource
}
```

---

## 最佳实践

- **有 Watch App 就先在 Watch 上启动训练**以拿到全部指标（`store.startWatchApp(...)`），并把训练镜像到 iPhone（见 WWDC 2023「Build a multi-device workout app」）。
- **只申请你需要的数据类型授权**，避免用户困惑于无关权限请求。
- **始终用 workout builder API 创建并保存训练**，以确保活动圆环（activity rings）正确更新。
- 锁屏时按数据可用性优雅降级 UI（只显示时长 / 隐藏不可用指标）。
- 已有 iPhone/iPad App 的，升级到本文的 Workout Builder API。

---

## 参考资料

- [WWDC 2025 Session 322 - Track workouts with HealthKit on iOS and iPadOS](https://developer.apple.com/videos/play/wwdc2025/322)
- [Running workout sessions](https://developer.apple.com/documentation/HealthKit/running-workout-sessions)
- [Building a workout app for iPhone and iPad](https://developer.apple.com/documentation/HealthKit/building-a-workout-app-for-iphone-and-ipad)
- [Building a multidevice workout app](https://developer.apple.com/documentation/HealthKit/building-a-multidevice-workout-app)
- [HKWorkoutSession](https://developer.apple.com/documentation/HealthKit/HKWorkoutSession)
- [Handling Workout Requests with SiriKit](https://developer.apple.com/documentation/SiriKit/handling-workout-requests-with-sirikit)
