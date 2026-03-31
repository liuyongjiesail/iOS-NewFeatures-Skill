# App Intents — iOS 18 / iOS 26 新特性

Source: WWDC 2025 Session 244 — "Explore the App Intents framework"
Official Docs: https://developer.apple.com/documentation/AppIntents
Domains Docs: https://developer.apple.com/documentation/AppIntents/app-intent-domains
Updates Log: https://developer.apple.com/documentation/Updates/AppIntents

> **范围说明**：本文档只覆盖 iOS 18 及之后的新增 API。iOS 16/17 的基础用法（AppIntent、AppEnum、AppEntity、EntityQuery、AppShortcutsProvider 等）AI 已知，不重复。

---

## iOS 18 新增

### 1. App Intent Domains — Siri / Apple Intelligence 深度集成

通过 `@AppIntent(schema:)`、`@AppEntity(schema:)`、`@AppEnum(schema:)` 三个宏，让 Siri 和 Apple Intelligence 理解 Intent / Entity / Enum 的语义，无需用户显式指定 App 名称。

**⚠️ 核心注意：不是协议继承，是宏**

```swift
// ✅ 正确写法
@AppIntent(schema: .mail.createDraft)
struct CreateDraftIntent: AppIntent { ... }

// ❌ 错误写法（这种协议不存在）
struct CreateDraftIntent: MailCreateDraftIntent { ... }
```

#### 宏用法模板

```swift
// Intent
@AppIntent(schema: .域名.action名)
struct MyIntent: AppIntent {
    // 宏自动添加必要属性，编译器会提示缺少哪些字段
    func perform() async throws -> some IntentResult { .result() }
}

// Entity
@AppEntity(schema: .域名.entity名)
struct MyEntity: AppEntity {
    static var defaultQuery = MyQuery()
    var displayRepresentation: DisplayRepresentation { "..." }
    let id: UUID
    // schema 要求的属性，编译器会提示
}

// Enum
@AppEnum(schema: .域名.enum名)
enum MyEnum: String, AppEnum { ... }
```

#### 全域索引

| 域 | schema 前缀 | 适用场景 |
|----|------------|---------|
| Mail | `.mail` | 邮件客户端 |
| Photos | `.photos` | 照片/视频 App |
| Browser | `.browser` | 浏览器 |
| Books | `.books` | 电子书阅读器 |
| Camera | `.camera` | 相机功能 |
| File management | `.fileManagement` | 文件管理 |
| Journaling | `.journaling` | 日记/记录类 App |
| Presentations | `.presentation` | 演示文稿 |
| Reader | `.reader` | 文档阅读器 |
| Spreadsheet | `.spreadsheet` | 表格类 App |
| System and in-app search | `.system` | App 内搜索 |
| Visual intelligence | `.visualIntelligence` | 视觉识别集成 |
| Whiteboard | `.whiteboard` | 白板类 App |
| Word processor | `.wordProcessor` | 文字处理 |
| Assistant | `.assistant` | 语音对话 App（仅日本） |

#### Mail 域

```swift
// Intent Actions：.mail.archiveMail / .mail.createDraft / .mail.deleteDraft
//                .mail.deleteMail / .mail.forwardMail / .mail.replyMail
//                .mail.saveDraft / .mail.sendDraft / .mail.updateDraft / .mail.updateMail
// Entity Types： .mail.account / .mail.draft / .mail.mailbox / .mail.message

@AppIntent(schema: .mail.sendDraft)
struct SendDraftIntent: AppIntent {
    var target: MailDraftEntity   // schema 要求的参数名
    var sendLaterDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult { .result() }
}

@AppEntity(schema: .mail.draft)
struct MailDraftEntity: AppEntity {
    static var defaultQuery = MailDraftQuery()
    var displayRepresentation: DisplayRepresentation { "\(subject ?? "无主题")" }
    let id = UUID()
    var to: [IntentPerson]
    var cc: [IntentPerson]
    var bcc: [IntentPerson]
    var subject: String?
    var body: AttributedString?
    var attachments: [IntentFile]
    var account: MailAccountEntity

    struct MailDraftQuery: EntityStringQuery {
        func entities(for identifiers: [MailDraftEntity.ID]) async throws -> [MailDraftEntity] { [] }
        func entities(matching string: String) async throws -> [MailDraftEntity] { [] }
    }
}
```

#### Photos 域

