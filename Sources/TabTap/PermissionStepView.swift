import AppKit

@MainActor
final class PermissionStepView: NSView {
    private let step: Int
    private let action: () -> Void
    private let iconView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let actionButton: NSButton

    init(
        step: Int,
        title: String,
        detail: String,
        buttonTitle: String,
        buttonIcon: String,
        action: @escaping () -> Void
    ) {
        self.step = step
        self.action = action
        actionButton = NSButton(title: buttonTitle, target: nil, action: nil)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detailLabel.textColor = .secondaryLabelColor

        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.bezelStyle = .rounded
        actionButton.image = systemSymbol(buttonIcon, pointSize: 13)
        actionButton.imagePosition = .imageLeading

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let titleRow = NSStackView(views: [
            iconView,
            titleLabel,
            statusLabel,
            spacer,
            actionButton,
        ])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10

        let contentStack = NSStackView(views: [titleRow, detailLabel])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 9
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        titleRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        detailLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isGranted: Bool) {
        let icon = isGranted ? "checkmark.circle.fill" : "\(step).circle.fill"
        iconView.image = systemSymbol(icon, pointSize: 22)
        iconView.contentTintColor = isGranted ? .systemGreen : .controlAccentColor
        statusLabel.stringValue = isGranted ? "已授权" : "待授权"
        statusLabel.textColor = isGranted ? .systemGreen : .secondaryLabelColor
        actionButton.isHidden = isGranted
    }

    @objc private func actionClicked() {
        action()
    }
}
