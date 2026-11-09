import Testing

@testable import SoundwaveCore

@Suite("Цвет")
struct RGBTests {
    @Test("Яркость: чёрный 0, белый 1, зелёный ярче синего")
    func luminance() {
        #expect(RGB.black.luminance == 0)
        #expect(abs(RGB(255, 255, 255).luminance - 1) < 1e-9)
        #expect(RGB(0, 255, 0).luminance > RGB(0, 0, 255).luminance)
    }

    @Test("maximized вытягивает ярчайший канал до 255 и сохраняет оттенок")
    func maximized() {
        #expect(RGB(0, 0, 100).maximized == RGB(0, 0, 255))
        #expect(RGB(50, 25, 0).maximized == RGB(255, 128, 0))
        #expect(RGB.black.maximized == .black)
    }

    @Test("dimmed умножает на яркость и прижимает её к 0...1")
    func dimmed() {
        #expect(RGB(200, 100, 50).dimmed(0.5) == RGB(100, 50, 25))
        #expect(RGB(200, 100, 50).dimmed(2) == RGB(200, 100, 50))
        #expect(RGB(200, 100, 50).dimmed(-1) == .black)
    }
}
