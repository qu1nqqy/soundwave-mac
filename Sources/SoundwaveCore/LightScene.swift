/// Как подсветка показывает обложку.
public enum LightMode: String, CaseIterable, Sendable {
    /// Вся лента одним основным (не чёрным) цветом обложки.
    case single
    /// Цвета обложки на своих местах вдоль ленты; рисует прошивка.
    case palette
}

/// Всё, что нужно, чтобы решить, какой пакет слать плате.
public struct LightScene: Hashable, Sendable {
    /// Подсветка включена в меню.
    public var enabled: Bool
    /// В Music что-то играет (не пауза и не остановка).
    public var playing: Bool
    public var mode: LightMode
    public var dominant: RGB
    public var palette: [PaletteColor]

    public init(enabled: Bool, playing: Bool, mode: LightMode, dominant: RGB, palette: [PaletteColor]) {
        self.enabled = enabled
        self.playing = playing
        self.mode = mode
        self.dominant = dominant
        self.palette = palette
    }

    /// Шлём ли вообще что-нибудь. Если нет — плата через 5 с тишины сама уходит в радугу.
    public var isActive: Bool { enabled && playing }

    /// Пакет «что показывать»: при смене сцены и раз в секунду, чтобы плата не ушла в радугу.
    /// `nil` — слать нечего.
    public var statePacket: [UInt8]? {
        guard isActive else { return nil }
        switch mode {
        case .single:
            return LightProtocol.fill(dominant)
        case .palette:
            // Без обложки сочетания нет — шлём основной цвет как палитру из одного цвета.
            let colors = palette.isEmpty ? [PaletteColor(color: dominant, weight: 1, x: 0.5)] : palette
            return LightProtocol.palette(colors)
        }
    }
}
