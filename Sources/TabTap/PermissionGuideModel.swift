import Foundation

@MainActor
final class PermissionGuideModel: ObservableObject {
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false
    @Published var monitoringRunning = false

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }
}
