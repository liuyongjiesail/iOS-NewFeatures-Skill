# MusicKit Integration (iOS 26+)

Source: WWDC 2026 Session 254 "Integrate MusicKit into your app" + [Apple Documentation](https://developer.apple.com/documentation/MusicKit/integrating-musickit-into-your-app)

MusicKit 是 Apple 平台的 Swift 框架，专为 Swift Concurrency 和 SwiftUI 设计，让 App 无需离开即可浏览、选取并播放 Apple Music 目录及用户个人媒体库的内容。

## Quick Example

```swift
import MusicKit
import SwiftUI

struct WorkoutView: View {
    @State private var showMusicPicker = false
    @State private var selectedSongs: [Song] = []

    var body: some View {
        Button("Pick some Music", systemImage: "music.note.list") {
            showMusicPicker = true
        }
        .musicPicker(isPresented: $showMusicPicker, selection: $selectedSongs)
        .task {
            // Authorize before making any MusicKit request
            let status = await MusicAuthorization.request()
            guard status == .authorized else { return }
        }
    }
}
```

---

# Full API Reference

## 1. 项目设置（Project Setup）

发起 MusicKit 请求前必须完成以下配置：

- **Developer Token**：在开发者门户注册。为你的 App ID 在 **App Services** 标签页勾选 **MusicKit**，系统会自动生成并管理令牌。令牌与开发者账户关联，需确保 Xcode 登录了同一账户。
- **Media Library capability**：在 Xcode 项目的 **Signing & Capabilities** 添加 "Media Library"，并填写使用说明文本（`NSAppleMusicUsageDescription`）。该描述会显示在授权提示底部。
- **后台播放**：`ApplicationMusicPlayer` 若需在 App 进入后台/退出后继续播放，需在项目设置启用 **Audio Background Mode**。（`SystemMusicPlayer` 默认支持后台播放，因为它控制系统 Music App。）

## 2. 授权（Authorization）

```swift
// 异步方法，返回授权状态；未决定时会弹出系统权限提示
let status = await MusicAuthorization.request()
switch status {
case .authorized:    break          // 可访问目录 + 库
case .denied, .restricted, .notDetermined: break
@unknown default:    break
}
```

- 使用 MusicKit **不要求**用户拥有 Apple Music 订阅。
- 无订阅时，App 只能访问用户**已购买或已同步**的音乐；音乐选取器也只会显示库内容，不显示目录。

## 3. 订阅状态与订阅优惠（Subscription）

监听订阅状态，仅在用户可成为订阅者时展示订阅入口：

```swift
@State var subscription: MusicSubscription?

var body: some View {
    VStack {
        if let subscription, subscription.canBecomeSubscriber {
            musicSubscriptionButton
        }
    }
    .task(id: isAuthorized) {
        self.subscription = try? await MusicSubscription.current
        for await subscription in MusicSubscription.subscriptionUpdates {
            self.subscription = subscription
        }
    }
}
```

使用 `.musicSubscriptionOffer` 视图修饰符让用户在 App 内订阅 Apple Music（可通过 Apple Services Performance Partner Program 获得佣金）：

```swift
@State var showSubscriptionOffer = false

let options = MusicSubscriptionOffer.Options(
    messageIdentifier: .playMusic   // 改变呈现的界面；也可自定义合作伙伴信息
)

@ViewBuilder
var musicSubscriptionButton: some View {
    Button("Subscribe to Apple Music", systemImage: "music.note") {
        showSubscriptionOffer = true
    }
    .musicSubscriptionOffer(isPresented: $showSubscriptionOffer, options: options)
}
```

## 4. 音乐条目（MusicItem）

MusicItem 是使用 MusicKit API 的基础构建块，均为**值类型**，位于 MusicKit 模型层。常见类型：`Song`、`Album`、`Playlist`、`Artist`、`Genre`、`Station`。

每个音乐条目包含三类信息：

- **Attributes**：内置简单属性，如 `Album.title`、`Album.contentRating`。
- **Relationships**：强关联的相关内容，如 `Album` 的 `tracks`（另一种 MusicItem 类型）。
- **Associations**：较弱关联的相关内容，如 `Album` 的 `otherVersions`（其他专辑集合）。

## 5. 音乐选取器（Music Picker）

`.musicPicker` 修饰符在统一界面中同时呈现 Apple Music 目录与用户音乐库，整合了多种 MusicKit 请求。**不需要订阅**即可使用。

```swift
@State var showMusicPicker = false
@State var selectedSong: Song? = nil            // 单选：可选类型
// @State var selectedSongs: [Song] = []        // 多选：改为数组即可

@ViewBuilder
var musicPickerButton: some View {
    Button("Pick some Music", systemImage: "music.note.list") {
        showMusicPicker = true
    }
    .musicPicker(isPresented: $showMusicPicker, selection: $selectedSong)
}
```

- **单选 vs 多选**：绑定单个可选值即为单选；绑定数组即允许多选。
- 用户可选取单曲，也可进入专辑/播放列表详情页，点击顶部加号选中整张专辑或播放列表的全部歌曲。

## 6. 播放器（Music Players）

MusicKit 提供两种播放器，均为 `MusicPlayer` 子类：

| | `SystemMusicPlayer` | `ApplicationMusicPlayer` |
|---|---|---|
| 控制对象 | 系统 Music App | 你的 App 内播放 |
| 队列访问 | 只能设置队列，除当前条目外不可读取 | 完整读写队列 |
| 后台播放 | 默认继续播放 | 需启用 Audio Background Mode |
| 播放状态/随机/重复 | ✅ 可设置 | ✅ 可设置 |

两者都是可观察（Observable）类，`state` 和 `queue` 可直接在 SwiftUI 视图中使用。

### 设置队列并播放

```swift
let player = ApplicationMusicPlayer.shared

// 队列可由任意可播放条目创建（歌曲，或专辑/播放列表等容器）
player.queue = ApplicationMusicPlayer.Queue(for: selectedSongs)

// 容器类型使用专用初始化器可延迟加载条目，进一步缩短加载时间
// player.queue = ApplicationMusicPlayer.Queue(album: album)

// 是否计入 Music App「最近播放」/ 收听历史，默认 true（遵循用户设置）
player.queue.affectsListeningHistory = true

try await player.prepareToPlay()   // 可选：提前缓冲，减少 play() 到出声的时间
try await player.play()            // 加载队列 → 加载音频资源 → 播放
player.pause()                     // 暂停
```

### 观察播放状态与当前条目

```swift
@State var queue = ApplicationMusicPlayer.shared.queue
@State var state = ApplicationMusicPlayer.shared.state
let player = ApplicationMusicPlayer.shared

var isPlaying: Bool { state.playbackStatus == .playing }

var body: some View {
    VStack {
        // 封面
        if let artwork = queue.currentEntry?.artwork {
            ArtworkImage(artwork, width: 200, height: 200)
        } else {
            RoundedRectangle(cornerRadius: 16).fill(.quaternary)
                .frame(width: 200, height: 200)
        }

        // 标题 / 副标题
        if let currentSong = queue.currentEntry {
            Text(currentSong.title).font(.title3.bold())
            if let subtitle = currentSong.subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }

        // 播放 / 暂停
        Button(isPlaying ? "Pause" : "Play",
               systemImage: isPlaying ? "pause.fill" : "play.fill") {
            if isPlaying { player.pause() }
            else { Task { try await player.play() } }
        }

        // 上一首 / 下一首
        HStack {
            Button("Back", systemImage: "backward.fill") {
                Task { try await player.skipToPreviousEntry() }
            }
            Button("Next", systemImage: "forward.fill") {
                Task { try await player.skipToNextEntry() }
            }
        }
    }
}
```

## 7. 目录请求（Catalog Requests）

结构化目录请求可独立于用户库，直接查询 Apple Music 内容（如为 App 提供精选/推荐）。

```swift
func fetchSongs(songIDs: [MusicItemID]) async throws -> (featured: Song?, other: [Song]) {
    var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: songIDs)
    request.options = [.findEquivalents]   // 跨地区/明确内容自动匹配等效资源

    let response = try await request.response()   // MusicCatalogResourceResponse

    let featuredSongID = songIDs[0]
    let featuredSong = response.item(for: featuredSongID)

    let others: [Song] = songIDs[1...].compactMap { response.item(for: $0) }
    return (featuredSong, others)
}
```

- 可在 `request` 上设置需要一并获取的 `properties`（relationships / associations），以及返回条目数量的 `limit`。
- 响应结果为强类型的 `MusicItemCollection<Song>`，支持分页：`hasNextBatch` 为 true 时可 `await response.nextBatch()`。
- 目录请求**不保证**返回所有请求内容（资源可能不可用）。

## ⚠️ Important Notes

- **授权是前提**：任何目录/库请求前必须先 `MusicAuthorization.request()` 得到 `.authorized`。
- **音乐选取器不需要订阅**，但无订阅时只显示用户库内容，不含 Apple Music 目录。
- **播放需订阅**：播放 Apple Music 目录内容需要有效订阅；无订阅只能播放已购买/已同步音乐。
- **后台播放**：`ApplicationMusicPlayer` 需手动启用 Audio Background Mode；`SystemMusicPlayer` 无需。
- **资源等效性**：不同店面/地区同一资源可能 ID 不同；明确内容可能有洁净版本。使用 `.findEquivalents` 处理。
- **`affectsListeningHistory`** 默认 true，会写入 Music App「最近播放」，同时遵循用户「使用收听历史」设置。

## 相关视频

- WWDC22 "借助 MusicKit 探索更多内容"（浏览与修改库内容的请求）
- WWDC22 "Apple Music API 和 MusicKit 简介"（Android / Web 集成）
- WWDC23 "探索 SwiftUI 中的观察"（Observation）
