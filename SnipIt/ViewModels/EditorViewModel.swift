import AppKit
import SwiftUI

// MARK: - EditorTool

enum EditorTool: String, CaseIterable, Identifiable {
    case select, pen, arrow, line, rectangle, ellipse, text, highlight,
         blur, crop, ocr, number, step, codeBlock

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select:    return "cursorarrow"
        case .pen:       return "pencil.tip"
        case .arrow:     return "arrow.up.right"
        case .line:      return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse:   return "circle"
        case .text:      return "textformat"
        case .highlight: return "highlighter"
        case .blur:      return "circle.grid.3x3"
        case .crop:      return "crop"
        case .ocr:       return "text.viewfinder"
        case .number:    return "number.circle"
        case .step:      return "text.bubble"
        case .codeBlock: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var label: String {
        switch self {
        case .select:    return "선택"
        case .pen:       return "펜"
        case .arrow:     return "화살표"
        case .line:      return "직선"
        case .rectangle: return "사각형"
        case .ellipse:   return "원"
        case .text:      return "텍스트"
        case .highlight: return "형광펜"
        case .blur:      return "블러"
        case .crop:      return "자르기"
        case .ocr:       return "OCR"
        case .number:    return "번호"
        case .step:      return "스텝"
        case .codeBlock: return "코드"
        }
    }

    /// Display character for tooltip
    var shortcutKey: Character? {
        switch self {
        case .select:    return "V"
        case .pen:       return "P"
        case .arrow:     return "A"
        case .line:      return "L"
        case .rectangle: return "R"
        case .ellipse:   return "E"
        case .text:      return "T"
        case .highlight: return "H"
        case .blur:      return "M"
        case .crop:      return "C"
        default:         return nil
        }
    }

    /// Hardware keyCode (language-independent)
    var keyCode: UInt16? {
        switch self {
        case .select:    return 9   // V
        case .pen:       return 35  // P
        case .arrow:     return 0   // A
        case .line:      return 37  // L
        case .rectangle: return 15  // R
        case .ellipse:   return 14  // E
        case .text:      return 17  // T
        case .highlight: return 4   // H
        case .blur:      return 46  // M
        case .crop:      return 8   // C
        default:         return nil
        }
    }

    static func fromKeyCode(_ code: UInt16) -> EditorTool? {
        allCases.first { $0.keyCode == code }
    }
}

// MARK: - EditorViewModel

@Observable
final class EditorViewModel {

    // MARK: - Image

    var image: NSImage

    // MARK: - Annotations

    var annotations: [AnyAnnotation] = []

    // MARK: - Tool State

    var currentTool: EditorTool = .select
    var strokeColor: Color = .red
    var strokeWidth: CGFloat = 3
    var fontSize: CGFloat = 16
    var fontBold = false
    var fontItalic = false

    // MARK: - Drawing State

    var isDrawing = false
    var drawingPoints: [CGPoint] = []
    var drawStartPoint: CGPoint?
    var drawCurrentPoint: CGPoint?

    // MARK: - Canvas Scale (fitted size → original image size)

    var canvasScale: CGFloat = 1.0

    // MARK: - Numbering

    var nextNumber: Int = 1

    // MARK: - Undo / Redo

