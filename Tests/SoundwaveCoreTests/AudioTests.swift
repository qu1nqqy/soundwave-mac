import Foundation
import Testing

@testable import SoundwaveCore

private let sampleRate = 48_000.0
private let hop = 512
/// Время между соседними окнами анализа.
private let dt = Double(hop) / sampleRate
private let bass = 40.0...150.0

private func sine(_ frequency: Double, count: Int, amplitude: Float = 0.5) -> [Float] {
    (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) }
}

@Suite("Спектр")
struct SpectrumTests {
    let spectrum = Spectrum()

    @Test("Тишина — ноль энергии")
    func silence() {
        #expect(
            spectrum.energy(of: [Float](repeating: 0, count: 2048), sampleRate: sampleRate, band: bass) == 0)
    }

    @Test("Бочка на 60 Гц попадает в басы, а 1 кГц — нет")
    func bassVsTreble() {
        let low = spectrum.energy(of: sine(60, count: 2048), sampleRate: sampleRate, band: bass)
        let high = spectrum.energy(of: sine(1000, count: 2048), sampleRate: sampleRate, band: bass)
        #expect(low > 1000 * max(high, 1e-12))
    }

    @Test("Громче — больше энергии")
    func louderIsMore() {
        let quiet = spectrum.energy(
            of: sine(80, count: 2048, amplitude: 0.1), sampleRate: sampleRate, band: bass)
        let loud = spectrum.energy(
            of: sine(80, count: 2048, amplitude: 0.8), sampleRate: sampleRate, band: bass)
        #expect(loud > quiet)
    }
}

/// Энергия басов по окнам: 120 BPM, на каждый удар `kickFrames` окон громко, остальное — тихо.
private func kicks(seconds: Double, bpm: Double = 120, kickFrames: Int = 4) -> [Double] {
    let frames = Int(seconds / dt)
    let period = Int((60 / bpm) / dt)
    return (0..<frames).map { $0 % period < kickFrames ? 1.0 : 0.05 }
}

@Suite("Удары")
struct BeatDetectorTests {
    func count(_ energies: [Double], threshold: Double = 1.5) -> Int {
        var detector = BeatDetector(threshold: threshold)
        return energies.filter { detector.update(energy: $0, dt: dt) }.count
    }

    @Test("120 BPM — два удара в секунду")
    func findsKicks() {
        // 5 секунд = 10 ударов; первый может пропасть, пока набирается среднее.
        #expect((9...10).contains(count(kicks(seconds: 5))))
    }

    @Test("Тишина — ударов нет")
    func silence() {
        #expect(count([Double](repeating: 0, count: 500)) == 0)
    }

    @Test("Ровный гул — ударов нет")
    func steadyTone() {
        #expect(count([Double](repeating: 0.7, count: 500)) == 0)
    }

    @Test("Длинный удар засчитывается один раз")
    func refractory() {
        // 8 окон подряд (~85 мс) громко — это одна бочка, а не восемь.
        let energies = [Double](repeating: 0.05, count: 100) + [Double](repeating: 1, count: 8)
        #expect(count(energies) == 1)
    }

    @Test("Ползунок чувствительности: правее — ниже порог")
    func sensitivity() {
        #expect(BeatDetector.threshold(forSensitivity: 0) == 1.9)
        #expect(BeatDetector.threshold(forSensitivity: 1) < BeatDetector.threshold(forSensitivity: 0.5))
        #expect(BeatDetector.threshold(forSensitivity: 5) == BeatDetector.threshold(forSensitivity: 1))
    }
}

@Suite("Уровень басов")
struct BassLevelTests {
    @Test("Всегда в 0...1")
    func bounded() {
        var level = BassLevel()
        for e in kicks(seconds: 3) + [100, 0, 1e9, 0] {
            let v = level.update(energy: e, dt: dt)
            #expect((0...1).contains(v))
        }
    }

    @Test("Тишина — ноль")
    func silence() {
        var level = BassLevel()
        for _ in 0..<100 { level.update(energy: 0, dt: dt) }
        #expect(level.value == 0)
    }

    @Test("Удар поднимает уровень быстро, а спадает он медленно")
    func attackAndRelease() {
        var level = BassLevel()
        // Сначала пара секунд с ударами — они задают максимум; потом полсекунды тихо.
        for e in kicks(seconds: 2) { level.update(energy: e, dt: dt) }
        for _ in 0..<50 { level.update(energy: 0.05, dt: dt) }
        let before = level.value
        for _ in 0..<3 { level.update(energy: 1, dt: dt) }  // ~32 мс удара
        let peak = level.value
        level.update(energy: 0.05, dt: dt)
        let after = level.value
        #expect(peak > 0.8)
        #expect(before < 0.3)
        #expect(after > peak - 0.1)  // через одно окно почти не упал
    }

    @Test("Авто-усиление: тихий трек тоже доходит до верха")
    func autoGain() {
        var level = BassLevel()
        for _ in 0..<200 { level.update(energy: 0.001, dt: dt) }
        #expect(level.value > 0.9)
    }
}

@Suite("Вспышка")
struct EnvelopeTests {
    @Test("Без ударов — базовая яркость")
    func idle() {
        var envelope = Envelope(base: 0.4)
        #expect(envelope.advance(1) == 0.4)
    }

    @Test("Удар — полная яркость, потом плавно гаснет к базе")
    func flashDecays() {
        var envelope = Envelope(base: 0.4, decay: 0.15)
        envelope.beat()
        #expect(envelope.brightness == 1)
        var previous = envelope.brightness
        for _ in 0..<60 {
            let b = envelope.advance(1.0 / 60)
            #expect(b < previous)
            previous = b
        }
        #expect(abs(previous - 0.4) < 0.01)  // через секунду — почти база
    }
}
