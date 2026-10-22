import AppKit

@MainActor
protocol NoteCopying {
    func copy(_ text: String) -> Bool
}

struct Clipboard: NoteCopying {
    func copy(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
