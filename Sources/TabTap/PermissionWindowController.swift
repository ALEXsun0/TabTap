import AppKit
import SwiftUI

@MainActor
final class PermissionWindowController: NSWindowController {
    init(
        model: PermissionGuideModel,
        requestAccessibility: @escaping () -> Void,
        requestInputMonitoring: @escaping () -> Void,
        recheckPermissions: @escaping () -> Void,
        restartApplication: @escaping () -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let rootView = PermissionGuideView(
            model: model,
            requestAccessibility: requestAccessibility,
            requestInputMonitoring: requestInputMonitoring,
            recheckPermissions: recheckPermissions,
            restartApplication: restartApplication,
            finish: { [weak window] in
                window?.close()
            }
        )

        window.title = "TabTap 权限与状态"
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
