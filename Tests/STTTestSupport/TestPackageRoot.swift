import Foundation

public enum TestPackageRoot {
    /// Finds the nearest package above the caller's test source, independent of working directory.
    public static func find(containing sourceFile: String = #filePath) throws -> URL {
        var directory = URL(fileURLWithPath: sourceFile).standardizedFileURL
            .deletingLastPathComponent()
        while true {
            let manifest = directory.appendingPathComponent("Package.swift")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: manifest.path, isDirectory: &isDirectory),
                !isDirectory.boolValue
            {
                return directory
            }
            let parent = directory.deletingLastPathComponent().standardizedFileURL
            guard parent.path != directory.path else {
                throw TestPackageRootError.notFound(sourceFile: sourceFile)
            }
            directory = parent
        }
    }
}

public enum TestPackageRootError: Error, LocalizedError {
    case notFound(sourceFile: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let sourceFile):
            return "Could not find Package.swift in any ancestor of test source: \(sourceFile)"
        }
    }
}
