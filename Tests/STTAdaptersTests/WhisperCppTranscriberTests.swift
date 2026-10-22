import Darwin
import Foundation
import STTCore
import XCTest

@testable import STTAdapters

final class WhisperCppTranscriberTests: XCTestCase {
    func testDecodesWhisperOffsetsAndPreservesArguments() async throws {
        let fixture = try WhisperFixture(
            body: """
                while [ "$#" -gt 0 ]; do
                  case "$1" in
                    -of) shift; output="$1" ;;
                  esac
                  shift
                done
                printf '%s' '{"transcription":[{"text":" Test note.","offsets":{"from":250,"to":1250}}]}' > "$output.json"
                """)
        defer { fixture.remove() }
        let prompt = "Retain dose; $(touch injected) 'quoted'"
        let result = try await fixture.transcriber().transcribe(
            .init(audioURL: fixture.audio, prompt: prompt))
        let arguments = try String(
            contentsOf: fixture.root.appendingPathComponent("arguments"), encoding: .utf8)
        XCTAssertTrue(arguments.contains(fixture.model.resolvingSymlinksInPath().path + "\n"))
        XCTAssertTrue(arguments.contains(fixture.audio.path + "\n"))
        XCTAssertTrue(arguments.contains("--prompt\n" + prompt + "\n"))
        XCTAssertTrue(arguments.contains("-l\nen\n"))
        try fixture.assertSessionRemoved()
        XCTAssertEqual(result.text, "Test note.")
        XCTAssertEqual(
            result.segments, [.init(text: " Test note.", startSeconds: 0.25, endSeconds: 1.25)])
        XCTAssertEqual(result.modelID, fixture.model.lastPathComponent)
        XCTAssertGreaterThanOrEqual(result.elapsedSeconds, 0)
    }
    func testResolvesSymlinkedExecutableAndModel() async throws {
        let fixture = try WhisperFixture(json: "{\"transcription\":[]}")
        defer { fixture.remove() }
        let executableLink = fixture.root.appendingPathComponent("linked whisper")
        let modelLink = fixture.root.appendingPathComponent("linked model.bin")
        try FileManager.default.createSymbolicLink(
            at: executableLink, withDestinationURL: fixture.executable)
        try FileManager.default.createSymbolicLink(at: modelLink, withDestinationURL: fixture.model)
        let transcriber = WhisperCppTranscriber(executableURL: executableLink, modelURL: modelLink)
        let result = try await transcriber.transcribe(.init(audioURL: fixture.audio))
        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.modelID, fixture.model.lastPathComponent)
        let arguments = try String(
            contentsOf: fixture.root.appendingPathComponent("arguments"), encoding: .utf8)
        XCTAssertTrue(arguments.contains(fixture.model.resolvingSymlinksInPath().path + "\n"))
        try fixture.assertSessionRemoved()
    }

    func testSilenceIsValidAndRepeatedCallsAreIndependent() async throws {
        let fixture = try WhisperFixture(json: "{\"transcription\":[]}")
        defer { fixture.remove() }
        for _ in 0..<2 {
            let result = try await fixture.transcriber().transcribe(.init(audioURL: fixture.audio))
            XCTAssertEqual(result.text, "")
            XCTAssertTrue(result.segments.isEmpty)
        }
    }

    func testInvalidJSONAndInvalidOffsetsAreRejected() async throws {
        for json in [
            "bad JSON", "{\"transcription\":[{\"text\":\"x\",\"offsets\":{\"from\":12,\"to\":1}}]}",
        ] {
            let fixture = try WhisperFixture(json: json)
            defer { fixture.remove() }
            do {
                _ = try await fixture.transcriber().transcribe(.init(audioURL: fixture.audio))
                XCTFail("Invalid JSON must fail")
            } catch {
                XCTAssertEqual(error as? WhisperCppTranscriberError, .invalidOutput)
                try fixture.assertSessionRemoved()
            }
        }
    }

    func testNonzeroExitNeverUsesDiagnosticsAsText() async throws {
        let fixture = try WhisperFixture(body: "echo 'diagnostic'; echo 'private' >&2; exit 7")
        defer { fixture.remove() }
        do {
            _ = try await fixture.transcriber().transcribe(.init(audioURL: fixture.audio))
            XCTFail("Nonzero exit must fail")
        } catch {
            XCTAssertEqual(error as? WhisperCppTranscriberError, .processFailed(exitCode: 7))
            try fixture.assertSessionRemoved()
        }
    }

    func testMissingAssetsAndInvalidAudioAreRejected() async throws {
        let fixture = try WhisperFixture(json: "{\"transcription\":[]}")
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.model)
        await assertFailure(fixture, expected: .invalidModel)
        try Data([1]).write(to: fixture.model)
        try Data("invalid".utf8).write(to: fixture.audio)
        await assertFailure(fixture, expected: .invalidAudio)
        try FileManager.default.removeItem(at: fixture.executable)
        await assertFailure(fixture, expected: .invalidExecutable)
    }

    func testTimeoutAndInvalidTimeoutAreTyped() async throws {
        let fixture = try WhisperFixture(body: "trap '' TERM; exec /bin/sleep 30")
        defer { fixture.remove() }
        await assertFailure(fixture, timeout: 3, expected: .timedOut)
        try fixture.assertSessionRemoved()
        for value in [Double.nan, Double.infinity, 0, -1] {
            await assertFailure(fixture, timeout: value, expected: .invalidTimeout)
        }
    }

    func testCancellationBeforeLaunchAndWhileRunning() async throws {
        let fixture = try WhisperFixture(body: "trap '' TERM; exec /bin/sleep 30")
        defer { fixture.remove() }
        let transcriber = fixture.transcriber()
        let audio = fixture.audio
        let task = Task { try await transcriber.transcribe(.init(audioURL: audio)) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled call must fail")
        } catch { XCTAssertTrue(error is CancellationError) }
        let running = Task { try await transcriber.transcribe(.init(audioURL: audio)) }
        do { try await fixture.waitUntilLaunched() } catch {
            running.cancel()
            throw error
        }
        running.cancel()
        do {
            _ = try await running.value
            XCTFail("Cancelled process must fail")
        } catch { XCTAssertTrue(error is CancellationError) }
        try fixture.assertSessionRemoved()
    }

    func testFloodedDiagnosticsDoNotDeadlockAndSessionIsRemoved() async throws {
        let fixture = try WhisperFixture(
            body: """
                while [ "$#" -gt 0 ]; do
                  case "$1" in -of) shift; output="$1" ;; esac
                  shift
                done
                /usr/bin/head -c 2000000 /dev/zero
                /usr/bin/head -c 2000000 /dev/zero >&2
                printf '%s' '{"transcription":[]}' > "$output.json"
                """)
        defer { fixture.remove() }
        let result = try await fixture.transcriber().transcribe(.init(audioURL: fixture.audio))
        XCTAssertEqual(result.text, "")
        try fixture.assertSessionRemoved()
    }

    func testMissingOutputIsRejectedAndRemoved() async throws {
        let fixture = try WhisperFixture(body: "exit 0")
        defer { fixture.remove() }
        await assertFailure(fixture, expected: .invalidOutput)
        try fixture.assertSessionRemoved()
    }

    func testConcurrentCallsAndLargeFiniteTimeout() async throws {
        let fixture = try WhisperFixture(json: "{\"transcription\":[]}")
        defer { fixture.remove() }
        let transcriber = fixture.transcriber(timeout: .greatestFiniteMagnitude)
        async let first = transcriber.transcribe(.init(audioURL: fixture.audio))
        async let second = transcriber.transcribe(.init(audioURL: fixture.audio))
        let results = try await [first, second]
        XCTAssertTrue(results.allSatisfy { $0.text.isEmpty })
    }

    func testRejectsUnsupportedWAVFormatAndTruncation() async throws {
        let fixture = try WhisperFixture(json: "{\"transcription\":[]}")
        defer { fixture.remove() }
        var audio = try Data(contentsOf: fixture.audio)
        audio[24] = 0
        try audio.write(to: fixture.audio)
        await assertFailure(fixture, expected: .invalidAudio)
        audio[24] = 128
        audio.removeLast()
        try audio.write(to: fixture.audio)
        await assertFailure(fixture, expected: .invalidAudio)
    }

    func testOversizedValidJSONIsRejectedAndSessionRemoved() async throws {
        let fixture = try WhisperFixture(
            body: """
                while [ "$#" -gt 0 ]; do
                  case "$1" in -of) shift; output="$1" ;; esac
                  shift
                done
                printf '%s' '{"transcription":[{"text":"' > "$output.json"
                /usr/bin/head -c 16777217 /dev/zero | /usr/bin/tr '\\000' 'x' >> "$output.json"
                printf '%s' '","offsets":{"from":0,"to":1}}]}' >> "$output.json"
                """)
        defer { fixture.remove() }
        await assertFailure(fixture, expected: .invalidOutput)
        try fixture.assertSessionRemoved()
    }

    func testExecutableWithInvalidFormatHasTypedLaunchFailure() async throws {
        let fixture = try WhisperFixture(json: "{\"transcription\":[]}")
        defer { fixture.remove() }
        try Data([0, 1, 2, 3]).write(to: fixture.executable)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.executable.path))
        await assertFailure(fixture, expected: .launchFailed)
    }

    private func assertFailure(
        _ fixture: WhisperFixture, timeout: Double = 3, expected: WhisperCppTranscriberError
    ) async {
        do {
            _ = try await fixture.transcriber(timeout: timeout).transcribe(
                .init(audioURL: fixture.audio))
            XCTFail("Expected \(expected)")
        } catch {
            XCTAssertEqual(error as? WhisperCppTranscriberError, expected)
        }
    }

}

