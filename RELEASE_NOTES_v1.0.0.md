# iOS New Features Skill v1.0.0 🎉

首个正式版本发布！为 Claude Code、Cursor 等 AI 工具补充 iOS/Swift/SwiftUI 新功能的精准文档。

---

## 🎯 核心特性

### 📚 27+ iOS/macOS/watchOS 功能参考

- ✅ **AlarmKit** (iOS 26+) - 倒计时闹钟、绕过静音模式
- ✅ **App Intents** (iOS 18/26) - App Intent Domains、15 个 assistant schema
- ✅ **Foundation Models** (iOS 27+) - Swift 原生 AI 模型 API
- ✅ **SF Symbols 6 & 7** (iOS 18/19) - Draw/Wiggle/Rotate/Breathe 动画、渐变
- ✅ **Spatial Computing** (visionOS 2.0+) - ARKit 6、RealityKit 4
- ✅ **Swift 6 Concurrency** - 完整数据隔离、Sendable 检查
- ✅ **SwiftUI Advanced Effects** (iOS 18+) - Metal 着色器、自定义渲染
- ✅ **相机 APIs** (iOS 16-18) - 零快门延迟、ProRAW Max、Center Stage
- ✅ **HealthKit Workout Zones** (iOS 27+) - 区间训练
- ✅ **Music Understanding** (iOS 27+) - 音乐分析、节奏检测
- ✅ **NowPlaying** (iOS 27+) - 锁屏媒体控制、SharePlay 集成
- ✅ **Speech Analyzer** (iOS 26+) - 实时转录、ASR
- ✅ **Vision** (iOS 17+) - 图像理解、分割
- ✅ 还有 14 个功能...

---

## 🚀 安装方式

### 方式 1：Claude Code 插件市场（推荐）

```bash
/skills install ios-new-features
```

### 方式 2：一键安装脚本

```bash
curl -fsSL https://raw.githubusercontent.com/liuyongjiesail/iOS-NewFeatures-Skill/main/install.sh | bash
```

### 方式 3：手动安装

```bash
git clone https://github.com/liuyongjiesail/iOS-NewFeatures-Skill.git
cp -r iOS-NewFeatures-Skill/skills/ios-new-features ~/.claude/skills/
```

---

## ✨ 使用方式

安装后，当你在 Claude Code 中提到相关关键词时，Skill 会自动加载：

```
"如何使用 iOS 26 的 AlarmKit？"
→ 自动加载 AlarmKit 参考文档

"SF Symbols 7 的 Draw 动画怎么用？"
→ 自动加载 SF Symbols 文档

"Swift 6 的数据隔离如何处理？"
→ 自动加载 Swift 6 Concurrency 文档
```

---

## 📊 统计数据

- **参考文档**: 27+ 个功能
- **代码示例**: 200+ 个可运行示例
- **覆盖版本**: iOS 16 - iOS 27
- **WWDC 会话**: 基于 15+ 场 WWDC 2023-2025
- **支持平台**: macOS、Linux、Windows
- **许可证**: MIT

---

## 📝 完整更新日志

### Added

**功能参考文档：**
- AlarmKit - 倒计时闹钟、绕过静音模式提醒
- App Intents - 15 个 App Intent Domains、ControlConfigurationIntent
- Foundation Models - Swift 原生 AI 模型 API、流式响应
- SF Symbols 6 & 7 - Draw/Wiggle/Rotate/Breathe 动画、渐变
- Spatial Computing - ARKit 6、RealityKit 4、空间音频
- Swift 6 Concurrency - 完整数据隔离、Sendable 检查
- SwiftUI Advanced Effects - Metal 着色器、域变形
- AVCapture Session - 零快门延迟、延迟快门
- Center Stage Front Camera - 人物居中跟踪
- Core Image RAW Processing - RAW 照片处理
- Generative Captions - AI 生成图片描述
- HealthKit Workout Zones - 区间训练
- High Resolution Photo Capture - ProRAW Max、48MP
- Music Understanding - 音乐分析、节奏检测、和弦识别
- NowPlaying - 锁屏媒体控制、SharePlay 集成
- Speech Analyzer - 实时转录、ASR
- SwiftUI Advanced Graphics - Metal 着色器、创意流水线
- Vision - 图像理解、分割、工具调用
- Vision Image Understanding - 场景分析、物体检测

**安装和工具：**
- ✅ 跨平台安装脚本 (install.sh)
- ✅ NPM 包支持 (package.json)
- ✅ 插件市场元数据 (marketplace.json)
- ✅ 文档验证脚本
- ✅ GitHub Actions 自动化工作流
- ✅ MIT 许可证

**文档：**
- ✅ 完整的 README 说明
- ✅ 发布指南 (PUBLISHING.md)
- ✅ 更新日志 (CHANGELOG.md)
- ✅ 示例代码 (ProCameraExample.swift)

---

## 🙏 致谢

- **Apple Developer Documentation** - 官方 API 文档
- **WWDC Sessions** - 最新特性详解
- **Claude Code Team** - 提供强大的 AI 辅助编程平台

---

## 📮 反馈和贡献

- **问题反馈**: [GitHub Issues](https://github.com/liuyongjiesail/iOS-NewFeatures-Skill/issues)
- **功能请求**: [GitHub Discussions](https://github.com/liuyongjiesail/iOS-NewFeatures-Skill/discussions)
- **贡献指南**: 参见 [README.md](https://github.com/liuyongjiesail/iOS-NewFeatures-Skill#%E5%A6%82%E4%BD%95%E8%B4%A1%E7%8C%AE%E6%96%B0%E5%8A%9F%E8%83%BD)

---

**如果这个项目对你有帮助，请给个 ⭐️ Star！**

Made with ❤️ by iOS Developers for iOS Developers
