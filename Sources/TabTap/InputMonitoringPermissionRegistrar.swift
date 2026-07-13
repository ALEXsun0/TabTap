import ApplicationServices

private let inputMonitoringProbeCallback: CGEventTapCallBack = { _, _, event, _ in
    Unmanaged.passUnretained(event)
}

enum InputMonitoringPermissionRegistrar {
    @discardableResult
    static func request() -> Bool {
        if CGPreflightListenEventAccess() {
            return true
        }

        _ = CGRequestListenEventAccess()

        let eventMask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)

        if let probeTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: inputMonitoringProbeCallback,
            userInfo: nil
        ) {
            CGEvent.tapEnable(tap: probeTap, enable: false)
            CFMachPortInvalidate(probeTap)
        }

        return CGPreflightListenEventAccess()
    }
}
