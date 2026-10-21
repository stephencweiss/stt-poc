# Product Requirement Document (PRD) & Technical Specification

## Core System Architecture & Scope

### Project Overview
The **Offline Medical Speech-to-Text (STT) Procedure Logger** is a local-first macOS application designed for interventional cardiologists and clinical operators. It transcribes spoken procedure logs (targeting **TAVR** initially) into structured clinical notes without sending audio or transcript data over external networks.

The system prioritizes **100% offline data privacy**, **zero-hallucination post-processing**, and **minimal operator friction** via global hotkeys and auto-clipboard integration.

---

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            LOCAL MACOS ENVIRONMENT                          │
│                                                                             │
│  ┌───────────────────────────┐         Global Hotkey: Cmd+Shift+R           │
│  │    SwiftUI Floating Panel │ ◄─────────────────────────────────────────┐  │
│  │ (Editable Note & Controls)│                                           │  │
│  └─────────────┬─────────────┘                                           │  │
│                │ 16kHz PCM Stream                                        │  │
│                ▼                                                         │  │
│  ┌───────────────────────────┐       ┌────────────────────────────────┐  │  │
│  │ Silero VAD Pre-Processor  │ ────► │ WhisperKit Core ML ANE Engine  │  │  │
│  │  (Filters non-speech audio│       │ (initial_prompt: TAVR Jargon)  │  │  │
│  └───────────────────────────┘       └───────────────┬────────────────┘  │  │
│                                                      │ Raw Text          │  │
│                                                      ▼                   │  │
│  ┌───────────────────────────┐       ┌────────────────────────────────┐  │  │
│  │   macOS NSPasteboard      │ ◄──── │ Deterministic Rule/RegEx Parser│  │  │
│  │   (Auto-Copied Output)    │       │ (Normalizes Units & Headings)  │  │  │
│  └───────────────────────────┘       └────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. System Specifications & Architectural Choices

### Target Pilot Procedure
* **Specialty:** Interventional Cardiology
* **Procedure:** Transcatheter Aortic Valve Replacement (TAVR)
* **Key Domain Jargon:** Edwards SAPIEN 3, Medtronic Evolut PRO/FX, femoral arterial access, balloon aortic valvuloplasty (BAV), rapid ventricular pacing, transesophageal echocardiography (TEE), paravalvular leak (PVL), sheath size (e.g., 14Fr, 16Fr eSheath), gradient (mean/peak), coronary obstruction.

### Processing Pipeline Strategy
* **Formatting Engine (MVP):** **Deterministic / RegEx-Based Rule Engine (Option B)**.
  * *Rationale:* Guarantees **zero hallucinated text**. Only formats what the clinician explicitly states. Converts numbers to standardized notation (e.g., *"sixteen french"* $\rightarrow$ *"16 Fr"*), structures explicit headers, and cleans up common phonetic misinterpretations.
  * *Extensibility:* Interface is abstract (`NoteFormatterProtocol`) to easily swap in local LLM engines (e.g., Apple Foundation Models or Ollama) in future releases.
* **Global Trigger Hotkey:** `Cmd + Shift + R` (Option A).
* **Target Hardware:** Apple Silicon Macs (M1/M2/M3/M4) running macOS 14.0+.

---

## 2. Technical Stack & Dependencies

| Component | Framework / Library | Description |
| :--- | :--- | :--- |
| **User Interface** | SwiftUI + `NSPanel` | Floating, always-on-top utility panel over EHR browser/desktop. |
| **Speech-to-Text Engine** | `WhisperKit` | Native Swift engine executing Core ML models on Apple Neural Engine (ANE). |
| **Voice Activity Detection** | `Silero VAD` (Core ML) | 2MB ONNX/CoreML model filtering non-speech frames prior to ASR. |
| **Audio Processing** | `AVAudioEngine` | Captures microphone input at 16kHz Float32 mono PCM. |
| **Post-Processing** | Custom Swift RegEx Parser | Lexicon lookup and deterministic normalization. |
| **System Output** | `NSPasteboard` | Automatic writing to macOS system clipboard. |

---

## 3. Component Details & Swift Protocols

### A. Transcriber Service Protocol
Decouples the core application UI from the underlying STT engine to allow future engine swapping.

```swift
import Foundation

public struct TranscriptionSegment {
    public let text: String
    public let startTime: Double
    public let endTime: Double
}

public protocol TranscriberService {
    func initialize(modelName: String) async throws
    func transcribe(
        audioSamples: [Float],
        initialPrompt: String?
    ) async throws -> [TranscriptionSegment]
    func unloadModel() async
}
```

### B. Dynamic TAVR Context Prompting
Passed to `WhisperKit` via `initialPrompt` to bias Transformer decoding toward complex interventional cardiology terms:

```swift
public struct TAVRContextPrompts {
    public static let defaultPrompt = """
    TAVR Procedure Note: Transcatheter Aortic Valve Replacement, Edwards SAPIEN 3 Ultra, \
    Medtronic Evolut PRO FX, eSheath, 14Fr, 16Fr, femoral artery access, balloon aortic valvuloplasty, \
    rapid pacing, 180 bpm, transesophageal echocardiogram, TEE, paravalvular leak, PVL, \
    mean gradient, peak velocity, fluoroscopy time, contrast volume, protamine reversal.
    """
}
```

### C. Deterministic Post-Processor Engine Interface
Ensures strict transformation of raw text without synthetic additions:

```swift
public protocol NoteFormatterProtocol {
    func format(rawTranscript: String) -> String
}

public class DeterministicTAVRFormatter: NoteFormatterProtocol {
    private let replacementDictionary: [String: String] = [
        "edwards sapien three": "Edwards SAPIEN 3",
        "edward sapien": "Edwards SAPIEN",
        "medtronic evolute": "Medtronic Evolut",
        "e sheath": "eSheath",
        "french": "Fr",
        "paravalvular leak": "paravalvular leak (PVL)",
        "pvl": "PVL",
        "bae": "BAV",
        "balloon aortic valvuloplasty": "balloon aortic valvuloplasty (BAV)",
        "tee": "TEE"
    ]

    public func format(rawTranscript: String) -> String {
        var processedText = rawTranscript

        // 1. Phonetic Replacements
        for (phrase, replacement) in replacementDictionary {
            processedText = processedText.replacingOccurrences(
                of: "\\b\(phrase)\\b",
                with: replacement,
                options: [.caseInsensitive, .regularExpressionSearch]
            )
        }

        // 2. Unit Normalization (e.g., "16 french" -> "16 Fr", "180 beats per minute" -> "180 bpm")
        processedText = processedText.replacingOccurrences(
            of: "(\\d+)\\s*french",
            with: "$1 Fr",
            options: [.caseInsensitive, .regularExpressionSearch]
        )
        
        processedText = processedText.replacingOccurrences(
            of: "(\\d+)\\s*milligrams",
            with: "$1 mg",
            options: [.caseInsensitive, .regularExpressionSearch]
        )

        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

---

## 4. Ground-Truth Test Suite Specification

To validate model accuracy, latency, and Word Error Rate (WER), the project includes a local 15-file test harness.

### Test Dataset Directory Structure
```text
/TAVR_Benchmark_Suite
  ├── /audio
  │     ├── tavr_01_baseline_sapien.wav
  │     ├── tavr_02_evolut_rapid_pace.wav
  │     ├── tavr_03_jargon_heavy_pvl.wav
  │     ├── ...
  │     └── tavr_15_noisy_cath_lab.wav
  └── /ground_truth
        ├── tavr_01_baseline_sapien.txt
        ├── tavr_02_evolut_rapid_pace.txt
        ├── tavr_03_jargon_heavy_pvl.txt
        ├── ...
        └── tavr_15_noisy_cath_lab.txt
```

### XCTest Accuracy Harness

```swift
import XCTest
@testable import TAVRProcedureLogger

final class TAVRBenchmarkTests: XCTestCase {
    var transcriber: TranscriberService!
    var formatter: NoteFormatterProtocol!

    override func setUp() async throws {
        transcriber = WhisperKitEngine()
        try await transcriber.initialize(modelName: "openai_whisper-large-v3-turbo")
        formatter = DeterministicTAVRFormatter()
    }

    func testBenchmarkSuiteAccuracy() async throws {
        let bundle = Bundle(for: type(of: self))
        guard let audioURLs = bundle.urls(forResourcesWithExtension: "wav", subdirectory: "TAVR_Benchmark_Suite/audio") else {
            XCTFail("Missing audio test samples")
            return
        }

        for audioURL in audioURLs {
            let baseName = audioURL.deletingPathExtension().lastPathComponent
            guard let truthURL = bundle.url(forResource: baseName, withExtension: "txt", subdirectory: "TAVR_Benchmark_Suite/ground_truth") else {
                continue
            }

            let groundTruth = try String(contentsOf: truthURL).trimmingCharacters(in: .whitespacesAndNewlines)
            let pcmBuffer = try AudioUtils.loadPCMBuffer(from: audioURL)

            let segments = try await transcriber.transcribe(audioSamples: pcmBuffer, initialPrompt: TAVRContextPrompts.defaultPrompt)
            let rawText = segments.map { $0.text }.joined(separator: " ")
            let formattedText = formatter.format(rawTranscript: rawText)

            print("==================================================")
            print("SAMPLE: \(baseName)")
            print("RAW:       \(rawText)")
            print("FORMATTED: \(formattedText)")
            print("TRUTH:     \(groundTruth)")
            
            // Assert essential domain terminology survived transcription
            if groundTruth.contains("SAPIEN 3") {
                XCTAssertTrue(formattedText.contains("SAPIEN 3"), "Failed to transcribe SAPIEN 3 in \(baseName)")
            }
        }
    }
}
```

---

## 5. MVP UI Layout Specification

A floating, persistent window (`NSPanel`) designed to sit on top of EHR web applications.

```text
┌─────────────────────────────────────────────────────────────────┐
│ 🔴 Recording... [Cmd+Shift+R]            TAVR Log Assistant  ⚙  │
├─────────────────────────────────────────────────────────────────┤
│ Formatted Clinical Output (Editable Text)                       │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ PROCEDURE: Transcatheter Aortic Valve Replacement (TAVR)   │ │
│ │ ACCESS: Right common femoral artery via 14 Fr eSheath.     │ │
│ │ VALVE IMPLANT: 26 mm Edwards SAPIEN 3 Ultra valve.          │ │
│ │ PACING: Rapid ventricular pacing at 180 bpm during BAV.     │ │
│ │ RESULTS: Post-implant TEE shows mean gradient of 4 mmHg    │ │
│ │ and trace paravalvular leak (PVL). No coronary obstruction. │ │
│ └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ 📋 Copied to Clipboard automatically!               [Copy Note] │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Execution Roadmap & Milestones

1. **Milestone 1: Audio Test Suite Setup (Day 1)**
   * Convert 10–15 TAVR voice recordings to 16kHz mono `.wav` files using `ffmpeg`.
   * Create matching ground-truth `.txt` files.
2. **Milestone 2: Engine Integration & Benchmark Run (Day 2)**
   * Integrate `WhisperKit` package via SPM.
   * Run the XCTest suite to verify baseline WER on TAVR jargon with `TAVRContextPrompts`.
3. **Milestone 3: RegEx Formatter Engine (Day 3)**
   * Build `DeterministicTAVRFormatter` and add unit tests for unit conversions and medical acronym normalization.
4. **Milestone 4: Floating UI & Global Hotkey (Day 4)**
   * Implement floating `NSPanel` using SwiftUI.
   * Register system-wide `Cmd + Shift + R` hotkey for record/stop toggling.
   * Connect output directly to `NSPasteboard`.