import STTAdapters
import SwiftUI

@main
struct STTPracticeApp: App {
    @NSApplicationDelegateAdaptor(PracticeAppDelegate.self) private var delegate
    @State private var session: SessionModel

    init() {
        let setup = PracticeSetup()
        _session = State(
            initialValue: SessionModel(
                capture: MicrophoneCaptureService(), clipboard: Clipboard(),
                setup: { try await setup.check($0) },
                transcriber: { configuration in
                    WhisperCppTranscriber(
                        executableURL: URL(fileURLWithPath: configuration.executablePath),
                        modelURL: URL(fileURLWithPath: configuration.modelPath))
                }))
    }

    var body: some Scene {
        Window("STT Practice", id: "practice") {
            ContentView(session: session)
                .onAppear { delegate.session = session }
        }
        .defaultSize(width: 820, height: 720)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
