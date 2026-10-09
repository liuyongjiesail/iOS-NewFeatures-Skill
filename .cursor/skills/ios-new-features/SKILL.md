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
| MusicKit Integration | iOS 26+ | [reference/musickit.md](../../skills/ios-new-features/reference/musickit.md) | MusicKit, Apple Music, MusicAuthorization, musicPicker, musicSubscriptionOffer, MusicSubscription, ApplicationMusicPlayer, SystemMusicPlayer, ArtworkImage, MusicCatalogResourceRequest, MusicItem, Song, Album, Playlist, queue, playback |
| HealthKit Medications | iOS 26+ | [reference/healthkit-medications.md](../../skills/ios-new-features/reference/healthkit-medications.md) | HealthKit, medications, HKUserAnnotatedMedication, HKMedicationDoseEvent, HKMedicationConcept, dose event, RxNorm, per-object authorization, medication tracking, HKAnchoredObjectQuery |
| HealthKit Workouts on iOS | iOS 26+ | [reference/healthkit-workout-ios.md](../../skills/ios-new-features/reference/healthkit-workout-ios.md) | HealthKit, workout, HKWorkoutSession, HKLiveWorkoutBuilder, HKLiveWorkoutDataSource, workout on iPhone, iPad workout, crash recovery, recoverActiveWorkoutSession, Siri workout intent, INStartWorkoutIntent, workout live activity |
| App Intents | iOS 18 / iOS 26 新特性 | [reference/app-intents.md](../../skills/ios-new-features/reference/app-intents.md) | App Intent Domains, @AppIntent(schema:), @AppEntity(schema:), @AppEnum(schema:), assistant schema, .mail, .photos, .browser, .fileManagement, ControlConfigurationIntent, CameraCaptureIntent, AudioRecordingIntent, IndexedEntity, FileEntity, UniqueAppEntity, URLRepresentableIntent, @UnionValue, AppIntentsPackage, @ComputedProperty, SnippetIntent, TargetContentProvidingIntent, IntentValueQuery, IntentModes, appEntityIdentifier |
| SpeechAnalyzer | iOS 26+ | [reference/speech-analyzer.md](../../skills/ios-new-features/reference/speech-analyzer.md) | SpeechAnalyzer, SpeechTranscriber, DictationTranscriber, speech-to-text, live transcription, ASR, AssetInventory, SFSpeechRecognizer replacement, volatile results, audioTimeRange, on-device transcription |
| SwiftData Updates | iOS 18+ / iOS 26+ / iOS 27+ | [reference/swiftdata.md](../../skills/ios-new-features/reference/swiftdata.md) | SwiftData, @Query sectionBy, @Attribute(.codable), ResultsObserver, HistoryObserver, @Model inheritance, HistoryDescriptor, @Index, @Unique, fetchHistory, deleteHistory, DataStore, ModelContext |
| SwiftUI 2025 Updates | iOS 26+ | [reference/swiftui-2025.md](../../skills/ios-new-features/reference/swiftui-2025.md) | SwiftUI 2025, Liquid Glass, glassEffect, buttonStyle glass, ToolbarSpacer, scrollEdgeEffectStyle, backgroundExtensionEffect, tabBarMinimizeBehavior, TabRole.search, WebView, WebPage, draggable, dragContainer, Animatable, AttributedTextSelection, FindContext, AssistiveAccess, ResolvedHDR, UIHostingSceneDelegate, manipulable, SpatialContainer, RemoteImmersiveSpace |
| SwiftUI 2026 Updates | iOS 27+ / Xcode 27+ | [reference/swiftui-2026.md](../../skills/ios-new-features/reference/swiftui-2026.md) | SwiftUI 2026, ContentBuilder, @ContentBuilder, reorderable, reorderContainer, swipeActionsContainer, ToolbarOverflowMenu, visibilityPriority, topBarPinnedTrailing, toolbarMinimizeBehavior, ReadableDocument, WritableDocument, AsyncImage cache, asyncImageURLSession, alert item, confirmationDialog item, TabRole.prominent, crossFade, GestureInputKinds, @State macro |
| Swift Concurrency | Swift 6.2+ | [reference/swift-concurrency.md](../../skills/ios-new-features/reference/swift-concurrency.md) | Embracing Swift concurrency, Approachable Concurrency, Default Actor Isolation MainActor, @concurrent, nonisolated, Sendable, actor, Task interleaving, SWIFT_APPROACHABLE_CONCURRENCY, SWIFT_DEFAULT_ACTOR_ISOLATION, WWDC 268 |
| Swift Concurrency Code-along | Swift 6.2+ / SwiftUI | [reference/swift-concurrency-code-along.md](../../skills/ios-new-features/reference/swift-concurrency-code-along.md) | Elevate app with Swift concurrency, sticker sample, async loadTransferable, .task LazyHStack, nonisolated @concurrent PhotoProcessor, async let parallel, data race ColorExtractor, visualEffect capture list, TaskGroup processAllPhotos, WWDC 270 |
| Structured Concurrency | Swift 5.5+ / 5.9+ | [reference/structured-concurrency.md](../../skills/ios-new-features/reference/structured-concurrency.md) | Beyond basics structured concurrency, task tree, cancellation cooperative, withTaskCancellationHandler, priority escalation, TaskGroup limit concurrency, DiscardingTaskGroup, TaskLocal, SwiftLog MetadataProvider, withSpan distributed tracing, WWDC 2023 10170 |
| SwiftUI Concurrency | Swift 6+ / SwiftUI | [reference/swiftui-concurrency.md](../../skills/ios-new-features/reference/swiftui-concurrency.md) | SwiftUI concurrency, @MainActor, Sendable, data race, visualEffect capture, Task, withAnimation, sync UI async model, Shape path background, Layout Sendable, onGeometryChange, Swift 6.2 default actor isolation, Mutex |
| Vision Framework | iOS 18+ / macOS 15+ | [reference/vision.md](../../skills/ios-new-features/reference/vision.md) | Vision, ImageRequestHandler, TargetedImageRequestHandler, VideoProcessor, RecognizeTextRequest, DetectTrajectoriesRequest, TrackOpticalFlowRequest, TrackHomographicImageRegistrationRequest, DetectBarcodesRequest, swift-native Vision API |
| Vision Image Understanding | iOS 27+ / watchOS 27+ | [reference/vision-image-understanding.md](../../skills/ios-new-features/reference/vision-image-understanding.md) | tap to segment, GenerateIterativeSegmentationRequest, seedPoint, addIncludedPoint, addExcludedPoint, DownloadableAssetsRequest, Foundation Models image, ImageReference, BarcodeReaderTool, OCRTool, WWDC 237 |

---

## How to Add a New Feature

1. Create a reference file: `skills/ios-new-features/reference/your-feature.md`
2. Add a row to the Feature Index table above (in both `skills/ios-new-features/SKILL.md` and `.cursor/skills/ios-new-features/SKILL.md`)
3. Format: feature name, minimum iOS version, file path, trigger keywords
