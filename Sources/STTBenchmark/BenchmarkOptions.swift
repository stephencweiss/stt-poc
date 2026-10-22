import Foundation

struct BenchmarkOptions {
    let manifestURL: URL
    let reportURL: URL
    let modelURL: URL
    let executableURL: URL
    let promptModes: [Bool]
    let repetitions: Int

    static let usage = """
        Usage: STTBenchmark --report PATH [--manifest PATH] [--model PATH] [--executable PATH]
                            [--prompt both|on|off] [--repetitions 1...10]
        Reports contain fixture transcripts. Use fictional data and review before publishing.
        A fresh report path is required. No models are downloaded; every inference is local.
        """

    static func parse(_ arguments: [String]) throws -> Self {
        let allowed = Set([
            "--manifest", "--report", "--model", "--executable", "--prompt", "--repetitions",
        ])
        var values: [String: String] = [:]
        guard arguments.count.isMultiple(of: 2) else { throw OptionError.invalidArguments }
        for index in stride(from: 0, to: arguments.count, by: 2) {
            let key = arguments[index]
            let value = arguments[index + 1]
            guard allowed.contains(key), values[key] == nil, !value.isEmpty else {
                throw OptionError.invalidArguments
            }
            values[key] = value
        }
        guard let report = values["--report"] else { throw OptionError.invalidArguments }
        let mode = values["--prompt"] ?? "both"
        guard ["both", "on", "off"].contains(mode),
            let repetitions = Int(values["--repetitions"] ?? "1"), (1...10).contains(repetitions)
        else { throw OptionError.invalidArguments }
        return Self(
            manifestURL: URL(
                fileURLWithPath: values["--manifest"] ?? "Fixtures/Benchmark/manifest.json"),
            reportURL: URL(fileURLWithPath: report),
            modelURL: URL(
                fileURLWithPath: values["--model"]
                    ?? "/opt/homebrew/share/whisper-cpp/ggml-medium.en.bin"),
            executableURL: URL(
                fileURLWithPath: values["--executable"] ?? "/opt/homebrew/bin/whisper-cli"),
            promptModes: mode == "both" ? [false, true] : [mode == "on"], repetitions: repetitions
        )
    }
}

enum OptionError: Error {
    case invalidArguments
    case reportExistsOrInsideFixtures
}