    var undoStack: [[AnyAnnotation]] = []
    var redoStack: [[AnyAnnotation]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Initialization

    init(image: NSImage) {
        self.image = image
    }

    // MARK: - Drawing Lifecycle

    func beginDraw(at point: CGPoint) {
        isDrawing = true
        drawingPoints = [point]
        drawStartPoint = point
        drawCurrentPoint = point
    }

    func continueDraw(at point: CGPoint) {
        guard isDrawing else { return }
        drawingPoints.append(point)
        drawCurrentPoint = point
    }

    func endDraw(at point: CGPoint) {
        guard isDrawing else { return }
        drawingPoints.append(point)
        drawCurrentPoint = point
        isDrawing = false
        commitAnnotation()
    }

    // MARK: - Commit Annotation

    func commitAnnotation() {
        guard let start = drawStartPoint, let end = drawCurrentPoint else { return }

        pushUndo()

        switch currentTool {
        case .pen:
            var annotation = PenAnnotation()
            annotation.color = strokeColor
            annotation.strokeWidth = strokeWidth
            annotation.points = drawingPoints
            annotations.append(AnyAnnotation(annotation))

        case .arrow:
            var annotation = ArrowAnnotation()
            annotation.color = strokeColor
            annotation.strokeWidth = strokeWidth
            annotation.start = start
            annotation.end = end
            annotations.append(AnyAnnotation(annotation))

        case .line:
            var annotation = LineAnnotation()
            annotation.color = strokeColor
            annotation.strokeWidth = strokeWidth
            annotation.start = start
            annotation.end = end
            annotations.append(AnyAnnotation(annotation))

        case .rectangle:
            var annotation = RectangleAnnotation()
            annotation.color = strokeColor
            annotation.strokeWidth = strokeWidth
            annotation.origin = CGPoint(
                x: min(start.x, end.x),
                y: min(start.y, end.y)
            )
            annotation.size = CGSize(
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            annotations.append(AnyAnnotation(annotation))

        case .ellipse:
            var annotation = EllipseAnnotation()
            annotation.color = strokeColor
            annotation.strokeWidth = strokeWidth
            annotation.origin = CGPoint(
                x: min(start.x, end.x),
                y: min(start.y, end.y)
            )
            annotation.size = CGSize(
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            annotations.append(AnyAnnotation(annotation))

        case .highlight:
            var annotation = HighlightAnnotation()
            annotation.color = strokeColor
            annotation.strokeWidth = strokeWidth
            annotation.points = drawingPoints
            annotations.append(AnyAnnotation(annotation))

        case .number:
            var annotation = NumberAnnotation()
            annotation.color = strokeColor
            annotation.position = start
            annotation.number = nextNumber
            annotations.append(AnyAnnotation(annotation))
            nextNumber += 1

        case .step:
            var annotation = StepAnnotation()
            annotation.color = strokeColor
            annotation.position = start
            annotation.number = nextNumber
            annotations.append(AnyAnnotation(annotation))
            nextNumber += 1

        case .codeBlock:
            var annotation = CodeBlockAnnotation()
            annotation.color = strokeColor
            annotation.origin = start
            annotations.append(AnyAnnotation(annotation))

        case .blur:
            let origin = CGPoint(
                x: min(start.x, end.x),
                y: min(start.y, end.y)
            )
            let blurSize = CGSize(
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            var annotation = BlurAnnotation()
            annotation.origin = origin
            annotation.size = blurSize
            annotations.append(AnyAnnotation(annotation))

            // Convert canvas coordinates to original image coordinates
            let s = canvasScale
            let imageRect = CGRect(
                x: origin.x * s,
                y: origin.y * s,
                width: blurSize.width * s,
                height: blurSize.height * s
            )
            image = ImageProcessor.applyMosaic(to: image, in: imageRect)

        case .select, .text, .crop, .ocr:
            break
        }

        drawingPoints = []
        drawStartPoint = nil
        drawCurrentPoint = nil
    }

    // MARK: - Text Insertion

    func addText(_ text: String, at position: CGPoint) {
        pushUndo()
        var annotation = TextAnnotation()
        annotation.color = strokeColor
        annotation.position = position
        annotation.text = text
        annotation.fontSize = fontSize
        annotation.bold = fontBold
        annotation.italic = fontItalic
        annotations.append(AnyAnnotation(annotation))
    }

    // MARK: - Undo / Redo

    func pushUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    func undo() {
        guard canUndo else { return }
        redoStack.append(annotations)
        annotations = undoStack.removeLast()
    }

    func redo() {
        guard canRedo else { return }
        undoStack.append(annotations)
        annotations = redoStack.removeLast()
    }

    // MARK: - Final Image Rendering

    @MainActor func renderFinalImage() -> NSImage {
        let size = image.size
        let finalImage = NSImage(size: size)

        finalImage.lockFocus()

        // Draw the base screenshot
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )

        finalImage.unlockFocus()

        // Composite annotations via ImageRenderer
        let annotationsCopy = annotations
        let renderer = ImageRenderer(
            content: Canvas { context, canvasSize in
                for annotation in annotationsCopy {
                    annotation.draw(in: &context, size: canvasSize)
                }
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 1.0

        guard let cgOverlay = renderer.cgImage else { return finalImage }
        let overlayImage = NSImage(cgImage: cgOverlay, size: size)

        finalImage.lockFocus()
        overlayImage.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .sourceOver,
            fraction: 1.0
        )
        finalImage.unlockFocus()

        return finalImage
    }
}
