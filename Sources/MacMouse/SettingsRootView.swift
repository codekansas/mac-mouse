import MacMouseCore
import SwiftUI

struct SettingsRootView: View {
    private enum Layout {
        static let width = 420.0
        static let height = 250.0
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
        }
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Allow Accessibility and Input Monitoring, then assign your mouse buttons.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Click Grant Access.")
                Text("2. Enable MacMouse if macOS asks.")
                Text("3. Come back here.")
            }
            .font(.system(size: 13))

            Spacer()

            HStack(spacing: 8) {
                Button("Grant Access") {
                    model.requestRequiredAccess()
                }
                .keyboardShortcut(.defaultAction)

                Button("Open Settings") {
                    model.openPrivacySettings()
                }
            }
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

            Spacer()

            Text(model.helperText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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
