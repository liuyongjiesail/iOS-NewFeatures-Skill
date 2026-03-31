# AlarmKit (iOS 26+)

Source: WWDC 2025 Session 230 + Apple Developer Documentation

## Quick Example

```swift
import AlarmKit

// Request authorization
do {
    let state = try await AlarmManager.shared.requestAuthorization()
    guard state == .authorized else { return }
} catch {
    print("Authorization error: \(error)")
}

// Schedule alarm
let id = UUID()
let stopButton = AlarmButton(text: "Dismiss", textColor: .white, systemImageName: "stop.circle")
let alertPresentation = AlarmPresentation.Alert(title: "Time's Up!", stopButton: stopButton)
let attributes = AlarmAttributes<NoMetadata>(
    presentation: AlarmPresentation(alert: alertPresentation),
    tintColor: .blue)
let config = AlarmManager.AlarmConfiguration<NoMetadata>(
    countdownDuration: Alarm.CountdownDuration(preAlert: 10 * 60, postAlert: 5 * 60),
    attributes: attributes)
let alarm = try await AlarmManager.shared.schedule(id: id, configuration: config)
```

---

# Full API Reference

## Schedule

```swift
// Fixed time (absolute, unaffected by timezone changes)
let date = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 9, hour: 9, minute: 41))!
let schedule = Alarm.Schedule.fixed(date)

// Relative time (respects timezone changes)
let time = Alarm.Schedule.Relative.Time(hour: 7, minute: 0)

// Single occurrence
let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .never))

// Weekly repeating
let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .weekly([.monday, .wednesday, .friday])))
```

## Full Appearance Configuration

```swift
let stopButton   = AlarmButton(text: "Dismiss", textColor: .white, systemImageName: "stop.circle")
let repeatButton = AlarmButton(text: "Repeat",  textColor: .white, systemImageName: "repeat.circle")
let pauseButton  = AlarmButton(text: "Pause",   textColor: .green, systemImageName: "pause")
let resumeButton = AlarmButton(text: "Resume",  textColor: .green, systemImageName: "play")
let openButton   = AlarmButton(text: "Open",    textColor: .white, systemImageName: "arrow.right.circle.fill")

// secondaryButtonBehavior: .countdown (triggers countdown) | .custom (executes Intent)
let alertPresentation = AlarmPresentation.Alert(
    title: "Food Ready!",
    stopButton: stopButton,
    secondaryButton: repeatButton,
    secondaryButtonBehavior: .countdown)

// Countdown and Paused presentations are optional
// Required only if the alarm supports countdown UI
let countdownPresentation = AlarmPresentation.Countdown(title: "Cooking", pauseButton: pauseButton)
let pausedPresentation    = AlarmPresentation.Paused(title: "Paused", resumeButton: resumeButton)

// tintColor applies consistently across all presentations (buttons, title, countdown timer)
let attributes = AlarmAttributes<CookingData>(
    presentation: AlarmPresentation(
        alert: alertPresentation,
        countdown: countdownPresentation,
        paused: pausedPresentation),
    metadata: CookingData(method: .frying),
    tintColor: .green)
```

## Custom Metadata (for Live Activity)

```swift
struct CookingData: AlarmMetadata {
    let method: Method
    enum Method: String, Codable {
        case frying   = "frying.pan"
        case grilling = "flame"
    }
}
```

## Live Activity Integration

```swift
import AlarmKit, ActivityKit, WidgetKit

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingData>.self) { context in
            switch context.state.mode {
            case .countdown: countdownView(context)
            case .paused:    pausedView(context)
            case .alert:     alertView(context)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading)  { leadingView(context) }
                DynamicIslandExpandedRegion(.trailing) { trailingView(context) }
            } compactLeading:  { compactLeadingView(context) }
              compactTrailing: { compactTrailingView(context) }
              minimal:         { minimalView(context) }
        }
    }
}
// Access metadata: context.attributes.metadata?.method
```

## LiveActivityIntent Custom Button

```swift
public struct OpenInApp: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Open App"
    public static var openAppWhenRun = true
    @Parameter(title: "alarmID") public var alarmID: String
    public func perform() async throws -> some IntentResult { .result() }
    public init(alarmID: String) { self.alarmID = alarmID }
    public init() { self.alarmID = "" }
}
```

## Full Schedule Example (with sound + Intent)

```swift
typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<CookingData>
let id = UUID()
let sound = AlertConfiguration.AlertSound.named("Chime") // File in main bundle or Library/Sounds

let alarmConfiguration = AlarmConfiguration(
    countdownDuration: Alarm.CountdownDuration(preAlert: 10 * 60, postAlert: 5 * 60),
    schedule: schedule,                                      // countdownDuration and schedule can coexist
    attributes: attributes,
    stopIntent: StopIntent(alarmID: id.uuidString),          // Intent for stop button
    secondaryIntent: OpenInApp(alarmID: id.uuidString),      // Intent for secondary button
    sound: sound)

let alarm = try await AlarmManager.shared.schedule(id: id, configuration: alarmConfiguration)
```

## Observing Alarm State Changes

```swift
// Subscribe at ViewModel init — syncs state even when app was not running
Task {
    for await incomingAlarms in AlarmManager.shared.alarmUpdates {
        updateAlarmState(with: incomingAlarms)
    }
}
// An Alarm not present in alarmUpdates stream is no longer scheduled with AlarmKit
```

## Lifecycle API

```swift
AlarmManager.shared.schedule(id:configuration:)  // Schedule
AlarmManager.shared.cancel(id:)                  // Cancel
AlarmManager.shared.stop(id:)                    // Stop
AlarmManager.shared.pause(id:)                   // Pause
AlarmManager.shared.resume(id:)                  // Resume
```

## ⚠️ Important Notes

- **Widget Extension is required**: If the alarm supports a Countdown presentation, the app must include a Widget Extension — otherwise the system may silently dismiss the alarm and fail to alert
- Missing or empty `NSAlarmKitUsageDescription` prevents AlarmKit from scheduling any alarms
- Use `tintColor` to visually associate alarms with your app and distinguish them from other apps

## Use Cases

- ✅ Fixed-interval countdowns: cooking timers, workout timers
- ✅ Repeating scheduled alerts: wake-up alarms
- ❌ Not a replacement for critical alerts or time-sensitive notifications
