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
    /// Что сейчас со звуком из Music.
    private(set) var audioStatus = "Звук: Music закрыт"
    /// Громкость басов 0...1 — для индикатора.
    private(set) var audioLevel = 0.0

    // Настройки: переживают перезапуск (UserDefaults) и сразу уходят в отправку.

    var enabled: Bool { didSet { save(enabled, for: .enabled) } }
    var mode: LightMode { didSet { save(mode.rawValue, for: .mode) } }
    var host: String {
        didSet {
            save(host, for: .host)
            sender.setHost(host)
        }
    }
    /// Насколько охотно засчитывать удары, 0...1.
    var sensitivity: Double {
        didSet {
            save(sensitivity, for: .sensitivity)
            applySensitivity()
        }
    }

    @ObservationIgnored private let nowPlaying = NowPlaying()
    @ObservationIgnored private let sender = LightSender()
    @ObservationIgnored private let audio = AudioMonitor()
    @ObservationIgnored private let analyzer = Analyzer()

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: Key.enabled.rawValue) as? Bool ?? true
        mode = defaults.string(forKey: Key.mode.rawValue).flatMap(LightMode.init(rawValue:)) ?? .single
        host = defaults.string(forKey: Key.host.rawValue) ?? ""
        sensitivity = defaults.object(forKey: Key.sensitivity.rawValue) as? Double ?? 0.5

        sender.onStatus = { [weak self] status in self?.senderStatus = status }
        sender.setHost(host)
        wireAudio()
        applySensitivity()
        audio.onStatus = { [weak self] status in self?.audioStatus = status }
        audio.start()
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

    /// Звук → анализатор → отправка. Всё это крутится на очереди звука, мимо главного потока;
    /// в главный поток приходит только индикатор громкости.
    private func wireAudio() {
        let analyzer = analyzer
        let sender = sender
        audio.tap.onSamples = { samples, sampleRate in analyzer.feed(samples, sampleRate: sampleRate) }
        analyzer.onFrame = { level, beat in sender.audioFrame(level: level, beat: beat) }
        analyzer.onMeter = { [weak self] level in
            Task { @MainActor in self?.audioLevel = level }
        }
    }

    private func applySensitivity() {
        let analyzer = analyzer
        let sensitivity = sensitivity
        audio.tap.queue.async { analyzer.setSensitivity(sensitivity) }
    }

    // MARK: - UserDefaults

    private enum Key: String {
        case enabled, mode, host, sensitivity
    }

    private func save(_ value: Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
