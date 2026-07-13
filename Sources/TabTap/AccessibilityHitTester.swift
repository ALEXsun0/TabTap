import ApplicationServices
import Foundation
import TabTapCore

struct ChromeTabTarget {
    let element: AXUIElement
    let identifier: String
    let wasCloseButtonHit: Bool

    func close(at point: CGPoint) -> Bool {
        if let closeButton = AccessibilityHitTester.findCloseButton(in: element),
           AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == .success {
            return true
        }

        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let mouseDown = CGEvent(
                mouseEventSource: source,
                mouseType: .otherMouseDown,
                mouseCursorPosition: point,
                mouseButton: .center
            ),
            let mouseUp = CGEvent(
                mouseEventSource: source,
                mouseType: .otherMouseUp,
                mouseCursorPosition: point,
                mouseButton: .center
            )
        else {
            return false
        }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
        return true
    }
}

enum AccessibilityHitTester {
    private static let systemWideElement = AXUIElementCreateSystemWide()
    private static let maximumAncestorDepth = 10
    private static let maximumChromeHeight: CGFloat = 140
    private static let maximumSearchDepth = 14
    private static let maximumSearchElements = 500

    static func tab(at point: CGPoint, chromePID: pid_t) -> ChromeTabTarget? {
        var hitElement: AXUIElement?
        let hitResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &hitElement
        )

        if hitResult == .success,
           let hitElement,
           let tabElement = tabAncestor(startingAt: hitElement),
           isInsideTopChrome(element: tabElement, point: point) {
            return makeTarget(
                tabElement: tabElement,
                hitElement: hitElement,
                chromePID: chromePID
            )
        }

        guard let tabElement = findTabInChromeWindow(at: point, chromePID: chromePID) else {
            return nil
        }

        return makeTarget(
            tabElement: tabElement,
            hitElement: hitElement,
            chromePID: chromePID
        )
    }

    private static func makeTarget(
        tabElement: AXUIElement,
        hitElement: AXUIElement?,
        chromePID: pid_t
    ) -> ChromeTabTarget {
        let frame = frame(of: tabElement) ?? .zero
        let title = stringAttribute(tabElement, kAXTitleAttribute) ?? ""
        let identifier = [
            String(chromePID),
            String(format: "%.1f", frame.minX),
            String(format: "%.1f", frame.minY),
            String(format: "%.1f", frame.width),
            title,
        ].joined(separator: "|")

        return ChromeTabTarget(
            element: tabElement,
            identifier: identifier,
            wasCloseButtonHit: hitElement.map {
                isCloseControlBetween($0, and: tabElement)
            } ?? false
        )
    }

    private static func findTabInChromeWindow(
        at point: CGPoint,
        chromePID: pid_t
    ) -> AXUIElement? {
        let application = AXUIElementCreateApplication(chromePID)
        let focusedWindow: AXUIElement? = attribute(application, kAXFocusedWindowAttribute)
        let mainWindow: AXUIElement? = attribute(application, kAXMainWindowAttribute)
        guard let window = focusedWindow ?? mainWindow,
              let windowFrame = frame(of: window),
              point.y >= windowFrame.minY,
              point.y <= windowFrame.minY + maximumChromeHeight else {
            return nil
        }

        var visited = 0
        return findTab(in: window, at: point, depth: 0, visited: &visited)
    }

    private static func findTab(
        in element: AXUIElement,
        at point: CGPoint,
        depth: Int,
        visited: inout Int
    ) -> AXUIElement? {
        guard depth <= maximumSearchDepth,
              visited < maximumSearchElements else {
            return nil
        }
        visited += 1

        if isTabElement(element),
           let elementFrame = frame(of: element),
           elementFrame.contains(point) {
            return element
        }

        for child in elementArrayAttribute(element, kAXChildrenAttribute) {
            if let childFrame = frame(of: child), !childFrame.contains(point) {
                continue
            }
            if let match = findTab(
                in: child,
                at: point,
                depth: depth + 1,
                visited: &visited
            ) {
                return match
            }
        }
        return nil
    }

    static func findCloseButton(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth <= 3 else {
            return nil
        }

        for child in elementArrayAttribute(element, kAXChildrenAttribute) {
            if isCloseControl(child) {
                return child
            }
            if let match = findCloseButton(in: child, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    private static func tabAncestor(startingAt element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element

        for _ in 0..<maximumAncestorDepth {
            guard let candidate = current else {
                return nil
            }
            if isTabElement(candidate) {
                return candidate
            }
            current = elementAttribute(candidate, kAXParentAttribute)
        }
        return nil
    }

    private static func isTabElement(_ element: AXUIElement) -> Bool {
        AccessibilitySemantics.isBrowserTab(
            role: stringAttribute(element, kAXRoleAttribute),
            roleDescription: stringAttribute(element, kAXRoleDescriptionAttribute),
            subrole: stringAttribute(element, kAXSubroleAttribute),
            identifier: stringAttribute(element, kAXIdentifierAttribute)
        )
    }

    private static func isInsideTopChrome(element: AXUIElement, point: CGPoint) -> Bool {
        var current: AXUIElement? = element

        for _ in 0..<maximumAncestorDepth {
            guard let candidate = current else {
                break
            }
            if stringAttribute(candidate, kAXRoleAttribute) == (kAXWindowRole as String),
               let windowFrame = frame(of: candidate) {
                return point.y >= windowFrame.minY
                    && point.y <= windowFrame.minY + maximumChromeHeight
            }
            current = elementAttribute(candidate, kAXParentAttribute)
        }
        return false
    }

    private static func isCloseControlBetween(
        _ hitElement: AXUIElement,
        and tabElement: AXUIElement
    ) -> Bool {
        var current: AXUIElement? = hitElement

        for _ in 0..<maximumAncestorDepth {
            guard let candidate = current else {
                return false
            }
            if CFEqual(candidate, tabElement) {
                return false
            }
            if isCloseControl(candidate) {
                return true
            }
            current = elementAttribute(candidate, kAXParentAttribute)
        }
        return false
    }

    private static func isCloseControl(_ element: AXUIElement) -> Bool {
        AccessibilitySemantics.isCloseButton(
            role: stringAttribute(element, kAXRoleAttribute),
            subrole: stringAttribute(element, kAXSubroleAttribute),
            identifier: stringAttribute(element, kAXIdentifierAttribute),
            title: stringAttribute(element, kAXTitleAttribute),
            description: stringAttribute(element, kAXDescriptionAttribute)
        )
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(element, kAXPositionAttribute),
              AXValueGetType(positionValue) == .cgPoint,
              let sizeValue: AXValue = attribute(element, kAXSizeAttribute),
              AXValueGetType(sizeValue) == .cgSize else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private static func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name)
    }

    private static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        attribute(element, name)
    }

    private static func elementArrayAttribute(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        attribute(element, name) ?? []
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

}
