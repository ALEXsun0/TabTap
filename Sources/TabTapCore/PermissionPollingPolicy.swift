public enum PermissionPollingPolicy {
    public static func shouldPoll(isEnabled: Bool, monitoringRunning: Bool) -> Bool {
        isEnabled && !monitoringRunning
    }
}
