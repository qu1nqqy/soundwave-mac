import SoundwaveCore

/// Режет поток сэмплов на окна (`Spectrum.size` сэмплов, новое окно каждые `hop` сэмплов)
/// и на каждом окне считает уровень басов и удары.
///
/// Работает целиком на очереди звука `AudioTap.queue`.
final class Analyzer: @unchecked Sendable {
    /// Басы 40–150 Гц: там живут бочка и бас-гитара.
    static let band = 40.0...150.0
    /// Сдвиг между окнами: при 48 кГц — ~94 окна в секунду.
    static let hop = 512

    /// Уровень басов 0...1 и был ли на этом окне удар. На каждом окне.
    var onFrame: (@Sendable (Double, Bool) -> Void)?
    /// Тот же уровень, но реже (~20 раз в секунду) — для индикатора в меню.
    var onMeter: (@Sendable (Double) -> Void)?

    private let spectrum = Spectrum()
    private var ring: [Float]
    private var position = 0
    private var filled = 0
    private var sinceHop = 0
    private var level = BassLevel()
    private var detector = BeatDetector()
    private var frames = 0

    init() {
        ring = [Float](repeating: 0, count: spectrum.size)
    }

    /// Ползунок «Чувствительность» 0...1.
    func setSensitivity(_ sensitivity: Double) {
        detector.threshold = BeatDetector.threshold(forSensitivity: sensitivity)
    }

    func feed(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) {
        for sample in samples {
            ring[position] = sample
            position = (position + 1) % ring.count
            filled = min(filled + 1, ring.count)
            sinceHop += 1
            if sinceHop >= Self.hop, filled == ring.count {
                sinceHop = 0
                analyze(sampleRate: sampleRate)
            }
        }
    }

    private func analyze(sampleRate: Double) {
        // Окно по порядку: от самого старого сэмпла (там, куда сейчас будем писать) к самому новому.
        let window = Array(ring[position...] + ring[..<position])
        let energy = spectrum.energy(of: window, sampleRate: sampleRate, band: Self.band)
        let dt = Double(Self.hop) / sampleRate
        let value = level.update(energy: energy, dt: dt)
        let beat = detector.update(energy: energy, dt: dt)
        onFrame?(value, beat)
        frames += 1
        if frames % 5 == 0 { onMeter?(value) }
    }
}
