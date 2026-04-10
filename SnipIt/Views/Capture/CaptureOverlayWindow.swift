import AppKit
import ScreenCaptureKit
import SwiftUI

// MARK: - CaptureResult

enum CaptureResult {
    case window(SCWindow)
    case region(SCDisplay, CGRect)
    case fullScreen
}

// MARK: - Overlay State (Observable for SwiftUI binding)

@Observable
final class OverlayState {
    var mousePosition: CGPoint = .zero
    var startPoint: CGPoint = .zero
    var currentPoint: CGPoint = .zero
    var isSelecting = false
    var screenImage: NSImage?
    var detectedWindowFrame: CGRect?
    var windowTitle: String?
    var dimmingOpacity: Double = 0.3
}

// MARK: - OverlayContentView

struct OverlayContentView: View {
    @Bindable var state: OverlayState

    var body: some View {
        ZStack {
            if state.isSelecting {
                RegionSelectionView(
                    dimmingOpacity: state.dimmingOpacity,
                    startPoint: state.startPoint,
                    currentPoint: state.currentPoint,
                    isSelecting: true
                )

                MagnifierView(screenImage: state.screenImage, mousePosition: state.mousePosition)
                    .position(
                        x: state.mousePosition.x + 80,
                        y: state.mousePosition.y - 80
                    )
            } else {
                RegionSelectionView(
                    dimmingOpacity: state.dimmingOpacity,
                    startPoint: .zero,
                    currentPoint: .zero,
                    isSelecting: false
                )

                SmartDetectionView(
                    detectedWindowFrame: state.detectedWindowFrame,
                    windowTitle: state.windowTitle
                )

                MagnifierView(screenImage: state.screenImage, mousePosition: state.mousePosition)
                    .position(
                        x: state.mousePosition.x + 80,
                        y: state.mousePosition.y - 80
                    )
            }
        }
    }
}

// MARK: - CaptureOverlayWindow

final class CaptureOverlayWindow: NSObject {

    // MARK: - Dependencies

    private let captureVM: CaptureViewModel
    private let state: OverlayState

    // MARK: - State

    private var overlayWindow: NSWindow?
    private var continuation: CheckedContinuation<CaptureResult?, Never>?

    private var isDragging = false
    private var detectedWindow: SCWindow?

    private var localMonitor: Any?

    private let captureService = ScreenCaptureService()

    // MARK: - Initialization

    init(captureVM: CaptureViewModel, dimmingOpacity: Double = 0.4) {
        self.captureVM = captureVM
        self.state = OverlayState()
        self.state.dimmingOpacity = dimmingOpacity
        super.init()
    }

    // MARK: - Public

    @MainActor
    func show() async -> CaptureResult? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            setupOverlay()
        }
    }

    // MARK: - Setup

    @MainActor
    private func setupOverlay() {
        let window = NSWindow.createOverlayWindow()
        overlayWindow = window

        // Create NSHostingView ONCE with observable state
        let contentView = OverlayContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        // Capture screen image for magnifier
        Task {
            await captureScreenImage()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        installEventMonitors()
    }

    // MARK: - Screen Image

    private func captureScreenImage() async {
        do {
            let content = try await captureService.getAvailableContent()
            guard let display = content.displays.first else { return }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int(display.width)
            configuration.height = Int(display.height)
            configuration.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            await MainActor.run {
                self.state.screenImage = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: display.width, height: display.height)
                )
            }
        } catch {
            // Magnifier will simply not show an image
        }
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown]
        ) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved:
            handleMouseMoved(event)
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
        case .leftMouseUp:
            handleMouseUp(event)
        case .keyDown:
            handleKeyDown(event)
        default:
            break
        }
    }

    // MARK: - Mouse Handlers

    private func handleMouseMoved(_ event: NSEvent) {
        guard let window = overlayWindow else { return }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let flipped = CGPoint(x: point.x, y: window.frame.height - point.y)

        Task { @MainActor in
            state.mousePosition = flipped
        }

        // Smart window detection
        Task {
            do {
                let screenPoint = NSEvent.mouseLocation
                let detected = try await captureService.findWindow(at: screenPoint)
                await MainActor.run {
                    self.detectedWindow = detected
                    if let detected {
                        let screen = NSScreen.main
                        let screenHeight = screen?.frame.height ?? 0
                        let wFrame = detected.frame
                        let overlayFrame = CGRect(
                            x: wFrame.origin.x,
                            y: screenHeight - wFrame.origin.y - wFrame.height,
                            width: wFrame.width,
                            height: wFrame.height
                        )
                        self.state.detectedWindowFrame = overlayFrame
                        self.state.windowTitle = detected.title
                    } else {
                        self.state.detectedWindowFrame = nil
                        self.state.windowTitle = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.detectedWindow = nil
                    self.state.detectedWindowFrame = nil
                    self.state.windowTitle = nil
                }
            }
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window = overlayWindow else { return }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let flipped = CGPoint(x: point.x, y: window.frame.height - point.y)

        isDragging = false

        Task { @MainActor in
            state.startPoint = flipped
            state.currentPoint = flipped
        }
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let window = overlayWindow else { return }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let flipped = CGPoint(x: point.x, y: window.frame.height - point.y)

        isDragging = true

        Task { @MainActor in
            state.currentPoint = flipped
            state.mousePosition = flipped
            state.isSelecting = true
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        if state.isSelecting {
            let rect = CGRect(
                x: min(state.startPoint.x, state.currentPoint.x),
                y: min(state.startPoint.y, state.currentPoint.y),
                width: abs(state.currentPoint.x - state.startPoint.x),
                height: abs(state.currentPoint.y - state.startPoint.y)
            )

            if rect.width > 5 && rect.height > 5 {
                Task {
                    do {
                        let content = try await captureService.getAvailableContent()
                        guard let display = content.displays.first else { return }

                        let screenHeight = CGFloat(display.height)
                        let captureRect = CGRect(
                            x: rect.origin.x,
                            y: screenHeight - rect.origin.y - rect.height,
                            width: rect.width,
                            height: rect.height
                        )

                        await finish(with: .region(display, captureRect))
                    } catch {
                        await finish(with: nil)
                    }
                }
            } else {
                Task { @MainActor in
                    state.isSelecting = false
                }
                isDragging = false
            }
        } else if !isDragging, let window = detectedWindow {
            Task {
                await finish(with: .window(window))
            }
        }
    }

    // MARK: - Key Handlers

    private func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 53: // ESC
            Task { await finish(with: nil) }
        case 49: // Space
            Task { await finish(with: .fullScreen) }
        default:
            break
        }
    }

    // MARK: - Finish & Cleanup

    @MainActor
    private func finish(with result: CaptureResult?) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil

        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        continuation?.resume(returning: result)
        continuation = nil
    }
}
