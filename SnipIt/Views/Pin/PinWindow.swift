import AppKit
import SwiftUI

// MARK: - PinWindowView

struct PinWindowView: View {
    let image: NSImage
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)

            Divider()

            HStack {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Slider(value: $opacity, in: 0.2...1.0, step: 0.05)
                    .controlSize(.small)

                Text("\(Int(opacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - PinWindowController

final class PinWindowController {

    // MARK: - Properties

    private var windows: [NSWindow] = []

    // MARK: - Pin Image

    func pin(image: NSImage) {
        let pinView = PinWindowView(image: image)
        let hostingView = NSHostingView(rootView: pinView)

        let contentSize = NSSize(
            width: min(image.size.width, 600),
            height: min(image.size.height, 500) + 32  // Extra space for opacity slider
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "SnipIt - 고정"
        window.contentView = hostingView
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        windows.append(window)
    }

    // MARK: - Close All

    func closeAll() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
    }
}
