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
| AVCapture Session | iOS 18+ | [reference/avcapture-session.md](reference/avcapture-session.md) | AVCaptureSession, zero shutter lag, deferred shutter, shutter sound customization, spatial photo capture, iOS 18 camera |
| Center Stage Front Camera | iOS 17+ | [reference/center-stage-front-camera.md](reference/center-stage-front-camera.md) | Center Stage, front camera, person tracking, video conferencing, AVCaptureDevice.isCenterStageActive |
| Core Image RAW Processing | iOS 17+ | [reference/core-image-raw-processing.md](reference/core-image-raw-processing.md) | Core Image, RAW processing, CIRAWFilter, professional photography, color grading |
| Generative Captions | iOS 27+ | [reference/generative-captions.md](reference/generative-captions.md) | GenerativeCaptions, AI captions, image description, accessibility |
| HealthKit Medications | iOS 26+ | [reference/healthkit-medications.md](reference/healthkit-medications.md) | HealthKit, medications, HKUserAnnotatedMedication, HKMedicationDoseEvent, HKMedicationConcept, dose event, RxNorm, per-object authorization, medication tracking, HKAnchoredObjectQuery |
| HealthKit Workouts on iOS | iOS 26+ | [reference/healthkit-workout-ios.md](reference/healthkit-workout-ios.md) | HealthKit, workout, HKWorkoutSession, HKLiveWorkoutBuilder, HKLiveWorkoutDataSource, workout on iPhone, iPad workout, crash recovery, recoverActiveWorkoutSession, Siri workout intent, INStartWorkoutIntent, workout live activity |
| HealthKit Workout Zones | iOS 27+ | [reference/healthkit-workout-zones.md](reference/healthkit-workout-zones.md) | HealthKit, workout zones, heart rate zones, training zones, HKWorkoutZone |
| High Resolution Photo Capture | iOS 16+ | [reference/high-resolution-photo-capture.md](reference/high-resolution-photo-capture.md) | ProRAW Max, 48MP photos, high resolution capture, AVCapturePhotoOutput |
| MusicKit Integration | iOS 26+ | [reference/musickit.md](reference/musickit.md) | MusicKit, Apple Music, MusicAuthorization, musicPicker, musicSubscriptionOffer, MusicSubscription, ApplicationMusicPlayer, SystemMusicPlayer, ArtworkImage, MusicCatalogResourceRequest, MusicItem, Song, Album, Playlist, queue, playback |
| Music Understanding | iOS 27+ | [reference/music-understanding.md](reference/music-understanding.md) | Music Understanding, audio analysis, beat detection, chord recognition, MusicKit |
| NowPlaying | iOS 27+ | [reference/nowplaying.md](reference/nowplaying.md) | NowPlaying, MediaSession, lock screen controls, SharePlay, remote playback |
| SF Symbols | iOS 18+ / iOS 19+ | [reference/sf-symbols.md](reference/sf-symbols.md) | SF Symbols, Wiggle, Rotate, Breathe, Draw, Draw On, Draw Off, Variable Draw, Magic Replace, Gradient, symbolEffect, symbol animation |
| SpeechAnalyzer | iOS 26+ | [reference/speech-analyzer.md](reference/speech-analyzer.md) | SpeechAnalyzer, SpeechTranscriber, DictationTranscriber, speech-to-text, live transcription, ASR, AssetInventory, SFSpeechRecognizer replacement, volatile results, audioTimeRange, on-device transcription |
| SwiftData Updates | iOS 18+ / iOS 26+ / iOS 27+ | [reference/swiftdata.md](reference/swiftdata.md) | SwiftData, @Query sectionBy, @Attribute(.codable), ResultsObserver, HistoryObserver, @Model inheritance, HistoryDescriptor, @Index, @Unique, fetchHistory, deleteHistory, DataStore, ModelContext |
| SwiftUI 2025 Updates | iOS 26+ | [reference/swiftui-2025.md](reference/swiftui-2025.md) | SwiftUI 2025, Liquid Glass, glassEffect, buttonStyle glass, ToolbarSpacer, scrollEdgeEffectStyle, backgroundExtensionEffect, tabBarMinimizeBehavior, TabRole.search, WebView, WebPage, draggable, dragContainer, Animatable, AttributedTextSelection, FindContext, AssistiveAccess, ResolvedHDR, UIHostingSceneDelegate, manipulable, SpatialContainer, RemoteImmersiveSpace |
| SwiftUI 2026 Updates | iOS 27+ / Xcode 27+ | [reference/swiftui-2026.md](reference/swiftui-2026.md) | SwiftUI 2026, ContentBuilder, @ContentBuilder, reorderable, reorderContainer, swipeActionsContainer, ToolbarOverflowMenu, visibilityPriority, topBarPinnedTrailing, toolbarMinimizeBehavior, ReadableDocument, WritableDocument, AsyncImage cache, asyncImageURLSession, alert item, confirmationDialog item, TabRole.prominent, crossFade, GestureInputKinds, @State macro |
| SwiftUI Advanced Graphics | iOS 17+ / iOS 18+ | [reference/swiftui-advanced-graphics.md](reference/swiftui-advanced-graphics.md) | Metal shader, layerEffect, colorEffect, distortionEffect, TimelineView, domain warping, SwiftUI graphics, visual effects |
| Swift Concurrency | Swift 6.2+ | [reference/swift-concurrency.md](reference/swift-concurrency.md) | Embracing Swift concurrency, Approachable Concurrency, Default Actor Isolation MainActor, @concurrent, nonisolated, Sendable, actor, Task interleaving, SWIFT_APPROACHABLE_CONCURRENCY, SWIFT_DEFAULT_ACTOR_ISOLATION, WWDC 268 |
| Swift Concurrency Code-along | Swift 6.2+ / SwiftUI | [reference/swift-concurrency-code-along.md](reference/swift-concurrency-code-along.md) | Elevate app with Swift concurrency, sticker sample, async loadTransferable, .task LazyHStack, nonisolated @concurrent PhotoProcessor, async let parallel, data race ColorExtractor, visualEffect capture list, TaskGroup processAllPhotos, WWDC 270 |
| Structured Concurrency | Swift 5.5+ / 5.9+ | [reference/structured-concurrency.md](reference/structured-concurrency.md) | Beyond basics structured concurrency, task tree, cancellation cooperative, withTaskCancellationHandler, priority escalation, TaskGroup limit concurrency, DiscardingTaskGroup, TaskLocal, SwiftLog MetadataProvider, withSpan distributed tracing, WWDC 2023 10170 |
| SwiftUI Concurrency | Swift 6+ / SwiftUI | [reference/swiftui-concurrency.md](reference/swiftui-concurrency.md) | SwiftUI concurrency, @MainActor, Sendable, data race, visualEffect capture, Task, withAnimation, sync UI async model, Shape path background, Layout Sendable, onGeometryChange, Swift 6.2 default actor isolation, Mutex |
| Vision Framework | iOS 18+ / macOS 15+ | [reference/vision.md](reference/vision.md) | Vision, ImageRequestHandler, TargetedImageRequestHandler, VideoProcessor, RecognizeTextRequest, DetectTrajectoriesRequest, TrackOpticalFlowRequest, TrackHomographicImageRegistrationRequest, DetectBarcodesRequest, swift-native Vision API |
| Vision Image Understanding | iOS 27+ / watchOS 27+ | [reference/vision-image-understanding.md](reference/vision-image-understanding.md) | tap to segment, GenerateIterativeSegmentationRequest, seedPoint, addIncludedPoint, addExcludedPoint, DownloadableAssetsRequest, Foundation Models image, ImageReference, BarcodeReaderTool, OCRTool, WWDC 237 |

---

## How to Add a New Feature

1. Create a reference file: `skills/ios-new-features/reference/your-feature.md`
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
