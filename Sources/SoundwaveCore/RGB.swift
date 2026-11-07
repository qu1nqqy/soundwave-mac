/// Цвет пикселя: три канала 0...255, как их понимает лента.
public struct RGB: Hashable, Sendable, CustomStringConvertible {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let black = RGB(0, 0, 0)
    /// Запасной цвет, когда в обложке нет ничего подходящего.
    public static let warmWhite = RGB(255, 196, 140)

    /// Воспринимаемая яркость 0...1 (Rec. 709): зелёный глаз видит ярче всего, синий — тусклее.
    public var luminance: Double {
        (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) / 255
    }

    /// Тот же оттенок, но ярчайший канал вытянут до 255. Тёмно-синий станет просто синим:
    /// лента светит, а не отражает, и тёмные цвета на ней выглядят грязно.
    public var maximized: RGB {
        let peak = Int(max(r, g, b))
        guard peak > 0 else { return self }
        // channel × 255 / peak с округлением, в целых числах: Double тут даёт 127.4999 вместо 127.5.
        func stretch(_ c: UInt8) -> UInt8 { UInt8((Int(c) * 510 + peak) / (2 * peak)) }
        return RGB(stretch(r), stretch(g), stretch(b))
    }

    /// Цвет, умноженный на яркость 0...1.
    public func dimmed(_ brightness: Double) -> RGB {
        let k = min(max(brightness, 0), 1)
        return RGB(scale(r, k), scale(g, k), scale(b, k))
    }

    public var description: String { "RGB(\(r), \(g), \(b))" }
}

private func scale(_ channel: UInt8, _ k: Double) -> UInt8 {
    UInt8(min(255, (Double(channel) * k).rounded()))
}
