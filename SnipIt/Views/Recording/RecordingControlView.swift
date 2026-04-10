import SwiftUI
import Combine

// MARK: - RecordingControlState

final class RecordingControlState: ObservableObject {
    @Published var duration: TimeInterval = 0
    @Published var frameCount: Int = 0
    var onStop: () -> Void = {}
    var onCancel: () -> Void = {}
}

// MARK: - RecordingControlView

struct RecordingControlView: View {

    @ObservedObject var state: RecordingControlState

    @State private var dotOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(dotOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        dotOpacity = 0.3
                    }
                }

            Text(formattedDuration)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)
                .fixedSize()

            Text("\(state.frameCount)f")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)
                .fixedSize()

            Divider()
                .frame(height: 18)
                .background(.white.opacity(0.3))

            Button(action: state.onStop) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.red)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("녹화 중지")

            Button(action: state.onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("녹화 취소")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.8))
        )
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
    }

    private var formattedDuration: String {
        let minutes = Int(state.duration) / 60
        let seconds = Int(state.duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
