import Foundation
import STTAdapters
import SwiftUI

struct ContentView: View {
    @State private var executablePath = "/opt/homebrew/bin/whisper-cli"
    @State private var modelPath = "/opt/homebrew/share/whisper-cpp/ggml-medium.en.bin"
    @State private var recoveryFailed = false

    private var filesFound: Bool {
        FileManager.default.isExecutableFile(atPath: executablePath)
            && FileManager.default.isReadableFile(atPath: modelPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local transcription baseline").font(.title2)
            Text("This first build provides file benchmarks. Live microphone recording comes next.")
            if recoveryFailed {
                Text("Old session files could not be removed. Check temporary-folder permissions.")
                    .foregroundStyle(.red)
            }
            Form {
                TextField("whisper.cpp executable", text: $executablePath)
                    .accessibilityIdentifier("setup.executable")
                TextField("Speech model", text: $modelPath)
                    .accessibilityIdentifier("setup.model")
            }
            Label(
                filesFound
                    ? "Files found. Run the benchmark to verify the model."
                    : "Check the executable and model paths.",
                systemImage: filesFound ? "checkmark.circle" : "exclamationmark.triangle")
            Text(
                "From the project folder, run: swift run STTBenchmark --report .local/baseline.json"
            )
            .font(.callout.monospaced())
            .textSelection(.enabled)
            Text(
                "The paths above are setup checks for this window. Pass custom paths to the benchmark with --executable and --model."
            )
            .font(.caption)
            Button("Record — available in the next build") {}
                .disabled(true)
        }
        .padding(24)
        .task {
            let cleanup = Task.detached { try WhisperSessionRecovery.removeAbandoned() }
            do { try await cleanup.value } catch { recoveryFailed = true }
        }
    }
}
