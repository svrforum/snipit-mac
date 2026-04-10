import SwiftUI

struct MagnifierView: View {
    let screenImage: NSImage?
    let mousePosition: CGPoint
    var zoom: CGFloat = 2.0
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            if let screenImage {
                let imageSize = screenImage.size

                Image(nsImage: screenImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(
                        width: imageSize.width * zoom,
                        height: imageSize.height * zoom
                    )
                    .offset(
                        x: -mousePosition.x * zoom + size / 2,
                        y: -mousePosition.y * zoom + size / 2
                    )
                    .frame(width: size, height: size)
                    .clipped()
            }

            // Crosshair lines
            Path { path in
                path.move(to: CGPoint(x: size / 2, y: 0))
                path.addLine(to: CGPoint(x: size / 2, y: size))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 0.5)

            Path { path in
                path.move(to: CGPoint(x: 0, y: size / 2))
                path.addLine(to: CGPoint(x: size, y: size / 2))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 0.5)

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
    }
}
