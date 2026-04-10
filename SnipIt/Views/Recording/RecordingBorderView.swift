import AppKit
import QuartzCore

// MARK: - RecordingBorderWindow

final class RecordingBorderWindow {

    // MARK: - Properties

    private var window: NSWindow?
    private var borderLayer: CAShapeLayer?

    private let borderWidth: CGFloat = 3
    private let borderColor: NSColor = .red

    // MARK: - Show

    @MainActor
    func show(around rect: CGRect) {
        guard let screen = NSScreen.main else { return }

        // Convert from screen coordinates (bottom-left origin) to window frame
        let padding = borderWidth * 2
        let windowFrame = CGRect(
            x: rect.origin.x - padding,
            y: screen.frame.height - rect.origin.y - rect.height - padding,
            width: rect.width + padding * 2,
            height: rect.height + padding * 2
        )

        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = NSView(frame: NSRect(origin: .zero, size: windowFrame.size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        // Create red border layer
        let borderLayer = CAShapeLayer()
        let inset = borderWidth / 2
        let borderRect = NSRect(
            x: inset,
            y: inset,
            width: windowFrame.width - borderWidth,
            height: windowFrame.height - borderWidth
        )
        borderLayer.path = CGPath(
            roundedRect: borderRect,
            cornerWidth: 2,
            cornerHeight: 2,
            transform: nil
        )
        borderLayer.fillColor = nil
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = borderWidth

        // Pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.4
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        borderLayer.add(pulseAnimation, forKey: "pulse")

        contentView.layer?.addSublayer(borderLayer)
        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)

        self.window = window
        self.borderLayer = borderLayer
    }

    // MARK: - Hide

    @MainActor
    func hide() {
        borderLayer?.removeAllAnimations()
        borderLayer = nil

        window?.close()
        window = nil
    }
}
