import AppKit
import ApplicationServices
import OSLog
import ServiceManagement
import TabTapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum DefaultsKey {
        static let enabled = "enabled"
    }

    private static let permissionPollingInterval: TimeInterval = 2

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "app.tabtap.TabTap", category: "permissions")
    private let permissionModel = PermissionGuideModel()
    private let automaticTerminationReason = "TabTap monitors Chrome tab double-clicks"
    private var statusItem: NSStatusItem!
    private var enabledMenuItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var permissionTimer: Timer?
    private var eventTapController: EventTapController!
    private var permissionWindowController: PermissionWindowController!
    private var lastPermissionState: PermissionState?

    private struct PermissionState: Equatable {
        let accessibilityGranted: Bool
        let inputMonitoringGranted: Bool
        let monitoringRunning: Bool
    }

    private var isEnabled: Bool {
        get {
            if defaults.object(forKey: DefaultsKey.enabled) == nil {
                return true
            }
            return defaults.bool(forKey: DefaultsKey.enabled)
        }
        set {
            defaults.set(newValue, forKey: DefaultsKey.enabled)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination(automaticTerminationReason)
        configureStatusItem()

        eventTapController = EventTapController(
            isEnabled: { [weak self] in self?.isEnabled ?? false },
            stateChanged: { [weak self] in
                DispatchQueue.main.async {
                    self?.eventTapStateDidChange()
                }
            }
        )
        configurePermissionWindow()

        refreshMonitoring()
        if eventTapController.isRunning == false {
            showPermissionWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPermissionPolling()
        eventTapController?.stop()
        ProcessInfo.processInfo.enableAutomaticTermination(automaticTerminationReason)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = menuBarIcon()
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "TabTap", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        enabledMenuItem = NSMenuItem(
            title: "启用",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        statusMenuItem = NSMenuItem(title: "监听状态：正在启动", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let permissionItem = NSMenuItem(
            title: "权限与状态...",
            action: #selector(showPermissionWindow),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        let accessibilityItem = NSMenuItem(
            title: "打开“辅助功能”设置...",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let inputMonitoringItem = NSMenuItem(
            title: "打开“输入监控”设置...",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        inputMonitoringItem.target = self
        menu.addItem(inputMonitoringItem)

        launchAtLoginMenuItem = NSMenuItem(
            title: "登录时启动",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 TabTap",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
        menu.delegate = self
        refreshMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMonitoring()
    }

    private func menuBarIcon() -> NSImage {
        let iconSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: iconSize)

        for resourceName in ["MenuBarIcon", "MenuBarIcon@2x"] {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
                  let sourceImage = NSImage(contentsOf: url),
                  let representation = sourceImage.representations.first else {
                continue
            }
            representation.size = iconSize
            image.addRepresentation(representation)
        }

        if image.representations.isEmpty,
           let fallback = NSImage(
               systemSymbolName: "rectangle.stack.badge.minus",
               accessibilityDescription: "TabTap"
           ) {
            fallback.isTemplate = true
            return fallback
        }

        image.isTemplate = true
        image.accessibilityDescription = "TabTap"
        return image
    }

    private func configurePermissionWindow() {
        permissionWindowController = PermissionWindowController(
            model: permissionModel,
            requestAccessibility: { [weak self] in
                self?.requestAccessibilityPermission(openSettings: true)
            },
            requestInputMonitoring: { [weak self] in
                self?.requestInputMonitoringPermission(openSettings: true)
            },
            recheckPermissions: { [weak self] in
                self?.refreshMonitoring()
            },
            restartApplication: { [weak self] in
                self?.restartApplication()
            }
        )
    }

    private func requestAccessibilityPermission(openSettings: Bool) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        logger.info("Requested Accessibility access")
        if openSettings {
            openSystemSettings(anchor: "Privacy_Accessibility")
        }
    }

    private func requestInputMonitoringPermission(openSettings: Bool) {
        let wasGranted = InputMonitoringPermissionRegistrar.request()
        logger.info("Requested Input Monitoring access; granted: \(wasGranted)")
        if openSettings {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.openSystemSettings(anchor: "Privacy_ListenEvent")
            }
        }
    }

    private func refreshMonitoring() {
        guard eventTapController != nil else {
            return
        }

        // Active event taps are authorized by Accessibility. Input Monitoring's
        // preflight result can remain stale for ad-hoc builds even when its
        // System Settings switch is enabled, so the event tap itself is the
        // authoritative operational check.
        if isEnabled && AXIsProcessTrusted() {
            _ = eventTapController.start()
        } else {
            eventTapController.stop()
        }
        refreshPermissionModel()
        refreshMenuState()
        updatePermissionPolling()
    }

    private func eventTapStateDidChange() {
        refreshPermissionModel()
        refreshMenuState()
        updatePermissionPolling()
    }

    private func updatePermissionPolling() {
        let shouldPoll = PermissionPollingPolicy.shouldPoll(
            isEnabled: isEnabled,
            monitoringRunning: eventTapController?.isRunning == true
        )

        if shouldPoll {
            startPermissionPolling()
        } else {
            stopPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        guard permissionTimer == nil else {
            return
        }

        let timer = Timer(
            timeInterval: Self.permissionPollingInterval,
            target: self,
            selector: #selector(permissionTimerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        logger.debug("Permission polling started")
    }

    private func stopPermissionPolling() {
        guard let permissionTimer else {
            return
        }

        permissionTimer.invalidate()
        self.permissionTimer = nil
        logger.debug("Permission polling stopped")
    }

    private func refreshPermissionModel() {
        let state = PermissionState(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess(),
            monitoringRunning: eventTapController?.isRunning == true
        )
        permissionModel.accessibilityGranted = state.accessibilityGranted
        permissionModel.inputMonitoringGranted = state.inputMonitoringGranted
        permissionModel.monitoringRunning = state.monitoringRunning

        if state != lastPermissionState {
            logger.info(
                "Permission state changed; Accessibility: \(state.accessibilityGranted), Input Monitoring: \(state.inputMonitoringGranted), listener: \(state.monitoringRunning)"
            )
            lastPermissionState = state
        }
    }

    private func refreshMenuState() {
        guard enabledMenuItem != nil else {
            return
        }

        enabledMenuItem.state = isEnabled ? .on : .off
        launchAtLoginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        if !isEnabled {
            statusMenuItem.title = "监听状态：已关闭"
        } else if !AXIsProcessTrusted() {
            statusMenuItem.title = "监听状态：需要辅助功能权限"
        } else if eventTapController?.isRunning == true {
            statusMenuItem.title = "监听状态：运行中"
        } else if !CGPreflightListenEventAccess() {
            statusMenuItem.title = "监听状态：无法启动，请检查输入监控"
        } else {
            statusMenuItem.title = "监听状态：不可用"
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        refreshMonitoring()
    }

    @objc private func permissionTimerDidFire(_ timer: Timer) {
        refreshMonitoring()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
        refreshMenuState()
    }

    @objc private func openAccessibilitySettings() {
        requestAccessibilityPermission(openSettings: true)
    }

    @objc private func openInputMonitoringSettings() {
        requestInputMonitoringPermission(openSettings: true)
    }

    @objc private func showPermissionWindow() {
        refreshMonitoring()
        permissionWindowController.show()
    }

    private func restartApplication() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [
            "-c",
            "sleep 1; exec /usr/bin/open -n \"$1\"",
            "tabtap-relaunch",
            Bundle.main.bundlePath,
        ]

        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            logger.error("Unable to relaunch TabTap: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func openSystemSettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
