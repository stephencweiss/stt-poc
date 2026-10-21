import AVFoundation
import CryptoKit
import Foundation
import STTCore

public struct LoadedBenchmarkCase: Sendable {
    public let definition: BenchmarkCase
    public let audioURL: URL
    public let referenceText: String
    public let durationSeconds: Double
}

public struct LoadedBenchmarkSuite: Sendable {
    public let manifestSha256: String
    public let cases: [LoadedBenchmarkCase]
}

public enum FileFingerprint {
    public static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        // Read-only close failure cannot change an already computed digest.
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum BenchmarkFixtureLoader {
    public static func load(_ manifestURL: URL) throws -> LoadedBenchmarkSuite {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(BenchmarkManifest.self, from: data)
        try manifest.validate()
        let base = manifestURL.deletingLastPathComponent().resolvingSymlinksInPath()
        let cases = try manifest.cases.map { try loadCase($0, under: base) }
        try checkInventory(cases, under: base)
        return LoadedBenchmarkSuite(
            manifestSha256: try FileFingerprint.sha256(manifestURL), cases: cases)
    }

    public static func resolve(_ path: String, under base: URL) throws -> URL {
        guard !path.isEmpty, !(path as NSString).isAbsolutePath else {
            throw ManifestError.unsafePath
        }
        let root = base.standardizedFileURL.resolvingSymlinksInPath()
        let file = root.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(root.path + "/") else { throw ManifestError.unsafePath }
        return file
    }

    private static func loadCase(_ entry: BenchmarkCase, under base: URL) throws
        -> LoadedBenchmarkCase
    {
        let audio = try resolve(entry.audio, under: base)
        let reference = try resolve(entry.reference, under: base)
        guard try FileFingerprint.sha256(audio) == entry.audioSha256,
            try FileFingerprint.sha256(reference) == entry.referenceSha256
        else { throw ManifestError.checksumMismatch(entry.id) }
        try CanonicalWAV.validate(audio)
        let file = try AVAudioFile(forReading: audio)
        let duration = Double(file.length) / file.fileFormat.sampleRate
        guard duration.isFinite, duration > 0 else { throw ManifestError.invalidAudio(entry.id) }
        return LoadedBenchmarkCase(
            definition: entry, audioURL: audio,
            referenceText: try String(contentsOf: reference, encoding: .utf8),
            durationSeconds: duration)
    }

    private static func checkInventory(_ cases: [LoadedBenchmarkCase], under base: URL) throws {
        let listed = try Set(
            cases.flatMap {
                [$0.audioURL, try resolve($0.definition.reference, under: base)]
            })
        var actual = Set<URL>()
        for folder in ["audio", "references"] {
            guard
                let enumerator = FileManager.default.enumerator(
                    at: base.appendingPathComponent(folder),
                    includingPropertiesForKeys: [.isRegularFileKey]
                )
            else { throw ManifestError.inventoryMismatch }
            for case let file as URL in enumerator {
                if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    actual.insert(file.resolvingSymlinksInPath())
                }
            }
        }
        guard listed == actual else { throw ManifestError.inventoryMismatch }
    }
}
