import Darwin
import Foundation
import STTAdapters
import STTCore

@main
struct BenchmarkCommand {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] {
            print(BenchmarkOptions.usage)
            return
        }
        do {
            try await runWithSignals(BenchmarkOptions.parse(arguments))
        } catch {
            // Decoder errors may quote input. Report the error kind without payload or note content.
            FileHandle.standardError.write(
                Data(
                    "Benchmark failed: \(BenchmarkDiagnostic.message(error))\n\(BenchmarkOptions.usage)\n"
                        .utf8))
            exit(1)
        }
    }

    private static func runWithSignals(_ options: BenchmarkOptions) async throws {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        let work = Task { try await execute(options) }
        let sources = [SIGINT, SIGTERM].map { number in
            let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
            source.setEventHandler { work.cancel() }
            source.resume()
            return source
        }
        defer {
            for source in sources { source.cancel() }
        }
        try await work.value
    }

    static func execute(_ options: BenchmarkOptions) async throws {
        try WhisperSessionRecovery.removeAbandoned()
        let output = options.reportURL.standardizedFileURL.resolvingSymlinksInPath()
        let base = options.manifestURL.deletingLastPathComponent().standardizedFileURL
            .resolvingSymlinksInPath()
        guard !FileManager.default.fileExists(atPath: output.path),
            !output.path.hasPrefix(base.path + "/")
        else { throw OptionError.reportExistsOrInsideFixtures }
        let suite = try BenchmarkFixtureLoader.load(options.manifestURL)
        let source = command("/usr/bin/git", ["rev-parse", "HEAD"])
        let dirty = !command("/usr/bin/git", ["status", "--porcelain"]).isEmpty
        let modelHash = try FileFingerprint.sha256(options.modelURL)
        let executableHash = try FileFingerprint.sha256(options.executableURL)
        let service = WhisperCppTranscriber(
            executableURL: options.executableURL, modelURL: options.modelURL)
        print(
            "Running \(suite.cases.count) fixed cases; prompt modes: \(options.promptModes.count); repetitions: \(options.repetitions)."
        )
        let rows = try await BenchmarkRunner(transcriber: service).measure(
            suite, modes: options.promptModes, repetitions: options.repetitions)
        let report = BenchmarkReport(
            schemaVersion: 1, createdAt: ISO8601DateFormatter().string(from: Date()),
            sourceCommit: source,
            workingTreeDirty: dirty,
            hardware: command(
                "/usr/sbin/sysctl", ["-n", "hw.model", "machdep.cpu.brand_string", "hw.memsize"]),
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            manifestSha256: suite.manifestSha256,
            modelID: options.modelURL.lastPathComponent, modelSha256: modelHash,
            executableSha256: executableHash,
            decodingSettings:
                "argv: -m MODEL -f AUDIO -l en -oj -of SESSION/transcript -np [--prompt PROMPT]; all remaining decoding options use the fingerprinted executable defaults",
            scoringVersion:
                "word-levenshtein-v1: Unicode letters/digits, lowercase, punctuation splits, no number normalization",
            promptVersion: CardiologyVocabulary.version, prompt: CardiologyVocabulary.prompt,
            timingNotes:
                "Every invocation launches and loads a new CLI process. First invocation is marked; subsequent runs may benefit from OS caches. Includes process/model load and JSON handling; excludes suite validation and fingerprints. No resident-model warm timing is claimed.",
            measurements: rows, summaries: BenchmarkRunner.summaries(rows))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(report).write(to: output, options: .withoutOverwriting)
        print("Completed \(rows.count) inferences. Report: \(output.path)")
    }

    private static func command(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "unavailable" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        completion.wait()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
