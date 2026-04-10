import SwiftUI

struct SmartDetectionView: View {
    let detectedWindowFrame: CGRect?
    let windowTitle: String?

    var body: some View {
        ZStack {
            // Detected window highlight
            if let frame = detectedWindowFrame {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                // Window title + size label
                windowLabel(for: frame)
            }

            // Bottom hint text
            VStack {
                Spacer()

                Text("클릭하여 창 캡처 \u{00B7} 드래그하여 영역 선택 \u{00B7} Space: 전체화면 \u{00B7} ESC: 취소")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.bottom, 40)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Window Label

    @ViewBuilder
    private func windowLabel(for frame: CGRect) -> some View {
        let title = windowTitle ?? "Window"
        let w = Int(frame.width)
        let h = Int(frame.height)

        Text("\(title) \u{2014} \(w) \u{00D7} \(h)")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.75))
            )
            .position(
                x: frame.midX,
                y: frame.maxY + 20
            )
    }
}
