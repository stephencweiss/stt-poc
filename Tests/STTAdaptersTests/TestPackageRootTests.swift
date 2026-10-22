import Foundation
import STTTestSupport
import XCTest

final class TestPackageRootTests: XCTestCase {
    func testFindsRootFromDeeplyNestedSourceWithSpaces() throws {
        let root = try temporaryDirectory()
        try Data().write(to: root.appendingPathComponent("Package.swift"))
        let source = root.appendingPathComponent("Tests/Nested/More Levels/Test.swift")
        let result = try TestPackageRoot.find(containing: source.path)
        XCTAssertEqual(result.path, root.path)
    }

    func testUsesNearestManifestAndRejectsDirectoryNamedPackageSwift() throws {
        let root = try temporaryDirectory()
        try Data().write(to: root.appendingPathComponent("Package.swift"))
        let nested = root.appendingPathComponent("Nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        let marker = nested.appendingPathComponent("Package.swift")
        let source = nested.appendingPathComponent("Tests/Test.swift")
        try FileManager.default.createDirectory(at: marker, withIntermediateDirectories: false)
        XCTAssertEqual(try TestPackageRoot.find(containing: source.path).path, root.path)
        try FileManager.default.removeItem(at: marker)
        try Data().write(to: marker)
        XCTAssertEqual(try TestPackageRoot.find(containing: source.path).path, nested.path)
    }

    func testMissingManifestHasClearError() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("Tests/Test.swift")
        XCTAssertThrowsError(try TestPackageRoot.find(containing: source.path)) { error in
            guard case TestPackageRootError.notFound(let startingSource) = error else {
                return XCTFail("Expected a package-root discovery error")
            }
            XCTAssertEqual(startingSource, source.path)
            XCTAssertTrue(error.localizedDescription.contains("Package.swift"))
            XCTAssertTrue(error.localizedDescription.contains(source.path))
        }
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }
}
