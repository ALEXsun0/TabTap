import Foundation

public enum AccessibilitySemantics {
    public static func isBrowserTab(
        role: String?,
        roleDescription: String?,
        subrole: String?,
        identifier: String?
    ) -> Bool {
        let role = normalized(role)
        let roleDescription = normalized(roleDescription)
        let subrole = normalized(subrole)
        let identifier = normalized(identifier)

        let hasTabSemantics = roleDescription == "tab"
            || roleDescription.contains("browser tab")
            || roleDescription.contains("标签")
            || subrole.contains("tab")
            || identifier.contains("tab")

        let hasExpectedRole = role == "axradiobutton"
            || role == "axbutton"
            || subrole.contains("tab")

        return hasTabSemantics && hasExpectedRole
    }

    public static func isCloseButton(
        role: String?,
        subrole: String?,
        identifier: String?,
        title: String?,
        description: String?
    ) -> Bool {
        guard normalized(role) == "axbutton" else {
            return false
        }

        let searchable = [subrole, identifier, title, description]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        return searchable.contains("close") || searchable.contains("关闭")
    }

    private static func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }
}
