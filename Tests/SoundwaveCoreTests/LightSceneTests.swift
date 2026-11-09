import Testing

@testable import SoundwaveCore

@Suite("Что слать плате")
struct LightSceneTests {
    let palette = [
        PaletteColor(color: RGB(0, 0, 0), weight: 0.6, x: 0.3),
        PaletteColor(color: RGB(250, 250, 250), weight: 0.4, x: 0.7),
    ]

    func scene(enabled: Bool = true, playing: Bool = true, mode: LightMode = .single) -> LightScene {
        LightScene(
            enabled: enabled, playing: playing, mode: mode, dominant: RGB(250, 250, 250), palette: palette)
    }

    @Test("Выключено — ничего не шлём")
    func disabled() {
        #expect(scene(enabled: false).statePacket == nil)
        #expect(!scene(enabled: false).isActive)
    }

    @Test("Пауза — ничего не шлём, плата сама уйдёт в радугу")
    func paused() {
        #expect(scene(playing: false).statePacket == nil)
    }

    @Test("«Один цвет» — Fill основным цветом")
    func single() {
        #expect(scene(mode: .single).statePacket == LightProtocol.fill(RGB(250, 250, 250)))
    }

    @Test("«Сочетание» — Palette с цветами обложки")
    func palettePacket() {
        #expect(scene(mode: .palette).statePacket == LightProtocol.palette(palette))
    }

    @Test("«Сочетание» без обложки — палитра из одного основного цвета")
    func paletteWithoutArtwork() {
        var s = scene(mode: .palette)
        s.palette = []
        #expect(s.statePacket == [0x53, 0x01, 0x02, 1, 250, 250, 250, 255])
    }
}
