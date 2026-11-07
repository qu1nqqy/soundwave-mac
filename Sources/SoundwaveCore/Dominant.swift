/// Цвет для режима «Один цвет»: самый большой по площади цвет обложки, но не чёрный.
public enum Dominant {
    /// Цвета темнее этого считаются чёрными (яркость 0...1).
    public static let minLuminance = 0.12

    /// Самый весомый не чёрный цвет палитры, вытянутый на полную яркость.
    /// Если в обложке одна темнота (или обложки нет) — тёплый белый.
    public static func color(of palette: [PaletteColor]) -> RGB {
        palette
            .filter { $0.color.luminance >= minLuminance }
            .max { $0.weight < $1.weight }?
            .color.maximized ?? .warmWhite
    }
}
