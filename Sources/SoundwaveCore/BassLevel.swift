import Foundation

/// Громкость басов 0...1, как её удобно показывать светом.
///
/// - **Авто-усиление:** энергия делится на недавний максимум, поэтому и тихий, и громкий трек
///   дают полный диапазон. Максимум сам «остывает» (половина за `peakHalfLife` секунд), чтобы после
///   громкого куска тихий не казался совсем тёмным.
/// - **Сглаживание:** вверх уровень идёт быстро (`attack`), чтобы удар бочки был виден сразу,
///   а вниз — медленно (`release`), чтобы свет не дрожал.
public struct BassLevel: Sendable {
    public private(set) var value = 0.0

    let peakHalfLife: Double
    let attack: Double
    let release: Double
    private var peak = 0.0

    public init(peakHalfLife: Double = 4, attack: Double = 0.01, release: Double = 0.25) {
        self.peakHalfLife = peakHalfLife
        self.attack = attack
        self.release = release
    }

    /// Новое окно звука: `energy` из `Spectrum`, `dt` — сколько секунд прошло с прошлого окна.
    @discardableResult
    public mutating func update(energy: Double, dt: Double) -> Double {
        peak = max(energy, peak * pow(0.5, dt / peakHalfLife))
        let target = peak > 0 ? energy / peak : 0
        let tau = target > value ? attack : release
        value += (target - value) * (1 - exp(-dt / tau))
        value = min(max(value, 0), 1)
        return value
    }
}