```swift
// Intent Actions：.photos.search / .photos.createAlbum / .photos.deleteAssets
//                .photos.updateAsset / .photos.setFilter / .photos.setExposure
//                .photos.crop / .photos.setRotation / .photos.addAssetsToAlbum 等
// Entity Types： .photos.album / .photos.asset / .photos.recognizedPerson
// Enum Types：   .photos.albumType / .photos.assetType / .photos.filterType / .photos.rotationDirection

@AppIntent(schema: .photos.search)
struct SearchPhotosIntent: AppIntent {
    @Parameter var searchText: String?
    func perform() async throws -> some IntentResult & ReturnsValue<[PhotoAssetEntity]> {
        let results = await PhotoLibrary.shared.search(query: searchText ?? "")
        return .result(value: results.map(PhotoAssetEntity.init))
    }
}

@AppEntity(schema: .photos.asset)
struct PhotoAssetEntity: AppEntity {
    static var defaultQuery = PhotoAssetQuery()
    var displayRepresentation: DisplayRepresentation { "\(filename)" }
    let id: String
    var filename: String
    var creationDate: Date?
}
```

#### Browser 域

```swift
// Intent Actions：.browser.createTab / .browser.closeTabs / .browser.switchTab
//                .browser.openURLInTab / .browser.bookmarkTab / .browser.bookmarkURL
//                .browser.openBookmark / .browser.deleteBookmarks / .browser.clearHistory
//                .browser.findOnPage / .browser.createWindow / .browser.closeWindows
// Entity Types： .browser.tab / .browser.bookmark / .browser.window
// Enum Types：   .browser.clearHistoryTimeFrame

@AppIntent(schema: .browser.createTab)
struct CreateTabIntent: AppIntent {
    var url: URL?
    func perform() async throws -> some IntentResult & ReturnsValue<BrowserTabEntity> {
        let tab = await Browser.shared.createTab(url: url)
        return .result(value: BrowserTabEntity(tab: tab))
    }
}
```

#### 其他域快速参考

```swift
// File Management
// .fileManagement.createFolder / .deleteFiles / .moveFiles / .openFile / .tagFiles

// Journaling
// .journaling.createEntry / .openEntry

// System & In-App Search
// .system.search  — App 内搜索，Spotlight 深度集成

// Word Processor / Spreadsheet / Presentation
// .wordProcessor.createDocument / .openDocument
// .spreadsheet.createDocument / .openDocument
// .presentation.createDocument / .openDocument

// Visual Intelligence
// .visualIntelligence.*  — 配合 IntentValueQuery 使用
```

#### Domain 注意事项

- **旧宏已废弃**：`@AssistantIntent`、`@AssistantEntity`、`@AssistantEnum` → 改用 `@AppIntent`/`@AppEntity`/`@AppEnum`
- **Intent 和 Entity 都要打宏**：关联的 Entity 也必须用 `@AppEntity(schema:)` 标注，否则 Siri 无法理解
- **编译器会提示缺少字段**：不需要死记每个域的必填属性，宏会在编译期报错提示
- **功能仍在开发中**：Apple 官方注明 Siri 上下文感知和 in-app actions 尚未完全上线

---

### 2. ControlConfigurationIntent — Control Center / 锁屏控件

配合 WidgetKit，让用户将 App 功能添加到锁屏或 Control Center。

```swift
import AppIntents
import WidgetKit

struct ToggleCameraIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Toggle Camera"

    func perform() async throws -> some IntentResult {
        // 执行操作
        return .result()
    }
}

// 在 Widget Extension 中声明对应的 ControlWidget
struct CameraControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.example.camera-control",
            provider: CameraControlProvider()
        ) { value in
            ControlWidgetToggle(
                "Camera",
                isOn: value,
                action: ToggleCameraIntent()
            )
        }
    }
}
```

---

### 3. CameraCaptureIntent — Action Button 相机快拍

创建锁屏相机捕捉扩展，允许通过 Action Button 在不解锁的情况下拍照/录像。

```swift
struct QuickCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "Quick Capture"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
```

需要在 App 中创建 **Locked Camera Capture Extension** 目标，并在扩展中实现 `CameraCaptureIntent`。

---

### 4. AudioRecordingIntent — 录音意图

```swift
struct StartRecordingIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Recording"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
```

---

### 5. IndexedEntity — Spotlight 语义索引

让 App 实体出现在 Spotlight 搜索结果中。iOS 18 引入协议，iOS 26 新增属性级索引键。

```swift
// iOS 18：基础用法
struct NoteEntity: IndexedEntity {
    var id: UUID
    var title: String
    var content: String

    // 提供 CSSearchableItemAttributeSet
    var attributeSet: CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.displayName = title
        attrs.contentDescription = content
        return attrs
    }
}

// iOS 26 新增：直接在属性上标注索引键，框架自动处理 attributeSet
struct NoteEntity: IndexedEntity {
    @Property(indexingKey: \.displayName)       // 映射到 CSSearchableItemAttributeSet.displayName
    var title: String

    @Property(indexingKey: \.contentDescription)
    var content: String

    // @ComputedProperty(indexingKey:) 同样支持，用于计算属性
    @ComputedProperty(indexingKey: \.keywords)
    var tags: [String] { note.tags }
}
```

