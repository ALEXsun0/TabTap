import XCTest
@testable import TabTapCore

final class PermissionPollingPolicyTests: XCTestCase {
    func testPollsWhileEnabledAndMonitoringIsUnavailable() {
        XCTAssertTrue(
            PermissionPollingPolicy.shouldPoll(
                isEnabled: true,
                monitoringRunning: false
            )
        )
    }

    func testStopsPollingWhenMonitoringIsRunning() {
        XCTAssertFalse(
            PermissionPollingPolicy.shouldPoll(
                isEnabled: true,
                monitoringRunning: true
            )
        )
    }

    func testStopsPollingWhenTabTapIsDisabled() {
        XCTAssertFalse(
            PermissionPollingPolicy.shouldPoll(
                isEnabled: false,
                monitoringRunning: false
            )
        )
    }
}
