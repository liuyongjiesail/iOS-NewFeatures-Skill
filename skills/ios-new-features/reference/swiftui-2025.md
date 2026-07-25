# SwiftUI Updates (June 2025 / iOS 26)

> **适用范围：** iOS 26+ / iPadOS 26+ / macOS 26+ / visionOS 26+（部分）
> **来源：** [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) · June 2025
> **框架：** SwiftUI / WebKit / Accessibility
>
> 本文档覆盖 **June 2025** 这一波 SwiftUI 更新：Liquid Glass、Tab / Scroll 边缘效果、SwiftUI `WebView`、多 item 拖拽、`@Animatable` 宏、AttributedString 文本编辑、Assistive Access、HDR、UIKit/AppKit scene 托管，以及 immersive / volumetric 布局增强。

---

## 目录

1. [功能概览](#功能概览)
2. [Liquid Glass](#liquid-glass)
3. [Scroll / Tab / 背景效果](#scroll--tab--背景效果)
4. [WebView + WebPage](#webview--webpage)
5. [多 item 拖拽](#多-item-拖拽)
6. [动画与控件](#动画与控件)
7. [AttributedString 文本编辑](#attributedstring-文本编辑)
8. [Accessibility / HDR](#accessibility--hdr)
9. [UIKit / AppKit 集成](#uikit--appkit-集成)
10. [Immersive Spaces（visionOS）](#immersive-spacesvisionos)
11. [⚠️ Important Notes](#️-important-notes)

---

## 功能概览

| 主题 | 关键 API |
|------|----------|
| Liquid Glass | `glassEffect(_:in:)` · `.buttonStyle(.glass)` · `ToolbarSpacer` |
| Scroll 边缘 | `scrollEdgeEffectStyle(_:for:)` |
| 背景延伸 | `backgroundExtensionEffect()` |
| Tab 行为 | `tabBarMinimizeBehavior` · `TabRole.search` · `TabViewBottomAccessoryPlacement` |
| Web 浏览 | `WebView` + `WebPage`（WebKit） |
| 拖拽 | `draggable(containerItemID:)` · `dragContainer(for:itemID:in:_:)` |
| 动画 | `@Animatable` 宏 |
| 控件 | `Slider` 刻度（`step`）、`windowResizeAnchor` |
| 富文本 | `TextEditor` + `AttributedString` · `AttributedTextSelection` · `FindContext` |
| 辅助功能 | `AssistiveAccess` |
| HDR | `Color.ResolvedHDR` |
| 跨框架 Scene | `UIHostingSceneDelegate` · `NSHostingSceneRepresentation` · `NSGestureRecognizerRepresentable` |
| 空间交互 | `manipulable` · `SurfaceSnappingInfo` · `RemoteImmersiveSpace` · `SpatialContainer` |

---

## Liquid Glass

为视图与按钮应用系统级 Liquid Glass 材质；Toolbar 中可用 `ToolbarSpacer` 在玻璃项之间制造视觉分隔。

```swift
struct GlassCard: View {
    var body: some View {
        VStack {
            Text("Now Playing")
            Button("Play") { }
                .buttonStyle(.glass)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

ContentView()
    .toolbar {
        ToolbarItem(placement: .primaryAction) {
            Button("Edit", action: edit)
        }
        ToolbarSpacer(.fixed)
        ToolbarItem(placement: .primaryAction) {
            Button("Share", action: share)
        }
    }
```

| API | 作用 |
|-----|------|
| `.glassEffect(_:in:)` | 给任意视图套 Liquid Glass |
| `PrimitiveButtonStyle.glass` | Button 的玻璃样式 |
| `ToolbarSpacer` | 玻璃 Toolbar 项之间的视觉间隔 |

---

## Scroll / Tab / 背景效果

### Scroll 边缘效果

```swift
ScrollView {
    // content
}
.scrollEdgeEffectStyle(.soft, for: .top)
```

### 背景延伸

`backgroundExtensionEffect()` 会复制、镜像并模糊边缘附近的视图，填入可用 safe area。

```swift
HeroImage()
    .backgroundExtensionEffect()
```

### Tab Bar 收起与 Search Tab

```swift
TabView {
    Tab("Home", systemImage: "house", value: .home) {
        HomeView()
    }
    Tab("Library", systemImage: "books.vertical", value: .library) {
        LibraryView()
    }
    // search 角色：进入搜索页，搜索框可取代 tab bar
    Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
        SearchView()
    }
}
.tabBarMinimizeBehavior(.onScrollDown)
```

底部 accessory 可根据放置位置调整内容：

```swift
.tabViewBottomAccessory {
    // 用 TabViewBottomAccessoryPlacement 判断当前放置位置
    PlayerBar()
}
```

---

## WebView + WebPage

SwiftUI 原生连接 WebKit：`WebView` 负责呈现，`WebPage` 负责控制浏览体验（导航、状态等）。

```swift
import WebKit
import SwiftUI

struct BrowserView: View {
    @State private var page = WebPage()

    var body: some View {
        WebView(page)
            .onAppear {
                page.load(URLRequest(url: URL(string: "https://developer.apple.com")!))
            }
    }
}
```

---

## 多 item 拖拽

一次拖多个 item：子视图标 `draggable(containerItemID:containerNamespace:)`，父视图用 `dragContainer` 作为容器。

```swift
struct PhotoGrid: View {
    let photos: [Photo]
    let namespace = Namespace().wrappedValue

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(photos) { photo in
                PhotoCell(photo: photo)
                    .draggable(containerItemID: photo.id, containerNamespace: namespace)
            }
        }
        .dragContainer(for: Photo.self, itemID: \.id, in: namespace) { ids in
            // 返回被拖的 Transferable / 载荷
            photos.filter { ids.contains($0.id) }
        }
    }
}
```

---

## 动画与控件

### @Animatable 宏

让 SwiftUI 自动合成自定义可动画数据属性，减少手写 `animatableData`。

```swift
@Animatable
struct WaveShape: Shape {
    var amplitude: Double
    var phase: Double

    func path(in rect: CGRect) -> Path {
        // 用 amplitude / phase 画路径
        Path()
    }
}
```

### Slider 刻度

带 `step` 初始化时自动显示 tick marks：

```swift
Slider(value: $volume, in: 0...10, step: 1)
```

### 窗口缩放锚点

窗口需要 resize 时指定锚点：

```swift
ContentView()
    .windowResizeAnchor(.topLeading)
```

---

## AttributedString 文本编辑

`TextEditor` 支持 `AttributedString`；可用选择、格式化定义与查找导航。

```swift
struct RichEditor: View {
    @State private var text = AttributedString("Hello")
    @State private var selection = AttributedTextSelection()

    var body: some View {
        TextEditor(text: $text, selection: $selection)
        // AttributedTextFormattingDefinition 定义特定上下文允许的样式
        // FindContext 用于在支持编辑的视图中接入查找导航
    }
}
```

| API | 作用 |
|-----|------|
| `TextEditor` + `AttributedString` | 富文本编辑 |
| `AttributedTextSelection` | 富文本选区 |
| `AttributedTextFormattingDefinition` | 限定可应用样式 |
| `FindContext` | 查找导航 |

---

## Accessibility / HDR

### Assistive Access

在 iOS / iPadOS scene 中支持辅助使用（Assistive Access）：

```swift
// 场景侧接入 AssistiveAccess，按辅助使用模式裁剪 / 简化 UI
```

### HDR 颜色

`Color.ResolvedHDR` 表示带 HDR headroom 的可显示 RGBA：

```swift
let hdr: Color.ResolvedHDR = ...
// 用于需要保留高动态范围信息的颜色解析
```

---

## UIKit / AppKit 集成

| API | 平台 | 作用 |
|-----|------|------|
| `UIHostingSceneDelegate` | UIKit | 在 UIKit 中托管并呈现 SwiftUI Scene |
| `NSHostingSceneRepresentation` | AppKit | 在 AppKit 中托管 SwiftUI Scene |
| `NSGestureRecognizerRepresentable` | AppKit | 把 AppKit 手势识别器接到 SwiftUI 视图 |

```swift
// UIKit：用 UIHostingSceneDelegate 呈现 SwiftUI Scene
// AppKit：NSHostingSceneRepresentation + NSGestureRecognizerRepresentable
```

---

## Immersive Spaces（visionOS）

| API | 作用 |
|-----|------|
| `.manipulable(...)` | 用手势操作视图（平移 / 旋转 / 缩放等） |
| `SurfaceSnappingInfo` | Volume 吸附到水平面，Window 吸附到竖直面 |
| `RemoteImmersiveSpace` | 从 Mac App 把立体内容渲染到 Apple Vision Pro |
| `SpatialContainer` | 在 3D 中对齐重叠内容的布局容器 |
| `aspectRatio3D` / `rotation3DLayout` / `depthAlignment` | 基于深度的 volumetric 布局修饰符 |

```swift
ModelView()
    .manipulable(
        coordinateSpace: .local,
        operations: [.translate, .rotate, .scale],
        inertia: true,
        isEnabled: true
    ) { _ in }

SpatialContainer {
    FrontLayer()
    BackLayer()
}
.depthAlignment(.center)
```

---

## ⚠️ Important Notes

- **Liquid Glass** 是系统材质；过度叠加会显得嘈杂，优先用在可交互表面与分组容器。
- **`TabRole.search`** 会改变 tab bar 与搜索框的布局关系，确保搜索页体验完整。
- **`WebView` / `WebPage`** 在 WebKit 中；注意导航、鉴权与内容安全策略仍由 `WebPage` 侧控制。
- **多 item 拖拽** 需要一致的 `containerNamespace` 与 `itemID`，否则容器无法聚合载荷。
- **`@Animatable`** 适合 Shape / 自定义几何属性；复杂状态仍用显式动画与 `Transaction`。
- Immersive / volumetric API 主要面向 **visionOS**；在 iPhone 上不可用或无意义。
- June 2026 的 `ContentBuilder`、任意容器 `reorderable` / Document URL API 等见 [swiftui-2026.md](swiftui-2026.md)。

---

## 参考资料

- [SwiftUI updates — June 2025](https://developer.apple.com/documentation/updates/swiftui)
- [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [WebView](https://developer.apple.com/documentation/webkit/webview)
- [Assistive Access](https://developer.apple.com/documentation/swiftui/assistiveaccess)
