/// Пиксель уменьшенной обложки: цвет и положение по горизонтали (0 — левый край, 1 — правый).
public struct Pixel: Hashable, Sendable {
    public var color: RGB
    public var x: Double

    public init(_ color: RGB, x: Double) {
        self.color = color
        self.x = x
    }
}

/// Палитра обложки: несколько главных цветов, их доля площади и место слева направо.
///
/// Алгоритм — k-means: раскладываем пиксели по k группам похожих цветов, цвет группы — среднее.
/// Начальные центры выбираются детерминированно (самый «средний» пиксель, затем каждый раз
/// самый непохожий на уже выбранные), поэтому одна и та же обложка всегда даёт одну и ту же палитру.
public enum Palette {
    /// Группы ближе этого (в единицах RGB 0...255) сливаются в одну: два почти одинаковых красных
    /// на ленте не нужны.
    static let mergeDistance = 28.0
    /// Группы меньше этой доли площади — шум (стыки цветов, мелкие детали) — вливаются
    /// в ближайшую по цвету крупную группу.
    static let minWeight = 0.04

    public static func extract(
        from pixels: [Pixel], maxColors: Int = LightProtocol.maxPaletteColors, iterations: Int = 12
    ) -> [PaletteColor] {
        guard !pixels.isEmpty, maxColors > 0 else { return [] }
        let points = pixels.map { Vec($0.color) }

        var centers = initialCenters(points, count: maxColors)
        var labels = [Int](repeating: 0, count: points.count)
        for _ in 0..<iterations {
            for (i, p) in points.enumerated() {
                labels[i] = nearest(p, in: centers)
            }
            var sums = [Vec](repeating: .zero, count: centers.count)
            var counts = [Int](repeating: 0, count: centers.count)
            for (i, p) in points.enumerated() {
                sums[labels[i]] = sums[labels[i]] + p
                counts[labels[i]] += 1
            }
            for c in centers.indices where counts[c] > 0 {
                centers[c] = sums[c] / Double(counts[c])
            }
        }

        var groups: [Group] = centers.map { _ in Group() }
        for (i, pixel) in pixels.enumerated() {
            groups[labels[i]].add(points[i], x: pixel.x)
        }
        groups = merge(groups.filter { $0.count > 0 })
        groups = absorbSpecks(groups, minCount: Int((minWeight * Double(pixels.count)).rounded(.up)))

        let total = Double(pixels.count)
        return
            groups
            .map { PaletteColor(color: $0.mean.rgb, weight: Double($0.count) / total, x: $0.meanX) }
            .sorted { $0.x < $1.x }
    }

    /// Первый центр — пиксель, ближайший к среднему цвету; каждый следующий — самый далёкий
    /// от уже выбранных. Одинаковые цвета не дублируются.
    private static func initialCenters(_ points: [Vec], count: Int) -> [Vec] {
        let mean = points.reduce(Vec.zero, +) / Double(points.count)
        var centers = [points.min { $0.distance2(to: mean) < $1.distance2(to: mean) }!]
        while centers.count < count {
            let (farthest, d2) =
                points
                .map { p in (p, centers.map { p.distance2(to: $0) }.min()!) }
                .max { $0.1 < $1.1 }!
            if d2 == 0 { break }  // все оставшиеся пиксели уже совпадают с каким-то центром
            centers.append(farthest)
        }
        return centers
    }

    private static func nearest(_ p: Vec, in centers: [Vec]) -> Int {
        centers.indices.min { p.distance2(to: centers[$0]) < p.distance2(to: centers[$1]) }!
    }

    /// Сливает группы, чьи цвета ближе `mergeDistance`, пока такие пары есть.
    private static func merge(_ groups: [Group]) -> [Group] {
        var groups = groups
        var merged = true
        while merged {
            merged = false
            search: for i in groups.indices {
                for j in groups.indices where j > i {
                    if groups[i].mean.distance2(to: groups[j].mean) < mergeDistance * mergeDistance {
                        groups[i].absorb(groups[j])
                        groups.remove(at: j)
                        merged = true
                        break search
                    }
                }
            }
        }
        return groups
    }

    /// Вливает группы меньше `minCount` пикселей в ближайшую по цвету из крупных.
    /// Если крупных нет вовсе (такого почти не бывает), оставляет как есть.
    private static func absorbSpecks(_ groups: [Group], minCount: Int) -> [Group] {
        var big = groups.filter { $0.count >= minCount }
        guard !big.isEmpty else { return groups }
        for speck in groups where speck.count < minCount {
            let target = big.indices.min {
                big[$0].mean.distance2(to: speck.mean) < big[$1].mean.distance2(to: speck.mean)
            }!
            big[target].absorb(speck)
        }
        return big
    }
}

/// Накопитель группы пикселей.
private struct Group {
    var sum = Vec.zero
    var sumX = 0.0
    var count = 0

    var mean: Vec { sum / Double(count) }
    var meanX: Double { sumX / Double(count) }

    mutating func add(_ p: Vec, x: Double) {
        sum = sum + p
        sumX += x
        count += 1
    }

    mutating func absorb(_ other: Group) {
        sum = sum + other.sum
        sumX += other.sumX
        count += other.count
    }
}

/// Цвет как точка в трёхмерном пространстве RGB.
private struct Vec {
    var r, g, b: Double

    static let zero = Vec(r: 0, g: 0, b: 0)

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(_ c: RGB) { self.init(r: Double(c.r), g: Double(c.g), b: Double(c.b)) }

    var rgb: RGB { RGB(channel(r), channel(g), channel(b)) }

    func distance2(to o: Vec) -> Double {
        (r - o.r) * (r - o.r) + (g - o.g) * (g - o.g) + (b - o.b) * (b - o.b)
    }

    static func + (a: Vec, b: Vec) -> Vec { Vec(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b) }
    static func / (a: Vec, k: Double) -> Vec { Vec(r: a.r / k, g: a.g / k, b: a.b / k) }
}

private func channel(_ v: Double) -> UInt8 { UInt8(min(max(v.rounded(), 0), 255)) }
