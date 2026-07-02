# SwiftUI 高级图形效果 — Metal Shader 与创意流水线

> **适用范围：** iOS 17+ (Shader 基础) / iOS 18+ (增强)  
> **来源：** WWDC 2024 Session 10151, WWDC 2026 Session 322  
> 
> 本文档涵盖 SwiftUI 的高级图形编程技术，包括 Metal Shader 三种效果、域变形技术、TimelineView 驱动动画、对齐参考线高级用法，以及如何通过"创意流水线"思维组合这些技术。

---

## 目录

1. [核心概念](#核心概念)
2. [Shader 效果基础](#shader-效果基础)
3. [Metal Shader 编程](#metal-shader-编程)
4. [域变形技术](#域变形技术)
5. [时间驱动动画](#时间驱动动画)
6. [高级布局技巧](#高级布局技巧)
7. [创意流水线思维](#创意流水线思维)
8. [完整示例](#完整示例)
9. [性能优化](#性能优化)

---

## 核心概念

### 什么是高级图形效果？

SwiftUI 的高级图形效果不是指复杂度，而是指**组合方式**：

```
简单构建块 + 创意组合 = 高级效果
```

**核心思想：流水线（Pipeline）**

```
数据 → 转换1 → 转换2 → 转换3 → 最终视图
```

每个阶段：
- 接收输入
- 进行转换
- 传递给下一阶段

**SwiftUI 中的流水线示例：**

```swift
Image("Cover")           // 原始数据
    .blur(radius: 30)    // 转换1：模糊
    .layerEffect(...)    // 转换2：Shader 扭曲
    .overlay(...)        // 转换3：叠加内容
```

---

## Shader 效果基础

### GPU 与 Shader 的关系

**渲染流程：**

1. **矢量图** → GPU 光栅化 → **像素网格**
2. **Shader 程序**在 GPU 上运行，决定每个像素的颜色
3. **并行执行**：每个像素独立计算，互不感知

### 三种 Shader 效果类型

| 类型 | 用途 | 输入 | 输出 | 典型场景 |
|------|------|------|------|---------|
| **colorEffect** | 颜色转换 | 位置 + 原颜色 | 新颜色 | 黑白滤镜、色调调整 |
| **distortionEffect** | 几何变换 | 当前位置 | 采样位置 | 扭曲、波纹、切变 |
| **layerEffect** | 图层采样 | 位置 + 整个图层 | 新颜色 | 模糊、发光、复杂变形 |

---


### colorEffect - 颜色转换

**工作原理：** 将每个像素的颜色转换为新颜色

**Metal 签名：**

```metal
[[stitchable]] half4 myColorEffect(
    float2 position,        // 必需：当前像素位置
    half4 color            // 必需：原始像素颜色
    // 可选：自定义参数...
) {
    return color;          // 返回新颜色
}
```

**SwiftUI 使用：**

```swift
Image("photo")
    .colorEffect(ShaderLibrary.grayscale())
```

**示例：黑白滤镜**

```swift
// SwiftUI
Image("photo")
    .colorEffect(ShaderLibrary.grayscale())

// Metal
[[stitchable]] half4 grayscale(float2 position, half4 color) {
    half gray = (color.r + color.g + color.b) / 3.0;
    return half4(gray, gray, gray, color.a);
}
```

---

### distortionEffect - 几何变换

**工作原理：** 告诉 SwiftUI 从哪个位置采样颜色

**Metal 签名：**

```metal
[[stitchable]] float2 myDistortion(
    float2 position        // 必需：当前位置
    // 可选：自定义参数...
) {
    return position;       // 返回采样位置
}
```

**SwiftUI 使用：**

```swift
Image("photo")
    .distortionEffect(
        ShaderLibrary.wave(.float(time)),
        maxSampleOffset: CGSize(width: 10, height: 10)
    )
```

**示例：波纹效果**

```swift
// SwiftUI
Image("photo")
    .distortionEffect(
        ShaderLibrary.wave(.float(time)),
        maxSampleOffset: CGSize(width: 10, height: 10)
    )

// Metal
[[stitchable]] float2 wave(float2 position, float time) {
    float offset = sin(position.y * 0.1 + time) * 10.0;
    return position + float2(offset, 0);
}
```

**注意：** `maxSampleOffset` 必须指定，告诉 SwiftUI 需要预留多少边界空间。

---

### layerEffect - 图层采样（最灵活）

**工作原理：** 可以从整个图层的任意位置采样

**Metal 签名：**

```metal
[[stitchable]] half4 myLayerEffect(
    float2 position,           // 必需：当前位置
    SwiftUI::Layer layer       // 必需：整个图层
    // 可选：自定义参数...
) {
    return layer.sample(position);  // 从任意位置采样
}
```

**SwiftUI 使用：**

```swift
Image("photo")
    .layerEffect(
        ShaderLibrary.blur(.float(radius)),
        maxSampleOffset: CGSize(width: radius, height: radius)
    )
```

**示例：简单模糊**

```swift
// SwiftUI
Image("photo")
    .layerEffect(
        ShaderLibrary.simpleBlur(.float(5)),
        maxSampleOffset: CGSize(width: 5, height: 5)
    )

// Metal
[[stitchable]] half4 simpleBlur(
    float2 position, 
    SwiftUI::Layer layer,
    float radius
) {
    half4 color = half4(0);
    float count = 0;
    
    // 采样周围像素
    for (float x = -radius; x <= radius; x += 1) {
        for (float y = -radius; y <= radius; y += 1) {
            color += layer.sample(position + float2(x, y));
            count += 1;
        }
    }
    
    return color / count;
}
```

---

## Metal Shader 编程

### 基础语法

**必需标记：**

```metal
[[stitchable]]  // 告诉编译器这是 SwiftUI shader
```

**数据类型映射：**

| Swift | Metal | 说明 |
|-------|-------|------|
| `Float` | `float` | 单精度浮点 |
| `CGFloat` | `float` | 单精度浮点 |
| `CGPoint` | `float2` | 二维向量 |
| `CGSize` | `float2` | 二维向量 |
| `Color` | `half4` | RGBA 颜色 |
| `Image` | `texture2d<half>` | 2D 纹理 |

**从 SwiftUI 传递参数：**

```swift
// SwiftUI
.layerEffect(
    ShaderLibrary.myShader(
        .float(3.14),
        .float2(CGPoint(x: 10, y: 20)),
        .image(Image("noise"))
    ),
    maxSampleOffset: .zero
)

// Metal
[[stitchable]] half4 myShader(
    float2 position,
    SwiftUI::Layer layer,
    float myFloat,              // 对应 .float(3.14)
    float2 myVector,           // 对应 .float2(...)
    texture2d<half> myTexture  // 对应 .image(...)
) {
    // ...
}
```

---

### 纹理采样

**创建采样器：**

```metal
constexpr sampler s(
    address::repeat,      // 重复模式：repeat/clamp_to_edge/mirrored_repeat
    filter::linear       // 过滤模式：linear/nearest
);
```

**采样纹理：**

```metal
// 使用 UV 坐标 (0-1 范围)
float2 uv = position / size;
half4 color = myTexture.sample(s, uv);
```

**常用采样模式：**

```metal
// 1. 重复平铺
constexpr sampler repeat_sampler(address::repeat, filter::linear);
half4 c1 = tex.sample(repeat_sampler, uv);

// 2. 边缘夹紧
constexpr sampler clamp_sampler(address::clamp_to_edge, filter::linear);
half4 c2 = tex.sample(clamp_sampler, uv);

// 3. 最近邻（像素艺术风格）
constexpr sampler pixel_sampler(address::repeat, filter::nearest);
half4 c3 = tex.sample(pixel_sampler, uv);
```

---

## 域变形技术

### 什么是域变形？

**Domain Warping** 是一种通过多层噪声采样创造自然流动效果的技术。

**核心思想：**

```
1. 第一次采样噪声 → 得到偏移量 A
2. 用偏移量 A 移动采样位置
3. 第二次采样噪声 → 得到偏移量 B
4. 用偏移量 B 采样原始图像
```

### 实现步骤

**步骤 1：准备噪声纹理**

使用 Perlin Noise 或 Simplex Noise 预生成纹理图像。

**步骤 2：单层噪声（简单扭曲）**

```swift
// SwiftUI
GeometryReader { proxy in
    Image("cover")
        .blur(radius: 30)
        .layerEffect(
            ShaderLibrary.simpleWarp(
                .float2(proxy.size),
                .image(Image("NoiseTexture"))
            ),
            maxSampleOffset: .zero
        )
}
```

```metal
// Metal
[[stitchable]] half4 simpleWarp(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    texture2d<half> noiseTex
) {
    constexpr sampler s(address::repeat, filter::linear);
    
    // 计算 UV 坐标
    float2 uv = position / size;
    
    // 采样噪声
    half4 noise = noiseTex.sample(s, uv);
    
    // 将噪声值 (0-1) 转换为偏移量 (-0.5 到 0.5)
    float2 offset = (float2(noise.r, noise.g) - 0.5) * 200.0;
    
    // 从偏移后的位置采样
    return layer.sample(position + offset);
}
```

**步骤 3：域变形（双层采样）**

```metal
[[stitchable]] half4 domainWarp(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    texture2d<half> noiseTex
) {
    constexpr sampler s(address::repeat, filter::linear);
    float2 uv = position / size;
    
    // 第一次采样：得到初始偏移
    half4 n1 = noiseTex.sample(s, uv);
    float2 q = float2(n1.r, n1.g);
    
    // 第二次采样：在被偏移的位置再次采样
    half4 n2 = noiseTex.sample(s, uv + q);
    
    // 使用第二次采样的结果作为最终偏移
    float2 offset = (float2(n2.r, n2.g) - 0.5) * 200.0;
    
    return layer.sample(position + offset);
}
```

**效果对比：**

| 方法 | 效果 | 适用场景 |
|------|------|---------|
| 单层噪声 | 轻微扭曲 | 水波纹、热浪 |
| 域变形（双层） | 自然流动的色块 | 云彩、烟雾、岩浆 |
| 三层+ | 复杂有机纹理 | 大理石、木纹 |

---

## 时间驱动动画

### Shader 的无状态特性

**关键概念：**

- Shader 函数是**无状态的**
- 每帧重新计算，不记忆上一帧
- 输出完全取决于输入参数

**因此，要动画化 shader：**

```
需要传入一个随时间变化的值
```

### TimelineView 基础

**TimelineView** 是 SwiftUI 的时间驱动容器。

```swift
TimelineView(.animation) { timeline in
    // timeline.date 会每帧更新
    MyView(timestamp: timeline.date)
}
```

**调度模式：**

| 模式 | 说明 |
|------|------|
| `.animation` | 每帧触发（~60 FPS） |
| `.everySecond` | 每秒触发一次 |
| `.periodic(from:by:)` | 自定义间隔 |
| `.explicit([Date])` | 指定具体时间点 |

### 结合 Shader 动画

```swift
@State private var startDate = Date.now

TimelineView(.animation) { timeline in
    let elapsed = timeline.date.timeIntervalSince(startDate)
    
    GeometryReader { proxy in
        CoverArtView()
            .layerEffect(
                ShaderLibrary.animatedWarp(
                    .float2(proxy.size),
                    .image(Image("NoiseTexture")),
                    .float(elapsed)  // 时间作为参数
                ),
                maxSampleOffset: .zero
            )
    }
}
```

```metal
[[stitchable]] half4 animatedWarp(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    texture2d<half> noiseTex,
    float time  // 接收时间参数
) {
    constexpr sampler s(address::repeat, filter::linear);
    
    // 在采样时加上时间偏移
    float2 uv = position / size + float2(time * 0.1, 0);
    
    half4 n1 = noiseTex.sample(s, uv);
    float2 q = float2(n1.r, n1.g);
    
    half4 n2 = noiseTex.sample(s, uv + q);
    float2 offset = (float2(n2.r, n2.g) - 0.5) * 200.0;
    
    return layer.sample(position + offset);
}
```

**动画速度控制：**

```metal
// 慢速流动
float2 uv = position / size + float2(time * 0.05, 0);

// 快速流动
float2 uv = position / size + float2(time * 0.5, 0);

// 双向流动
float2 uv = position / size + float2(time * 0.1, time * 0.15);
```

---


## 高级布局技巧

### 对齐参考线（Alignment Guides）

**核心概念：**

对齐是布局系统用来定位视图的**参考点**，由两个轴定义。

**想象成一根针：**

```
容器 ●━━━━━━━━━━━● 子视图
     ↑           ↑
   对齐点      对齐点
```

针穿过两个视图的对齐点，将它们固定在一起。

### 默认对齐行为

```swift
Text("Hello")
    .overlay {
        Text("World")
    }
```

**默认行为：**
- overlay 使用 `.center` 对齐
- 针穿过两个视图的中心点
- 它们居中重叠

### 改变对齐方式

```swift
Text("Hello")
    .overlay(alignment: .bottomLeading) {
        Text("World")
    }
```

**现在：**
- 针穿过两个视图的左下角
- 子视图的左下角与容器的左下角对齐

### 自定义对齐点

**问题：** 如何让子视图的**顶边**接触容器的**底边**？

**解决方案：** 覆盖对齐参考线

```swift
Text("Hello")
    .overlay(alignment: .bottomLeading) {
        Text("World")
            .alignmentGuide(.bottom) { d in
                d[.top]  // 当被问及 bottom 时，返回 top
            }
    }
```

**工作原理：**

1. 布局系统请求子视图的 `.bottom` 对齐点
2. 子视图返回其 `.top` 位置
3. 针穿过容器的底部和子视图的顶部
4. 结果：子视图附着在容器底部

**代码解释：**

```swift
.alignmentGuide(.bottom) { dimensions in
    dimensions[.top]  // 使用 ViewDimensions 查询其他对齐点
}
```

### 使用 ViewDimensions

```swift
Text("Timestamp")
    .alignmentGuide(.bottom) { d in
        d[.top]          // 查询顶部位置
    }
    .alignmentGuide(.leading) { d in
        d.width / 2      // 水平居中
    }
```

**ViewDimensions 属性：**

- `d.width` - 视图宽度
- `d.height` - 视图高度
- `d[.top]` - 顶部对齐点
- `d[.bottom]` - 底部对齐点
- `d[.leading]` - 前导边对齐点
- `d[.trailing]` - 尾随边对齐点
- `d[.center]` - 中心对齐点

### 实际应用：浮动时间戳

```swift
Text(line.text)
    .overlay(alignment: .bottomLeading) {
        Text(line.formattedTimestamp)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            .alignmentGuide(.bottom) { $0[.top] }  // 附着在底边
            .opacity(isCurrent ? 1 : 0)            // 仅当前行可见
    }
```

---

## 创意流水线思维

### 流水线模型

**核心思想：** 每个 SwiftUI modifier 和 API 都是流水线中的一个阶段。

```
原始数据 → 转换1 → 转换2 → 转换3 → 最终视图
```

**特点：**

- 每个阶段独立工作
- 输出成为下一阶段的输入
- 可以串联、分支、合并

### 播客 App 示例

**需求：** 类似 Apple Music 实时歌词的播客文字稿视图

**拆解：**

```
1. 封面图片 → blur → shader 扭曲 → 时间动画
2. 文字稿数据 → 滚动视图 → 时间同步 → 高亮当前行
3. 时间戳 → overlay → 对齐参考线 → 浮动附件
```

**流水线连接：**

```swift
ZStack {
    // 流水线 1：动态背景
    TimelineView(.animation) { timeline in
        let elapsed = timeline.date.timeIntervalSince(startDate)
        
        Image("Cover")
            .blur(radius: 30)
            .layerEffect(
                ShaderLibrary.domainWarp(
                    .float2(size),
                    .image(Image("Noise")),
                    .float(elapsed)
                ),
                maxSampleOffset: .zero
            )
    }
    
    // 流水线 2：时间同步文字稿
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack {
                ForEach(transcript) { line in
                    TranscriptLine(
                        line: line,
                        isCurrent: line.id == currentLineIndex
                    )
                }
            }
        }
        .onChange(of: currentLineIndex) { _, newIndex in
            proxy.scrollTo(newIndex, anchor: .center)
        }
    }
}
```

### 其他创意组合

**输入源可以是：**
- 音频波形数据
- 陀螺仪传感器
- 触摸手势
- 网络数据流

**转换管道可以是：**
- 不同的 shader 效果（涟漪、扭曲、发光）
- 不同的布局容器（Canvas、Grid、Flow）
- 不同的动画方式（spring、easing、timeline）

**输出可以是：**
- 2D 视图
- 3D 场景（RealityKit）
- 音频可视化
- 实时图表

**关键：** API 始终如一，创意在于组合方式。

---

## 完整示例

### 示例 1：动态背景播客视图

```swift
import SwiftUI

struct PodcastTranscriptView: View {
    @State private var startDate = Date.now
    @State private var playback = PlaybackState()
    
    let transcript: [TranscriptLine]
    
    var body: some View {
        ZStack {
            // 动态背景
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                
                GeometryReader { proxy in
                    CoverArtView()
                        .layerEffect(
                            ShaderLibrary.backgroundWarp(
                                .float2(proxy.size),
                                .image(Image("NoiseTexture")),
                                .float(elapsed)
                            ),
                            maxSampleOffset: .zero
                        )
                }
            }
            .ignoresSafeArea()
            
            // 文字稿滚动视图
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(transcript) { line in
                            TranscriptLineView(
                                line: line,
                                isCurrent: line.id == playback.currentLineIndex
                            )
                        }
                    }
                    .padding()
                }
                .onChange(of: playback.currentLineIndex) { _, newIndex in
                    withAnimation {
                        scrollProxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}

struct TranscriptLineView: View {
    let line: TranscriptLine
    let isCurrent: Bool
    
    var body: some View {
        Text(line.text)
            .font(.title)
            .fontWeight(isCurrent ? .bold : .regular)
            .foregroundStyle(isCurrent ? .primary : .secondary)
            .opacity(isCurrent ? 1.0 : 0.5)
            .overlay(alignment: .bottomLeading) {
                Text(line.formattedTimestamp)
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .alignmentGuide(.bottom) { $0[.top] }
                    .opacity(isCurrent ? 1 : 0)
            }
    }
}

struct CoverArtView: View {
    var body: some View {
        Image("CoverArt")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .blur(radius: 30)
    }
}
```

**对应的 Metal Shader：**

```metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[stitchable]] half4 backgroundWarp(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    texture2d<half> noiseTex,
    float time
) {
    constexpr sampler s(address::repeat, filter::linear);
    
    // 计算 UV，加入时间偏移
    float2 uv = position / size + float2(time * 0.1, time * 0.05);
    
    // 第一层噪声
    half4 n1 = noiseTex.sample(s, uv);
    float2 q = float2(n1.r, n1.g);
    
    // 第二层噪声（域变形）
    half4 n2 = noiseTex.sample(s, uv + q);
    float2 offset = (float2(n2.r, n2.g) - 0.5) * 200.0;
    
    return layer.sample(position + offset);
}
```

---

### 示例 2：交互式涟漪效果

```swift
struct RippleEffectView: View {
    @State private var tapLocation: CGPoint = .zero
    @State private var lastTapTime: Date = .distantPast
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(lastTapTime)
            
            Image("photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .distortionEffect(
                    ShaderLibrary.ripple(
                        .float2(tapLocation),
                        .float(elapsed)
                    ),
                    maxSampleOffset: CGSize(width: 50, height: 50)
                )
                .onTapGesture { location in
                    tapLocation = location
                    lastTapTime = Date.now
                }
        }
    }
}
```

```metal
[[stitchable]] float2 ripple(
    float2 position,
    float2 tapLocation,
    float time
) {
    float distance = length(position - tapLocation);
    float ripple = sin(distance * 0.1 - time * 10.0) * 10.0;
    float fade = exp(-time * 2.0);  // 淡出
    
    float2 direction = normalize(position - tapLocation);
    return position + direction * ripple * fade;
}
```

---

## 性能优化

### Shader 性能建议

**✅ 推荐做法：**

1. **避免复杂计算**
   ```metal
   // ❌ 慢：每个像素都计算 sin/cos
   float angle = atan2(position.y, position.x);
   
   // ✅ 快：预计算并传入
   float angle = precomputedAngle;
   ```

2. **使用纹理查找表（LUT）**
   ```metal
   // ❌ 慢：复杂数学运算
   float result = pow(sin(x * 3.14), 2.0) * cos(y);
   
   // ✅ 快：查表
   half4 result = lutTexture.sample(sampler, float2(x, y));
   ```

3. **限制循环次数**
   ```metal
   // ❌ 慢：大量迭代
   for (int i = 0; i < 100; i++) { ... }
   
   // ✅ 快：固定少量迭代
   for (int i = 0; i < 5; i++) { ... }
   ```

4. **使用低精度类型**
   ```metal
   // ✅ 颜色用 half（16位）
   half4 color = layer.sample(position);
   
   // ⚠️ 位置用 float（32位）
   float2 offset = ...;
   ```

### maxSampleOffset 的重要性

**必须准确设置：**

```swift
// ❌ 错误：设置为 .zero 但 shader 实际采样范围更大
.layerEffect(
    ShaderLibrary.blur(.float(20)),
    maxSampleOffset: .zero  // 会导致边缘裁切！
)

// ✅ 正确：匹配实际采样范围
.layerEffect(
    ShaderLibrary.blur(.float(20)),
    maxSampleOffset: CGSize(width: 20, height: 20)
)
```

**作用：**
- 告诉 SwiftUI 需要预留多少边界空间
- 防止采样超出图层范围
- 优化渲染区域

### TimelineView 性能

**选择合适的调度模式：**

```swift
// ❌ 不必要的高频更新
TimelineView(.animation) { timeline in
    Text(Date.now, format: .dateTime.hour().minute())  // 每帧更新但只显示分钟
}

// ✅ 按需更新
TimelineView(.periodic(from: .now, by: 60)) { timeline in
    Text(timeline.date, format: .dateTime.hour().minute())  // 每分钟更新一次
}
```

**动画时才使用 .animation：**

```swift
// ✅ 需要平滑动画
TimelineView(.animation) { timeline in
    RotatingView(angle: timeline.date.timeIntervalSince1970)
}

// ✅ 静态内容，手动触发
@State private var needsUpdate = false

if needsUpdate {
    MyView()
}
```

### 内存管理

**大型纹理优化：**

```swift
// ❌ 每帧创建新 Image
TimelineView(.animation) { _ in
    view.layerEffect(
        ShaderLibrary.effect(.image(Image("LargeTexture")))  // 重复加载
    )
}

// ✅ 提前加载，重复使用
@State private var noiseTexture = Image("NoiseTexture")

TimelineView(.animation) { _ in
    view.layerEffect(
        ShaderLibrary.effect(.image(noiseTexture))  // 复用
    )
}
```

---

## 最佳实践

### 开发流程

1. **分解设计** - 识别独立的视觉层
2. **选择 API** - 为每层选择合适的技术
3. **原型验证** - 单独测试每个阶段
4. **组合集成** - 连接流水线
5. **性能优化** - 分析和调优

### 调试技巧

**1. 单独测试 Shader**

```swift
// 创建独立的预览视图
struct ShaderPreview: View {
    @State private var param1: Float = 0
    
    var body: some View {
        VStack {
            Image("test")
                .layerEffect(
                    ShaderLibrary.myShader(.float(param1)),
                    maxSampleOffset: .zero
                )
            
            Slider(value: $param1, in: 0...10)
        }
    }
}
```

**2. 可视化中间结果**

```metal
// 在 shader 中输出调试颜色
[[stitchable]] half4 debug(float2 position, SwiftUI::Layer layer) {
    // 可视化 UV 坐标
    float2 uv = position / float2(1000, 1000);
    return half4(uv.x, uv.y, 0, 1);
}
```

**3. 性能分析**

- 使用 Instruments 的 Metal System Trace
- 检查 GPU 使用率
- 分析帧率下降

### 常见错误

**❌ 错误 1：忘记 [[stitchable]]**

```metal
// ❌ 编译错误
half4 myShader(float2 position, SwiftUI::Layer layer) { ... }

// ✅ 正确
[[stitchable]] half4 myShader(float2 position, SwiftUI::Layer layer) { ... }
```

**❌ 错误 2：maxSampleOffset 设置不当**

```swift
// ❌ 会导致视觉裁切
.distortionEffect(
    ShaderLibrary.bigWave(),
    maxSampleOffset: .zero  // 实际偏移远大于 0
)
```

**❌ 错误 3：在 Shader 中使用状态**

```metal
// ❌ Shader 是无状态的，这不会工作
static float counter = 0;
counter += 1;

// ✅ 从 SwiftUI 传入状态
[[stitchable]] half4 shader(float2 pos, SwiftUI::Layer layer, float counter)
```

---

## 参考资料

- [SwiftUI Shader Documentation](https://developer.apple.com/documentation/SwiftUI/Shader)
- [SwiftUI Alignment Documentation](https://developer.apple.com/documentation/SwiftUI/Alignment)
- [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
- [WWDC 2024 Session 10151 - Create custom visual effects with SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10151)
- [WWDC 2026 Session 322 - Composing advanced graphics effects with SwiftUI](https://developer.apple.com/videos/play/wwdc2026/322)
- [Sample Code: Composing advanced graphics effects with SwiftUI](https://developer.apple.com/documentation/SwiftUI/Composing-advanced-graphics-effects-with-SwiftUI)

---

## 快速参考

### Shader 效果选择指南

| 需求 | 推荐使用 | 示例 |
|------|---------|------|
| 改变颜色/饱和度 | `colorEffect` | 黑白滤镜、色调调整 |
| 扭曲/变形 | `distortionEffect` | 波纹、透视变换 |
| 模糊/发光 | `layerEffect` | 高斯模糊、光晕 |
| 复杂采样 | `layerEffect` | 域变形、流体效果 |

### 数据类型速查

| Swift | Metal | 用途 |
|-------|-------|------|
| `Float` | `float` | 单个数值 |
| `CGPoint` | `float2` | 位置、向量 |
| `CGSize` | `float2` | 尺寸 |
| `Color` | `half4` | RGBA 颜色 |
| `Image` | `texture2d<half>` | 纹理图像 |

### TimelineView 调度模式

| 模式 | 更新频率 | 适用场景 |
|------|---------|---------|
| `.animation` | ~60 FPS | 平滑动画 |
| `.everySecond` | 1 Hz | 时钟、计时器 |
| `.periodic(from:by:)` | 自定义 | 定期更新 |
| `.explicit([Date])` | 指定时间 | 事件触发 |

