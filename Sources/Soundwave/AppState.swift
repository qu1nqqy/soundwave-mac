import AppKit
import Observation
import SoundwaveCore

/// Всё состояние приложения, которое видит меню.
@MainActor
@Observable
final class AppState {
    private(set) var track: Track?
    private(set) var artwork: NSImage?
    /// Цвета обложки слева направо.
    private(set) var palette: [PaletteColor] = []
    /// Основной не чёрный цвет — для режима «Один цвет».
    private(set) var dominant: RGB = .warmWhite

    @ObservationIgnored private let nowPlaying = NowPlaying()

    init() {
        nowPlaying.onChange = { [weak self] track, artwork in
            self?.update(track: track, artwork: artwork)
        }
        nowPlaying.start()
    }

    private func update(track: Track?, artwork: NSImage?) {
        if artwork !== self.artwork {
            palette = artwork.map { Palette.extract(from: ArtworkSampler.pixels(of: $0)) } ?? []
            dominant = Dominant.color(of: palette)
        }
        self.track = track
        self.artwork = artwork
    }
}
