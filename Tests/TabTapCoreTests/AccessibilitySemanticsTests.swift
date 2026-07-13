import XCTest
@testable import TabTapCore

final class AccessibilitySemanticsTests: XCTestCase {
    func testRecognizesEnglishChromeTab() {
        XCTAssertTrue(AccessibilitySemantics.isBrowserTab(
            role: "AXRadioButton",
            roleDescription: "tab",
            subrole: nil,
            identifier: nil
        ))
    }

    func testRecognizesChineseChromeTab() {
        XCTAssertTrue(AccessibilitySemantics.isBrowserTab(
            role: "AXRadioButton",
            roleDescription: "标签",
            subrole: nil,
            identifier: nil
        ))
    }

    func testRejectsWebPageRadioButton() {
        XCTAssertFalse(AccessibilitySemantics.isBrowserTab(
            role: "AXRadioButton",
            roleDescription: "radio button",
            subrole: nil,
            identifier: "newsletter-choice"
        ))
    }

    func testRecognizesEnglishCloseButton() {
        XCTAssertTrue(AccessibilitySemantics.isCloseButton(
            role: "AXButton",
            subrole: "AXCloseButton",
            identifier: nil,
            title: nil,
            description: "Close"
        ))
    }

    func testRejectsNonButtonWithCloseText() {
        XCTAssertFalse(AccessibilitySemantics.isCloseButton(
            role: "AXStaticText",
            subrole: nil,
            identifier: nil,
            title: "Close",
            description: nil
        ))
    }
}
