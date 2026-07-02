# SF Symbols 参考文档

> **适用版本**：iOS 17+ / macOS 14+（基础动画）、iOS 18+（SF Symbols 6）、iOS 19+（SF Symbols 7）  
> **最后更新**：2025 年  
> **相关 Session**：WWDC 2024 Session 10188、WWDC 2025 Session 337

---

## 概述

SF Symbols 是 Apple 设计的图标库，与系统字体 San Francisco 无缝集成，提供超过 6,000 个符号。支持多种缩放、粗细、渲染模式和动画预设。

**核心特性：**
- ✅ **9 种粗细 × 3 种缩放** - 自动适配不同界面
- ✅ **矢量设计** - 无损缩放，支持自定义颜色
- ✅ **多层渲染** - 分层、调色板、多色、可变色渲染
- ✅ **动画预设** - 系统级动画效果
- ✅ **本地化** - 自动适配全球语言和书写方向

---

## SF Symbols 6 新特性（iOS 18+）

### 1. Wiggle 动画（摇摆）

**用途：** 引起注意、强调交互、指示方向

**方向选项：**
```swift
// 水平方向
.symbolEffect(.wiggle.left)       // 向左摇摆
.symbolEffect(.wiggle.right)      // 向右摇摆
.symbolEffect(.wiggle.forward)    // 向前（阅读方向）
.symbolEffect(.wiggle.backward)   // 向后（阅读方向）

// 垂直方向
.symbolEffect(.wiggle.up)         // 向上摇摆
.symbolEffect(.wiggle.down)       // 向下摇摆

// 旋转方向
.symbolEffect(.wiggle.clockwise)         // 顺时针
.symbolEffect(.wiggle.counterClockwise)  // 逆时针

// 自定义角度（如飞机符号 315°）
.symbolEffect(.wiggle.angle(degrees: 315))
```

**重复控制：**
```swift
// 播放一次
.symbolEffect(.wiggle, options: .once)

// 延迟重复（可自定义延迟时间）
.symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2.0)))

// 连续播放（无延迟）
.symbolEffect(.wiggle, options: .continuous)
```

---

### 2. Rotate 动画（旋转）

**用途：** 模拟物理旋转、进度指示、状态变化

**旋转模式：**
```swift
// 整体旋转
Image(systemName: "arrow.triangle.2.circlepath")
    .symbolEffect(.rotate)

// 分层旋转（仅旋转特定层，如风扇叶片）
Image(systemName: "fan.desk")
    .symbolEffect(.rotate.byLayer)

// 方向控制
.symbolEffect(.rotate.clockwise)
.symbolEffect(.rotate.counterClockwise)
```

**注释旋转锚点：**
- 在 SF Symbols 应用中为图层启用 `canRotate`
- 使用 **Snap to Points** 精确放置锚点
- 必须定义 Regular、Ultralight、Black 三种粗细的锚点

---

### 3. Breathe 动画（呼吸）

**用途：** 传达生命感、持续活动、状态变化

**基础用法：**
```swift
Image(systemName: "heart.fill")
    .symbolEffect(.breathe)
```

**与 Pulse 结合（增强层次感）：**
```swift
.symbolEffect(.breathe, options: .pulses)
```

**Breathe vs Pulse 对比：**

| 特性 | Breathe | Pulse |
|------|---------|-------|
| **不透明度** | ✅ 变化 | ✅ 变化 |
| **大小** | ✅ 缩放 | ❌ 无变化 |
| **适用场景** | 生命感、有机动态 | 简单闪烁、轻量提示 |

---

### 4. Magic Replace（智能替换增强）

**新特性：** 自动检测相关符号，实现流畅过渡

**智能行为：**
- ✅ **斜线独立绘制** - `bell` ↔ `bell.slash` 斜线自动绘制
- ✅ **徽章独立替换** - 徽章层独立出现/消失/替换
- ✅ **基础符号保持** - 相同基础部分保持不动

