import AppKit
import ScreenCaptureKit
import SwiftUI

// MARK: - CaptureResult

enum CaptureResult {
    case window(SCWindow)
    case region(SCDisplay, CGRect)
    case fullScreen
}

// MARK: - CaptureOverlayWindow

final class CaptureOverlayWindow: NSObject {

    // MARK: - Dependencies

    private let captureVM: CaptureViewModel
    private let dimmingOpacity: Double

    // MARK: - State

    private var overlayWindow: NSWindow?
    private var screenImage: NSImage?
    private var continuation: CheckedContinuation<CaptureResult?, Never>?

    private var mousePosition: CGPoint = .zero
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isSelecting = false
    private var isDragging = false
    private var detectedWindow: SCWindow?
    private var detectedWindowFrame: CGRect?
    private var windowTitle: String?

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var mouseMoveMonitor: Any?

    private let captureService = ScreenCaptureService()

    // MARK: - Initialization

    init(captureVM: CaptureViewModel, dimmingOpacity: Double = 0.4) {
        self.captureVM = captureVM
        self.dimmingOpacity = dimmingOpacity
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

        // Take a screenshot to use for the magnifier
        Task {
            await captureScreenImage()
            updateContent()
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
                self.screenImage = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: display.width, height: display.height)
                )
            }
        } catch {
            // Magnifier will simply not show an image
        }
    }

    // MARK: - Content Update

    @MainActor
    private func updateContent() {
        guard let window = overlayWindow else { return }

        let screenImage = self.screenImage
        let mousePosition = self.mousePosition
        let dimmingOpacity = self.dimmingOpacity
        let startPoint = self.startPoint
        let currentPoint = self.currentPoint
        let isSelecting = self.isSelecting
        let detectedWindowFrame = self.detectedWindowFrame
        let windowTitle = self.windowTitle

        let contentView = ZStack {
            if isSelecting {
                RegionSelectionView(
                    dimmingOpacity: dimmingOpacity,
                    startPoint: startPoint,
                    currentPoint: currentPoint,
                    isSelecting: true
                )

                // Magnifier during drag
                MagnifierView(screenImage: screenImage, mousePosition: mousePosition)
                    .position(
                        x: mousePosition.x + 80,
                        y: mousePosition.y - 80
                    )
            } else {
                // Smart detection mode
                RegionSelectionView(
                    dimmingOpacity: dimmingOpacity,
                    startPoint: .zero,
                    currentPoint: .zero,
                    isSelecting: false
                )

                SmartDetectionView(
                    detectedWindowFrame: detectedWindowFrame,
                    windowTitle: windowTitle
                )

                // Magnifier follows mouse
                MagnifierView(screenImage: screenImage, mousePosition: mousePosition)
                    .position(
                        x: mousePosition.x + 80,
                        y: mousePosition.y - 80
                    )
            }
        }
        .frame(
            width: window.frame.width,
            height: window.frame.height
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        window.contentView = hostingView
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

        mousePosition = flipped

        // Smart window detection
        Task {
            do {
                let screenPoint = NSEvent.mouseLocation
                let detected = try await captureService.findWindow(at: screenPoint)
                await MainActor.run {
                    self.detectedWindow = detected
                    if let detected {
                        // Convert window frame to overlay coordinates
                        let screen = NSScreen.main
                        let screenHeight = screen?.frame.height ?? 0
                        let wFrame = detected.frame
                        let overlayFrame = CGRect(
                            x: wFrame.origin.x,
                            y: screenHeight - wFrame.origin.y - wFrame.height,
                            width: wFrame.width,
                            height: wFrame.height
                        )
                        self.detectedWindowFrame = overlayFrame
                        self.windowTitle = detected.title
                    } else {
                        self.detectedWindowFrame = nil
                        self.windowTitle = nil
                    }
                    self.updateContent()
                }
            } catch {
                await MainActor.run {
                    self.detectedWindow = nil
                    self.detectedWindowFrame = nil
                    self.windowTitle = nil
                    self.updateContent()
                }
            }
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window = overlayWindow else { return }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let flipped = CGPoint(x: point.x, y: window.frame.height - point.y)

        startPoint = flipped
        currentPoint = flipped
        isDragging = false

        Task { @MainActor in
            updateContent()
        }
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let window = overlayWindow else { return }
        let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let flipped = CGPoint(x: point.x, y: window.frame.height - point.y)

        currentPoint = flipped
        isDragging = true
        isSelecting = true

        Task { @MainActor in
            updateContent()
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        if isSelecting {
            // Region selection
            let rect = CGRect(
                x: min(startPoint.x, currentPoint.x),
                y: min(startPoint.y, currentPoint.y),
                width: abs(currentPoint.x - startPoint.x),
                height: abs(currentPoint.y - startPoint.y)
            )

            if rect.width > 5 && rect.height > 5 {
                Task {
                    do {
                        let content = try await captureService.getAvailableContent()
                        guard let display = content.displays.first else { return }

                        // Convert overlay rect to screen coordinates
                        let screenHeight = CGFloat(display.height)
                        let captureRect = CGRect(
                            x: rect.origin.x,
                            y: screenHeight - rect.origin.y - rect.height,
                            width: rect.width,
                            height: rect.height
                        )

                        await cleanup()
                        continuation?.resume(returning: .region(display, captureRect))
                        continuation = nil
                    } catch {
                        await cleanup()
                        continuation?.resume(returning: nil)
                        continuation = nil
                    }
                }
            } else {
                // Too small, reset
                isSelecting = false
                isDragging = false
                Task { @MainActor in
                    updateContent()
                }
            }
        } else if !isDragging, let window = detectedWindow {
            // Click on detected window
            Task {
                await cleanup()
                continuation?.resume(returning: .window(window))
                continuation = nil
            }
        }
    }

    // MARK: - Key Handlers

    private func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 53: // ESC
            Task {
                await cleanup()
                continuation?.resume(returning: nil)
                continuation = nil
            }
        case 49: // Space
            Task {
                await cleanup()
                continuation?.resume(returning: .fullScreen)
                continuation = nil
            }
        default:
            break
        }
    }

    // MARK: - Cleanup

    @MainActor
    private func cleanup() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let mouseMoveMonitor {
            NSEvent.removeMonitor(mouseMoveMonitor)
        }

        localMonitor = nil
        globalMonitor = nil
        mouseMoveMonitor = nil

        overlayWindow?.close()
        overlayWindow = nil
    }
}
