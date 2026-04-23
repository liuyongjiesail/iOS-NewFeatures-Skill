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
| AlarmKit | iOS 26+ | [reference/alarmkit.md](../../skills/ios-new-features/reference/alarmkit.md) | alarm, timer alert, AlarmKit, override silent mode, countdown alert, Live Activity alarm |
| App Intents | iOS 18 / iOS 26 新特性 | [reference/app-intents.md](../../skills/ios-new-features/reference/app-intents.md) | App Intent Domains, @AppIntent(schema:), @AppEntity(schema:), @AppEnum(schema:), assistant schema, .mail, .photos, .browser, .fileManagement, ControlConfigurationIntent, CameraCaptureIntent, AudioRecordingIntent, IndexedEntity, FileEntity, UniqueAppEntity, URLRepresentableIntent, @UnionValue, AppIntentsPackage, @ComputedProperty, SnippetIntent, TargetContentProvidingIntent, IntentValueQuery, IntentModes, appEntityIdentifier |
| SpeechAnalyzer | iOS 26+ | [reference/speech-analyzer.md](../../skills/ios-new-features/reference/speech-analyzer.md) | SpeechAnalyzer, SpeechTranscriber, DictationTranscriber, speech-to-text, live transcription, ASR, AssetInventory, SFSpeechRecognizer replacement, volatile results, audioTimeRange, on-device transcription |
| Vision Framework | iOS 18+ / macOS 15+ | [reference/vision.md](../../skills/ios-new-features/reference/vision.md) | Vision, ImageRequestHandler, RecognizeTextRequest, DetectFaceRectanglesRequest, GenerateObjectnessBasedSaliencyImageRequest, DetectBarcodesRequest, ClassifyImageRequest, swift-native Vision API, async/await Vision |

---

## How to Add a New Feature

1. Create a reference file: `skills/ios-new-features/reference/your-feature.md`
2. Add a row to the Feature Index table above (in both `skills/ios-new-features/SKILL.md` and `.cursor/skills/ios-new-features/SKILL.md`)
3. Format: feature name, minimum iOS version, file path, trigger keywords