**代码示例：**
```swift
@State private var isMuted = false

var body: some View {
    Button {
        isMuted.toggle()
    } label: {
        Image(systemName: isMuted ? "speaker.slash" : "speaker.wave.2")
            .contentTransition(.symbolEffect(.replace.magic))
    }
}
```

**回退机制：**
- 当两个符号不相关时，自动回退到标准 Replace 动画
- 可指定回退方向：`.replace.offUp`、`.replace.downUp` 等

---

### 5. Variable Color 改进

**新特性：** 支持闭环设计的无缝循环播放

**闭环 vs 开环：**
- **开环**：两端不相连（如进度条 0% → 100%）
- **闭环**：两端相连（如圆形进度 circle.bottomhalf.filled）

**注释闭环符号：**
```swift
// 在 SF Symbols 应用中标记为闭环
// 系统自动优化循环播放
Image(systemName: "circle.hexagonpath")
    .symbolEffect(.variableColor, options: .continuous)
```

---

## SF Symbols 7 新特性（iOS 19+）

### 1. Draw 动画（绘制动画）

**核心概念：** 模拟手绘笔触，沿定义路径绘制符号

**动画类型：**

#### Draw On（绘制出现）
```swift
Image(systemName: "heart")
    .symbolEffect(.drawOn, isActive: isVisible)
```

#### Draw Off（绘制消失）
```swift
.symbolEffect(.drawOff, isActive: !isVisible)
```

**播放模式：**
```swift
// By Layer（默认）- 逐层绘制
.symbolEffect(.drawOn.byLayer)

// Whole Symbol - 所有层同时绘制
.symbolEffect(.drawOn.wholeSymbol)

// Individually - 顺序绘制（每层等待前一层完成）
.symbolEffect(.drawOn.individually)
```

**Draw Off 反向控制：**
```swift
// 默认：沿绘制方向消失
.symbolEffect(.drawOff)

// 反向：从终点回到起点
.symbolEffect(.drawOff, options: .reverse)
```

---

### 2. Variable Draw（可变绘制）

**用途：** 通过绘制进度显示强度或完成度

**基础用法：**
```swift
// 下载进度
Image(systemName: "arrow.down.circle")
    .symbolRenderingMode(.variableDraw(value: downloadProgress))
```

**与 Variable Color 对比：**

| 特性 | Variable Draw | Variable Color |
|------|---------------|----------------|
| **视觉效果** | 路径部分绘制 | 不透明度变化 |
| **精度** | 高（基于路径长度） | 中（基于层填充） |
| **适用场景** | 下载、进度、温度 | 信号强度、电量 |
| **iOS 版本** | iOS 19+ | iOS 17+ |

**注意事项：**
- 符号必须支持 Variable Draw 注释
- 不能同时使用 Variable Color 和 Variable Draw（系统优先 Variable Color）

---

### 3. Magic Replace 增强（Enclosure Matching）

**新特性：** 识别共享封闭图形，实现更流畅的过渡

**封闭图形示例：**
- 圆形基础：`circle.fill` ↔ `circle.badge.checkmark`
- 方形基础：`square.fill` ↔ `square.badge.plus`

**Draw + Magic Replace：**
```swift
@State private var isLocked = true

Button {
    isLocked.toggle()
} label: {
    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
        .contentTransition(.symbolEffect(.replace.magic.draw))
}
// ✅ 封闭图形保持不变
// ✅ 消失符号使用 Draw Off
// ✅ 出现符号使用 Draw On
```

---

### 4. Gradient（渐变渲染）

**用途：** 为符号添加光影、维度、视觉吸引力

**启用渐变：**
```swift
// SwiftUI
Image(systemName: "star.fill")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.blue)
    .symbolGradient(true)

// UIKit
let config = UIImage.SymbolConfiguration(
    paletteColors: [.systemBlue]
)
.applying(UIImage.SymbolConfiguration(colorRenderingMode: .gradient))
```

**特性：**
- ✅ 从单一颜色生成线性渐变
- ✅ 支持系统颜色和自定义颜色
- ✅ 适用于所有渲染模式
- ✅ 自动适配所有尺寸（大尺寸效果最佳）

---

## 自定义符号注释系统

