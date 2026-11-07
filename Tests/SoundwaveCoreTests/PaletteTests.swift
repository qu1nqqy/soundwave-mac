import Testing

@testable import SoundwaveCore

/// «Картинка» шириной `width`: каждый цвет занимает свою полосу слева направо, ширина — в колонках.
private func stripes(_ bands: [(RGB, Int)], height: Int = 4) -> [Pixel] {
    let width = bands.reduce(0) { $0 + $1.1 }
    var pixels: [Pixel] = []
    var column = 0
    for (color, columns) in bands {
        for _ in 0..<columns {
            let x = (Double(column) + 0.5) / Double(width)
            pixels += Array(repeating: Pixel(color, x: x), count: height)
            column += 1
        }
    }
    return pixels
}

private let red = RGB(220, 30, 30)
private let blue = RGB(30, 40, 200)
private let green = RGB(40, 180, 60)
private let white = RGB(250, 250, 250)
private let black = RGB(5, 5, 5)

@Suite("Палитра")
struct PaletteTests {
    @Test("Пустая обложка — пустая палитра")
    func empty() {
        #expect(Palette.extract(from: []).isEmpty)
    }

    @Test("Один цвет — одна группа на всю площадь")
    func singleColor() throws {
        let palette = Palette.extract(from: stripes([(red, 8)]))
        let only = try #require(palette.first)
        #expect(palette.count == 1)
        #expect(only.color == red)
        #expect(only.weight == 1)
    }

    @Test("Цвета идут в том же порядке, что слева направо на обложке")
    func orderedLeftToRight() {
        let palette = Palette.extract(from: stripes([(blue, 4), (red, 4), (green, 4)]))
        #expect(palette.map(\.color) == [blue, red, green])
    }

    @Test("Доля площади считается по числу пикселей")
    func weights() {
        let palette = Palette.extract(from: stripes([(red, 5), (blue, 3), (green, 2)]))
        #expect(palette.map(\.weight) == [0.5, 0.3, 0.2])
    }

    @Test("x — середина полосы цвета")
    func meanX() throws {
        let palette = Palette.extract(from: stripes([(red, 2), (blue, 2)]))
        let left = try #require(palette.first)
        let right = try #require(palette.last)
        #expect(abs(left.x - 0.25) < 1e-9)
        #expect(abs(right.x - 0.75) < 1e-9)
    }

    @Test("Почти одинаковые цвета сливаются в один")
    func mergesNearDuplicates() {
        let palette = Palette.extract(from: stripes([(RGB(200, 20, 20), 3), (RGB(210, 25, 18), 3)]))
        #expect(palette.count == 1)
    }

    @Test("Не больше пяти цветов, даже если на обложке их больше")
    func capped() {
        let many: [RGB] = [
            red, blue, green, white, black, RGB(250, 200, 0), RGB(150, 0, 200), RGB(0, 200, 200),
        ]
        let palette = Palette.extract(from: stripes(many.map { ($0, 2) }))
        #expect(palette.count <= 5)
        #expect(abs(palette.map(\.weight).reduce(0, +) - 1) < 1e-9)
    }

    @Test("Крошечные пятна (меньше 4% площади) вливаются в ближайший крупный цвет")
    func absorbsSpecks() throws {
        // 1 колонка из 40 = 2.5%: такое бывает на стыках цветов после уменьшения картинки.
        let palette = Palette.extract(from: stripes([(red, 20), (RGB(120, 40, 160), 1), (blue, 19)]))
        #expect(palette.count == 2)
        #expect(abs(palette.map(\.weight).reduce(0, +) - 1) < 1e-9)
        let blueish = try #require(palette.last)
        #expect(blueish.weight == 0.5)
    }

    @Test("Чёрный в палитре остаётся — он нужен режиму «Сочетание»")
    func keepsBlack() {
        let palette = Palette.extract(from: stripes([(black, 6), (white, 2)]))
        #expect(palette.map(\.color) == [black, white])
    }

    @Test("Одна и та же обложка — одна и та же палитра")
    func deterministic() {
        let image = stripes([(red, 3), (blue, 5), (green, 1), (white, 2)])
        #expect(Palette.extract(from: image) == Palette.extract(from: image))
    }
}

@Suite("Основной цвет")
struct DominantTests {
    @Test("Самый большой не чёрный цвет, на полной яркости")
    func largestNonBlack() {
        let palette = Palette.extract(from: stripes([(black, 6), (blue, 3), (red, 1)]))
        #expect(Dominant.color(of: palette) == blue.maximized)
    }

    @Test("Если чёрного нет — просто самый большой")
    func largest() {
        let palette = Palette.extract(from: stripes([(red, 2), (green, 5)]))
        #expect(Dominant.color(of: palette) == green.maximized)
    }

    @Test("Одна темнота или нет обложки — тёплый белый")
    func fallback() {
        #expect(Dominant.color(of: Palette.extract(from: stripes([(black, 4)]))) == .warmWhite)
        #expect(Dominant.color(of: []) == .warmWhite)
    }
}
