import AppKit
import Observation
import SoundwaveCore

/// Всё состояние приложения, которое видит меню.
@MainActor
@Observable
final class AppState {
    private(set) var track: Track?
    private(set) var artwork: NSImage?

    @ObservationIgnored private let nowPlaying = NowPlaying()

    init() {
        nowPlaying.onChange = { [weak self] track, artwork in
            self?.track = track
            self?.artwork = artwork
        }
        nowPlaying.start()
    }
}