### 1. Draw 注释（Guide Points）

**核心概念：** 通过引导点定义绘制路径和方向

#### 基础引导点

**最少配置：** 开始点 + 结束点

```
开始点（空心圆）━━━━━━━━━> 结束点（实心圆）
```

**在 SF Symbols 应用中：**
1. 选择符号 → 动画检查器 → Draw On
2. 点击工具栏 **Guide Point 模式**
3. 点击路径放置引导点
4. 系统自动判断方向（箭头显示）

#### 复杂路径注释

**多引导点：** 填补开始/结束之间的空隙

```
开始点 ━━> 引导点1 ━━> 引导点2 ━━> 结束点
```

**应用场景：**
- ✅ 急转弯路径（需要 Corner Point）
- ✅ 多段绘制路径
- ✅ 矢量箭头附件（箭头跟随路径移动）

---

### 2. 特殊引导点类型

#### Corner Point（拐角点）

**用途：** 标记急转弯，确保正确计算

**标记方式：**
- 右键引导点 → 类型 → Corner
- 显示为**菱形**（而非圆形）

#### 闭环路径（Closed Loop）

**特性：** 开始点 = 结束点（显示为胶囊形状）

**默认方向：** 顺时针

**反转方向：**
```
右键引导点 → Toggle Direction → 逆时针
```

---

### 3. 绘制方向控制

**全局方向：**
- **左 → 右** - 西方语言（英语、西班牙语）
- **右 → 左** - 阿拉伯语、希伯来语
- **中心 → 外** - 正对称符号（波浪、放射）
- **自定义角度** - 任意方向（如飞机符号）

**双向绘制：**
1. 开始点放置在路径中心
2. 在开始点两侧各放置一个引导点
3. 系统自动识别为双向（显示双向箭头）

---

### 4. Adaptive End Caps（自适应端点）

**用途：** 让绘制动画端点样式匹配路径设计

**启用方式：**
```
右键开始点 → Adaptive End Cap
```

**效果：**
- ✅ 圆角路径 → 圆形端点
- ✅ 直角路径 → 方形端点
- ⚠️ 仅适用于单向绘制

---

### 5. Drawing Attachments（绘制附件）

**用途：** 让非绘制元素（如箭头尖）跟随路径移动

**创建步骤：**
1. 将箭头尖放在独立路径（不能与基础路径合并）
2. 拖动箭头尖路径到引导点
3. 显示预览线（表示附件关系）

**移除附件：**
```
拖动路径离开引导点 → 放置到画布其他位置
```

---

### 6. 多粗细注释

**必须注释的粗细：**
1. **Regular** - 基础注释（唯一可添加/删除引导点的粗细）
2. **Ultralight** - 系统自动补间
3. **Black** - 系统自动补间

**引导点关联：**
- Ultralight 和 Black 的引导点自动关联到 Regular
- 移动 Regular 的引导点 → 其他粗细自动跟随

**手动调整：**
- 使用 **Option + 拖动** 独立移动单个端点
- 启用 **Show Guide Point Numbers** 检查顺序
- 错位的引导点显示为**橙色**

---

### 7. Variable Draw 注释

**启用步骤：**
1. 完成 Draw 注释
2. 设置弹窗 → 启用 **Variable Rendering**
3. 图层列表 → 点击图层的 **Variable Draw 按钮**

**预览：**
```swift
// 在渲染检查器中
Variable Rendering → Draw → 拖动滑块（0.0 - 1.0）
```

**最佳实践：**
- ✅ 仅在需要进度显示的层启用
- ✅ 温度计示例：仅度量层启用，框架层不启用
- ⚠️ 与 Variable Color 互斥（同一时间只能用一个）

---

## API 速查表

### SwiftUI

