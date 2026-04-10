import SwiftUI

// MARK: - DimmingOverlay

struct DimmingOverlay: View {
    let opacity: Double
    let cutoutRect: CGRect

    var body: some View {
        Canvas { context, canvasSize in
            // Fill entire area with dimming color
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.black.opacity(opacity))
            )

            // Cut out the selection rectangle
            context.blendMode = .destinationOut
            context.fill(
                Path(cutoutRect),
                with: .color(.white)
            )
        }
        .compositingGroup()
    }
}

// MARK: - RegionSelectionView

struct RegionSelectionView: View {
    let dimmingOpacity: Double
    let startPoint: CGPoint
    let currentPoint: CGPoint
    let isSelecting: Bool

    var selectionRect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    var body: some View {
        if isSelecting {
            ZStack {
                // Dimming overlay with cutout
                DimmingOverlay(opacity: dimmingOpacity, cutoutRect: selectionRect)

                // Selection border
                Rectangle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(
                        x: selectionRect.midX,
                        y: selectionRect.midY
                    )

                // Corner handles
                ForEach(cornerPositions, id: \.x) { corner in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .position(corner)
                }

                // Size label
                sizeLabel
            }
        } else {
            // When not selecting, just a solid dimming overlay
            Color.black.opacity(dimmingOpacity)
        }
    }

    // MARK: - Corner Positions

    private var cornerPositions: [CGPoint] {
        let rect = selectionRect
        return [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
    }

    // MARK: - Size Label

    @ViewBuilder
    private var sizeLabel: some View {
        let rect = selectionRect
        let w = Int(rect.width)
        let h = Int(rect.height)

        Text("\(w) \u{00D7} \(h)")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
            )
            .position(
                x: rect.midX,
                y: rect.maxY + 20
            )
    }
}
