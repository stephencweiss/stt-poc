import STTCore
import SwiftUI

struct ContentView: View {
    @Bindable var session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local dictation practice").font(.title2)
            DisclosureGroup("Local setup") {
                TextField("whisper.cpp executable", text: $session.configuration.executablePath)
                TextField("Speech model", text: $session.configuration.modelPath)
                Button("Check setup") { session.requestSetupCheck() }
                    .disabled(session.state.isBusy || !session.rawText.isEmpty)
            }
            .disabled(session.state.isBusy)
            HStack {
                Button("Record") { session.record() }
                    .disabled(!session.canRecord)
                    .accessibilityIdentifier("record")
                Button("Stop") { session.stop() }.disabled(session.state != .recording)
                Button("Cancel") { session.cancel() }
                    .disabled(
                        ![.starting, .recording, .stopping, .transcribing].contains(session.state))
                Button("New Note") { session.newNote() }
                    .disabled(session.state.isBusy)
                Spacer()
                Text(
                    String(
                        format: "%.1f / %.0f seconds", session.durationSeconds,
                        RecordingConfiguration.maximumDurationSeconds)
                )
                .monospacedDigit()
            }
            ProgressView(value: Double(session.level), total: 1)
                .accessibilityLabel("Microphone input level")
            Text(session.message).textSelection(.enabled)
            if [.starting, .stopping, .transcribing, .cancelling].contains(session.state) {
                ProgressView().controlSize(.small)
            }
            Text("Edit note").font(.headline)
            TextEditor(text: $session.editedText)
                .font(.body)
                .border(.secondary.opacity(0.3))
                .disabled(session.state != .ready)
                .accessibilityIdentifier("note.editor")
            DisclosureGroup("Raw transcript") {
                ScrollView {
                    Text(session.rawText.isEmpty ? "No transcript yet." : session.rawText)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(maxHeight: 120)
            }
            HStack {
                Button("Copy Note") { session.copyNote() }.disabled(session.state != .ready)
                Text(copyMessage).foregroundStyle(.secondary)
                Spacer()
                Button("Export practice sample…") { exportSample() }
                    .disabled(session.state != .ready || session.exportWAV == nil)
            }
            if !session.exportStatus.isEmpty { Text(session.exportStatus).font(.caption) }
            Text(
                "Local processing. Notes and current audio stay in memory until New Note or quit. Review all clinical facts before copy."
            )
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .task { await session.checkSetup() }
    }

    private var copyMessage: String {
        switch session.copyStatus {
        case .none: ""
        case .copied: "Copied."
        case .stale: "Note changed. Copy again."
        case .failed: "Copy failed. Try again."
        }
    }

    private func exportSample() {
        guard let sample = session.exportSnapshot() else { return }
        SampleExport.chooseDestination { directory in
            if let directory { session.exportSample(sample, to: directory) }
        }
    }
}
