import SwiftUI

struct ButtonCaptureField: View {
    let label: String
    let isCapturing: Bool
    let onArm: () -> Void
    let onCapture: (Int) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isCapturing ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isCapturing ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isCapturing ? 1.5 : 1
                )
                .allowsHitTesting(false)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isCapturing ? .accentColor : .primary)
                .allowsHitTesting(false)

            MouseCaptureInputView(
                isCapturing: isCapturing,
                onArm: onArm,
                onCapture: onCapture
            )
        }
        .frame(width: 148, height: 30)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MouseCaptureInputView: NSViewRepresentable {
    let isCapturing: Bool
    let onArm: () -> Void
    let onCapture: (Int) -> Void

    func makeNSView(context: Context) -> MouseCaptureNSView {
        let view = MouseCaptureNSView()
        view.isCapturing = isCapturing
        view.onArm = onArm
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: MouseCaptureNSView, context: Context) {
        nsView.isCapturing = isCapturing
        nsView.onArm = onArm
        nsView.onCapture = onCapture
    }
}

final class MouseCaptureNSView: NSView {
    var isCapturing = false
    var onArm: () -> Void = {}
    var onCapture: (Int) -> Void = { _ in }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        onArm()
    }

    override func rightMouseDown(with event: NSEvent) {}

    override func otherMouseDown(with event: NSEvent) {
        let button = Int(event.buttonNumber)
        guard button > 1 else {
            return
        }

        if !isCapturing {
            onArm()
        }

        onCapture(button)
    }
}
