import MacMouseCore
import SwiftUI

struct SettingsRootView: View {
    private enum Layout {
        static let width = 420.0
        static let height = 330.0
        static let padding = 18.0
    }

    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.permissionStatus.hasRequiredAccess {
                assignmentsView
            } else {
                permissionView
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .padding(Layout.padding)
        .onAppear {
            model.refreshPermissionState()
            model.refreshRunOnStartupState()
        }
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grant both permissions so MacMouse can read extra mouse buttons and trigger macOS shortcuts.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            permissionChecklist

            Spacer()

            preferencesView

            HStack(spacing: 8) {
                Button("Grant Permissions") {
                    model.requestRequiredAccess()
                }
                .keyboardShortcut(.defaultAction)

                Button("Open Settings") {
                    model.openPrivacySettings()
                }
            }
        }
    }

    private var permissionChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            PermissionRequirementRow(
                title: "Accessibility",
                detail: "Allows MacMouse to control Mission Control and Space shortcuts.",
                isGranted: model.permissionStatus.accessibilityEnabled
            )

            PermissionRequirementRow(
                title: "Input Monitoring",
                detail: "Allows MacMouse to read extra mouse buttons and scroll-wheel input.",
                isGranted: model.permissionStatus.listenEnabled
            )
        }
    }

    private var assignmentsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                ForEach(MouseAction.allCases) { action in
                    AssignmentRow(action: action, model: model)
                }
            }

            Toggle(
                "Show menu bar icon",
                isOn: Binding(
                    get: {
                        model.showsMenuBarIcon
                    },
                    set: { isOn in
                        model.setShowsMenuBarIcon(isOn)
                    }
                )
            )
            .toggleStyle(.switch)
            .font(.system(size: 13))

            preferencesView

            Spacer()

            Text(model.helperText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var preferencesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "Run on Startup",
                isOn: Binding(
                    get: {
                        model.runsOnStartup
                    },
                    set: { isOn in
                        model.setRunsOnStartup(isOn)
                    }
                )
            )
            .toggleStyle(.switch)
            .font(.system(size: 13))
            .disabled(!model.canConfigureRunOnStartup && !model.runsOnStartup)

            if let runOnStartupNote = model.runOnStartupNote {
                Text(runOnStartupNote)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct PermissionRequirementRow: View {
    let title: String
    let detail: String
    let isGranted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundColor(isGranted ? .green : .orange)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    Text(isGranted ? "Granted" : "Needed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isGranted ? .green : .orange)
                }

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AssignmentRow: View {
    let action: MouseAction
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Text(action.title)
                .frame(maxWidth: .infinity, alignment: .leading)

            ButtonCaptureField(
                label: model.buttonLabel(for: action),
                isCapturing: model.isCapturing(action),
                onArm: {
                    model.beginCapture(for: action)
                },
                onCapture: { button in
                    model.assignCapturedButton(button, to: action)
                }
            )

            Button("Clear") {
                model.clearAssignment(for: action)
            }
            .buttonStyle(.plain)
            .foregroundColor(model.assignments[action] == nil ? .clear : .secondary)
            .disabled(model.assignments[action] == nil)
            .frame(width: 36, alignment: .trailing)
        }
        .font(.system(size: 14))
    }
}
