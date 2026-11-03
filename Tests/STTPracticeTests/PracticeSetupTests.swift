import Foundation
import XCTest
import os

@testable import STTPractice

final class PracticeSetupTests: XCTestCase {
    func testInvalidAssetsStillRunSessionRecovery() async {
        let recovered = OSAllocatedUnfairLock(initialState: false)
        let setup = PracticeSetup(recover: { recovered.withLock { $0 = true } })
        var configuration = PracticeConfiguration()
        configuration.modelPath = "/missing-model"
        do {
            try await setup.check(configuration)
            XCTFail("Missing model must fail setup")
        } catch { XCTAssertTrue(recovered.withLock { $0 }) }
    }
}
