import Foundation

@MainActor
final class PermissionGuideModel {
    private(set) var accessibilityGranted = false
    private(set) var inputMonitoringGranted = false
    private(set) var monitoringRunning = false
    var onChange: (() -> Void)?

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    func update(
        accessibilityGranted: Bool,
        inputMonitoringGranted: Bool,
        monitoringRunning: Bool
    ) {
        let changed = self.accessibilityGranted != accessibilityGranted
            || self.inputMonitoringGranted != inputMonitoringGranted
            || self.monitoringRunning != monitoringRunning

        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
        self.monitoringRunning = monitoringRunning

        if changed {
            onChange?()
        }
    }
}
