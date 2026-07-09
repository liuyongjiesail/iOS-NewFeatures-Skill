# iOS New Features Reference (Codex)

This is a knowledge base of Swift and SwiftUI APIs introduced **after the AI training cutoff**
(iOS 18+ / iOS 26+, WWDC 2023–2025). Codex does not auto-trigger skills, so use this file as the
entry point: when a request matches any trigger keyword below, **read the matching reference file
before writing code**. Do not answer newer-iOS API questions from memory alone.

## When to consult a reference

Read the corresponding `reference/<file>.md` when the user's request mentions any of the trigger
keywords, a specific WWDC session, or targets iOS 18 and newer.

## Feature Index

| Feature | Version | Reference File | Trigger Keywords |
|---------|---------|----------------|-----------------|
| AlarmKit | iOS 26+ | [reference/alarmkit.md](reference/alarmkit.md) | alarm, timer alert, AlarmKit, override silent mode, countdown alert, Live Activity alarm |
| App Intents | iOS 18 / iOS 26 | [reference/app-intents.md](reference/app-intents.md) | App Intent Domains, @AppIntent(schema:), @AppEntity(schema:), @AppEnum(schema:), assistant schema, .mail, .photos, .browser, .fileManagement, ControlConfigurationIntent, CameraCaptureIntent, AudioRecordingIntent, IndexedEntity, FileEntity, UniqueAppEntity, URLRepresentableIntent, @UnionValue, AppIntentsPackage, @ComputedProperty, SnippetIntent, TargetContentProvidingIntent, IntentValueQuery, IntentModes, appEntityIdentifier |
| AVCapture Session | iOS 18+ | [reference/avcapture-session.md](reference/avcapture-session.md) | AVCaptureSession, zero shutter lag, deferred shutter, shutter sound customization, spatial photo capture, iOS 18 camera |
| Center Stage Front Camera | iOS 17+ | [reference/center-stage-front-camera.md](reference/center-stage-front-camera.md) | Center Stage, front camera, person tracking, video conferencing, AVCaptureDevice.isCenterStageActive |
| Core Image RAW Processing | iOS 17+ | [reference/core-image-raw-processing.md](reference/core-image-raw-processing.md) | Core Image, RAW processing, CIRAWFilter, professional photography, color grading |
| Generative Captions | iOS 27+ | [reference/generative-captions.md](reference/generative-captions.md) | GenerativeCaptions, AI captions, image description, accessibility |
| HealthKit Workout Zones | iOS 27+ | [reference/healthkit-workout-zones.md](reference/healthkit-workout-zones.md) | HealthKit, workout zones, heart rate zones, training zones, HKWorkoutZone |
| High Resolution Photo Capture | iOS 16+ | [reference/high-resolution-photo-capture.md](reference/high-resolution-photo-capture.md) | ProRAW Max, 48MP photos, high resolution capture, AVCapturePhotoOutput |
| Music Understanding | iOS 27+ | [reference/music-understanding.md](reference/music-understanding.md) | Music Understanding, audio analysis, beat detection, chord recognition, MusicKit |
| NowPlaying | iOS 27+ | [reference/nowplaying.md](reference/nowplaying.md) | NowPlaying, MediaSession, lock screen controls, SharePlay, remote playback |
| SF Symbols | iOS 18+ / iOS 19+ | [reference/sf-symbols.md](reference/sf-symbols.md) | SF Symbols, Wiggle, Rotate, Breathe, Draw, Draw On, Draw Off, Variable Draw, Magic Replace, Gradient, symbolEffect, symbol animation |
| SpeechAnalyzer | iOS 26+ | [reference/speech-analyzer.md](reference/speech-analyzer.md) | SpeechAnalyzer, SpeechTranscriber, DictationTranscriber, speech-to-text, live transcription, ASR, AssetInventory, SFSpeechRecognizer replacement, volatile results, audioTimeRange, on-device transcription |
| SwiftUI Advanced Graphics | iOS 17+ / iOS 18+ | [reference/swiftui-advanced-graphics.md](reference/swiftui-advanced-graphics.md) | Metal shader, layerEffect, colorEffect, distortionEffect, TimelineView, domain warping, SwiftUI graphics, visual effects |
| Vision Framework | iOS 18+ / macOS 15+ | [reference/vision.md](reference/vision.md) | Vision, ImageRequestHandler, RecognizeTextRequest, DetectFaceRectanglesRequest, GenerateObjectnessBasedSaliencyImageRequest, DetectBarcodesRequest, ClassifyImageRequest, swift-native Vision API, async/await Vision |
| Vision Image Understanding | iOS 18+ | [reference/vision-image-understanding.md](reference/vision-image-understanding.md) | Vision Pro, image understanding, scene analysis, object detection, VNImageRequestHandler |

## Notes

- Reference files live in `reference/` next to this file.
- The single source of truth is `skills/ios-new-features/reference/` in the upstream repository;
  the installer copies it here so Codex can read it locally.
- To add a feature: add its reference file upstream and a row to this table.