```swift
// ===== Draw =====
.symbolEffect(.drawOn, isActive: isVisible)
.symbolEffect(.drawOff, isActive: !isVisible)
.symbolEffect(.drawOn.byLayer)           // 逐层
.symbolEffect(.drawOn.wholeSymbol)       // 整体
.symbolEffect(.drawOn.individually)      // 顺序

// ===== Variable Draw =====
Image(systemName: "thermometer")
    .symbolRenderingMode(.variableDraw(value: temperature))

// ===== Gradient =====
Image(systemName: "star.fill")
    .foregroundStyle(.blue)
    .symbolGradient(true)

// ===== Wiggle =====
.symbolEffect(.wiggle.up)
.symbolEffect(.wiggle.angle(degrees: 45))

// ===== Rotate =====
.symbolEffect(.rotate.clockwise)
.symbolEffect(.rotate.byLayer)  // 分层旋转

// ===== Breathe =====
.symbolEffect(.breathe)
.symbolEffect(.breathe, options: .pulses)

// ===== Magic Replace =====
.contentTransition(.symbolEffect(.replace.magic))
.contentTransition(.symbolEffect(.replace.magic.draw))
```

### UIKit / AppKit

```swift
// Draw On / Off
imageView.addSymbolEffect(.drawOn)
imageView.addSymbolEffect(.drawOff, animated: false)

// Variable Draw
let config = UIImage.SymbolConfiguration(
    variableValue: progress  // 0.0 - 1.0
)
imageView.setPreferredSymbolConfiguration(config, forImageIn: .normal)

// Gradient
let gradientConfig = UIImage.SymbolConfiguration(
    paletteColors: [.systemBlue]
).applying(
    UIImage.SymbolConfiguration(colorRenderingMode: .gradient)
)
```

---

## 重复播放控制

### 播放模式对比

| 模式 | SwiftUI 选项 | 行为 |
|------|--------------|------|
| **播放一次** | `.once` | 播放后停止 |
| **延迟重复** | `.repeat(.periodic(delay: 2.0))` | 每次重复前等待 |
| **连续播放** | `.continuous` | 无缝循环（适合闭环设计） |

### 代码示例

```swift
// 播放一次
.symbolEffect(.wiggle, options: .once)

// 每 2 秒重复一次
.symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2.0)))

// 连续播放（适合圆形进度）
.symbolEffect(.breathe, options: .continuous)
```

---

## 最佳实践

### ✅ 推荐做法

1. **选择合适的动画预设**
   - Wiggle → 引起注意
   - Rotate → 进行中状态
   - Breathe → 持续活动
   - Draw → 首次出现、教学引导

2. **优先使用 Magic Replace**
   ```swift
   // ✅ 优先
   .contentTransition(.symbolEffect(.replace.magic))
   
   // ❌ 避免手动指定方向（除非必要）
   .contentTransition(.symbolEffect(.replace.downUp))
   ```

3. **为自定义符号添加注释**
   - Regular 粗细完成基础注释
   - Ultralight / Black 系统自动补间
   - 预览所有配置（9 粗细 × 3 缩放）

4. **尊重系统动画偏好**
   ```swift
   // 自动遵守辅助功能设置
   .symbolEffect(.wiggle, isActive: shouldAnimate)
   ```

### ❌ 常见错误

1. **过度使用动画**
   ```swift
   // ❌ 过度刺激
   VStack {
       Image(systemName: "bell").symbolEffect(.wiggle)
       Image(systemName: "star").symbolEffect(.rotate)
       Image(systemName: "heart").symbolEffect(.breathe)
   }
   
   // ✅ 有节制使用
   Image(systemName: "bell")
       .symbolEffect(.wiggle, isActive: hasNotification)
   ```

2. **锚点位置不精确**
   ```swift
   // ❌ 风扇旋转偏移
   // 原因：锚点未对齐叶片中心
   
   // ✅ 使用 Snap to Points 精确对齐
   ```

3. **忽略绘制方向**
   ```swift
   // ❌ 阿拉伯语界面使用左→右绘制
   
   // ✅ 使用 Forward/Backward（自动适配阅读方向）
   .symbolEffect(.wiggle.forward)
   ```

---

## 性能优化

### 动画开销对比

