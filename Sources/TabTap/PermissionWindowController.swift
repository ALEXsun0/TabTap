import AppKit

@MainActor
final class PermissionWindowController: NSWindowController, NSWindowDelegate {
    private let model: PermissionGuideModel
    private let onClose: () -> Void

    init(
        model: PermissionGuideModel,
        requestAccessibility: @escaping () -> Void,
        requestInputMonitoring: @escaping () -> Void,
        recheckPermissions: @escaping () -> Void,
        restartApplication: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 390),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let guideView = PermissionGuideView(
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
        window.contentView = guideView
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        model.onChange = { [weak guideView] in
            guideView?.update()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        model.onChange?()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        model.onChange = nil
        onClose()
    }
}
