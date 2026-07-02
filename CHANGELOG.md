# Changelog

All notable changes to the iOS New Features Skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2024-12-20

### 🎉 Initial Release

#### Added

**27+ iOS/macOS/watchOS Features:**

- **AlarmKit** (iOS 26+) - Countdown alarms with silent mode override
- **App Intents** (iOS 18/26) - App Intent Domains, ControlConfigurationIntent, CameraCaptureIntent
- **Foundation Models** (iOS 27+) - Native AI model APIs with streaming responses
- **SF Symbols 6 & 7** (iOS 18/19) - Draw animations, Wiggle/Rotate/Breathe, Variable Draw, Gradients
- **Spatial Computing** (visionOS 2.0+) - ARKit 6, RealityKit 4, spatial audio
- **Swift 6 Concurrency** - Complete data isolation, Sendable checking
- **SwiftUI Advanced Effects** (iOS 18+) - Metal shaders, custom rendering
- **Camera APIs** (iOS 16-18) - Zero shutter lag, ProRAW Max, Center Stage
- **HealthKit Workout Zones** (iOS 27+) - Zone-based training
- **Music Understanding** (iOS 27+) - Audio analysis, beat detection
- **NowPlaying** (iOS 27+) - Lock screen media controls, SharePlay integration
- **Speech Analyzer** (iOS 26+) - Live transcription, ASR
- **Vision** (iOS 17+) - Image understanding, segmentation
- And 14 more features...

#### Features

- ✅ **Auto-triggered by keywords** - Mentions iOS 18+, WWDC sessions, or specific APIs
- ✅ **Official documentation sources** - All content from WWDC and Apple docs
- ✅ **Runnable code examples** - Every feature includes working Swift code
- ✅ **Multiple installation methods** - NPM, Bash script, Git submodule
- ✅ **Cross-platform support** - macOS, Linux, Windows

#### Documentation

- Comprehensive README with installation guides
- Publishing guide for contributing to plugin marketplace
- Validation scripts for documentation quality
- MIT License

---

## [Unreleased]

### Planned

- More iOS 27 features as they're announced
- Video tutorials for common use cases
- Interactive examples
- Community contributions

---

## How to Update

```bash
# NPM
npm update -g @claude-code/ios-new-features-skill

# Manual
cd ~/.claude/skills
rm -rf ios-new-features
git clone https://github.com/liuyongjie/iOS-NewFeatures-Skill.git
cp -r iOS-NewFeatures-Skill/ios-new-features .
```

---

[1.0.0]: https://github.com/liuyongjie/iOS-NewFeatures-Skill/releases/tag/v1.0.0
[Unreleased]: https://github.com/liuyongjie/iOS-NewFeatures-Skill/compare/v1.0.0...HEAD