private struct WhisperFixture {
    let root: URL
    let executable: URL
    let model: URL
    let audio: URL

    init(json: String) throws {
        try self.init(
            body: """
                while [ "$#" -gt 0 ]; do
                  case "$1" in -of) shift; output="$1" ;; esac
                  shift
                done
                cat > "$output.json" <<'JSON'
                \(json)
                JSON
                """)
    }

    init(body: String) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "whisper test \(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        executable = root.appendingPathComponent("fake whisper")
        model = root.appendingPathComponent("model file.bin")
        audio = root.appendingPathComponent("audio file.wav")
        let prelude = """
            #!/bin/sh
            printf '%s\n' "$@" > '\(root.path)/arguments'
            printf '%s\n' "$$" > '\(root.path)/process-id'
            record_output() {
              while [ "$#" -gt 0 ]; do
                case "$1" in -of) shift; printf '%s' "$1" > '\(root.path)/output-path' ;; esac
                shift
              done
            }
            record_output "$@"
            """
        try Data((prelude + "\n" + body + "\n").utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: executable.path)
        try Data([1]).write(to: model)
        var wav = Data("RIFF".utf8)
        wav.append(contentsOf: [38, 0, 0, 0])
        wav.append(Data("WAVEfmt ".utf8))
        wav.append(contentsOf: [16, 0, 0, 0, 1, 0, 1, 0, 128, 62, 0, 0, 0, 125, 0, 0, 2, 0, 16, 0])
        wav.append(Data("data".utf8))
        wav.append(contentsOf: [2, 0, 0, 0, 0, 0])
        try wav.write(to: audio)
    }

    func transcriber(timeout: Double = 3) -> WhisperCppTranscriber {
        WhisperCppTranscriber(executableURL: executable, modelURL: model, timeoutSeconds: timeout)
    }

    func waitUntilLaunched() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !FileManager.default.fileExists(
            atPath: root.appendingPathComponent("output-path").path)
        {
            guard ContinuousClock.now < deadline else {
                throw CocoaError(.executableNotLoadable)
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func assertSessionRemoved() throws {
        let path = try String(
            contentsOf: root.appendingPathComponent("output-path"), encoding: .utf8)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path))
        let processID = try String(
            contentsOf: root.appendingPathComponent("process-id"), encoding: .utf8)
        let pid = try XCTUnwrap(Int32(processID.trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func remove() {
        // Each test owns this temporary directory; removal is best effort after the assertion.
        try? FileManager.default.removeItem(at: root)
    }
}