捐赠实体到 Spotlight：

```swift
// 批量捐赠
try await EntityIndexer.shared.index(notes.map(NoteEntity.init))

// 删除
try await EntityIndexer.shared.deleteEntities(ofType: NoteEntity.self, identifiers: [id])
```

---

### 6. FileEntity — 文件型实体

用于表示 App 中的文件内容（文档、图片等），可被 Shortcuts 的文件动作直接使用。

```swift
struct DocumentEntity: FileEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Document")
    static let defaultQuery = DocumentEntityQuery()

    var id: UUID
    var fileURL: URL

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(fileURL.lastPathComponent)")
    }
}
```

---

### 7. UniqueAppEntity — 单例实体

适用于全局唯一的实体，例如 App 设置。无需复杂 Query，框架自动处理。

```swift
struct AppSettingsEntity: UniqueAppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "App Settings")
    static let defaultQuery = AppSettingsQuery()

    @Property var notificationsEnabled: Bool
    @Property var darkModeEnabled: Bool
}

struct AppSettingsQuery: UniqueAppEntityQuery {
    func uniqueEntity() async throws -> AppSettingsEntity {
        AppSettingsEntity(
            notificationsEnabled: UserDefaults.standard.bool(forKey: "notifications"),
            darkModeEnabled: UserDefaults.standard.bool(forKey: "darkMode")
        )
    }
}
```

---

### 8. URLRepresentable — Universal Link 深链接

让 Intent / Entity / Enum 可以用 Universal Link 表示，支持深链接跳转。

```swift
struct NoteEntity: AppEntity, URLRepresentableEntity {
    // ...
    static var urlRepresentation: URLRepresentation {
        "https://example.com/notes/\(.id)"
    }
}

struct OpenNoteIntent: AppIntent, URLRepresentableIntent {
    static let title: LocalizedStringResource = "Open Note"
    static var urlRepresentation: URLRepresentation {
        "https://example.com/notes/\(\.$note)"
    }

    @Parameter var note: NoteEntity
    func perform() async throws -> some IntentResult { .result() }
}
```

---

### 9. @UnionValue — 联合类型参数

一个参数支持多种类型，类似 enum with associated values。

```swift
@UnionValue
enum ContentTarget {
    case note(NoteEntity)
    case folder(FolderEntity)
}

struct OpenContentIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Content"

    @Parameter var target: ContentTarget

    func perform() async throws -> some IntentResult {
        switch target {
        case .note(let note):   // 处理 note
        case .folder(let folder): // 处理 folder
        }
        return .result()
    }
}
```

---

### 10. requestConfirmation 条件确认

iOS 18 新增 `conditions` 参数，只在满足特定条件时才弹出确认框。

```swift
func perform() async throws -> some IntentResult {
    try await requestConfirmation(
        conditions: .runningInNonInteractiveContext,  // 仅在非交互场景（如 Siri）时确认
        actionName: .delete,
        dialog: "Delete \(note.title)?"
    )
    deleteNote()
    return .result()
}
```

---

### 11. AppIntentError 细化

iOS 18 新增更具体的错误类型：

```swift
// perform() 中使用
throw AppIntentError.PermissionRequired("需要通讯录权限")   // 权限缺失，引导用户授权
throw AppIntentError.UserActionRequired("请先登录")         // 需要用户主动操作
throw AppIntentError.Unrecoverable("数据库损坏，无法恢复")  // 不可恢复错误
```

---

### 12. 屏幕内容提供给 Siri（NSUserActivity + appEntityIdentifier）

通过 `NSUserActivity` 将当前屏幕显示的实体告知 Siri，实现"屏幕感知"。

```swift
// 在视图出现时更新 NSUserActivity
struct NoteDetailView: View {
    let note: NoteEntity

    var body: some View {
        Text(note.title)
            .userActivity("com.example.view-note") { activity in
                activity.appEntityIdentifier = note.id   // iOS 18 新增属性
                activity.isEligibleForSearch = true
            }
    }
}
```

iOS 26 起，无需采用 assistant schema 也可将屏幕内容暴露给 Siri，只需 `Transferable` + `appEntityIdentifier`。

---

## iOS 26 新增

### 1. IntentModes / supportedModes — 执行模式控制

取代之前通过 `openAppWhenRun` 控制前台的方式，提供更细粒度的模式。

```swift
struct NavigateIntent: AppIntent {
    static let title: LocalizedStringResource = "Navigate"

    // .foreground：执行前先前台化 App
    // 不设置或留空：后台执行，通过 dialog/snippet 展示结果
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult { .result() }
}
```

---

### 2. @ComputedProperty — 实体计算属性

避免在 AppEntity 中重复存储数据，直接引用底层数据模型的计算属性。

