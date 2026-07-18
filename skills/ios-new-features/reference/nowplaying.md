# NowPlaying Framework — 系统媒体播放集成

> **适用范围：** iOS 27+ / iPadOS 27+ / macOS 27+ / watchOS 27+ / tvOS 27+ / visionOS 27+  
> **来源：** WWDC 2026 Session 312  
> **框架：** NowPlaying
> 
> 本文档涵盖 NowPlaying 框架的三大核心功能：本地媒体会话、远程媒体会话、媒体共享扩展。

---

## 目录

1. [框架概览](#框架概览)
2. [媒体会话 (Media Session)](#媒体会话-media-session)
3. [远程媒体会话 (Remote Media Session)](#远程媒体会话-remote-media-session)
4. [媒体共享扩展 (Media Sharing Extensions)](#媒体共享扩展-media-sharing-extensions)
5. [完整示例](#完整示例)

---

## 框架概览

### NowPlaying 是什么？

**NowPlaying 是 iOS 27 全新推出的 Swift 框架**，用于将 App 的媒体播放集成到系统界面。

### 系统"正在播放"体验

**显示位置：**
```
📱 iPhone / iPad
├─ 锁定屏幕 (Lock Screen)
├─ 控制中心 (Control Center)
├─ 灵动岛 (Dynamic Island)
├─ StandBy 模式
└─ CarPlay 车载

⌚ Apple Watch
├─ 表盘 (Watch Face)
└─ Now Playing App

📺 Apple TV
└─ 控制中心

🥽 Apple Vision Pro
└─ 控制中心
```

---

### 三大核心功能

| 功能 | 说明 | 使用场景 |
|------|------|----------|
| **Media Session** | 本地播放集成 | 音乐 App、播客 App、视频 App |
| **Remote Media Session** | 远程设备控制 | 控制智能音箱、投屏设备 |
| **Media Sharing Extensions** | 统一设备选择器 | 投屏到电视、音箱 |

---

## 媒体会话 (Media Session)

### 使用场景

**App 在 iPhone 本地播放音频/视频**，需要在锁定屏幕显示控制界面。

---

### 核心概念

**MediaSessionRepresentable 协议** = App 与系统之间的契约

```swift
protocol MediaSessionRepresentable {
    var id: String { get }                                    // 唯一标识符
    var content: (any MediaContentRepresentable)? { get }     // 当前播放的内容
    var playbackSnapshot: MediaPlaybackSnapshot? { get }      // 播放状态快照
    var commands: [MediaCommand] { get }                      // 支持的操作
}
```

---

### 完整实现步骤

#### 步骤 1: 定义 PlayerModel

```swift
import Observation

@Observable
final class PlayerModel {
    let player: SoundPlayer          // 音频引擎
    var sound: Sound { player.currentSound }
    
    init(player: SoundPlayer) {
        self.player = player
    }
}
```

---

#### 步骤 2: 遵循 MediaSessionRepresentable

```swift
import NowPlaying

extension PlayerModel: MediaSessionRepresentable {
    // 1️⃣ 唯一标识符
    var id: String { "ambient-sound-session" }
    
    // 2️⃣ 当前播放的内容
    var content: (any MediaContentRepresentable)? {
        return GenericContent(
            id: sound.id,
            title: sound.name,
            subtitle: sound.description,
            type: .audio,                    // .audio 或 .video
            duration: .live,                 // .live（无固定时长/直播/环境音）或 .seconds(120)
            artwork: Artwork(id: sound.id) { size in
                let data = try await self.artworkData(size: size)
                return try ArtworkRepresentation(data: data)
            }
        )
    }
    
    // 3️⃣ 播放状态快照
    var playbackSnapshot: MediaPlaybackSnapshot? {
        MediaPlaybackSnapshot(
            state: player.isPlaying ? .playing() : .paused
            // 如果有固定时长，添加: elapsedTime: CMTime(seconds: 30, preferredTimescale: 1)
        )
    }
    
    // 4️⃣ 支持的命令
    var commands: [MediaCommand] {[
        .play { self.player.play() },
        .pause { self.player.pause() },
        .previous { self.player.previous() },
        .next { self.player.next() }
    ]}
}
```

---

#### 步骤 3: 创建 MediaSession

```swift
import NowPlaying

struct PlayerController {
    let player: SoundPlayer
    let model: PlayerModel
    let session: MediaSession<PlayerModel>
    
    init() {
        self.player = SoundPlayer()
        self.model = PlayerModel(player: player)
        
        // ✅ 创建 MediaSession，自动监听模型变化
        self.session = MediaSession(model)
    }
}
```

**关键点：**
- `MediaSession` 会自动监听 `@Observable` 模型
- 当模型更新时，系统界面自动刷新
- 无需手动调用任何更新方法

---

### 内容类型

**NowPlaying 提供 4 种内容类型：**

| 类型 | 说明 | 适用场景 |
|------|------|----------|
| **GenericContent** | 通用内容 | 环境音、有声书、白噪音 |
| **MusicContent** | 音乐 | 音乐播放器、音乐流媒体 |
| **PodcastContent** | 播客 | 播客 App |
| **MovieContent** | 视频 | 视频播放器、流媒体 |

**示例：音乐内容**

```swift
var content: (any MediaContentRepresentable)? {
    MusicContent(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.albumName,
        duration: .seconds(song.duration),
        artwork: Artwork(id: song.id) { size in
            // 加载封面图
        }
    )
}
```

---

### 命令类型

**支持的媒体命令：**

```swift
var commands: [MediaCommand] {[
    // 基础控制
    .play { /* 播放 */ },
    .pause { /* 暂停 */ },
    .stop { /* 停止 */ },
    
    // 切歌
    .next { /* 下一首 */ },
    .previous { /* 上一首 */ },
    
    // 跳转
    .skipForward(interval: 15) { /* 快进 15 秒 */ },
    .skipBackward(interval: 15) { /* 快退 15 秒 */ },
    
    // 进度条拖动
    .seek { time in
        self.player.seek(to: time)
    },
    
    // 播放速率
    .changePlaybackRate { rate in
        self.player.playbackRate = rate
    },
    
    // 喜欢/收藏
    .like { /* 收藏 */ },
    .dislike { /* 取消收藏 */ },
    
    // 其他
    .toggleShuffle { /* 切换随机播放 */ },
    .toggleRepeatMode { /* 切换循环模式 */ }
]}
```

---

### 播放状态

**MediaPlaybackSnapshot 表示当前播放状态：**

```swift
// 播放中（有固定时长）
MediaPlaybackSnapshot(
    state: .playing(
        rate: 1.0,                                      // 播放速率
        elapsedTime: CMTime(seconds: 30, preferredTimescale: 1)
    )
)

// 暂停
MediaPlaybackSnapshot(state: .paused)

// 停止
MediaPlaybackSnapshot(state: .stopped)

// 连续播放（无固定时长，如直播流/环境音，content.duration 设为 .live）
MediaPlaybackSnapshot(
    state: .playing()  // 不传 elapsedTime
)
```

---

## 远程媒体会话 (Remote Media Session)

### 使用场景

**App 控制远程设备**（如智能音箱、电视盒子），需要在 iPhone 系统界面显示远程设备的播放状态。

---

### 架构图

```
┌─────────────┐
│ 远程音箱     │ ← 用户直接操作
└──────┬──────┘
       │ 状态变更
       ↓
┌─────────────┐
│ Web 服务器   │
└──────┬──────┘
       │ 推送通知 (APNs)
       ↓
┌─────────────┐
│ iPhone      │
│ ├─ App      │
│ └─ App 扩展 │ ← RemoteMediaSessionExtension
└──────┬──────┘
       │ 更新表示
       ↓
┌─────────────┐
│ 系统 UI     │ (锁定屏幕、控制中心)
└─────────────┘
```

**交互流程：**

1. **用户 → 音箱**：用户按音箱上的播放按钮
2. **音箱 → 服务器**：音箱通知服务器状态变更
3. **服务器 → APNs**：服务器发送推送通知
4. **APNs → iPhone**：推送通知携带新状态
5. **系统 → App 扩展**：系统唤醒 App 扩展
6. **App 扩展 → 系统**：提供更新后的会话表示
7. **系统更新 UI**：锁定屏幕显示新状态

---

### 完整实现步骤

#### 步骤 1: 创建 App Extension

**Xcode 操作：**
```
File → New → Target → App Extension
选择：Remote Media Session Extension
```

**Extension 入口：**

```swift
import ExtensionFoundation
import NowPlaying

@main
final class SampleAppExtension: @MainActor RemoteMediaSessionExtension {
    var configuration: some AppExtensionConfiguration {
        RemoteMediaSessionExtensionConfiguration(extension: self)
    }
    
    var extensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(
            host: "com.apple.nowplaying",
            name: "remote-media"
        )
    }
    
    // 系统需要会话表示时调用
    func session(_ state: RemotePlayerState) async throws -> RemotePlayerModel {
        RemotePlayerModel(state: state)
    }
}
```

---

#### 步骤 2: 定义 RemotePlayerState

```swift
struct RemotePlayerState: RemoteMediaSessionAttributes {
    let sessionID: String
    let sound: Sound
    let isPlaying: Bool
    let devices: [RemoteDevice]
}

struct RemoteDevice: Codable {
    let id: String
    let name: String
    let volume: Float
}
```

**⚠️ RemotePlayerState 必须：**
- 遵循 `RemoteMediaSessionAttributes`
- 包含推送通知载荷中的所有数据
- 可被 `Codable` 序列化

---

#### 步骤 3: 定义 RemotePlayerModel

```swift
import Observation

@Observable
@MainActor
final class RemotePlayerModel {
    let client: ServerClient
    var state: RemotePlayerState
    
    init(state: RemotePlayerState) {
        self.client = ServerClient(sessionID: state.sessionID)
        self.state = state
    }
}
```

---

#### 步骤 4: 遵循 RemoteMediaSessionRepresentable

```swift
import NowPlaying

extension RemotePlayerModel: @MainActor RemoteMediaSessionRepresentable {
    // 1️⃣ 唯一标识符
    var id: String { state.sessionID }
    
    // 2️⃣ 当前播放的内容
    var content: (any MediaContentRepresentable)? {
        GenericContent(
            id: state.sound.id,
            title: state.sound.name,
            subtitle: state.sound.description,
            type: .audio,
            duration: .live,
            artwork: Artwork(id: state.sound.id) { size in
                let data = try await self.artworkData(size: size)
                return try ArtworkRepresentation(data: data)
            }
        )
    }
    
    // 3️⃣ 播放状态快照
    var playbackSnapshot: MediaPlaybackSnapshot? {
        MediaPlaybackSnapshot(
            state: state.isPlaying ? .playing() : .paused
        )
    }
    
    // 4️⃣ 命令（发送到服务器）
    var commands: [MediaCommand] {[
        .play { try await self.client.send(.play) },
        .pause { try await self.client.send(.pause) },
        .previous { try await self.client.send(.previous) },
        .next { try await self.client.send(.next) }
    ]}
    
    // 5️⃣ 远程设备列表（远程会话特有）
    var devices: [MediaDevice] {
        state.devices.map { device in
            MediaDevice(
                id: device.id,
                name: device.name,
                type: .speaker,
                capabilities: [
                    .absoluteVolume(device.volume) { volume in
                        // 发送音量变更到服务器
                        try await self.client.send(.setVolume(volume))
                    }
                ]
            )
        }
    }
    
    // 6️⃣ 收到推送通知时更新（远程会话特有）
    func update(_ state: RemotePlayerState) {
        self.state = state
        // ✅ 由于 @Observable，系统自动检测变化并更新 UI
    }
}
```

---

### 设备能力 (Device Capabilities)

**MediaDevice 支持的能力：**

```swift
var devices: [MediaDevice] {[
    MediaDevice(
        id: "living-room-speaker",
        name: "Living Room Speaker",
        type: .speaker,          // .speaker / .tv / .display
        capabilities: [
            // 绝对音量控制
            .absoluteVolume(0.5) { volume in
                try await self.client.send(.setVolume(volume))
            },
            
            // 相对音量控制
            .relativeVolume { delta in
                try await self.client.send(.adjustVolume(delta))
            },
            
            // 静音控制
            .mute(isMuted: false) { isMuted in
                try await self.client.send(.setMute(isMuted))
            }
        ]
    )
]}
```

---

### 推送通知配置

**1. 配置 APNs 证书**

在 Apple Developer 网站配置推送通知证书。

**2. 推送通知载荷格式**

```json
{
  "aps": {
    "content-available": 1,
    "sound": ""
  },
  "nowplaying": {
    "sessionID": "living-room-session-123",
    "sound": {
      "id": "rain",
      "name": "Rain",
      "description": "Gentle rain sounds"
    },
    "isPlaying": true,
    "devices": [
      {
        "id": "speaker-001",
        "name": "Living Room Speaker",
        "volume": 0.7
      }
    ]
  }
}
```

**3. 服务器发送推送**

```python
# Python 示例
import requests

apns_url = "https://api.push.apple.com/3/device/{device_token}"
headers = {
    "apns-topic": "com.yourapp.nowplaying",
    "apns-push-type": "background",
    "authorization": f"bearer {jwt_token}"
}
payload = {
    "aps": {"content-available": 1, "sound": ""},
    "nowplaying": { /* 状态数据 */ }
}

requests.post(apns_url, json=payload, headers=headers)
```

**参考文档：** [Setting up a remote notification server](https://developer.apple.com/documentation/UserNotifications/setting-up-a-remote-notification-server)

---

## 媒体共享扩展 (Media Sharing Extensions)

### 使用场景

**简化投屏流程**：使用系统统一的设备选择器，支持多种媒体协议（AirPlay、Chromecast、DLNA 等）。

---

### 对比：传统方式 vs Media Sharing Extensions

**传统方式（多 SDK 嵌入）：**

```
App 包体积
├─ App 代码 (10 MB)
├─ AirPlay SDK (5 MB)
├─ Chromecast SDK (8 MB)
├─ DLNA SDK (6 MB)
└─ 自定义设备选择器 UI
   
总包体积: 29 MB+
```

**Media Sharing Extensions 方式：**

```
App 包体积
├─ App 代码 (10 MB)
└─ NowPlaying 集成 (< 1 MB)
   
总包体积: 11 MB

协议支持由系统管理：
├─ AirPlay (系统内置)
├─ Chromecast (系统扩展)
└─ DLNA (系统扩展)
```

---

### 优势

| 优势 | 说明 |
|------|------|
| **统一体验** | 所有 App 使用相同的设备选择器 UI |
| **减小包体积** | 无需嵌入多个 SDK |
| **自动支持新协议** | 系统更新时自动支持新设备协议 |
| **系统集成** | 设备选择显示在控制中心 |

---

### 使用方式

```swift
import AVSystemRouting

// 1. 打开系统设备选择器
let picker = AVSystemRoutingPicker()
picker.present(from: viewController)

// 2. 用户选择设备后，系统自动处理连接
// 3. App 通过 NowPlaying API 发送媒体数据
```

**参考文档：** [Routing media to third-party devices](https://developer.apple.com/documentation/AVSystemRouting/routing-media-to-third-party-devices)

---

## 完整示例

### 示例 1: 环境音 App（本地播放）

```swift
import SwiftUI
import NowPlaying
import Observation

// 1️⃣ 播放器模型
@Observable
final class PlayerModel {
    let player: SoundPlayer
    var sound: Sound { player.currentSound }
    
    init(player: SoundPlayer) {
        self.player = player
    }
}

// 2️⃣ 遵循协议
extension PlayerModel: MediaSessionRepresentable {
    var id: String { "ambient-sound-session" }
    
    var content: (any MediaContentRepresentable)? {
        GenericContent(
            id: sound.id,
            title: sound.name,
            subtitle: sound.description,
            type: .audio,
            duration: .live,
            artwork: Artwork(id: sound.id) { size in
                let data = try await self.artworkData(size: size)
                return try ArtworkRepresentation(data: data)
            }
        )
    }
    
    var playbackSnapshot: MediaPlaybackSnapshot? {
        MediaPlaybackSnapshot(
            state: player.isPlaying ? .playing() : .paused
        )
    }
    
    var commands: [MediaCommand] {[
        .play { self.player.play() },
        .pause { self.player.pause() },
        .previous { self.player.previous() },
        .next { self.player.next() }
    ]}
}

// 3️⃣ 控制器
struct PlayerController {
    let player: SoundPlayer
    let model: PlayerModel
    let session: MediaSession<PlayerModel>
    
    init() {
        self.player = SoundPlayer()
        self.model = PlayerModel(player: player)
        self.session = MediaSession(model)
    }
}

// 4️⃣ SwiftUI 视图
struct ContentView: View {
    @State private var controller = PlayerController()
    
    var body: some View {
        VStack {
            Text(controller.model.sound.name)
                .font(.title)
            
            HStack {
                Button("Previous") {
                    controller.player.previous()
                }
                
                Button(controller.player.isPlaying ? "Pause" : "Play") {
                    if controller.player.isPlaying {
                        controller.player.pause()
                    } else {
                        controller.player.play()
                    }
                }
                
                Button("Next") {
                    controller.player.next()
                }
            }
        }
    }
}
```

---

### 示例 2: 音乐播放器（带进度条）

```swift
import NowPlaying

@Observable
final class MusicPlayerModel {
    let player: AVPlayer
    var currentSong: Song
    
    func observeProgress() {
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            // 触发 @Observable 更新
            self?.objectWillChange.send()
        }
    }
}

extension MusicPlayerModel: MediaSessionRepresentable {
    var id: String { "music-player-session" }
    
    var content: (any MediaContentRepresentable)? {
        MusicContent(
            id: currentSong.id,
            title: currentSong.title,
            artist: currentSong.artist,
            album: currentSong.albumName,
            duration: .seconds(currentSong.duration),
            artwork: Artwork(id: currentSong.id) { size in
                let data = try await self.loadArtwork(size: size)
                return try ArtworkRepresentation(data: data)
            }
        )
    }
    
    var playbackSnapshot: MediaPlaybackSnapshot? {
        guard let currentTime = player.currentItem?.currentTime() else { return nil }
        
        return MediaPlaybackSnapshot(
            state: player.timeControlStatus == .playing
                ? .playing(rate: player.rate, elapsedTime: currentTime)
                : .paused
        )
    }
    
    var commands: [MediaCommand] {[
        .play { self.player.play() },
        .pause { self.player.pause() },
        .next { self.playNextSong() },
        .previous { self.playPreviousSong() },
        
        // 拖动进度条
        .seek { time in
            self.player.seek(to: time)
        },
        
        // 快进/快退
        .skipForward(interval: 15) {
            let current = self.player.currentTime()
            let new = CMTimeAdd(current, CMTime(seconds: 15, preferredTimescale: 1))
            self.player.seek(to: new)
        },
        .skipBackward(interval: 15) {
            let current = self.player.currentTime()
            let new = CMTimeSubtract(current, CMTime(seconds: 15, preferredTimescale: 1))
            self.player.seek(to: new)
        }
    ]}
}
```

---

### 示例 3: 播客 App

```swift
extension PodcastPlayerModel: MediaSessionRepresentable {
    var content: (any MediaContentRepresentable)? {
        PodcastContent(
            id: episode.id,
            title: episode.title,
            showTitle: episode.showName,
            episodeNumber: episode.number,
            duration: .seconds(episode.duration),
            artwork: Artwork(id: episode.id) { size in
                let data = try await self.loadArtwork(size: size)
                return try ArtworkRepresentation(data: data)
            }
        )
    }
    
    var commands: [MediaCommand] {[
        .play { self.player.play() },
        .pause { self.player.pause() },
        
        // 播客常用：跳过片头/片尾
        .skipForward(interval: 30) { /* 跳过 30 秒 */ },
        .skipBackward(interval: 15) { /* 回退 15 秒 */ },
        
        // 播放速率
        .changePlaybackRate { rate in
            self.player.rate = rate  // 0.5x, 1.0x, 1.5x, 2.0x
        }
    ]}
}
```

---

## 关键要点总结

### Media Session（本地播放）
- **核心协议** - `MediaSessionRepresentable`
- **自动更新** - 使用 `@Observable` 模型
- **简单集成** - 只需 3 步（遵循协议 → 实现属性 → 创建 MediaSession）

### Remote Media Session（远程控制）
- **App Extension** - `RemoteMediaSessionExtension`
- **推送通知** - 通过 APNs 接收状态更新
- **设备管理** - `MediaDevice` + `capabilities`

### Media Sharing Extensions
- **统一体验** - 系统设备选择器
- **减小包体积** - 无需嵌入多个 SDK
- **自动扩展** - 系统更新时支持新协议

---

## 与旧 API 的对比

### MPNowPlayingInfoCenter（旧 API）

```swift
// ❌ 旧方式：手动字典
var nowPlayingInfo: [String: Any] = [
    MPMediaItemPropertyTitle: "Song Title",
    MPMediaItemPropertyArtist: "Artist Name",
    MPNowPlayingInfoPropertyElapsedPlaybackTime: 30.0,
    MPMediaItemPropertyPlaybackDuration: 180.0
]
MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

// ❌ 手动更新
MPNowPlayingInfoCenter.default().playbackState = .playing
```

### NowPlaying（新 API）

```swift
// ✅ 新方式：类型安全 + 自动更新
extension PlayerModel: MediaSessionRepresentable {
    var content: (any MediaContentRepresentable)? {
        MusicContent(
            title: song.title,
            artist: song.artist,
            duration: .seconds(song.duration)
        )
    }
    
    var playbackSnapshot: MediaPlaybackSnapshot? {
        MediaPlaybackSnapshot(
            state: player.isPlaying ? .playing() : .paused
        )
    }
}

let session = MediaSession(model)
// ✅ 模型更新时，系统自动刷新
```

**优势：**
- **类型安全**：编译时检查，不会拼错键名
- **自动更新**：结合 `@Observable`，无需手动调用
- **远程支持**：内置远程设备控制
- **Swift 优先**：现代 API 设计

---

## 参考资料

- [WWDC 2026 Session 312 — Meet the NowPlaying framework](https://developer.apple.com/videos/play/wwdc2026/312/)
- [Publishing Media Sessions — Apple Developer Documentation](https://developer.apple.com/documentation/NowPlaying/publishing-media-sessions)
- [Publishing Remote Media Sessions — Apple Developer Documentation](https://developer.apple.com/documentation/NowPlaying/publishing-remote-media-sessions)
- [Routing media to third-party devices — Apple Developer Documentation](https://developer.apple.com/documentation/AVSystemRouting/routing-media-to-third-party-devices)
- [Setting up a remote notification server — Apple Developer Documentation](https://developer.apple.com/documentation/UserNotifications/setting-up-a-remote-notification-server)

---

## 关键词索引

`NowPlaying`, `MediaSession`, `MediaSessionRepresentable`, `RemoteMediaSession`, `RemoteMediaSessionRepresentable`, `RemoteMediaSessionExtension`, `MediaCommand`, `MediaPlaybackSnapshot`, `GenericContent`, `MusicContent`, `PodcastContent`, `MovieContent`, `Artwork`, `MediaDevice`, `Media Sharing Extensions`, `AVSystemRouting`, `Lock Screen`, `Control Center`, `Dynamic Island`, `CarPlay`, `StandBy`, `APNs`, `push notification`, `media playback`, `now playing`, `system integration`, `锁定屏幕`, `控制中心`, `灵动岛`, `正在播放`, `媒体播放`, `远程控制`, `智能音箱`, `投屏`, `@Observable`
