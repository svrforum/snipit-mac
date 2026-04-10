import SwiftUI

struct EditorCanvasView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        GeometryReader { geometry in
            let imageSize = viewModel.image.size
            let canvasSize = geometry.size
            let fitted = fittedRect(imageSize: imageSize, in: canvasSize)

            ZStack {
                // Layer 1: Base image
                Image(nsImage: viewModel.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Layer 2: Canvas for committed annotations + live preview
                Canvas { context, size in
                    // Draw committed annotations
                    for annotation in viewModel.annotations {
                        annotation.draw(in: &context, size: size)
                    }

                    // Draw live preview of current tool
                    if viewModel.isDrawing {
                        drawPreview(in: &context, size: size)
                    }
                }
                .frame(width: fitted.width, height: fitted.height)

                // Layer 3: Invisible interaction layer
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: fitted.width, height: fitted.height)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let point = value.location
                                if !viewModel.isDrawing {
                                    viewModel.beginDraw(at: point)
                                } else {
                                    viewModel.continueDraw(at: point)
                                }
                            }
                            .onEnded { value in
                                viewModel.endDraw(at: value.location)
                            }
                    )
            }
        }
    }

    // MARK: - Live Preview Rendering

    private func drawPreview(in context: inout GraphicsContext, size: CGSize) {
        let color = viewModel.strokeColor
        let width = viewModel.strokeWidth
        let points = viewModel.drawingPoints
        let start = viewModel.drawStartPoint ?? .zero
        let current = viewModel.drawCurrentPoint ?? .zero

        switch viewModel.currentTool {
        case .pen:
            guard points.count >= 2 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(color), lineWidth: width)

        case .arrow:
            var path = Path()
            path.move(to: start)
            path.addLine(to: current)
            // Arrowhead
            let angle = atan2(current.y - start.y, current.x - start.x)
            let arrowAngle: CGFloat = .pi / 6
            let arrowLen: CGFloat = 15
            let left = CGPoint(
                x: current.x - arrowLen * cos(angle - arrowAngle),
                y: current.y - arrowLen * sin(angle - arrowAngle)
            )
            let right = CGPoint(
                x: current.x - arrowLen * cos(angle + arrowAngle),
                y: current.y - arrowLen * sin(angle + arrowAngle)
            )
            path.move(to: left)
            path.addLine(to: current)
            path.addLine(to: right)
            context.stroke(path, with: .color(color), lineWidth: width)

        case .line:
            var path = Path()
            path.move(to: start)
            path.addLine(to: current)
            context.stroke(path, with: .color(color), lineWidth: width)

        case .rectangle:
            let rect = CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )
            context.stroke(Path(rect), with: .color(color), lineWidth: width)

        case .ellipse:
            let rect = CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )
            context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: width)

        case .highlight:
            guard points.count >= 2 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(.yellow.opacity(0.4)),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )

        case .blur:
            let rect = CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )
            context.stroke(
                Path(rect),
                with: .color(.gray.opacity(0.5)),
                style: StrokeStyle(lineWidth: 2, dash: [6, 3])
            )
            context.fill(Path(rect), with: .color(.gray.opacity(0.15)))

        default:
            break
        }
    }

    // MARK: - Helpers

    private func fittedRect(imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
}
