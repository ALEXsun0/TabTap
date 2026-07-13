import AppKit
import ApplicationServices
import OSLog
import TabTapCore

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<EventTapController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return controller.handle(type: type, event: event)
}

final class EventTapController {
    private static let chromeBundleIdentifiers: Set<String> = [
        "com.google.Chrome",
    ]

    private let logger = Logger(subsystem: "app.tabtap.TabTap", category: "mouse")
    private let isEnabled: () -> Bool
    private let stateChanged: () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recognizer = DoubleClickRecognizer()
    private var suppressNextLeftMouseUp = false

    init(isEnabled: @escaping () -> Bool, stateChanged: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.stateChanged = stateChanged
    }

    var isRunning: Bool {
        guard let eventTap else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    @discardableResult
    func start() -> Bool {
        if isRunning {
            return true
        }

        stop()

        let events: [CGEventType] = [.leftMouseDown, .leftMouseUp]
        let mask = events.reduce(CGEventMask(0)) { partialResult, type in
            partialResult | (CGEventMask(1) << type.rawValue)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Unable to create the global event tap")
            stateChanged()
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("Global event tap started")
        stateChanged()
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        suppressNextLeftMouseUp = false
        recognizer.reset()
        stateChanged()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            stateChanged()
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseUp, suppressNextLeftMouseUp {
            suppressNextLeftMouseUp = false
            return nil
        }

        guard type == .leftMouseDown else {
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled(), let chromePID = frontmostChromePID else {
            recognizer.reset()
            return Unmanaged.passUnretained(event)
        }

        let point = event.location
        guard let target = AccessibilityHitTester.tab(at: point, chromePID: chromePID),
              !target.wasCloseButtonHit else {
            logger.debug("Chrome click did not resolve to a tab at \(point.x), \(point.y)")
            recognizer.reset()
            return Unmanaged.passUnretained(event)
        }

        logger.debug("Recognized a Chrome tab click at \(point.x), \(point.y)")

        let isDoubleClick = recognizer.registerClick(
            timestamp: ProcessInfo.processInfo.systemUptime,
            position: PointerPosition(x: point.x, y: point.y),
            targetID: target.identifier
        )

        guard isDoubleClick else {
            return Unmanaged.passUnretained(event)
        }

        guard target.close(at: point) else {
            logger.error("The tab was identified but could not be closed")
            recognizer.reset()
            return Unmanaged.passUnretained(event)
        }

        suppressNextLeftMouseUp = true
        logger.info("Closed a Chrome tab after a double-click")
        return nil
    }

    private var frontmostChromePID: pid_t? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier,
              Self.chromeBundleIdentifiers.contains(bundleIdentifier) else {
            return nil
        }
        return application.processIdentifier
    }
}
