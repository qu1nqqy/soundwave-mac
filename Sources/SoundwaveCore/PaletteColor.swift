/// Один цвет из палитры обложки.
public struct PaletteColor: Hashable, Sendable {
    /// Средний цвет группы пикселей.
    public var color: RGB
    /// Доля площади обложки, 0...1.
    public var weight: Double
    /// Где этот цвет в среднем находится по горизонтали: 0 — левый край, 1 — правый.
    public var x: Double

    public init(color: RGB, weight: Double, x: Double) {
        self.color = color
        self.weight = weight
        self.x = x
    }
}
