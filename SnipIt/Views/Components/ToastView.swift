import SwiftUI

struct ToastView: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
