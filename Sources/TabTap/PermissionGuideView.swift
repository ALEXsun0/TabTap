import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var model: PermissionGuideModel
    let requestAccessibility: () -> Void
    let requestInputMonitoring: () -> Void
    let recheckPermissions: () -> Void
    let restartApplication: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            PermissionStepRow(
                step: 1,
                title: "辅助功能",
                detail: "允许识别 Chrome 原生标签页。更新测试版后若开关已开启但仍待授权，请关闭后重新开启。",
                isGranted: model.accessibilityGranted,
                isEnabled: true,
                buttonTitle: "打开辅助功能设置",
                buttonIcon: "gearshape",
                action: requestAccessibility
            )

            PermissionStepRow(
                step: 2,
                title: "输入监控",
                detail: "授权后需要重新启动 TabTap。未正式签名的测试版若未自动出现，请使用“+”添加。",
                isGranted: model.inputMonitoringGranted,
                isEnabled: true,
                buttonTitle: "申请并打开设置",
                buttonIcon: "cursorarrow.click.2",
                action: requestInputMonitoring
            )

            Divider()

            HStack(spacing: 12) {
                Label(monitoringText, systemImage: monitoringIcon)
                    .foregroundStyle(monitoringColor)
                    .font(.callout)

                Spacer()

                Button(action: recheckPermissions) {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }

                Button(action: restartApplication) {
                    Label("重新启动", systemImage: "arrow.clockwise.circle")
                }

                Button(action: finish) {
                    Text("完成并在后台运行")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.allPermissionsGranted)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: 46, height: 46)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("设置 TabTap")
                    .font(.title2.weight(.semibold))
                Text("依次完成两项系统授权，TabTap 将在菜单栏静默运行。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monitoringText: String {
        if model.monitoringRunning {
            return "监听运行中"
        }
        if model.allPermissionsGranted {
            return "正在启动监听"
        }
        return "等待完成授权"
    }

    private var monitoringIcon: String {
        model.monitoringRunning ? "checkmark.circle.fill" : "circle.dotted"
    }

    private var monitoringColor: Color {
        model.monitoringRunning ? .green : .secondary
    }
}

private struct PermissionStepRow: View {
    let step: Int
    let title: String
    let detail: String
    let isGranted: Bool
    let isEnabled: Bool
    let buttonTitle: String
    let buttonIcon: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "\(step).circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(stepColor)
                    .frame(width: 30)

                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(isGranted ? "已授权" : "待授权")
                        .font(.caption)
                        .foregroundStyle(isGranted ? .green : .secondary)
                }

                Spacer()
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !isGranted {
                HStack {
                    Spacer()
                    Button(action: action) {
                        Label(buttonTitle, systemImage: buttonIcon)
                    }
                    .disabled(!isEnabled)
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
    }

    private var stepColor: Color {
        if isGranted {
            return .green
        }
        return isEnabled ? .accentColor : .secondary.opacity(0.5)
    }
}
