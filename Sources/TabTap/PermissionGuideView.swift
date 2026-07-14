import AppKit

@MainActor
final class PermissionGuideView: NSView {
    private let model: PermissionGuideModel
    private let recheckPermissions: () -> Void
    private let restartApplication: () -> Void
    private let finish: () -> Void

    private let accessibilityStep: PermissionStepView
    private let inputMonitoringStep: PermissionStepView
    private let monitoringImageView = NSImageView()
    private let monitoringLabel = NSTextField(labelWithString: "")
    private let finishButton = NSButton()

    init(
        model: PermissionGuideModel,
        requestAccessibility: @escaping () -> Void,
        requestInputMonitoring: @escaping () -> Void,
        recheckPermissions: @escaping () -> Void,
        restartApplication: @escaping () -> Void,
        finish: @escaping () -> Void
    ) {
        self.model = model
        self.recheckPermissions = recheckPermissions
        self.restartApplication = restartApplication
        self.finish = finish
        accessibilityStep = PermissionStepView(
            step: 1,
            title: "辅助功能",
            detail: "允许识别 Chrome 原生标签页。更新测试版后若开关已开启但仍待授权，请关闭后重新开启。",
            buttonTitle: "打开辅助功能设置",
            buttonIcon: "gearshape",
            action: requestAccessibility
        )
        inputMonitoringStep = PermissionStepView(
            step: 2,
            title: "输入监控",
            detail: "授权后需要重新启动 TabTap。未正式签名的测试版若未自动出现，请使用“+”添加。",
            buttonTitle: "申请并打开设置",
            buttonIcon: "cursorarrow.click.2",
            action: requestInputMonitoring
        )

        super.init(frame: .zero)
        buildLayout()
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update() {
        accessibilityStep.update(isGranted: model.accessibilityGranted)
        inputMonitoringStep.update(isGranted: model.inputMonitoringGranted)

        let isRunning = model.monitoringRunning
        let monitoringIcon = isRunning ? "checkmark.circle.fill" : "circle.dotted"
        monitoringImageView.image = systemSymbol(monitoringIcon, pointSize: 15)
        monitoringImageView.contentTintColor = isRunning ? .systemGreen : .secondaryLabelColor

        if isRunning {
            monitoringLabel.stringValue = "监听运行中"
        } else if model.allPermissionsGranted {
            monitoringLabel.stringValue = "正在启动监听"
        } else {
            monitoringLabel.stringValue = "等待完成授权"
        }
        monitoringLabel.textColor = isRunning ? .systemGreen : .secondaryLabelColor
        finishButton.isEnabled = model.allPermissionsGranted
    }

    private func buildLayout() {
        let header = makeHeader()
        let divider = NSBox()
        divider.boxType = .separator

        let rootStack = NSStackView(views: [
            header,
            accessibilityStep,
            inputMonitoringStep,
            divider,
            makeFooter(),
        ])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 18
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        for view in rootStack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
        ])
    }

    private func makeHeader() -> NSView {
        let iconView = NSImageView()
        iconView.image = systemSymbol("rectangle.stack.badge.minus", pointSize: 25)
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 46),
            iconView.heightAnchor.constraint(equalToConstant: 46),
        ])

        let titleLabel = NSTextField(labelWithString: "设置 TabTap")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let detailLabel = NSTextField(
            labelWithString: "依次完成两项系统授权，TabTap 将在菜单栏静默运行。"
        )
        detailLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detailLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let header = NSStackView(views: [iconView, textStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14
        return header
    }

    private func makeFooter() -> NSView {
        monitoringImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            monitoringImageView.widthAnchor.constraint(equalToConstant: 18),
            monitoringImageView.heightAnchor.constraint(equalToConstant: 18),
        ])
        monitoringLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let recheckButton = makeButton(
            title: "重新检测",
            icon: "arrow.clockwise",
            action: #selector(recheckPermissionsClicked)
        )
        let restartButton = makeButton(
            title: "重新启动",
            icon: "arrow.clockwise.circle",
            action: #selector(restartApplicationClicked)
        )

        finishButton.title = "完成并在后台运行"
        finishButton.target = self
        finishButton.action = #selector(finishClicked)
        finishButton.bezelStyle = .rounded
        finishButton.keyEquivalent = "\r"

        let footer = NSStackView(views: [
            monitoringImageView,
            monitoringLabel,
            spacer,
            recheckButton,
            restartButton,
            finishButton,
        ])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10
        return footer
    }

    private func makeButton(title: String, icon: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.image = systemSymbol(icon, pointSize: 13)
        button.imagePosition = .imageLeading
        return button
    }

    @objc private func recheckPermissionsClicked() {
        recheckPermissions()
    }

    @objc private func restartApplicationClicked() {
        restartApplication()
    }

    @objc private func finishClicked() {
        finish()
    }
}

func systemSymbol(_ name: String, pointSize: CGFloat) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
}
