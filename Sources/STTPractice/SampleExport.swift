import AppKit

@MainActor
enum SampleExport {
    static func chooseDestination(completion: @escaping @MainActor (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.begin { response in completion(response == .OK ? panel.url : nil) }
    }
}

actor SampleWriter {
    func write(audio: Data, reference: String, directory: URL) throws {
        let target = directory.appendingPathComponent(
            "practice-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: target, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        do {
            try audio.write(to: target.appendingPathComponent("audio.wav"), options: .atomic)
            try reference.write(
                to: target.appendingPathComponent("reference.txt"), atomically: true,
                encoding: .utf8)
        } catch {
            // Remove a partial explicit export; propagate cleanup failures too.
            try FileManager.default.removeItem(at: target)
            throw error
        }
    }
}
