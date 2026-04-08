# SpeechAnalyzer (iOS 26+)

Source: WWDC 2025 Session 277 — "Meet SpeechAnalyzer" / [Apple Documentation](https://developer.apple.com/documentation/speech/speechanalyzer)

## Overview
New speech-to-text API replacing `SFSpeechRecognizer` (iOS 10). Built with Swift, runs entirely on-device, supports long-form audio, live transcription with low latency, and returns results via async sequences.

---

## SpeechAnalyzer

```swift
// Initializers
init(modules: [SpeechAnalysisModule])
init(modules: [SpeechAnalysisModule], options: SpeechAnalyzer.Options?)

// Static — get best audio format for your modules
static func bestAvailableAudioFormat(
    compatibleWith modules: [SpeechAnalysisModule]
) async -> AVAudioFormat?

// Feed from AsyncStream (live mic use case)
func start(inputSequence: AsyncStream<AnalyzerInput>) async

// Feed from audio file
func start(inputAudioFile: URL, finishAfterFile: Bool) async
func analyzeSequence(from url: URL) async   // convenience — finishAfterFile: true

// Finalize
func finalizeAndFinish(through framePosition: AVAudioFramePosition) async
func finalizeAndFinishThroughEndOfInput() async
```

### SpeechAnalyzer.Options

```swift
struct Options {
    enum ModelRetention {
        case processLifetime   // keep model loaded for the app's lifetime
    }
    var modelRetention: ModelRetention
}
```

---

## SpeechTranscriber

```swift
// Full initializer
init(
    locale: Locale,
    transcriptionOptions: [SpeechTranscriber.TranscriptionOptions] = [],
    reportingOptions: [SpeechTranscriber.ReportingOption] = [],
    attributeOptions: [SpeechTranscriber.ResultAttributeOption] = []
)

// Preset-based initializer (recommended for common use cases)
init(locale: Locale, preset: SpeechTranscriber.Preset)

// Results stream
var results: AsyncSequence<SpeechTranscriptionResult>

// Device / locale support
static func supportsDevice() -> Bool
static var supportedLocales: AsyncSequence<Locale>
static var installedLocales: AsyncSequence<Locale>
```

### SpeechTranscriber.Preset

| Preset | Use Case |
|--------|----------|
| `.offlineTranscription` | Batch / file transcription, highest accuracy |
| `.progressiveLiveTranscription` | Live mic input, low latency with volatile results |

### SpeechTranscriber.ReportingOption

| Option | Description |
|--------|-------------|
| `.volatileResults` | Deliver quick-but-rough guesses before finalization |
| `.fastResults` | Bias toward speed; faster but less accurate |

### SpeechTranscriber.ResultAttributeOption

| Option | Description |
|--------|-------------|
| `.audioTimeRange` | Attach `CMTimeRange` to each run in the `AttributedString` |
| `.transcriptionConfidence` | Attach confidence score to each run |

### Supported Locales
ar_SA, da_DK, de_AT, de_CH, de_DE, en_AU, en_CA, en_GB, en_IE, en_IN, en_NZ, en_SG, en_US, en_ZA, es_CL, es_ES, es_MX, es_US, fi_FI, fr_BE, fr_CA, fr_CH, fr_FR, he_IL, it_CH, it_IT, ja_JP, ko_KR, ms_MY, nb_NO, nl_BE, nl_NL, pt_BR, ru_RU, sv_SE, th_TH, tr_TR, vi_VN, yue_CN, zh_CN, zh_HK, zh_TW

---

## SpeechTranscriptionResult

```swift
struct SpeechTranscriptionResult {
    var text: AttributedString   // transcription for this audio segment
    var isFinal: Bool            // false = volatile guess, true = finalized

    // When .audioTimeRange is enabled, each run in text carries:
    //   run[SpeechTranscriber.AudioTimeRangeAttribute.self] -> CMTimeRange?
    // When .transcriptionConfidence is enabled:
    //   run[SpeechTranscriber.ConfidenceAttribute.self] -> Float?
}
```

---

## AnalyzerInput

```swift
struct AnalyzerInput {
    init(buffer: AVAudioPCMBuffer)
}

// Create an input stream for live audio:
let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
continuation.yield(AnalyzerInput(buffer: pcmBuffer))
continuation.finish()   // signals end of audio
```

---

## AssetInventory

```swift
// Request model download for a set of modules
static func assetInstallationRequest(
    supporting modules: [SpeechAnalysisModule]
) async -> AssetInstallationRequest   // has .progress: Progress

// Check install status
static func status(forModules modules: [SpeechAnalysisModule]) async -> AssetStatus

// How many locales can be reserved simultaneously
static var maximumReservedLocales: Int

// Currently reserved locales
static var reservedLocales: [Locale]

// Free up a reserved locale slot
static func release(reservedLocale locale: Locale) async
```

---

## DictationTranscriber

Drop-in fallback for devices/languages not supported by `SpeechTranscriber`.
Uses the same on-device model as iOS 10 `SFSpeechRecognizer` — no Siri/Settings requirement.

```swift
init(locale: Locale)
init(locale: Locale, preset: SpeechTranscriber.Preset)

var results: AsyncSequence<SpeechTranscriptionResult>

// Content hints for better accuracy
enum ContentHint {
    case customizedLanguage(modelConfiguration: LanguageModelConfiguration)
}
```

---

## Common Patterns

### 1 — Transcribe a File (simple)

```swift
import Speech

func transcribe(fileURL: URL) async throws -> AttributedString {
    let transcriber = SpeechTranscriber(
        locale: Locale(identifier: "en-US"),
        preset: .offlineTranscription
    )

    async let transcription = transcriber.results.reduce(into: AttributedString()) { acc, result in
        acc += result.text
    }

    let analyzer = SpeechAnalyzer(modules: [transcriber])
    await analyzer.analyzeSequence(from: fileURL)

    return try await transcription
}
```

### 2 — Live Transcription (volatile + finalized)

```swift
@Observable
class SpokenWordTranscriber {
    var volatileTranscript = AttributedString()
    var finalizedTranscript = AttributedString()

    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    func start(locale: Locale) async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveLiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        // Ensure model is installed
        try await ensureModel(for: transcriber)

        // Wire up input stream
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.continuation = continuation
        Task { await analyzer.start(inputSequence: stream) }

        // Consume results
        resultsTask = Task { @MainActor in
            for await result in transcriber.results {
                if result.isFinal {
                    finalizedTranscript += result.text
                    volatileTranscript = AttributedString()   // prevent duplicates
                } else {
                    volatileTranscript = result.text
                }
            }
        }
    }

    func addAudio(_ buffer: AVAudioPCMBuffer) {
        continuation?.yield(AnalyzerInput(buffer: buffer))
    }

    func stop() async {
        continuation?.finish()
        await resultsTask?.value
    }

    var displayTranscript: AttributedString { finalizedTranscript + volatileTranscript }
}
```

### 3 — Model Management

```swift
func ensureModel(for transcriber: SpeechTranscriber) async throws {
    guard await SpeechTranscriber.supportsDevice() else {
        throw TranscriberError.unsupportedDevice
    }

    // Check if locale is supported
    let locale = Locale(identifier: "en-US")
    let supported = await SpeechTranscriber.supportedLocales.contains(locale)
    guard supported else { throw TranscriberError.unsupportedLocale }

    // Already installed?
    let installed = await SpeechTranscriber.installedLocales.contains(locale)
    if installed { return }

    // Check slot availability
    if AssetInventory.reservedLocales.count >= AssetInventory.maximumReservedLocales {
        // Free oldest slot
        if let toRelease = AssetInventory.reservedLocales.first {
            await AssetInventory.release(reservedLocale: toRelease)
        }
    }

    // Download
    let request = await AssetInventory.assetInstallationRequest(supporting: [transcriber])
    // Observe request.progress to show download UI
    _ = try await request.progress.fractionCompleted   // waits until 1.0
}
```

### 4 — Audio Input via AVAudioEngine

```swift
// Get best format before setting up the tap
let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    ?? AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
try AVAudioSession.sharedInstance().setActive(true)

let engine = AVAudioEngine()
engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
    transcriber.addAudio(buffer)   // route to your SpokenWordTranscriber
}
engine.prepare()
try engine.start()
```

### 5 — Highlight Words During Playback

```swift
// Build attributed string with timing during transcription:
//   SpeechTranscriber(locale:, attributeOptions: [.audioTimeRange])

// During AVPlayer/AVAudioPlayer playback:
func highlightedTranscript(
    _ transcript: AttributedString,
    at currentTime: CMTime
) -> AttributedString {
    var attributed = transcript
    for run in transcript.runs {
        guard let range = run[SpeechTranscriber.AudioTimeRangeAttribute.self] else { continue }
        let isActive = range.containsTime(currentTime)
        attributed[run.range].foregroundColor = isActive ? .yellow : .primary
    }
    return attributed
}

// Use in SwiftUI:
Text(highlightedTranscript(story.finalTranscript, at: player.currentTime()))
    .onReceive(timer) { _ in /* re-evaluate each frame */ }
```

---

## ⚠️ Important Notes

- **Replaces `SFSpeechRecognizer`** — use `SpeechAnalyzer` for all new iOS 26+ work.
- **On-device only** — model must be downloaded via `AssetInventory` before first use; no server fallback.
- **Model lives in system storage** — does not count toward your app's size or runtime memory budget.
- **Per-app locale limit** — check `AssetInventory.maximumReservedLocales`; release unused locales before requesting new ones.
- **Clear volatile results** on every finalized result to avoid duplicate text.
- **Call `continuation.finish()`** (or `finalizeAndFinishThroughEndOfInput()`) when recording stops — otherwise the results stream never closes.
- **Use `SpeechAnalyzer.bestAvailableAudioFormat`** to get the optimal format before configuring `AVAudioEngine`.
- **Preset `.progressiveLiveTranscription`** automatically enables volatile results and low-latency mode.
- **Available platforms**: iOS 26+, macOS, iPadOS, visionOS — **not watchOS**.
- Model updates are delivered automatically by the system.
