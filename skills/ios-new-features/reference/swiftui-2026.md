# SwiftUI Updates (June 2026 / Xcode 27)

> **适用范围：** iOS 27+ / iPadOS 27+ / macOS 27+ / watchOS（部分）/ Xcode 27+
> **来源：** [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) · [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/)
> **框架：** SwiftUI
>
> 本文档覆盖 **June 2026** 这一波 SwiftUI 更新：统一 `ContentBuilder`、容器拖拽重排与滑动操作、Toolbar 精细控制、URL 文档 API、`AsyncImage` 缓存、`@State` 宏行为、Alert/Dialog item 绑定，以及手势输入源。

---

## 目录

1. [功能概览](#功能概览)
2. [ContentBuilder 与编译性能](#contentbuilder-与编译性能)
3. [@State 宏：类属性只初始化一次](#state-宏类属性只初始化一次)
4. [容器拖拽重排](#容器拖拽重排)
5. [任意容器的 swipeActions](#任意容器的-swipeactions)
6. [Toolbar 精细控制](#toolbar-精细控制)
7. [Document API（Readable / Writable）](#document-apireadable--writable)
8. [AsyncImage 缓存](#asyncimage-缓存)
9. [Alert / ConfirmationDialog item 绑定](#alert--confirmationdialog-item-绑定)
10. [其他更新](#其他更新)
11. [⚠️ Important Notes](#️-important-notes)

---

## 功能概览

| 主题 | 关键 API |
|------|----------|
| 统一 Result Builder | `@ContentBuilder` |
| `@State` 宏 | 类类型懒初始化，视图生命周期内只存一次 |
| 任意容器重排 | `.reorderable()` + `.reorderContainer(for:isEnabled:move:)` |
| 任意容器滑动操作 | `.swipeActions(...)` + `.swipeActionsContainer()` |
| Toolbar 优先级 / 溢出 / 钉住 | `visibilityPriority` / `ToolbarOverflowMenu` / `topBarPinnedTrailing` / `toolbarMinimizeBehavior` |
| URL 文档读写 | `ReadableDocument` / `WritableDocument` / `DocumentReader` / `DocumentWriter` |
| AsyncImage 缓存 | 默认尊重 HTTP cache；`asyncImageURLSession` / `URLRequest` 初始化 |
| 呈现绑定 | `alert(_:item:)` / `alert(error:)` / `confirmationDialog(_:item:)` |
| Sheet 过渡 | `NavigationTransition.crossFade` |
| Tab | `TabRole.prominent` |
| 手势输入源 | `GestureInputKinds` |

---

## ContentBuilder 与编译性能

`ContentBuilder` 是统一的 Result Builder，用于替代类型特定的 `ToolbarContentBuilder`、`CommandsBuilder` 等。内部改为更偏 type-agnostic 的条件一致性，减轻编译器过载解析，**Xcode 27 下大型 SwiftUI 层级编译更快**。

```swift
// 闭包参数、计算属性、协议要求都可标 @ContentBuilder
func contextMenu(
    @ContentBuilder menuItems: () -> some View
) -> some View { ... }

@ContentBuilder
var toolbarItems: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
        Button("Save", action: save)
    }
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", action: cancel)
    }
}
```

> `ContentBuilder` 作为 `ViewBuilder` 的统一暴露面；用 Xcode 27+ 构建即可受益。旧专用 builder 仍可用，新代码优先写 `@ContentBuilder`。

---

## @State 宏：类属性只初始化一次

Xcode 27+ 中 `@State` 通过宏创建状态。当属性是**类**时，只在视图生命周期内初始化并存储一次（懒初始化），避免每次 body 求值都重新构造。

```swift
@Observable
final class FormModel {
    var name = ""
    var notes = ""
}

struct EditorView: View {
    // 类实例：视图存活期间只创建一次
    @State private var model = FormModel()

    var body: some View {
        TextField("Name", text: $model.name)
    }
}
```

适用于 `App` / `Scene` / `View` 中的 `@State`。

---

## 容器拖拽重排

不再局限于 `List`：List、Stack、Grid、自定义布局都可用同一套 API。watchOS 首次支持重排。

```swift
struct PlaylistView: View {
    @State private var songs: [Song] = [...]

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(songs) { song in
                    SongRow(song: song)
                        .reorderable()
                }
            }
        }
        .reorderContainer(for: Song.self, isEnabled: true) { from, to in
            songs.move(fromOffsets: from, toOffset: to)
        }
    }
}
```

**要点：**
- 子项标 `.reorderable()`
- 父容器用 `.reorderContainer(for:isEnabled:move:)` 更新数据模型
- SwiftUI 负责手势、动画与交互体验

---

## 任意容器的 swipeActions

`swipeActions` 可挂到 ScrollView / Stack / Grid / 自定义布局中的视图；父级加 `.swipeActionsContainer()` 启用。

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        archive(item)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
        }
    }
}
.swipeActionsContainer()
```

---

## Toolbar 精细控制

空间变窄时，精确控制哪些项保留、哪些进溢出菜单、哪些永远钉住。

```swift
ContentView()
    .toolbar {
        // 高优先级：空间不够时尽量保留
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Edit", action: edit)
            Button("Share", action: share)
        }
        .visibilityPriority(.high)

        // 次要操作：直接进溢出菜单
        ToolbarOverflowMenu {
            Button("Archive", action: archive)
            Button("Delete", role: .destructive, action: delete)
        }

        // 钉在顶部栏 trailing，其他项移动时它不动
        ToolbarItem(placement: .topBarPinnedTrailing) {
            Button("Done", action: done)
        }
    }
    // 滚动时自动收起导航栏 / toolbar
    .toolbarMinimizeBehavior(.onScrollDown)
```

| API | 作用 |
|-----|------|
| `visibilityPriority(_:)` | 优先保留重要项，低优先级先进入溢出 |
| `ToolbarOverflowMenu` | 次要操作永久放溢出菜单 |
| `topBarPinnedTrailing` | 钉在顶部栏 trailing |
| `toolbarMinimizeBehavior(_:for:)` | 控制滚动时 toolbar 收起行为 |

---

## Document API（Readable / Writable）

基于文件 URL 的文档模型：适合大文件、异步增量读写，并可结合 Foundation Subprogress 报告进度。

```swift
// 只读
struct ReportDocument: ReadableDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    init(configuration: ReadConfiguration) throws {
        // 从 configuration 读取 URL / 内容
    }
}

// 可写：再 conform WritableDocument
struct NoteDocument: ReadableDocument, WritableDocument {
    var text: String

    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }

    init(configuration: ReadConfiguration) throws { ... }

    func write(to configuration: inout WriteConfiguration) throws {
        // 写回文件
    }
}
```

相关类型：

| 类型 | 用途 |
|------|------|
| `ReadableDocument` / `WritableDocument` | URL 文档读写协议 |
| `DocumentReader` / `DocumentWriter` | 自定义读写逻辑 |
| `FileWrapperDocumentReader` / `FileWrapperDocumentWriter` | 基于 FileWrapper 的简化实现 |
| `URLDocumentConfiguration` | 文件 URL、修改日期、额外文件访问协调 |
| `fileExporter(isPresented:document:...)` | 导出 `WritableDocument` |

---

## AsyncImage 缓存

默认遵守服务器 HTTP cache headers，重复出现不必重新下载。需要更多控制时用 `URLRequest` 初始化或自定义 `URLSession` / `URLCache`。

```swift
// 默认：已启用标准 HTTP 缓存，通常无需改代码
AsyncImage(url: imageURL)

// 自定义请求（缓存策略、headers 等）
AsyncImage(request: URLRequest(url: imageURL, cachePolicy: .returnCacheDataElseLoad)) { phase in
    switch phase {
    case .success(let image): image.resizable()
    case .failure: Image(systemName: "photo")
    case .empty: ProgressView()
    @unknown default: EmptyView()
    }
}

// 为子树指定带自定义 URLCache 的 URLSession
ContentView()
    .asyncImageURLSession(cachingSession)
```

也可用：

- `AsyncImage(request:scale:)`
- `AsyncImage(request:scale:content:placeholder:)`
- `AsyncImage(request:scale:transaction:content:)`

---

## Alert / ConfirmationDialog item 绑定

与 sheet 相同的 item / error 绑定模式：绑定非 `nil` 时自动呈现。

```swift
struct DetailView: View {
    @State private var selected: Item?
    @State private var saveError: Error?

    var body: some View {
        List(items) { item in
            Button(item.title) { selected = item }
        }
        .alert("Item", item: $selected) { item in
            Button("OK") { selected = nil }
            Button("Edit") { edit(item) }
        } message: { item in
            Text(item.detail)
        }
        .alert(error: $saveError) { _ in
            Button("OK") { saveError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .confirmationDialog("Actions", item: $selected, titleVisibility: .visible) { item in
            Button("Duplicate") { duplicate(item) }
            Button("Delete", role: .destructive) { delete(item) }
        }
    }
}
```

新增重载包括：

- `alert(_:item:actions:)` / `alert(_:item:actions:message:)`
- `alert(error:actions:)` / `alert(error:actions:message:)`
- `confirmationDialog(_:item:titleVisibility:actions:)` / `...message:`

---

## 其他更新

### Sheet 淡入过渡

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .navigationTransition(.crossFade)
}
```

### Tab：prominent 角色

```swift
TabView {
    Tab("Home", systemImage: "house", value: .home) { HomeView() }
    Tab("Search", systemImage: "magnifyingglass", value: .search) { SearchView() }
    Tab("Compose", systemImage: "plus", value: .compose, role: .prominent) {
        ComposeView()
    }
}
```

`TabRole.prominent` 把该 tab 放到 tab bar 独立的 trailing 位置。

### 手势输入源

`DragGesture`、`LongPressGesture`、`MagnifyGesture`、`RotateGesture`、`TapGesture` 等支持指定输入源（直接/间接触摸、Pencil、指针）。详见 `GestureInputKinds`。

```swift
DragGesture(/* input kinds via new initializers */)
```

---

## ⚠️ Important Notes

- **用 Xcode 27+ 构建**才能获得 `@State` 宏行为与 `ContentBuilder` 编译收益。
- **重排 / swipeActions**：子项加修饰符后，父容器必须配套 `.reorderContainer` / `.swipeActionsContainer`，否则无效。
- **AsyncImage**：默认已缓存；盲目加自定义 `URLSession` 可能反而绕过系统优化，只在需要自定义 cache 策略时再配。
- **Document API**：大文件优先 `ReadableDocument` / `WritableDocument`（URL + 异步增量），不要把整文件读进内存。
- **Toolbar**：`visibilityPriority` + `ToolbarOverflowMenu` + `topBarPinnedTrailing` 组合使用，避免空间缩小时主操作被挤掉。
- June 2025 的 Liquid Glass（`glassEffect` 等）不在本文范围；见既有 Liquid Glass / graphics 相关文档。

---

## 参考资料

- [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui)
- [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/)
- [ContentBuilder](https://developer.apple.com/documentation/swiftui/contentbuilder)
- [AsyncImage](https://developer.apple.com/documentation/swiftui/asyncimage)
- [DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup)
