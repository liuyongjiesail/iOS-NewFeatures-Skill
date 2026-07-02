# 发布到插件市场指南

本文档介绍如何将 iOS New Features Skill 发布到不同的插件市场。

---

## 📦 发布前检查清单

### ✅ 必需文件

- [x] `README.md` - 项目说明
- [x] `LICENSE` - MIT 许可证
- [x] `package.json` - NPM 配置
- [x] `skill.yaml` - Claude Code 元数据
- [x] `install.sh` - Bash 安装脚本
- [x] `ios-new-features/SKILL.md` - Skill 定义
- [x] `ios-new-features/reference/*.md` - 参考文档

### ✅ 质量检查

```bash
# 1. 验证文档完整性
npm run validate

# 2. 检查 Markdown 格式
npx markdownlint ios-new-features/reference/*.md

# 3. 测试本地安装
./install.sh

# 4. 测试 NPM 安装
npm install
npm run install
```

---

## 🎯 发布渠道

### 方式 1：Claude Code 官方市场（推荐）

#### 1.1 准备元数据

确保 `skill.yaml` 包含完整信息：

```yaml
skill:
  name: ios-new-features
  displayName: iOS New Features Reference
  version: 1.0.0
  category: development
  # ... 其他配置
```

#### 1.2 提交到官方仓库

```bash
# 1. Fork Claude Code 插件仓库
gh repo fork anthropics/claude-code-skills

# 2. 添加你的 skill
cd claude-code-skills
mkdir -p skills/ios-new-features
cp -r /path/to/your/skill/* skills/ios-new-features/

# 3. 创建 Pull Request
git checkout -b add-ios-new-features-skill
git add skills/ios-new-features
git commit -m "Add: iOS New Features Skill"
git push origin add-ios-new-features-skill
gh pr create --title "Add iOS New Features Skill" \
             --body "Comprehensive iOS/Swift/SwiftUI reference for post-cutoff features"
```

#### 1.3 等待审核

官方团队会审核你的提交，通常需要 1-2 周。

---

### 方式 2：NPM 包发布

#### 2.1 登录 NPM

```bash
npm login
# 输入你的 NPM 账号信息
```

#### 2.2 发布包

```bash
# 1. 确保版本号正确
npm version 1.0.0

# 2. 发布（使用作用域包名）
npm publish --access public

# 或发布到 @claude-code 组织（需要权限）
npm publish --scope=@claude-code --access public
```

#### 2.3 用户安装方式

```bash
# 全局安装
npm install -g @claude-code/ios-new-features-skill

# 安装脚本会自动复制到 ~/.claude/skills/
```

---

### 方式 3：GitHub Releases

#### 3.1 创建发布

```bash
# 1. 创建 Git tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 2. 使用 GitHub CLI 创建 release
gh release create v1.0.0 \
  --title "iOS New Features Skill v1.0.0" \
  --notes "Initial release with 27+ iOS features"

# 3. 上传安装脚本
gh release upload v1.0.0 install.sh
```

#### 3.2 用户安装方式

```bash
# 下载并安装
curl -fsSL https://github.com/liuyongjie/iOS-NewFeatures-Skill/releases/download/v1.0.0/install.sh | bash
```

---

### 方式 4：Homebrew Tap（macOS）

#### 4.1 创建 Homebrew Formula

创建文件 `Formula/ios-new-features-skill.rb`：

```ruby
class IosNewFeaturesSkill < Formula
  desc "AI reference for iOS/Swift/SwiftUI new features"
  homepage "https://github.com/liuyongjie/iOS-NewFeatures-Skill"
  url "https://github.com/liuyongjie/iOS-NewFeatures-Skill/archive/v1.0.0.tar.gz"
  sha256 "YOUR_SHA256_HASH"
  license "MIT"

  def install
    (share/"claude/skills/ios-new-features").install Dir["ios-new-features/*"]
  end

  def caveats
    <<~EOS
      iOS New Features Skill has been installed to:
        #{share}/claude/skills/ios-new-features

      To activate, symlink to your home directory:
        ln -sf #{share}/claude/skills/ios-new-features ~/.claude/skills/
    EOS
  end

  test do
    assert_predicate share/"claude/skills/ios-new-features/SKILL.md", :exist?
  end
end
```

#### 4.2 创建 Homebrew Tap

