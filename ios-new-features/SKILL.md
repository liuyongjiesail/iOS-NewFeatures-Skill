---
name: ios-new-features
description: Reference for Swift and SwiftUI new features introduced after the AI training cutoff. Use when the user asks about new Swift/SwiftUI APIs, mentions a specific WWDC session, or when implementing features that may require knowledge of newer iOS versions (iOS 18+). Covers AlarmKit, and more. Each feature links to its dedicated reference file.
---

# iOS New Features Reference

This skill covers Swift and SwiftUI APIs introduced after the AI training cutoff.
Each feature has its own reference file — load only the one you need.

## Feature Index

| Feature | Version | Reference File | Trigger Keywords |
|---------|---------|----------------|-----------------|
| AlarmKit | iOS 26+ | [reference/alarmkit.md](reference/alarmkit.md) | alarm, timer alert, AlarmKit, override silent mode, countdown alert, Live Activity alarm |
| App Intents | iOS 18 / iOS 26 新特性 | [reference/app-intents.md](reference/app-intents.md) | App Intent Domains, @AppIntent(schema:), @AppEntity(schema:), @AppEnum(schema:), assistant schema, .mail, .photos, .browser, .fileManagement, ControlConfigurationIntent, CameraCaptureIntent, AudioRecordingIntent, IndexedEntity, FileEntity, UniqueAppEntity, URLRepresentableIntent, @UnionValue, AppIntentsPackage, @ComputedProperty, SnippetIntent, TargetContentProvidingIntent, IntentValueQuery, IntentModes, appEntityIdentifier |

---

## How to Add a New Feature

1. Create a reference file: `.cursor/skills/ios-new-features/your-feature.md`
2. Add a row to the Feature Index table above
3. Format: feature name, minimum iOS version, file path, trigger keywords

---

## Reference File Template

```markdown
# FeatureName (iOS XX+)

Source: WWDC 20XX Session XXX / Apple Documentation

## Overview
One-line description of what this feature does.

## Key APIs
\```swift
// Core API examples
\```

## Common Patterns
\```swift
// Typical usage
\```

## ⚠️ Important Notes
- Critical gotchas or requirements
```
