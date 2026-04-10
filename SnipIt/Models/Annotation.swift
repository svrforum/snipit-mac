import SwiftUI

// MARK: - Annotation Protocol

protocol Annotation: Identifiable, Equatable {
    var id: UUID { get }
    var color: Color { get set }
    var strokeWidth: CGFloat { get set }
    func draw(in context: inout GraphicsContext, size: CGSize)
}

// MARK: - PenAnnotation

struct PenAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 2
    var points: [CGPoint] = []

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(color), lineWidth: strokeWidth)
    }
}

// MARK: - ArrowAnnotation

struct ArrowAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 2
    var start: CGPoint = .zero
    var end: CGPoint = .zero
    var arrowheadLength: CGFloat = 15

    func draw(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle: CGFloat = .pi / 6
        let leftPoint = CGPoint(
            x: end.x - arrowheadLength * cos(angle - arrowAngle),
            y: end.y - arrowheadLength * sin(angle - arrowAngle)
        )
        let rightPoint = CGPoint(
            x: end.x - arrowheadLength * cos(angle + arrowAngle),
            y: end.y - arrowheadLength * sin(angle + arrowAngle)
        )
        path.move(to: leftPoint)
        path.addLine(to: end)
        path.addLine(to: rightPoint)

        context.stroke(path, with: .color(color), lineWidth: strokeWidth)
    }
}

// MARK: - LineAnnotation

struct LineAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 2
    var start: CGPoint = .zero
    var end: CGPoint = .zero

    func draw(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: strokeWidth)
    }
}

// MARK: - RectangleAnnotation

struct RectangleAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 2
    var origin: CGPoint = .zero
    var size: CGSize = .zero

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: origin, size: self.size)
        context.stroke(Path(rect), with: .color(color), lineWidth: strokeWidth)
    }
}

// MARK: - EllipseAnnotation

struct EllipseAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 2
    var origin: CGPoint = .zero
    var size: CGSize = .zero

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: origin, size: self.size)
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: strokeWidth)
    }
}

// MARK: - TextAnnotation

struct TextAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 0
    var position: CGPoint = .zero
    var text: String = ""
    var font: String = "Helvetica"
    var fontSize: CGFloat = 16
    var bold: Bool = false
    var italic: Bool = false

    func draw(in context: inout GraphicsContext, size: CGSize) {
        var resolvedFont = Font.custom(font, size: fontSize)
        if bold { resolvedFont = resolvedFont.bold() }
        if italic { resolvedFont = resolvedFont.italic() }

        let textView = Text(text)
            .font(resolvedFont)
            .foregroundColor(color)

        context.draw(
            context.resolve(textView),
            at: position,
            anchor: .topLeading
        )
    }
}

// MARK: - HighlightAnnotation

struct HighlightAnnotation: Annotation {
    let id = UUID()
    var color: Color = .yellow
    var strokeWidth: CGFloat = 20
    var points: [CGPoint] = []
    var opacity: Double = 0.4

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - NumberAnnotation

struct NumberAnnotation: Annotation {
    let id = UUID()
    var color: Color = .red
    var strokeWidth: CGFloat = 0
    var position: CGPoint = .zero
    var number: Int = 1
    var circleRadius: CGFloat = 14

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let circleRect = CGRect(
            x: position.x - circleRadius,
            y: position.y - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        context.fill(Path(ellipseIn: circleRect), with: .color(color))

        let numberText = Text("\(number)")
            .font(.system(size: circleRadius, weight: .bold))
            .foregroundColor(.white)

        context.draw(
            context.resolve(numberText),
            at: position,
            anchor: .center
        )
    }
}

// MARK: - StepAnnotation

struct StepAnnotation: Annotation {
    let id = UUID()
    var color: Color = .blue
    var strokeWidth: CGFloat = 0
    var position: CGPoint = .zero
    var number: Int = 1
    var text: String = ""
    var cornerRadius: CGFloat = 8
    var padding: CGFloat = 8

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let label = "\(number). \(text)"
        let textView = Text(label)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)

        let resolved = context.resolve(textView)
        let textSize = resolved.measure(in: size)

        let bubbleRect = CGRect(
            x: position.x,
            y: position.y,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        let bubblePath = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)
        context.fill(bubblePath, with: .color(color))

        context.draw(
            resolved,
            at: CGPoint(x: bubbleRect.midX, y: bubbleRect.midY),
            anchor: .center
        )
    }
}

// MARK: - CodeBlockAnnotation

struct CodeBlockAnnotation: Annotation {
    let id = UUID()
    var color: Color = .green
    var strokeWidth: CGFloat = 1
    var origin: CGPoint = .zero
    var text: String = ""
    var fontSize: CGFloat = 12
    var padding: CGFloat = 12
    var backgroundColor: Color = Color(white: 0.15)

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let codeText = Text(text)
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundColor(color)

        let resolved = context.resolve(codeText)
        let textSize = resolved.measure(in: size)

        let blockRect = CGRect(
            x: origin.x,
            y: origin.y,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        let blockPath = Path(roundedRect: blockRect, cornerRadius: 6)
        context.fill(blockPath, with: .color(backgroundColor))
        context.stroke(blockPath, with: .color(color.opacity(0.3)), lineWidth: strokeWidth)

        context.draw(
            resolved,
            at: CGPoint(x: blockRect.midX, y: blockRect.midY),
            anchor: .center
        )
    }
}

// MARK: - AnyAnnotation (Type-Erased Wrapper)

struct AnyAnnotation: Identifiable, Equatable {
    let id: UUID
    let base: any Annotation
    private let _draw: (inout GraphicsContext, CGSize) -> Void
    private let _isEqual: (any Annotation) -> Bool

    init<A: Annotation>(_ annotation: A) {
        self.id = annotation.id
        self.base = annotation
        self._draw = { context, size in
            annotation.draw(in: &context, size: size)
        }
        self._isEqual = { other in
            guard let otherTyped = other as? A else { return false }
            return annotation == otherTyped
        }
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        _draw(&context, size)
    }

    static func == (lhs: AnyAnnotation, rhs: AnyAnnotation) -> Bool {
        lhs._isEqual(rhs.base)
    }
}
