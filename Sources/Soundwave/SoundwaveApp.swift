import SwiftUI

@main
struct SoundwaveApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Soundwave", systemImage: "waveform") {
            MenuView(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}
