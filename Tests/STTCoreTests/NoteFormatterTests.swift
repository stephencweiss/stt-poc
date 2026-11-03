import STTCore
import XCTest

final class NoteFormatterTests: XCTestCase {
    func testWhitespaceAndFreeFormStatements() {
        let cases: [(String, String)] = [
            ("", ""), (" \t\n ", ""),
            ("  no  obstruction.\r\n\r\n\r\n  no\tleak.  ", "no obstruction.\n\nno leak."),
            (
                "left access. cannot exclude obstruction. no paravalvular leak.",
                "left access. cannot exclude obstruction. no paravalvular leak."
            ),
            ("first\n \nsecond\n\n\nthird", "first\n\nsecond\n\nthird"),
        ]
        assertCases(cases)
    }

    func testHeadingsAndExactSpelling() {
        assertCases([
            ("left radial\nFindings: no leak.", "left radial\nFindings:\nno leak."),
            ("left radial\nheading findings. no leak.", "left radial\nFindings:\nno leak."),
            ("Procedure. Findings. No leak.", "Procedure:\nFindings:\nNo leak."),
            ("unpunctuated note\n\nFindings\nNo leak.", "unpunctuated note\n\nFindings:\nNo leak."),
            ("Findings. No coronary obstruction.", "Findings:\nNo coronary obstruction."),
            ("heading findings. No coronary obstruction.", "Findings:\nNo coronary obstruction."),
            (
                "Findings: No coronary obstruction. Plan. review.",
                "Findings:\nNo coronary obstruction. Plan:\nreview."
            ),
            ("Procedure\nTAVR.\nFindings\nno leak.", "Procedure:\nTAVR.\nFindings:\nno leak."),
            (
                "Findings were reviewed. the procedure was uncomplicated.",
                "Findings were reviewed. the procedure was uncomplicated."
            ),
            (
                "the findings were normal. heading unknown. keep this.",
                "the findings were normal. heading unknown. keep this."
            ),
            ("No\ncomplications.", "No\ncomplications."),
            (
                "pci tavr lad rca ivus ffr sapien evolut.",
                "PCI TAVR LAD RCA IVUS FFR SAPIEN Evolut."
            ),
            ("evolution evolutpro sapian unknownPCI.", "evolution evolutpro sapian unknownPCI."),
            (
                "Access. left femoral. Complications. cannot exclude coronary obstruction. Plan. no paravalvular leak.",
                "Access:\nleft femoral. Complications:\ncannot exclude coronary obstruction. Plan:\nno paravalvular leak."
            ),
        ])
    }

    func testNumericUnitsAndDeviceContext() {
        assertCases([
            (
                "16 french sheath. 26 millimeters. 2.50 millimeters.",
                "16 Fr sheath. 26 mm. 2.50 mm."
            ),
            (
                "sixteen French catheter. twenty six millimeters. twenty-six mm.",
                "16 Fr catheter. 26 mm. 26 mm."
            ),
            (
                "zero millimeter; ninety-nine millimeters; -2.50 MM; +0.25 millimeters.",
                "0 mm; 99 mm; -2.50 mm; +0.25 mm."
            ),
            ("sixteen french", "16 Fr"),
            ("Findings: sixteen French", "Findings:\n16 Fr"),
            ("size sixteen french.", "size 16 Fr."),
            (
                "the patient is French. sixteen French patients. 16 French people.",
                "the patient is French. sixteen French patients. 16 French people."
            ),
            (
                "sixteen French arrived. sixteen french device.",
                "sixteen French arrived. sixteen french device."
            ),
            (
                "right access with sixteen french sheath. sapien twenty nine millimeters valve. gradient twelve millimeters mercury. cannot exclude leak.",
                "right access with 16 Fr sheath. SAPIEN 29 mm valve. gradient 12 mm mercury. cannot exclude leak."
            ),
        ])
    }

    func testUnsupportedNumericConstructionsRemainComplete() {
        let unsupported = [
            "two point five millimeters", "twenty to twenty six millimeters",
            "twenty six by forty millimeters", "twenty six no twenty nine millimeters",
            "one hundred twenty six millimeters", "one and a half millimeters",
            "1/2 millimeters", "26-29 millimeters", "26–29 millimeters", "26 x 40 mm",
            "26, no 29 millimeters", "twenty twenty six millimeters", "one twenty millimeters",
            "1.2.3 millimeters", "2,5 millimeters", "sixteen point five french sheath",
            "minus two millimeters", "one-half millimeters", "26/29 millimeters",
            "26 - 29 millimeters", "twenty - twenty six millimeters",
            "one 26 millimeters", "1 26 millimeters", "two 2.5 millimeters",
            "twenty six or twenty nine millimeters", "twenty six sorry twenty nine millimeters",
            "twenty six plus two millimeters", "twenty-six-29 millimeters",
        ]
        assertCases(unsupported.map { ($0, $0) })
        assertCases([
            (
                "two point five millimeters. twenty six millimeters; sixteen french sheath",
                "two point five millimeters. 26 mm; 16 Fr sheath"
            ),
            (
                "twenty to twenty six millimeters, sixteen french sheath",
                "twenty to twenty six millimeters, sixteen french sheath"
            ),
        ])
    }

    func testOtherNumericContinuationTokensRemainUnchanged() {
        let unsupported = [
            "two dot five millimeters", "two decimal five millimeters",
            "twenty six dash twenty nine millimeters", "26 until 29 millimeters",
            "26 times 40 mm", "twenty six I mean twenty nine millimeters",
            "1⁄2 millimeters", "26−29 millimeters", "one third of twenty six millimeters",
        ]
        assertCases(unsupported.map { ($0, $0) })
    }

    func testConsecutiveHeadingSequences() {
        let headings = [
            "Procedure", "Indication", "Access", "Findings", "Intervention", "Hemodynamics",
            "Complications", "Plan",
        ]
        for first in headings {
            for second in headings {
                for separator in ["\n", ". ", "\n\n"] {
                    let input = first + separator + second + "\nNo leak."
                    let expected =
                        first + ":" + (separator == "\n\n" ? "\n\n" : "\n") + second + ":\nNo leak."
                    assertCases([(input, expected)])
                }
            }
        }
        assertCases([("Procedure\nPlan\nreview.", "Procedure:\nPlan:\nreview.")])
    }

    func testReviewedUnsupportedNumericPhrasesRemainUnchanged() {
        let unsupported = [
            "one fifth of twenty six millimeters",
            "twenty six, make that twenty nine millimeters",
            "twenty six, actually twenty nine millimeters",
            "26 millimeters, actually 29 millimeters",
            "negative .5 millimeters", ".5 millimeters", "-.5 millimeters",
        ]
        assertCases(unsupported.map { ($0, $0) })
    }

    func testPairedFreeFormAndHeadedNotesPreserveStatements() {
        let statements =
            "right femoral access. sixteen french sheath. cannot exclude obstruction. no paravalvular leak."
        let formattedStatements =
            "right femoral access. 16 Fr sheath. cannot exclude obstruction. no paravalvular leak."
        assertCases([
            (statements, formattedStatements),
            ("Findings. " + statements, "Findings:\n" + formattedStatements),
        ])
    }

    private func assertCases(
        _ cases: [(String, String)], file: StaticString = #filePath, line: UInt = #line
    ) {
        for (input, expected) in cases {
            let result = NoteFormatter.format(input)
            XCTAssertEqual(result, expected, file: file, line: line)
            XCTAssertEqual(NoteFormatter.format(result), result, file: file, line: line)
        }
    }
}
