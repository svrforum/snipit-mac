import SwiftUI

// MARK: - RecordingControlView

struct RecordingControlView: View {

    // MARK: - Properties

    let duration: TimeInterval
    let frameCount: Int
    let onStop: () -> Void
    let onCancel: () -> Void

    // MARK: - State

    @State private var dotOpacity: Double = 1.0

    // MARK: - Body

    var body: some View {
        HStack(spacing: 14) {
            // Recording indicator dot
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(dotOpacity)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                    ) {
                        dotOpacity = 0.3
                    }
                }

            // Duration
            Text(formattedDuration)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            // Frame count
            Text("\(frameCount) frames")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))

            Divider()
                .frame(height: 18)
                .background(.white.opacity(0.3))

            // Stop button
            Button(action: onStop) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.red)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Stop Recording")

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Cancel Recording")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.8))
        )
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    RecordingControlView(
        duration: 67,
        frameCount: 142,
        onStop: {},
        onCancel: {}
    )
    .padding()
    .background(.gray.opacity(0.3))
}
