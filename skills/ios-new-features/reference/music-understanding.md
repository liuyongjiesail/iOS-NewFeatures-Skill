# Music Understanding — 设备端音乐智能分析框架

> **适用范围：** iOS 27+ / iPadOS 27+ / macOS 27+ / visionOS 27+  
> **来源：** WWDC 2026 Session 253  
> **框架：** MusicUnderstanding
> 
> 本文档涵盖 Music Understanding 框架的六大分析维度、API 使用、性能优化、实际应用场景。

---

## 目录

1. [框架概览](#框架概览)
2. [六大分析维度](#六大分析维度)
3. [基础使用](#基础使用)
4. [详细 API](#详细-api)
5. [流式 API](#流式-api)
6. [实际应用场景](#实际应用场景)
7. [完整示例](#完整示例)

---

## 框架概览

### 核心特性

| 特性 | 说明 |
|------|------|
| **设备端运行** | 完全离线，保护隐私 |
| **无需专业知识** | 自动处理信号处理和 ML 推理 |
| **全平台支持** | iOS / iPadOS / macOS / visionOS |
| **6 大分析维度** | 调性、节奏、结构、步调、乐器活动、响度 |

### Apple 内部使用案例

**Final Cut Pro — 节拍检测功能**
```
分析歌曲的节奏 + 结构
   ↓
揭示节拍网格
   ↓
帮助编辑将剪辑与节拍/小节/段落对齐
```

**Final Cut Pro for iPad — 蒙太奇功能**
```
分析节奏 + 速度 + 结构
   ↓
自动将视频剪辑与音乐同步
```

---

## 六大分析维度

### 1. 调性 (Key)

**音乐围绕的音符集合**

- **主音 (Tonic)**: C、D、E、F、G、A、B 及其升降半音
- **调式 (Mode)**: 大调 (Major) / 小调 (Minor)

```swift
// 示例：降 D 大调
KeySignature(tonic: .dFlat, mode: .major)
```

---

### 2. 节奏 (Rhythm)

**歌曲的脉搏**

```
节拍 (Beats)
   ↓ 组成
小节 (Bars)
   ↓ 形成
乐句 (Phrases) ← 音乐句子
   ↓ 组合
段落 (Segments)
   ↓ 构成
章节 (Sections) ← 副歌、主歌、前奏
```

**BPM (Beats Per Minute)**: 每分钟节拍数

---

### 3. 结构 (Structure)

**歌曲的层次结构**

| 层次 | 说明 | 示例 |
|------|------|------|
| **Sections** | 章节 | 副歌、主歌、前奏、过渡 |
| **Segments** | 段落 | 更完整的音乐表述 |
| **Phrases** | 乐句 | 音乐句子 |

---

### 4. 步调 (Pace)

**音乐的感觉快慢（不是 BPM）**

- 相同 BPM 的歌曲，不同部分可能**感觉**更快或更慢
- 用于驱动视频剪辑节奏：活力高 = 快切，活力低 = 慢切

---

### 5. 乐器活动 (Instrument Activity)

**乐器的存在与强度**

支持的乐器：
- 鼓 (Drums)
- 低音 (Bass)
- 人声 (Vocals)
- 其他乐器

**两种数据：**
- **Ranges**: 乐器在哪些时间段存在
- **Activity**: 乐器在每个时刻的强度 (0.0 ~ 1.0)

---

### 6. 响度 (Loudness)

**音量的感知测量**

| 类型 | 说明 | 单位 | 更新频率 |
|------|------|------|----------|
| **Integrated** | 整体平均响度 | LUFS | 一次 |
| **Momentary** | 瞬时响度（400ms 窗口） | LUFS | 每 100ms |
| **ShortTerm** | 短期响度（3s 窗口） | LUFS | 每 100ms |
| **Peak** | 绝对最大电平 | dB | 一次 |

**LUFS**: Loudness Units relative to Full Scale（满刻度响度单位）

---

## 基础使用

### 快速开始

```swift
import MusicUnderstanding
import AVFoundation

// 1. 创建 AVAsset
let asset = AVURLAsset(
    url: audioFileURL,
    options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]  // ⚠️ 必须设置
)

// 2. 创建会话
let session = try await MusicUnderstandingSession(asset: asset)

// 3. 分析（默认所有维度）
let results = try await session.analyze()

// 4. 访问结果
if let keyResult = results.key {
    print("调性: \(keyResult.ranges.first?.value)")
}

if let rhythmResult = results.rhythm {
    print("BPM: \(rhythmResult.beatsPerMinute ?? 0)")
    print("节拍数: \(rhythmResult.beats.count)")
}
```

### 指定分析类型（性能优化）

```swift
// 只分析节奏和结构
let results = try await session.analyze(for: [.rhythm, .structure])

// results.rhythm ✅ 有数据
// results.structure ✅ 有数据
// results.key ❌ nil
// results.pace ❌ nil
// results.instrumentActivity ❌ nil
// results.loudness ❌ nil
```

---

## 详细 API

### SessionResult 结构

```swift
public struct SessionResult: Codable, Sendable {
    public let instrumentActivity: InstrumentActivityResult?
    public let key: KeyResult?
    public let loudness: LoudnessResult?
    public let pace: PaceResult?
    public let rhythm: RhythmResult?
    public let structure: StructureResult?
}
```

**所有结果都是可选值：**
- 使用 `analyze()` → 所有结果都有
- 使用 `analyze(for:)` → 只返回请求的结果

---

### 时间值类型

**TimedValue: 时间点 + 值**

```swift
public struct TimedValue<Value>: Codable {
    public let time: CMTime
    public let value: Value
}

// 示例：某一时刻的响度
TimedValue(time: CMTime(seconds: 10.5), value: -12.3)  // -12.3 LUFS at 10.5s
```

**RangedValue: 时间范围 + 值**

```swift
public struct RangedValue<Value>: Codable {
    public let range: CMTimeRange
    public let value: Value
}

// 示例：某段时间的调性
RangedValue(
    range: CMTimeRange(start: CMTime(seconds: 0), duration: CMTime(seconds: 30)),
    value: KeySignature(tonic: .c, mode: .major)  // C 大调，持续 30 秒
)
```

---

### 1. KeyResult — 调性分析

```swift
public struct KeyResult: Codable {
    public let ranges: [RangedValue<KeySignature>]
}

public struct KeySignature: Codable {
    public let tonic: Tonic      // 主音：C, D, E, F, G, A, B, C#, Db...
    public let mode: Mode        // 调式：major / minor
}

// 使用示例
if let keyResult = results.key {
    for rangedKey in keyResult.ranges {
        print("\(rangedKey.range.start.seconds)s ~ \(rangedKey.range.end.seconds)s:")
        print("  调性: \(rangedKey.value.tonic) \(rangedKey.value.mode)")
    }
}
```

---

### 2. RhythmResult — 节奏分析

```swift
public struct RhythmResult: Codable {
    public let beats: [CMTime]         // 每个节拍的时间戳
    public let bars: [CMTime]          // 每个小节的时间戳
    public let beatsPerMinute: Float?  // BPM（可选）
}

// 使用示例
if let rhythm = results.rhythm {
    print("BPM: \(rhythm.beatsPerMinute ?? 0)")
    print("总节拍数: \(rhythm.beats.count)")
    print("总小节数: \(rhythm.bars.count)")
    
    // 同步视觉效果到节拍
    for beat in rhythm.beats {
        scheduleAnimation(at: beat)
    }
}
```

**⚠️ BPM 为 nil 的情况：** 音频太短，找不到至少 2 个节拍

---

### 3. StructureResult — 结构分析

```swift
public struct StructureResult: Codable {
    public let sections: [CMTimeRange]   // 章节（副歌、主歌）
    public let segments: [CMTimeRange]   // 段落
    public let phrases: [CMTimeRange]    // 乐句
}

// 使用示例
if let structure = results.structure {
    print("章节数: \(structure.sections.count)")
    print("段落数: \(structure.segments.count)")
    print("乐句数: \(structure.phrases.count)")
    
    // 在每个章节开始处触发特效
    for section in structure.sections {
        scheduleTransition(at: section.start)
    }
}
```

---

### 4. PaceResult — 步调分析

```swift
public struct PaceResult: Codable {
    public let ranges: [RangedValue<Double>]  // 每个时间段的能量值
}

// 使用示例
if let pace = results.pace {
    for rangedPace in pace.ranges {
        let energy = rangedPace.value
        let range = rangedPace.range
        
        if energy > 0.8 {
            // 高能量：快速剪辑
            print("\(range.start.seconds)s ~ \(range.end.seconds)s: 高能量")
        } else {
            // 低能量：慢速剪辑
            print("\(range.start.seconds)s ~ \(range.end.seconds)s: 低能量")
        }
    }
}
```

**计算剪辑时长：** `timePerClip = 60 / paceValue`

---

### 5. InstrumentActivityResult — 乐器活动分析

```swift
public struct InstrumentActivityResult: Codable {
    public let ranges: [Instrument: [CMTimeRange]]                    // 乐器存在的时间段
    public let activity: [Instrument: [TimedValue<Float>]]            // 乐器的强度（0.0 ~ 1.0）
}

// 使用示例：检查乐器是否存在
if let instrumentActivity = results.instrumentActivity {
    if let drumRanges = instrumentActivity.ranges[.drums] {
        print("鼓声出现在 \(drumRanges.count) 个时间段")
    }
    
    // 使用示例：获取乐器强度（驱动动画）
    if let vocalActivity = instrumentActivity.activity[.vocals] {
        for timedValue in vocalActivity {
            let intensity = timedValue.value  // 0.0 ~ 1.0
            let time = timedValue.time
            
            // 根据人声强度调整可视化效果
            scheduleVisualization(at: time, intensity: intensity)
        }
    }
}
```

---

### 6. LoudnessResult — 响度分析

```swift
public struct LoudnessResult: Codable {
    public let integrated: TimedValue<Float>       // 整体平均响度
    public let momentary: [TimedValue<Float>]      // 瞬时响度（每 100ms）
    public let shortTerm: [TimedValue<Float>]      // 短期响度（每 100ms）
    public let peak: TimedValue<Float>             // 峰值
}

// 使用示例
if let loudness = results.loudness {
    print("平均响度: \(loudness.integrated.value) LUFS")
    print("峰值: \(loudness.peak.value) dB at \(loudness.peak.time.seconds)s")
    
    // 绘制响度曲线
    for timedLoudness in loudness.shortTerm {
        plotLoudness(time: timedLoudness.time, value: timedLoudness.value)
    }
}
```

---

## 流式 API

### 响度流式分析

**使用场景：** 实时音频电平表、VU 表、音频可视化

```swift
import MusicUnderstanding

// 1. 创建自定义音频提供器
struct AudioProvider: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = AVReadOnlyAudioPCMBuffer?
    
    func makeAsyncIterator() -> Self {
        return self
    }
    
    mutating func next() async -> AVReadOnlyAudioPCMBuffer? {
        // 返回下一个音频缓冲区
        // 返回 nil 表示完成
        return getNextBuffer()
    }
}

// 2. 使用流式 API
let audioProvider = AudioProvider()
let session = MusicUnderstandingSession(audioProvider: audioProvider)

await withThrowingTaskGroup(of: Void.self) { group in
    // 任务 1: 处理响度结果
    group.addTask {
        for try await result in await session.loudnessResults {
            updateAudioLevel(result.momentary.last?.value ?? 0)
        }
    }
    
    // 任务 2: 开始分析
    group.addTask {
        try await session.analyze(for: [.loudness])
    }
}
```

**关键点：**
- 每 100ms 返回一次结果
- 适用于**实时音频输入**（麦克风、音频流）

---

## 实际应用场景

### 1. 视频编辑 App（如 Final Cut Pro）

**功能：自动剪辑同步**

```swift
// 1. 分析音乐
let results = try await session.analyze()

guard let structure = results.structure,
      let pace = results.pace else { return }

// 2. 在每个章节开始处切换视频剪辑
for section in structure.sections {
    insertClip(at: section.start)
}

// 3. 根据步调调整剪辑长度
for rangedPace in pace.ranges {
    let clipDuration = 60.0 / rangedPace.value  // 高能量 = 短剪辑
    adjustClipDuration(in: rangedPace.range, to: clipDuration)
}
```

---

### 2. DJ App

**功能：智能歌曲匹配**

```swift
// 分析曲库中的所有歌曲
for song in library {
    let results = try await analyze(song)
    
    // 保存元数据
    song.bpm = results.rhythm?.beatsPerMinute
    song.key = results.key?.ranges.first?.value
    song.energy = results.pace?.ranges.first?.value
}

// 找到 BPM 和调性匹配的歌曲
func findCompatibleSongs(for currentSong: Song) -> [Song] {
    return library.filter { song in
        // BPM 差异 < 5
        abs(song.bpm - currentSong.bpm) < 5 &&
        // 调性兼容（同调或关系调）
        areKeysCompatible(song.key, currentSong.key)
    }
}
```

---

### 3. 音乐可视化 App

**功能：音频响应式动画**

```swift
// 使用乐器活动驱动可视化
if let instrumentActivity = results.instrumentActivity {
    // 鼓声 → 粒子爆炸
    if let drumActivity = instrumentActivity.activity[.drums] {
        for timedValue in drumActivity {
            if timedValue.value > 0.7 {
                triggerParticleExplosion(at: timedValue.time)
            }
        }
    }
    
    // 人声 → 波形动画
    if let vocalActivity = instrumentActivity.activity[.vocals] {
        for timedValue in vocalActivity {
            animateWaveform(intensity: timedValue.value, at: timedValue.time)
        }
    }
}
```

---

### 4. 健身 App

**功能：根据音乐节奏调整运动指导**

```swift
// 分析播放列表
let results = try await session.analyze()

if let rhythm = results.rhythm {
    let bpm = rhythm.beatsPerMinute ?? 0
    
    // 根据 BPM 推荐运动
    if bpm < 100 {
        recommendWorkout(.yoga)  // 瑜伽、伸展
    } else if bpm < 140 {
        recommendWorkout(.jogging)  // 慢跑
    } else {
        recommendWorkout(.hiit)  // 高强度间歇训练
    }
    
    // 在每个节拍时给出提示音
    for beat in rhythm.beats {
        scheduleBeep(at: beat)
    }
}
```

---

### 5. 游戏

**功能：音乐节奏游戏**

```swift
// 预先计算并捆绑分析数据
let results = try await session.analyze()

// 导出为 JSON
let encoder = JSONEncoder()
let jsonData = try encoder.encode(results)
try jsonData.write(to: bundleURL)

// 游戏中加载数据
let decoder = JSONDecoder()
let results = try decoder.decode(SessionResult.self, from: jsonData)

// 在每个节拍生成游戏对象
for beat in results.rhythm!.beats {
    spawnGameObject(at: beat)
}
```

---

### 6. 音频工具 App

**功能：响度标准化（广播/播客）**

```swift
// 分析音频响度
let results = try await session.analyze(for: [.loudness])

if let loudness = results.loudness {
    let currentLoudness = loudness.integrated.value
    let targetLoudness: Float = -16.0  // 广播标准：-16 LUFS
    
    // 计算增益调整
    let gainAdjustment = targetLoudness - currentLoudness
    
    print("当前响度: \(currentLoudness) LUFS")
    print("需要调整: \(gainAdjustment) dB")
    
    // 应用增益
    applyGain(gainAdjustment)
}
```

---

## 完整示例

### Music Understanding Lab（示例 App）

```swift
import SwiftUI
import MusicUnderstanding
import AVFoundation

@MainActor
class MusicAnalyzer: ObservableObject {
    @Published var results: SessionResult?
    @Published var isAnalyzing = false
    
    func analyze(url: URL) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            // 1. 创建 Asset
            let asset = AVURLAsset(
                url: url,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )
            
            // 2. 创建会话
            let session = try await MusicUnderstandingSession(asset: asset)
            
            // 3. 分析所有维度
            let sessionResults = try await session.analyze()
            
            // 4. 更新 UI
            self.results = sessionResults
            
        } catch {
            print("❌ 分析失败: \(error)")
        }
    }
    
    func exportToJSON() -> Data? {
        guard let results = results else { return nil }
        let encoder = JSONEncoder()
        return try? encoder.encode(results)
    }
}

struct ContentView: View {
    @StateObject private var analyzer = MusicAnalyzer()
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 选择歌曲按钮
            Button("选择歌曲...") {
                isImporting = true
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.audio]
            ) { result in
                switch result {
                case .success(let url):
                    Task {
                        await analyzer.analyze(url: url)
                    }
                case .failure(let error):
                    print("❌ \(error)")
                }
            }
            
            if analyzer.isAnalyzing {
                ProgressView("分析中...")
            }
            
            // 显示结果
            if let results = analyzer.results {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // 调性
                        if let key = results.key?.ranges.first {
                            KeyTileView(keySignature: key.value)
                        }
                        
                        // 节奏
                        if let rhythm = results.rhythm {
                            RhythmTileView(rhythm: rhythm)
                        }
                        
                        // 结构
                        if let structure = results.structure {
                            StructureTileView(structure: structure)
                        }
                        
                        // 步调
                        if let pace = results.pace {
                            PaceTileView(pace: pace)
                        }
                        
                        // 乐器活动
                        if let activity = results.instrumentActivity {
                            InstrumentActivityTileView(activity: activity)
                        }
                        
                        // 响度
                        if let loudness = results.loudness {
                            LoudnessTileView(loudness: loudness)
                        }
                    }
                    .padding()
                }
            }
            
            // 导出按钮
            if analyzer.results != nil {
                Button("导出 JSON") {
                    if let data = analyzer.exportToJSON() {
                        saveJSON(data)
                    }
                }
            }
        }
        .padding()
    }
    
    private func saveJSON(_ data: Data) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-analysis.json")
        try? data.write(to: url)
        print("✅ 已导出: \(url)")
    }
}

// 调性图块
struct KeyTileView: View {
    let keySignature: KeySignature
    
    var body: some View {
        VStack {
            Text("调性")
                .font(.headline)
            Text("\(keySignature.tonic.rawValue) \(keySignature.mode.rawValue)")
                .font(.title)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// 节奏图块
struct RhythmTileView: View {
    let rhythm: RhythmResult
    
    var body: some View {
        VStack {
            Text("节奏")
                .font(.headline)
            HStack {
                Text("BPM: \(Int(rhythm.beatsPerMinute ?? 0))")
                Spacer()
                Text("节拍: \(rhythm.beats.count)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
}

// 其他图块视图...
```

---

## 关键要点总结

### 核心特性
- **6 大分析维度** - 调性、节奏、结构、步调、乐器活动、响度
- **设备端运行** - 离线可用、隐私保护
- **无需专业知识** - 自动处理信号处理和 ML

### API 设计
- **SessionResult** - 统一结果结构
- **TimedValue / RangedValue** - 标准时间类型
- **流式 API** - 支持实时音频输入

### 性能优化
- **指定分析类型** - `analyze(for:)` 避免不必要计算
- **结果可编码** - 预先计算并捆绑到 App

### 应用场景
- 视频编辑（自动剪辑同步）
- DJ App（智能歌曲匹配）
- 音乐可视化（音频响应式动画）
- 健身 App（节奏同步运动）
- 游戏（音乐节奏游戏）
- 音频工具（响度标准化）

---

## 参考资料

- [WWDC 2026 Session 253 — Meet the Music Understanding framework](https://developer.apple.com/videos/play/wwdc2026/253/)
- [Music Understanding — Apple Developer Documentation](https://developer.apple.com/documentation/MusicUnderstanding)
- [Creating visuals with Music Understanding analysis results — Sample Code](https://developer.apple.com/documentation/MusicUnderstanding/create-visuals-using-musicunderstanding-analysis-results)

---

## 关键词索引

`MusicUnderstanding`, `MusicUnderstandingSession`, `SessionResult`, `KeyResult`, `RhythmResult`, `StructureResult`, `PaceResult`, `InstrumentActivityResult`, `LoudnessResult`, `TimedValue`, `RangedValue`, `调性`, `节奏`, `BPM`, `结构`, `步调`, `乐器活动`, `响度`, `LUFS`, `音乐分析`, `音频分析`, `设备端`, `离线`, `Final Cut Pro`, `视频编辑`, `DJ`, `音乐可视化`, `健身`, `游戏`, `音频工具`
