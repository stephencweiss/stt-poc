import XCTest

@testable import STTCore

final class BenchmarkScoringTests: XCTestCase {
    func testCountsSubstitutionInsertionAndDeletion() {
        let substitution = WordErrorScore.compare(
            reference: "left radial access", hypothesis: "right radial access")
        XCTAssertEqual(substitution.substitutions, 1)
        XCTAssertEqual(substitution.insertions, 0)
        XCTAssertEqual(substitution.deletions, 0)
        XCTAssertEqual(substitution.wordErrorRate, 1.0 / 3.0)
        XCTAssertEqual(
            WordErrorScore.compare(reference: "radial access", hypothesis: "right radial access")
                .insertions, 1)
        XCTAssertEqual(
            WordErrorScore.compare(reference: "right radial access", hypothesis: "radial access")
                .deletions, 1)
    }

    func testRepeatedWordsAreNotReducedToASet() {
        let result = WordErrorScore.compare(
            reference: "no no complications", hypothesis: "no complications")
        XCTAssertEqual(result.deletions, 1)
    }

    func testPunctuationAndCaseButNotNumberWordsAreNormalized() {
        XCTAssertEqual(
            WordErrorScore.compare(reference: "LAD, stenosis.", hypothesis: "lad stenosis")
                .wordErrorRate, 0)
        XCTAssertEqual(WordErrorScore.compare(reference: "six", hypothesis: "6").substitutions, 1)
    }

    func testSilenceHasNoDividedByZeroWER() {
        let score = WordErrorScore.compare(reference: "", hypothesis: "unexpected text")
        XCTAssertNil(score.wordErrorRate)
        XCTAssertEqual(score.insertions, 2)
    }

    func testFactsRequireWholePhrasesAndReportForbiddenPhrases() {
        let fact = ExpectedFact(
            id: "side", acceptedPhrases: ["right radial"], forbiddenPhrases: ["left radial"])
        XCTAssertFalse(fact.evaluate("right artery and radial access").matched)
        XCTAssertFalse(fact.evaluate("bright radial").matched)
        let result = fact.evaluate("Right radial access, not left radial")
        XCTAssertTrue(result.matched)
        XCTAssertEqual(result.unexpectedPhrases, ["left radial"])
    }

    func testFactsPreserveUnitAndNegativeFindingPhrases() {
        let size = ExpectedFact(
            id: "size", acceptedPhrases: ["34 millimeter", "34 mm"],
            forbiddenPhrases: ["34 centimeter"])
        XCTAssertTrue(size.evaluate("A 34 mm valve was used.").matched)
        let wrongUnit = size.evaluate("A 34 centimeter valve was used.")
        XCTAssertFalse(wrongUnit.matched)
        XCTAssertEqual(wrongUnit.unexpectedPhrases, ["34 centimeter"])
        let finding = ExpectedFact(
            id: "finding", acceptedPhrases: ["no signs of stroke"], forbiddenPhrases: [])
        XCTAssertTrue(finding.evaluate("No signs of stroke.").matched)
        XCTAssertFalse(finding.evaluate("Signs of stroke.").matched)
    }
}
