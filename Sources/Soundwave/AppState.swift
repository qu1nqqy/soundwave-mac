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
    /// Что сейчас со связью с платой.
    private(set) var senderStatus = "Не указан адрес платы"

    // Настройки: переживают перезапуск (UserDefaults) и сразу уходят в отправку.

    var enabled: Bool { didSet { save(enabled, for: .enabled) } }
    var mode: LightMode { didSet { save(mode.rawValue, for: .mode) } }
    var host: String {
        didSet {
            save(host, for: .host)
            sender.setHost(host)
        }
    }

    @ObservationIgnored private let nowPlaying = NowPlaying()
    @ObservationIgnored private let sender = LightSender()

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: Key.enabled.rawValue) as? Bool ?? true
        mode = defaults.string(forKey: Key.mode.rawValue).flatMap(LightMode.init(rawValue:)) ?? .single
        host = defaults.string(forKey: Key.host.rawValue) ?? ""

        sender.onStatus = { [weak self] status in self?.senderStatus = status }
        sender.setHost(host)
        nowPlaying.onChange = { [weak self] track, artwork in
            self?.update(track: track, artwork: artwork)
        }
        nowPlaying.start()
        observeScene()
    }

    private func update(track: Track?, artwork: NSImage?) {
        if artwork !== self.artwork {
            palette = artwork.map { Palette.extract(from: ArtworkSampler.pixels(of: $0)) } ?? []
            dominant = Dominant.color(of: palette)
        }
        self.track = track
        self.artwork = artwork
    }

    private var scene: LightScene {
        LightScene(
            enabled: enabled, playing: track?.isPlaying ?? false, mode: mode, dominant: dominant,
            palette: palette)
    }

    /// Отдаёт сцену в отправку при любом изменении того, из чего она складывается.
    private func observeScene() {
        let scene = withObservationTracking {
            self.scene
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeScene() }
        }
        sender.setScene(scene)
    }

    // MARK: - UserDefaults

    private enum Key: String {
        case enabled, mode, host
    }

    private func save(_ value: Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