```swift
struct NoteEntity: AppEntity {
    let note: Note  // 底层模型

    // iOS 26 前：需手动拷贝值
    // @Property var title: String  →  在初始化时赋值

    // iOS 26 新增：直接计算，无需拷贝
    @ComputedProperty
    var title: String { note.title }

    @ComputedProperty
    var wordCount: Int { note.content.split(separator: " ").count }

    // 同时支持 Spotlight 索引键
    @ComputedProperty(indexingKey: \.displayName)
    var displayTitle: String { note.title }
}
```

---

### 3. SnippetIntent — 交互式 Snippet

之前 snippet 只能是静态视图，iOS 26 起可以是可交互的独立 intent。

```swift
struct NoteSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Note Snippet"

    @Parameter var note: NoteEntity

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        return .result(view: NoteSnippetView(note: note))
    }
}

// Snippet 视图内可以继续触发其他 Intent
struct NoteSnippetView: View {
    let note: NoteEntity
    var body: some View {
        VStack {
            Text(note.title)
            Button(intent: ToggleFavoriteIntent(note: note)) {
                Label("Favorite", systemImage: "star")
            }
        }
    }
}
```

---

### 4. TargetContentProvidingIntent + onAppIntentExecution — 声明式导航

无需在 Intent 的 `perform()` 中处理导航，改为在视图层用 modifier 监听执行。

```swift
// Intent 只声明目标，不写导航逻辑
struct OpenNoteIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Note"

    @Parameter(title: "Note")
    var target: NoteEntity
    // 不需要 perform()
}

// 在视图层处理导航
struct NotesNavigationStack: View {
    @State var path: [Note] = []

    var body: some View {
        NavigationStack(path: $path) { ... }
            .onAppIntentExecution(OpenNoteIntent.self) { intent in
                path.append(intent.target.note)
            }
    }
}
```

---

### 5. IntentValueQuery — 视觉智能集成

通过 `IntentValueQuery` 将 App 实体提供给视觉智能（Visual Intelligence），让系统可以通过相机/截图识别 App 内容。

```swift
struct LandmarkIntentValueQuery: IntentValueQuery {
    typealias Value = LandmarkEntity

    func values(matching input: String) async throws -> [LandmarkEntity] {
        // 根据视觉识别结果匹配实体
        modelData.landmarks.filter { $0.name.localizedCaseInsensitiveContains(input) }
            .map(LandmarkEntity.init)
    }
}

// 在 AppEntity 上关联
struct LandmarkEntity: AppEntity {
    static let defaultQuery = LandmarkEntityQuery()
    static let intentValueQuery = LandmarkIntentValueQuery()
    // ...
}
```

---

### 6. AppIntentsPackage — Swift Package / Static Library 支持

iOS 26 起，App Intents 类型可以定义在 Swift Package 中，跨 Target 共享时需注册 Package。

```swift
// Swift Package 中定义
public struct SharedIntentsPackage: AppIntentsPackage {}

// App Target
struct AppPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [SharedIntentsPackage.self]
    }
}

// Extension Target（同样引用）
struct ExtensionPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [SharedIntentsPackage.self]
    }
}
```

---

### 7. macOS Spotlight 直接调用 Intent（新行为）

当 Intent 的 `parameterSummary` 包含所有必填参数时，macOS Spotlight 可以直接内联填写参数并执行，无需跳转到 Shortcuts。

```swift
struct SearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Notes"

    // 必须：包含所有必填参数，macOS Spotlight 才能内联调用
    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query) in Notes")
    }

    @Parameter(title: "Query") var query: String

    func perform() async throws -> some IntentResult { .result() }
}
```

---

## ⚠️ Important Notes

- **title 等元数据必须编译期常量**：build time 处理，调用函数或计算属性会编译报错
- **struct 重命名 = 破坏性变更**：Intent 的 struct 名是唯一 ID，重命名会使所有用户已创建的 Shortcut 失效
- **`@Dependency` 注册时机**：必须在 App 生命周期最早期（`App.init()`）注册，Extension 运行时依赖未就绪会崩溃
- **`updateAppShortcutParameters()`**：收藏/关注实体列表变化后调用，否则参数化 App Shortcut 不更新
- **`IndexedEntity` 需主动捐赠**：采用协议后还需调用 `EntityIndexer.shared.index()` 才会出现在 Spotlight
- **`ControlConfigurationIntent` 需要 Widget Extension**：控件在独立进程运行，不能直接访问主 App 的内存
- **`CameraCaptureIntent` 需要单独的 Extension Target**：Locked Camera Capture Extension，不是在主 App 中实现
- **`TargetContentProvidingIntent` 不写 `perform()`**：导航完全由 `onAppIntentExecution` 接管，写了也不会被调用
