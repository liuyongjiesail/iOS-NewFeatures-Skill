# AGENTS.md — iOS New Features Skill 项目说明

## 项目用途

这个仓库是一个 **Cursor Agent Skill**，专门为 AI 提供 iOS / Swift / SwiftUI 新功能的参考知识库。

AI 训练数据存在截止日期，对于 iOS 18 之后引入的新 API（如 AlarmKit、iOS 26+ 新特性等），AI 可能不了解或产生错误。这个 skill 通过提供精准的参考文档来弥补这一缺口。

---

## 项目结构

```
ios-new-features/
├── SKILL.md               # Skill 入口，包含功能索引和触发条件
└── reference/
    └── alarmkit.md        # AlarmKit 参考文档（iOS 26+）
    └── ...                # 未来新增的功能文档
operateLog.md              # 操作日志
AGENTS.md                  # 本文件
```

---

## 维护规范

### 新增功能文档

1. 在 `ios-new-features/reference/` 下创建新的 `.md` 文件
2. 在 `ios-new-features/SKILL.md` 的 Feature Index 表格中添加对应条目
3. 文件命名使用小写 + 连字符，如 `foundation-models.md`

### 参考文档格式

每个功能文档必须包含：

- **标题**：`# FeatureName (iOS XX+)`
- **来源**：WWDC Session 编号 或 Apple 文档链接
- **Quick Example**：可直接运行的最小示例
- **Key APIs**：核心 API 列表
- **⚠️ Important Notes**：已知限制、必要配置、常见坑

### 代码规范

- 示例代码使用 **Swift**（可包含 SwiftUI / UIKit）
- 代码要求简洁、可直接复用，不写多余注释
- 使用 `@Observable` 而非 `ObservableObject`（iOS 17+）

---

## 操作记录

每次修改后更新根目录的 `operateLog.md`，格式：

```
## YYYY-MM-DD
### 修改内容
- 具体变更说明
```
