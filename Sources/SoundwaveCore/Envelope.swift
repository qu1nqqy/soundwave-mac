import Foundation

/// Яркость пульса для режима «Один цвет»: на удар вспыхивает до 1, потом плавно гаснет до `base`.
public struct Envelope: Sendable {
    /// Яркость между ударами, 0...1.
    public var base: Double
    /// За сколько секунд вспышка гаснет примерно на 63%.
    public var decay: Double
    private var flash = 0.0

    public init(base: Double = 0.45, decay: Double = 0.15) {
        self.base = base
        self.decay = decay
    }

    /// Текущая яркость 0...1.
    public var brightness: Double { base + (1 - base) * flash }

    public mutating func beat() { flash = 1 }

    /// Прошло `dt` секунд — вспышка немного погасла.
    @discardableResult
    public mutating func advance(_ dt: Double) -> Double {
        flash *= exp(-dt / decay)
        return brightness
    }
}
