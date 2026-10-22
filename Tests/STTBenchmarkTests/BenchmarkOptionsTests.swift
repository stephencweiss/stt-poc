import XCTest

@testable import STTBenchmark

final class BenchmarkOptionsTests: XCTestCase {
    func testDefaultsRequireExplicitReportAndRejectUnknownOptions() throws {
        XCTAssertThrowsError(try BenchmarkOptions.parse([]))
        XCTAssertThrowsError(
            try BenchmarkOptions.parse(["--report", "out.json", "--unknown", "value"]))
        XCTAssertThrowsError(try BenchmarkOptions.parse(["--report"]))
        let result = try BenchmarkOptions.parse(["--report", "out.json"])
        XCTAssertEqual(result.promptModes, [false, true])
        XCTAssertEqual(result.repetitions, 1)
    }

    func testRejectsInvalidPromptAndRepetitionValues() {
        for value in ["0", "-1", "nan", "101"] {
            XCTAssertThrowsError(
                try BenchmarkOptions.parse(["--report", "out.json", "--repetitions", value]))
        }
        XCTAssertThrowsError(
            try BenchmarkOptions.parse(["--report", "out.json", "--prompt", "maybe"]))
    }
}
