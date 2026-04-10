import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Text("SnipIt")
                .font(.headline)
                .padding()

            Divider()

            Text("Coming soon...")
                .foregroundStyle(.secondary)
                .padding()
        }
        .frame(width: 280)
    }
}
