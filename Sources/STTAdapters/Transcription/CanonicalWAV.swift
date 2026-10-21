import Foundation

/// Checks WAV chunks without loading the recording into memory.
enum CanonicalWAV {
    static func validate(_ url: URL) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer {
            // Closing a read-only validation handle cannot change the validation result.
            try? file.close()
        }
        let size = try file.seekToEnd()
        try file.seek(toOffset: 0)
        let header = try read(file, count: 12)
        guard header.prefix(4) == Data("RIFF".utf8), header.suffix(4) == Data("WAVE".utf8),
            UInt64(littleEndian(header, at: 4, count: 4)) + 8 == size
        else { throw WhisperCppTranscriberError.invalidAudio }
        try validateChunks(file, size: size)
    }

    private static func validateChunks(_ file: FileHandle, size: UInt64) throws {
        var position: UInt64 = 12
        var hasFormat = false
        var hasAudio = false
        while position + 8 <= size {
            try file.seek(toOffset: position)
            let header = try read(file, count: 8)
            let length = UInt64(littleEndian(header, at: 4, count: 4))
            let next = position + 8 + length + length % 2
            guard next <= size else { throw WhisperCppTranscriberError.invalidAudio }
            if header.prefix(4) == Data("fmt ".utf8) {
                try validateFormat(file, length: length)
                hasFormat = true
            }
            if header.prefix(4) == Data("data".utf8) {
                guard length > 0, length % 2 == 0 else {
                    throw WhisperCppTranscriberError.invalidAudio
                }
                hasAudio = true
            }
            position = next
        }
        guard hasFormat, hasAudio, position == size else {
            throw WhisperCppTranscriberError.invalidAudio
        }
    }

    private static func validateFormat(_ file: FileHandle, length: UInt64) throws {
        guard length >= 16 else { throw WhisperCppTranscriberError.invalidAudio }
        let bytes = try read(file, count: 16)
        let expected = Data([1, 0, 1, 0, 128, 62, 0, 0, 0, 125, 0, 0, 2, 0, 16, 0])
        guard bytes == expected else { throw WhisperCppTranscriberError.invalidAudio }
    }

    private static func read(_ file: FileHandle, count: Int) throws -> Data {
        guard let bytes = try file.read(upToCount: count), bytes.count == count else {
            throw WhisperCppTranscriberError.invalidAudio
        }
        return bytes
    }

    private static func littleEndian(_ bytes: Data, at offset: Int, count: Int) -> UInt32 {
        (0..<count).reduce(UInt32(0)) { result, index in
            result | UInt32(bytes[offset + index]) << (index * 8)
        }
    }
}
