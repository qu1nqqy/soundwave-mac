import Testing

@testable import SoundwaveCore

@Suite("Протокол")
struct LightProtocolTests {
    @Test("Fill — те же байты, что в примере с nc из прошивки")
    func fillMatchesFirmwareExample() {
        // printf 'S\x01\x01\xff\x00\x00' | nc -u -w1 <ip> 4242
        #expect(LightProtocol.fill(RGB(255, 0, 0)) == [0x53, 0x01, 0x01, 0xFF, 0x00, 0x00])
    }

    @Test("Fill хранит порядок каналов R, G, B")
    func fillKeepsChannelOrder() {
        #expect(LightProtocol.fill(RGB(1, 2, 3)) == [0x53, 0x01, 0x01, 1, 2, 3])
    }

    @Test("Palette: N, затем R G B W на каждый цвет")
    func paletteLayout() {
        let packet = LightProtocol.palette([
            PaletteColor(color: RGB(10, 20, 30), weight: 1, x: 0.2),
            PaletteColor(color: RGB(40, 50, 60), weight: 0, x: 0.8),
        ])
        #expect(packet == [0x53, 0x01, 0x02, 2, 10, 20, 30, 255, 40, 50, 60, 0])
    }

    @Test("Palette длиной 4 + 4N")
    func paletteLength() {
        let colors = (0..<3).map { _ in PaletteColor(color: .black, weight: 0.5, x: 0) }
        #expect(LightProtocol.palette(colors).count == 4 + 4 * 3)
    }

    @Test("Palette обрезается до пяти цветов")
    func paletteIsCapped() {
        let colors = (0..<8).map { _ in PaletteColor(color: .black, weight: 0.1, x: 0) }
        let packet = LightProtocol.palette(colors)
        #expect(packet[3] == 5)
        #expect(packet.count == 4 + 4 * 5)
    }

    @Test("Level: 0...1 превращается в один байт")
    func levelEncoding() {
        #expect(LightProtocol.level(0) == [0x53, 0x01, 0x03, 0])
        #expect(LightProtocol.level(1) == [0x53, 0x01, 0x03, 255])
        #expect(LightProtocol.level(0.5) == [0x53, 0x01, 0x03, 128])
    }

    @Test("Значения вне 0...1 прижимаются к краям", arguments: [(-3.0, UInt8(0)), (7.0, UInt8(255))])
    func byteClamps(value: Double, expected: UInt8) {
        #expect(byte(value) == expected)
    }
}