| 动画类型 | CPU 占用 | GPU 占用 | 建议 |
|----------|----------|----------|------|
| **Wiggle** | 低 | 低 | ✅ 适合频繁使用 |
| **Rotate** | 低 | 中 | ✅ 适合持续动画 |
| **Breathe** | 低 | 中 | ✅ 适合状态指示 |
| **Draw** | 中 | 高 | ⚠️ 首次出现时使用 |
| **Variable Draw** | 中 | 中 | ⚠️ 高频更新需优化 |
| **Magic Replace** | 中 | 中 | ✅ 优于手动过渡 |

### 优化建议

1. **避免同时播放多个 Draw 动画**
   ```swift
   // ❌ 可能卡顿
   List(items) { item in
       Image(systemName: item.icon)
           .symbolEffect(.drawOn)
   }
   
   // ✅ 限制可见范围
   LazyVStack {
       ForEach(visibleItems) { item in
           Image(systemName: item.icon)
               .symbolEffect(.drawOn)
       }
   }
   ```

2. **Variable Draw 节流**
   ```swift
   // ❌ 每帧更新
   .onChange(of: progress) { _, newValue in
       currentProgress = newValue
   }
   
   // ✅ 节流更新（每 100ms）
   let throttledProgress = progress
       .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
   ```

---

## 调试技巧

### SF Symbols 应用调试

1. **显示引导点编号**
   ```
   工具栏 → Show Guide Point Numbers
   ```
   - 橙色编号 = 手动调整过的点
   - 检查顺序是否与 Regular 一致

2. **预览所有配置**
   ```
   检查器 → Weight & Scale 切换器
   Regular / Ultralight / Black × S / M / L
   ```

3. **导出检查**
   ```
   文件 → 导出符号
   → 在 Xcode 16+ 中导入
   → 预览动画是否正常
   ```

### Xcode 调试

```swift
#if DEBUG
struct SymbolPreview: View {
    var body: some View {
        VStack {
            // 测试所有粗细
            ForEach(Font.Weight.allCases, id: \.self) { weight in
                Image(systemName: "custom.icon")
                    .font(.system(size: 50, weight: weight))
                    .symbolEffect(.drawOn, isActive: true)
            }
        }
    }
}
#endif
```

---

## 快速参考

### 选择动画预设决策树

```
需要引起注意？
├─ 是 → Wiggle（摇摆）
└─ 否 ↓

表示进行中状态？
├─ 是 → Rotate（旋转）
└─ 否 ↓

需要生命感？
├─ 是 → Breathe（呼吸）
└─ 否 ↓

首次出现/教学？
├─ 是 → Draw On（绘制）
└─ 否 ↓

符号切换？
└─ 是 → Magic Replace（智能替换）
```

### 进度指示选择

| 场景 | 推荐方案 | 示例符号 |
|------|----------|----------|
| **下载进度** | Variable Draw | `arrow.down.circle` |
| **信号强度** | Variable Color | `wifi` |
| **电池电量** | Variable Color | `battery.100percent` |
| **温度计** | Variable Draw | `thermometer` |
| **音量** | Variable Color | `speaker.wave.3` |

---

## 总结

### SF Symbols 6 核心价值
- ✅ **Wiggle / Rotate / Breathe** - 三种通用动画覆盖 90% 场景
- ✅ **Magic Replace** - 智能过渡无需手动配置
- ✅ **Variable Color 闭环** - 进度动画更流畅

### SF Symbols 7 核心价值
- ✅ **Draw** - 手绘风格动画，教学/首次体验首选
- ✅ **Variable Draw** - 高精度进度显示
- ✅ **Gradient** - 视觉升级无需设计资源
- ✅ **完善的注释系统** - 自定义符号也能享受系统级动画

---

## 相关资源

- [SF Symbols 应用下载](https://developer.apple.com/sf-symbols/)
- [Human Interface Guidelines - SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- WWDC 2024 Session 10188 - What's new in SF Symbols 6
- WWDC 2025 Session 337 - What's new in SF Symbols 7
- WWDC 2023 Session 10197 - What's new in SF Symbols 5
- WWDC 2023 Session 10257 - Create animated symbols

---

**文档版本**：1.0  
**最后验证**：iOS 19.0 beta (2025)
