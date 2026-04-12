import SwiftUI

struct MagnifierView: View {
    let screenImage: NSImage?
    let mousePosition: CGPoint
    var zoom: CGFloat = 4.0
    var size: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            // Magnifier circle
            ZStack {
                if let screenImage {
                    // Screen image is 1x points. Mouse position is in points.
                    // Scale the image by zoom and offset to center on mouse.
                    let imgW = screenImage.size.width
                    let imgH = screenImage.size.height

                    Image(nsImage: screenImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: imgW * zoom, height: imgH * zoom)
                        .offset(
                            x: -mousePosition.x * zoom + size / 2,
                            y: -mousePosition.y * zoom + size / 2
                        )
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    Color.black.opacity(0.3)
                        .frame(width: size, height: size)
                }

                // Crosshair
                CrosshairShape(size: size)
                    .stroke(Color.white.opacity(0.7), lineWidth: 0.5)

                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 3, height: 3)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: 4)

            // Coordinate label
            Text("\(Int(mousePosition.x)), \(Int(mousePosition.y))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.black.opacity(0.7))
                )
                .padding(.top, 6)
        }
    }
}

private struct CrosshairShape: Shape {
    let size: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Vertical
        p.move(to: CGPoint(x: size / 2, y: 0))
        p.addLine(to: CGPoint(x: size / 2, y: size))
        // Horizontal
        p.move(to: CGPoint(x: 0, y: size / 2))
        p.addLine(to: CGPoint(x: size, y: size / 2))
        return p
    }
}
