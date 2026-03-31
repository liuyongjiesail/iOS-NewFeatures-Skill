# iOS New Features Skill

一个 **AI 参考知识库**，为 Cursor、Claude、ChatGPT 等 AI 工具补充 iOS / Swift / SwiftUI 新功能的精准文档。

---

## 背景

AI 的训练数据存在截止日期。对于 iOS 18 之后引入的新 API（如 AlarmKit、iOS 26+ 新特性等），AI 可能不了解或给出错误答案。这个 Skill 通过提供经过验证的参考文档来弥补这一缺口，让 Cursor 在处理新 iOS 功能时能给出准确的代码建议。

---

## 已收录功能

| 功能 | 系统要求 | 说明 |
|------|----------|------|
| [AlarmKit](ios-new-features/reference/alarmkit.md) | iOS 26+ | 倒计时闹钟、绕过静音模式提醒、Live Activity 集成 |
| [App Intents](ios-new-features/reference/app-intents.md) | iOS 18 / iOS 26 新特性 | App Intent Domains（含 15 个域的 assistant schema）、ControlConfigurationIntent、CameraCaptureIntent、IndexedEntity、UniqueAppEntity、@ComputedProperty、SnippetIntent、TargetContentProvidingIntent、IntentValueQuery 等 |

---

## 项目结构

```
ios-new-features/
├── SKILL.md              # Skill 入口（功能索引 + 触发条件）
└── reference/
    └── alarmkit.md       # AlarmKit 参考文档
    └── ...               # 后续新增功能文档
AGENTS.md                 # 项目维护规范（供 AI 读取）
operateLog.md             # 操作记录
```

---

## 如何使用

将对应的参考文档内容附加到你的 AI 对话上下文中，AI 即可基于准确的文档给出正确的代码建议。

**Cursor**：已配置为 Agent Skill，遇到相关 API 时会自动加载对应文档。

**其他 AI 工具**（Claude、ChatGPT 等）：手动将 `reference/` 下对应的 `.md` 文件内容粘贴到对话中，或作为附件上传即可。

典型触发场景：
- 询问 iOS 26+ 新 API（如 `AlarmKit`、`AlarmManager`）
- 提到具体的 WWDC Session
- 实现可能涉及较新 iOS 版本的功能

---

## 如何贡献新功能

1. 在 `ios-new-features/reference/` 下新建 `.md` 文件（命名：小写 + 连字符，如 `foundation-models.md`）
2. 按以下模板填写内容：

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

3. 在 `ios-new-features/SKILL.md` 的 Feature Index 表格中添加对应条目
4. 在 `operateLog.md` 记录本次修改

---

## 参考来源

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [WWDC Sessions](https://developer.apple.com/wwdc/)
