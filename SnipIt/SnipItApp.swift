import SwiftUI

@main
struct SnipItApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: "scissors")
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Settings placeholder")
        }
    }
}

@Observable
final class AppState {
    var lastCapturedImage: NSImage?
    var isRecording = false
}
