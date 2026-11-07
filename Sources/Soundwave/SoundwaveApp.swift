import SwiftUI

@main
struct SoundwaveApp: App {
    var body: some Scene {
        MenuBarExtra("Soundwave", systemImage: "waveform") {
            Button("Выход") { NSApplication.shared.terminate(nil) }
        }
    }
}