```bash
# 1. 创建 tap 仓库
gh repo create homebrew-tap --public

# 2. 添加 Formula
git clone https://github.com/liuyongjie/homebrew-tap.git
cd homebrew-tap
mkdir Formula
cp ../Formula/ios-new-features-skill.rb Formula/
git add Formula/ios-new-features-skill.rb
git commit -m "Add ios-new-features-skill formula"
git push origin main
```

#### 4.3 用户安装方式

```bash
brew tap liuyongjie/tap
brew install ios-new-features-skill
```

---

## 📊 版本管理

### 语义化版本

遵循 [SemVer](https://semver.org/)：

- **1.0.0** - 初始发布
- **1.0.1** - Bug 修复
- **1.1.0** - 新增功能（向后兼容）
- **2.0.0** - 破坏性更新

### 更新版本

```bash
# 补丁版本（bug 修复）
npm version patch

# 次版本（新功能）
npm version minor

# 主版本（破坏性更新）
npm version major
```

### 发布新版本

```bash
# 1. 更新 CHANGELOG.md
echo "## [1.1.0] - 2024-XX-XX\n### Added\n- New feature\n" >> CHANGELOG.md

# 2. 提交变更
git add .
git commit -m "chore: bump version to 1.1.0"

# 3. 创建 tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main --tags

# 4. 发布到 NPM
npm publish

# 5. 创建 GitHub Release
gh release create v1.1.0 --generate-notes
```

---

## 📣 推广渠道

### 1. 社区分享

- **Twitter/X**: `#ClaudeCode #iOS #Swift`
- **Reddit**: r/iOSProgramming, r/swift
- **Hacker News**: Show HN
- **Dev.to**: 撰写使用教程

### 2. 开发者社区

- **GitHub Discussions**: 创建讨论区
- **Discord/Slack**: 加入 iOS 开发社区
- **WWDC 社区**: 分享到 Apple 开发者论坛

### 3. 文档网站

创建专属文档网站（可选）：

```bash
# 使用 Docusaurus
npx create-docusaurus@latest docs classic
cd docs
npm run start
```

---

## 🔧 持续维护

### 自动化工作流

创建 `.github/workflows/publish.yml`：

```yaml
name: Publish to NPM

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          registry-url: 'https://registry.npmjs.org'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run validation
        run: npm run validate
      
      - name: Publish to NPM
        run: npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### 自动更新检查

创建 `.github/workflows/update-check.yml`：

```yaml
name: Check for Updates

on:
  schedule:
    - cron: '0 0 * * 1'  # 每周一检查
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Check WWDC updates
        run: |
          # 检查是否有新的 WWDC session
          # 发送通知到 Issues
```

---

## 📈 统计和反馈

### 收集使用数据

1. **GitHub Stars**: 关注仓库收藏数
2. **NPM Downloads**: `npm info @claude-code/ios-new-features-skill`
3. **Issues/PRs**: 跟踪用户反馈

### 用户调研

在 GitHub Discussions 创建：

```markdown
# 用户反馈调研

**你最常使用哪个功能？**
- [ ] AlarmKit
- [ ] App Intents
- [ ] SF Symbols
- [ ] 其他

**希望增加哪些功能？**
（自由回答）
```

---

## ✅ 发布后检查

- [ ] NPM 包可以正常安装
- [ ] GitHub Release 页面显示正常
- [ ] README 链接都可访问
- [ ] 安装脚本在各平台测试通过
- [ ] Claude Code 中能正常触发
- [ ] 文档示例代码可以运行

---

## 🆘 常见问题

### Q: NPM 发布失败

```bash
# 检查包名是否被占用
npm search @claude-code/ios-new-features-skill

# 更换包名
# 修改 package.json 中的 name 字段
```

### Q: GitHub Release 创建失败

```bash
# 检查 tag 是否存在
git tag -l

# 删除本地 tag
git tag -d v1.0.0

# 删除远程 tag
git push origin --delete v1.0.0
```

### Q: 安装脚本权限问题

```bash
# 添加执行权限
chmod +x install.sh

# 修复 Windows 换行符
dos2unix install.sh
```

---

## 📚 参考资源

- [NPM Publishing Guide](https://docs.npmjs.com/cli/v9/commands/npm-publish)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Semantic Versioning](https://semver.org/)

---

**祝发布顺利！🎉**
