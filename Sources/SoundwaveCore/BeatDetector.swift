/// Ищет удары (бочку) в энергии басов.
///
/// Удар — это когда энергия резко выше своего среднего за последнюю секунду:
/// `energy > среднее × threshold`. Ровный гул и тишина ударами не считаются.
/// После удара `refractory` секунд новые не засчитываются: одна бочка — один удар.
public struct BeatDetector: Sendable {
    /// Во сколько раз энергия должна превысить среднее. Меньше — чувствительнее.
    public var threshold: Double

    let windowSeconds: Double
    let refractory: Double
    private var history: [Double] = []
    private var historyCapacity = 0
    private var sinceBeat = Double.infinity

    public init(threshold: Double = 1.5, windowSeconds: Double = 1, refractory: Double = 0.1) {
        self.threshold = threshold
        self.windowSeconds = windowSeconds
        self.refractory = refractory
    }

    /// Ползунок «Чувствительность» 0...1 → порог 1.9 (только явные удары) ... 1.2 (почти всё).
    public static func threshold(forSensitivity s: Double) -> Double {
        1.9 - 0.7 * min(max(s, 0), 1)
    }

    /// Новое окно звука. Возвращает `true`, если на нём удар.
    public mutating func update(energy: Double, dt: Double) -> Bool {
        if historyCapacity == 0 {
            historyCapacity = max(1, Int((windowSeconds / dt).rounded()))
        }
        sinceBeat += dt

        // Пока не набрали хотя бы четверть окна, среднему верить рано.
        let ready = history.count >= historyCapacity / 4
        let mean = history.isEmpty ? 0 : history.reduce(0, +) / Double(history.count)
        let beat = ready && energy > 0 && energy > mean * threshold && sinceBeat >= refractory

        history.append(energy)
        if history.count > historyCapacity { history.removeFirst(history.count - historyCapacity) }
        if beat { sinceBeat = 0 }
        return beat
    }
}
