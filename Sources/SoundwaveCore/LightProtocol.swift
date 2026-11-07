/// Протокол обмена с прошивкой ESP32: один UDP-пакет — одна команда.
///
/// Формат задаёт прошивка (`soundwave-firmware`, `core/src/protocol.rs`), здесь только кодирование.
///
///     байт 0     'S' (магия)
///     байт 1     версия протокола
///     байт 2     тип команды
///     байт 3...  данные команды
public enum LightProtocol {
    /// UDP-порт, который слушает плата.
    public static let port: UInt16 = 4242
    public static let magic: UInt8 = 0x53  // 'S'
    public static let version: UInt8 = 1
    /// Сколько цветов максимум влезает в команду «палитра».
    public static let maxPaletteColors = 5

    public enum Command: UInt8, Sendable {
        /// Залить всю ленту цветом: `R G B`.
        case fill = 0x01
        /// Цвета обложки на своих местах: `N`, затем N × `R G B W`.
        case palette = 0x02
        /// Громкость басов 0...255: `L`.
        case level = 0x03
    }

    /// «Залей всю ленту цветом». 6 байт.
    public static func fill(_ color: RGB) -> [UInt8] {
        header(.fill) + [color.r, color.g, color.b]
    }

    /// Цвета обложки слева направо, у каждого — доля площади (W, 0...255).
    /// Лишние цвета после пятого отбрасываются. 4 + 4N байт.
    public static func palette(_ colors: [PaletteColor]) -> [UInt8] {
        let colors = colors.prefix(maxPaletteColors)
        var packet = header(.palette) + [UInt8(colors.count)]
        for c in colors {
            packet += [c.color.r, c.color.g, c.color.b, byte(c.weight)]
        }
        return packet
    }

    /// Громкость басов 0...1, на проводе — один байт. 4 байта.
    public static func level(_ value: Double) -> [UInt8] {
        header(.level) + [byte(value)]
    }

    private static func header(_ command: Command) -> [UInt8] {
        [magic, version, command.rawValue]
    }
}

/// 0...1 → 0...255 с округлением; всё, что вне диапазона, прижимается к краю.
func byte(_ value: Double) -> UInt8 {
    UInt8((min(max(value, 0), 1) * 255).rounded())
}
