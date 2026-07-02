# 生成式字幕和字幕样式预览

> **适用范围：** iOS 27+ / macOS 27+ / tvOS 27+ / visionOS 27+  
> **来源：** WWDC 2026 Session 256  
> **框架：** AVKit, AVFoundation, MediaAccessibility
> 
> 本文档涵盖 Apple AI 生成式字幕（语音转录和语言翻译）以及字幕样式预览功能的实现细节。

---

## 目录

1. [功能概览](#功能概览)
2. [生成式字幕](#生成式字幕)
3. [字幕样式预览](#字幕样式预览)
4. [实现方式](#实现方式)
5. [完整示例代码](#完整示例代码)
6. [平台和语言支持](#平台和语言支持)
7. [最佳实践](#最佳实践)

---

## 功能概览

### 核心特性

| 特性 | 说明 |
|------|------|
| **生成式字幕** | 使用设备端 AI 模型实时转录语音或翻译字幕 |
| **字幕样式预览** | 在播放过程中预览和自定义字幕样式 |
| **设备端处理** | 完全在本地运行，保护隐私 |
| **自动启用** | 无需编写代码，自动集成 |
| **无障碍访问** | 为失聪、听力障碍或其他需求用户提供支持 |

### 使用场景

**生成式字幕适用于：**
- 失聪或听力障碍用户
- 辅助理解对话内容
- 在嘈杂环境中观看视频（如机场、咖啡厅）
- 学习外语（通过翻译字幕）
- 原始内容缺少用户所需语言的字幕

**字幕样式预览适用于：**
- 在播放过程中快速调整字幕可读性
- 预览不同样式效果后再应用
- 无需离开视频跳转到系统设置

---

## 生成式字幕

### 两种生成方式

#### 1. 语音转录 (Speech Transcription)

从音频直接生成字幕：

```
源音频 → 设备端 Speech-to-Text 模型 → 生成字幕
```

**示例：** 英语音频 → 英语字幕

#### 2. 语言翻译 (Language Translation)

从现有字幕翻译生成新语言字幕：

```
源字幕 → 设备端翻译模型 → 新语言字幕
```

**示例：** 英语字幕 → 意大利语字幕

### 媒体制作流程

```
拍摄视频
   ↓
视频和音频剪辑
   ↓
人工创建字幕（预制字幕）
   ↓
多语言音频和字幕
   ↓
最终媒体：视频 + 音频 + 预制字幕
   ↓
【生成式字幕】填补缺失的语言支持
```

**注意：** 预制字幕始终优先显示，生成式字幕提供额外的语言支持。

### 支持的内容类型

| 内容类型 | 说明 | 示例 |
|---------|------|------|
| **HTTP Live Streaming (HLS)** | 流媒体内容 | 电视频道、电影、剧集、直播活动 |
| **点播视频 (VOD)** | 录制内容 | 电影、电视节目、旅行视频 |
| **直播内容** | 实时流媒体 | 体育赛事、新闻、活动直播 |
| **基于文件的内容** | 本地媒体文件 | App 内置视频、已下载文件 |
| **专业内容** | 制作级内容 | 电影、剧集 |
| **用户创作内容 (UGC)** | 用户生成 | iPhone 拍摄视频、社交媒体视频 |

### 自动启用

**零代码集成：** 生成式字幕在视频播放时自动启用，无需任何额外实现。

```swift
// 无需编写任何代码，系统自动处理
// 当预制字幕不可用时，用户可在字幕菜单中选择生成式字幕
```

**字幕菜单标识：**
- 生成式字幕选项带有 **星光符号 (✨)**
- 标注为 **"已翻译"** 或 **"已转录"**

---

## 字幕样式预览

### 功能说明

字幕样式预览允许用户在播放视频时：
1. 直接从视频播放界面打开样式菜单
2. 实时预览不同字幕样式效果
3. 选择最适合的样式并立即应用
4. 无需跳转到系统设置 App

### 系统字幕样式

**内置样式：**
- Default（默认）
- Large Text（大文本）
- Classic（经典）
- Outline（轮廓）

**自定义样式：**
用户可在系统设置中创建自定义样式，包括：
- 字体大小和样式
- 文字颜色
- 背景颜色和透明度
- 边框和阴影效果

### 样式预览行为

当用户在菜单中选择某个样式时：
1. **隐藏当前字幕**：所有现有字幕自动隐藏
2. **显示预览文本**：使用选定样式显示占位文本
3. **本地化文本**：预览文本自动使用当前字幕语言
4. **实时预览**：用户可浏览多个样式并实时查看效果
5. **应用样式**：关闭菜单后，新样式应用于所有字幕

---

## 实现方式

### 方案 1: AVPlayerViewController (推荐)

**完整实现，零配置**

```swift
import AVKit

// iOS
let playerViewController = AVPlayerViewController()
playerViewController.player = player
present(playerViewController, animated: true)

// macOS
let playerView = AVPlayerView()
playerView.player = player
```

**特性：**
- ✅ 字幕选择界面（包括生成式字幕）
- ✅ 字幕样式预览
- ✅ 播放器控件
- ✅ 无需额外代码

---

### 方案 2: AVLegibleMediaOptionsMenuController

**字幕控件，无播放器控件**

```swift
import AVKit

class CustomPlayerViewController: UIViewController {
    let player = AVPlayer(url: videoURL)
    let playerLayer = AVPlayerLayer()
    
    lazy var legibleMenuController = AVLegibleMediaOptionsMenuController(
        player: player
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置播放器层
        playerLayer.player = player
        view.layer.addSublayer(playerLayer)
        
        // 添加字幕菜单按钮到你的自定义 UI
        let menuButton = UIButton(type: .system)
        menuButton.setTitle("字幕", for: .normal)
        menuButton.addTarget(self, action: #selector(showSubtitleMenu), for: .touchUpInside)
    }
    
    @objc func showSubtitleMenu() {
        // 显示字幕菜单
        legibleMenuController.present(from: self, animated: true)
    }
}
```

**特性：**
- ✅ 字幕选择界面（包括生成式字幕）
- ✅ 字幕样式预览
- ❌ 不提供播放器控件
- 适合：已有自定义播放器 UI，只需添加字幕控件

---

### 方案 3: AVPlayerLayer + 自定义 UI

**完全自定义实现**

#### 3.1 获取所有字幕样式

```swift
import MediaAccessibility

func updateProfileList() {
    // 获取系统中所有字幕样式的 ID
    subtitleStyleProfileIDs = MACaptionAppearanceCopyProfileIDs() as? [String] ?? []
    
    // 获取每个样式的显示名称
    for profileID in subtitleStyleProfileIDs {
        let displayName = MACaptionAppearanceCopyProfileName(profileID as CFString)
        // 使用 displayName 填充 UI
    }
}
```

#### 3.2 显示样式预览

```swift
import AVFoundation

func showPreviewStyle(subtitleStyleProfileID: String) {
    // 显示指定样式的预览
    // text: nil 表示使用系统本地化的占位文本
    // position: 相对于默认位置的偏移量（避开 UI 控件）
    playerLayer.setCaptionPreviewProfileID(
        subtitleStyleProfileID,
        position: .zero,
        text: nil
    )
    
    // 自动行为：
    // - 隐藏所有当前字幕
    // - 显示样式化的预览文本
}

// 使用自定义预览文本（可选）
func showPreviewWithCustomText(subtitleStyleProfileID: String) {
    playerLayer.setCaptionPreviewProfileID(
        subtitleStyleProfileID,
        position: CGPoint(x: 0, y: -50), // 向上偏移 50 点
        text: "自定义预览文本"
    )
}
```

#### 3.3 停止预览

```swift
func stopPreviewStyle() {
    // 移除预览文本，恢复所有当前活跃的字幕
    playerLayer.stopShowingCaptionPreview()
}
```

#### 3.4 应用选定的样式

```swift
func setSubtitleStyle(subtitleStyleProfileID: CFString) {
    // 将样式应用于系统上的所有字幕
    MACaptionAppearanceSetActiveProfileID(subtitleStyleProfileID)
    
    // 注意：这会全局生效，影响所有 App 的字幕显示
}
```

**特性：**
- ✅ 完全自定义样式菜单 UI
- ✅ 字幕样式预览 API
- ❌ 需要自行实现字幕选择逻辑
- ❌ 需要自行实现播放器控件
- 适合：需要完全匹配 App 设计风格的场景

---

### 方案 4: AVCaptionRenderer

**自定义渲染**

```swift
import AVFoundation

let captionRenderer = AVCaptionRenderer()

// 配置渲染器
captionRenderer.bounds = renderingBounds
captionRenderer.captionSceneChangesInRange(range) { scene, timeRange in
    // 自行负责渲染字幕
    // 可使用 MACaptionAppearance API 获取样式信息
}
```

**特性：**
- ✅ 完全控制渲染流程
- ✅ 可实现样式预览
- ❌ 需要自行处理渲染逻辑
- 适合：需要特殊渲染效果的高级场景

---

## 完整示例代码

### 示例 1: 使用 AVPlayerViewController（最简单）

```swift
import UIKit
import AVKit

class VideoPlayerViewController: UIViewController {
    let player = AVPlayer(url: URL(string: "https://example.com/video.m3u8")!)
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 完整功能的播放器
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        
        // 呈现播放器
        present(playerVC, animated: true) {
            self.player.play()
        }
        
        // ✅ 自动支持生成式字幕
        // ✅ 自动支持字幕样式预览
    }
}
```

---

### 示例 2: 自定义字幕样式预览

```swift
import UIKit
import AVFoundation
import MediaAccessibility

class CustomSubtitlePlayerViewController: UIViewController {
    let player = AVPlayer(url: videoURL)
    let playerLayer = AVPlayerLayer()
    
    var subtitleStyleProfileIDs: [String] = []
    var currentPreviewID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置播放器层
        playerLayer.player = player
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        // 加载字幕样式列表
        loadSubtitleStyles()
        
        // 添加样式菜单按钮
        setupStyleMenuButton()
    }
    
    // MARK: - 加载字幕样式
    
    func loadSubtitleStyles() {
        subtitleStyleProfileIDs = MACaptionAppearanceCopyProfileIDs() as? [String] ?? []
    }
    
    // MARK: - 显示样式菜单
    
    func showStyleMenu() {
        let alert = UIAlertController(title: "选择字幕样式", message: nil, preferredStyle: .actionSheet)
        
        for profileID in subtitleStyleProfileIDs {
            let displayName = MACaptionAppearanceCopyProfileName(profileID as CFString) as String? ?? "未知样式"
            
            let action = UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.previewStyle(profileID)
            }
            alert.addAction(action)
        }
        
        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.stopPreview()
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - 预览样式
    
    func previewStyle(_ profileID: String) {
        currentPreviewID = profileID
        
        // 显示预览（使用默认本地化文本）
        playerLayer.setCaptionPreviewProfileID(profileID, position: .zero, text: nil)
    }
    
    // MARK: - 停止预览
    
    func stopPreview() {
        playerLayer.stopShowingCaptionPreview()
        currentPreviewID = nil
    }
    
    // MARK: - 应用样式
    
    func applySelectedStyle() {
        guard let profileID = currentPreviewID else { return }
        
        // 停止预览
        stopPreview()
        
        // 应用样式（全局生效）
        MACaptionAppearanceSetActiveProfileID(profileID as CFString)
        
        // 提示用户
        let alert = UIAlertController(title: "样式已应用", message: "字幕样式已更改", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - UI 设置
    
    func setupStyleMenuButton() {
        let button = UIButton(type: .system)
        button.setTitle("字幕样式", for: .normal)
        button.addTarget(self, action: #selector(styleMenuButtonTapped), for: .touchUpInside)
        // 添加到视图...
    }
    
    @objc func styleMenuButtonTapped() {
        showStyleMenu()
    }
}
```

---

### 示例 3: 监听样式变化

```swift
import MediaAccessibility

class SubtitleStyleObserver {
    init() {
        // 监听字幕样式变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captionStyleDidChange),
            name: NSNotification.Name.MACaptionAppearanceSettingsChanged,
            object: nil
        )
    }
    
    @objc func captionStyleDidChange() {
        // 用户在系统设置中更改了字幕样式
        // 更新 UI 或重新加载样式列表
        print("字幕样式已更改")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

---

## 平台和语言支持

### 支持的平台

| 平台 | 版本 | 语音转录 | 语言翻译 |
|------|------|---------|---------|
| **iOS** | 27+ | ✅ 英语音频 → 英语字幕 | ✅ 英语字幕 → 多种语言 |
| **macOS** | 27+ | ✅ 英语音频 → 英语字幕 | ✅ 英语字幕 → 多种语言 |
| **tvOS** | 27+ | ✅ 英语音频 → 英语字幕 | ❌ |
| **visionOS** | 27+ | ✅ 英语音频 → 英语字幕 | ❌ |

### 支持的语言（翻译）

**从英语字幕可生成的语言（iOS/macOS）：**
- 西班牙语 (Spanish)
- 法语 (French)
- 德语 (German)
- 意大利语 (Italian)
- 葡萄牙语 (Portuguese)
- 日语 (Japanese)
- 韩语 (Korean)
- 中文简体 (Simplified Chinese)
- 中文繁体 (Traditional Chinese)
- 阿拉伯语 (Arabic)
- 俄语 (Russian)
- 更多语言持续增加...

**注意：** 具体支持的语言可能因设备和系统版本而异。

---

## 最佳实践

### ✅ 推荐做法

1. **使用 AVPlayerViewController / AVPlayerView**
   - 除非有特殊定制需求，否则优先使用系统提供的播放器控件
   - 自动获得最新功能和最佳用户体验

2. **提供字幕选择界面**
   - 在视频播放期间提供字幕选择界面至关重要
   - 让用户能够轻松切换字幕语言和样式

3. **测试多种内容类型**
   - 测试 HLS 流媒体内容
   - 测试本地文件
   - 测试有/无预制字幕的内容

4. **考虑无障碍访问**
   - 确保字幕菜单可通过 VoiceOver 访问
   - 提供键盘快捷键（macOS）
   - 支持动态类型（Dynamic Type）

5. **优化样式预览体验**
   - 使用 `position` 参数避开 UI 控件
   - 使用 `nil` 作为 `text` 参数以显示本地化文本
   - 在用户做出最终选择后调用 `stopShowingCaptionPreview()`

### ⚠️ 注意事项

1. **预制字幕优先**
   - 生成式字幕不会替换预制字幕
   - 预制字幕始终优先显示
   - 生成式字幕仅在预制字幕不可用时提供

2. **全局样式设置**
   - `MACaptionAppearanceSetActiveProfileID()` 会影响系统上的所有字幕
   - 用户在你的 App 中更改样式，也会影响其他 App
   - 这是预期行为，符合系统无障碍设计

3. **隐私和性能**
   - 生成式字幕完全在设备端运行
   - 不会将音频或字幕发送到服务器
   - 可能消耗更多设备资源（CPU/GPU/内存）

4. **语言支持动态变化**
   - 支持的语言和平台可能随系统更新而变化
   - 使用系统 API 动态检查可用选项
   - 不要硬编码语言列表

5. **生成式字幕质量**
   - 由 AI 模型生成，可能不如人工字幕准确
   - 在嘈杂环境或音质差的情况下准确度可能下降
   - 专业术语或方言可能识别不准确

### 🚫 避免的做法

1. **不要隐藏字幕选项**
   - 即使你的内容有预制字幕，也应提供字幕菜单
   - 用户可能需要切换到生成式字幕或调整样式

2. **不要自行实现 AI 字幕生成**
   - 使用系统提供的生成式字幕功能
   - 不要尝试调用 Speech framework 自行实现
   - 系统方案更高效、更准确、更省电

3. **不要阻止用户更改样式**
   - 即使你的 App 有品牌色，也不应强制字幕样式
   - 尊重用户的无障碍需求

4. **不要假设字幕总是可用**
   - 生成式字幕需要网络下载语言模型（首次使用）
   - 旧设备或不支持的平台可能无法使用
   - 提供优雅的降级体验

---

## 相关 API 参考

### MediaAccessibility 框架

```swift
// 获取所有字幕样式 ID
MACaptionAppearanceCopyProfileIDs() -> CFArray?

// 获取样式显示名称
MACaptionAppearanceCopyProfileName(_ profileID: CFString) -> CFString?

// 设置活跃样式
MACaptionAppearanceSetActiveProfileID(_ profileID: CFString)

// 获取当前活跃样式
MACaptionAppearanceGetActiveProfileID() -> CFString

// 字幕样式变化通知
NSNotification.Name.MACaptionAppearanceSettingsChanged
```

### AVPlayerLayer

```swift
// 显示字幕样式预览
func setCaptionPreviewProfileID(
    _ profileID: String,
    position: CGPoint,
    text: String?
)

// 停止字幕样式预览
func stopShowingCaptionPreview()
```

### AVKit

```swift
// iOS/tvOS/visionOS
class AVPlayerViewController: UIViewController

// macOS
class AVPlayerView: NSView

// 字幕选择菜单控制器
class AVLegibleMediaOptionsMenuController
```

---

## 相关 WWDC Sessions

- **WWDC 2026 Session 256**: 探索生成式字幕和字幕样式
- **WWDC 2024 Session 10135**: What's new in AVKit
- **WWDC 2023 Session 10122**: Enhance your spatial computing app with RealityKit
- **WWDC 2022 Session 10117**: Create accessible experiences for watchOS
- **WWDC 2021 Session 10188**: Explore HLS variants in AVFoundation

---

## 额外资源

- [Apple Developer Documentation: AVKit](https://developer.apple.com/documentation/avkit)
- [Apple Developer Documentation: MediaAccessibility](https://developer.apple.com/documentation/mediaaccessibility)
- [Human Interface Guidelines: Playing Media](https://developer.apple.com/design/human-interface-guidelines/playing-media)
- [Accessibility - Closed Captions](https://developer.apple.com/accessibility/closed-captions/)
- [What's new in HTTP Live Streaming](https://developer.apple.com/streaming/Whats-new-HLS.pdf)

---

## 总结

生成式字幕和字幕样式预览是 iOS 27+ 引入的强大无障碍功能：

1. **生成式字幕**：自动启用，无需代码，提供语音转录和语言翻译
2. **字幕样式预览**：让用户在播放时快速调整字幕样式
3. **多种实现方式**：从零配置到完全自定义，满足不同需求
4. **设备端处理**：保护隐私，离线运行
5. **无障碍优先**：为所有用户提供更好的内容访问体验

**推荐：** 使用 `AVPlayerViewController` 或 `AVPlayerView` 获得最佳开箱即用体验。
