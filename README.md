# iOS New Features Skill

一个 **AI 参考知识库**，为 Claude Code、Cursor 等 AI 工具补充 iOS / Swift / SwiftUI 新功能的精准文档。

---

## 安装

### Claude Code

在 Claude Code 中执行：

```
/plugin marketplace add liuyongjiesail/iOS-NewFeatures-Skill
/plugin install ios-new-features@iOS-NewFeatures-Skill
```

安装后，遇到 iOS 18+ / iOS 26+ 相关 API 时会自动加载参考文档。

### Cursor（GitHub CLI）

需要 [GitHub CLI](https://cli.github.com/) v2.90.0+：

```bash
gh skill install github/liuyongjiesail/iOS-NewFeatures-Skill ios-new-features
```

### 手动安装（通用）

```bash
git clone https://github.com/liuyongjiesail/iOS-NewFeatures-Skill
```

- **Claude Code**：将 `skills/` 目录复制到项目的 `.claude/skills/`
- **Cursor**：将 `.cursor/skills/ios-new-features/` 复制到项目的 `.cursor/skills/`，同时复制 `skills/ios-new-features/reference/` 到相同目录下

---

## 背景

AI 的训练数据存在截止日期。对于 iOS 18 之后引入的新 API（如 AlarmKit、iOS 26+ 新特性等），AI 可能不了解或给出错误答案。这个 Skill 通过提供经过验证的参考文档来弥补这一缺口。

---

## 已收录功能

| 功能 | 系统要求 | 说明 |
|------|----------|------|
| [AlarmKit](skills/ios-new-features/reference/alarmkit.md) | iOS 26+ | 倒计时闹钟、绕过静音模式提醒、Live Activity 集成；支持固定时间 / 相对时间调度、自定义声音、Intent 按钮 |
| [App Intents](skills/ios-new-features/reference/app-intents.md) | iOS 18 / iOS 26+ | App Intent Domains 15 个域（@AppIntent(schema:) 宏）、ControlConfigurationIntent、CameraCaptureIntent、IndexedEntity、UniqueAppEntity、SnippetIntent、TargetContentProvidingIntent、IntentValueQuery、AppIntentsPackage |
| [SpeechAnalyzer](skills/ios-new-features/reference/speech-analyzer.md) | iOS 26+ | 替代 SFSpeechRecognizer；SpeechTranscriber 实时转写（volatile + finalized）、DictationTranscriber 降级方案、AssetInventory 模型管理、audioTimeRange 字幕同步 |
| [Vision Framework](skills/ios-new-features/reference/vision.md) | iOS 18+ / macOS 15+ | Swift-native async/await API；ImageRequestHandler、文字识别、人脸检测、条码识别、图像分类；iOS 26+ 新增 API 单独标注 |

---

## 项目结构

```
.claude-plugin/
└── plugin.json                        # Claude Code 插件清单
.cursor/skills/ios-new-features/
└── SKILL.md                           # Cursor skill 入口
skills/ios-new-features/               # 唯一文件源（Claude Code + Cursor 共用 reference）
    ├── SKILL.md                       # Claude Code skill 入口
    └── reference/
        ├── alarmkit.md
        ├── app-intents.md
        ├── speech-analyzer.md
        └── vision.md
```

---

## 如何贡献新功能

1. 在 `skills/ios-new-features/reference/` 下新建 `.md` 文件（命名：小写 + 连字符，如 `foundation-models.md`）
2. 按以下模板填写：

```markdown
# FeatureName (iOS XX+)

Source: WWDC 20XX Session XXX / Apple 文档链接

## Quick Example
\```swift
// 最小可运行示例
\```

## Key APIs
\```swift
// 核心 API 列表
\```

## ⚠️ Important Notes
- 已知限制、必要配置、常见坑
```

3. 在 `skills/ios-new-features/SKILL.md` **和** `.cursor/skills/ios-new-features/SKILL.md` 的 Feature Index 表格中各添加一行

---

## 参考来源

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [WWDC Sessions](https://developer.apple.com/wwdc/)
