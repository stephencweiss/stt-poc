import AVFoundation
import Foundation
import STTCore
import os

struct ConvertedCapture: Sendable {
    let durationSeconds: Double
}

/// Runs only after capture stops. One converter consumes all source chunks and drains its EOF tail.
enum CaptureAudioConverter {
    static func convert(input: URL, output: URL) throws -> ConvertedCapture {
        let source: AVAudioFile
        do { source = try AVAudioFile(forReading: input) } catch {
            throw AudioCaptureError.conversionFailed
        }
        guard source.length > 0 else { throw AudioCaptureError.emptyRecording }
        let duration = Double(source.length) / source.processingFormat.sampleRate
        guard duration.isFinite, duration <= 120.1 else { throw AudioCaptureError.conversionFailed }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1),
            let converter = AVAudioConverter(from: source.processingFormat, to: format),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)
        else { throw AudioCaptureError.conversionFailed }
        let writer = try makeWriter(output, format: format)
        let statistics = try drain(source, converter: converter, buffer: buffer, writer: writer)
        guard statistics.frames > 0, sqrt(statistics.energy / Double(statistics.frames)) > 0.0001
        else {
            throw AudioCaptureError.emptyRecording
        }
        return ConvertedCapture(durationSeconds: Double(statistics.frames) / 16000)
    }

    private static func makeWriter(_ url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        var settings = format.settings
        settings[AVLinearPCMBitDepthKey] = 16
        settings[AVLinearPCMIsFloatKey] = false
        settings[AVLinearPCMIsNonInterleaved] = false
        settings[AVLinearPCMIsBigEndianKey] = false
        do {
            return try AVAudioFile(
                forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32,
                interleaved: false)
        } catch { throw AudioCaptureError.writeFailed }
    }

    private static func drain(
        _ source: AVAudioFile, converter: AVAudioConverter, buffer: AVAudioPCMBuffer,
        writer: AVAudioFile
    ) throws -> AudioEnergy {
        let readFailed = OSAllocatedUnfairLock(initialState: false)
        let input: AVAudioConverterInputBlock = { requested, status in
            if source.framePosition >= source.length {
                status.pointee = .endOfStream
                return nil
            }
            guard
                let chunk = AVAudioPCMBuffer(
                    pcmFormat: source.processingFormat, frameCapacity: min(requested, 4096))
            else {
                readFailed.withLock { $0 = true }
                status.pointee = .endOfStream
                return nil
            }
            do { try source.read(into: chunk, frameCount: chunk.frameCapacity) } catch {
                readFailed.withLock { $0 = true }
                status.pointee = .endOfStream
                return nil
            }
            status.pointee = .haveData
            return chunk
        }
        var statistics = AudioEnergy()
        while true {
            try Task.checkCancellation()
            var error: NSError?
            let status = converter.convert(to: buffer, error: &error, withInputFrom: input)
            guard error == nil, status != .error, !readFailed.withLock({ $0 }) else {
                throw AudioCaptureError.conversionFailed
            }
            try statistics.append(buffer)
            do { try writer.write(from: buffer) } catch { throw AudioCaptureError.writeFailed }
            if status == .endOfStream { return statistics }
            guard status != .inputRanDry else { throw AudioCaptureError.conversionFailed }
        }
    }
}

private struct AudioEnergy {
    var frames = 0
    var energy = 0.0

    mutating func append(_ buffer: AVAudioPCMBuffer) throws {
        guard let samples = buffer.floatChannelData?[0] else {
            throw AudioCaptureError.conversionFailed
        }
        for index in 0..<Int(buffer.frameLength) {
            let sample = Double(samples[index])
            guard sample.isFinite else { throw AudioCaptureError.conversionFailed }
            energy += sample * sample
        }
        frames += Int(buffer.frameLength)
        guard frames <= 1_921_600 else { throw AudioCaptureError.conversionFailed }
    }
}
