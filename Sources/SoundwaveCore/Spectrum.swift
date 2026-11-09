import Accelerate

/// Энергия звука в полосе частот: окно Ханна → FFT (vDSP) → сумма квадратов амплитуд нужных бинов.
public final class Spectrum {
    /// Сколько сэмплов на одно окно. При 48 кГц 2048 сэмплов — это ~43 мс и шаг по частоте ~23 Гц.
    public let size: Int
    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]

    public init(size: Int = 2048) {
        precondition(size > 1 && size & (size - 1) == 0, "размер окна FFT должен быть степенью двойки")
        self.size = size
        fft = vDSP.FFT(
            log2n: vDSP_Length(size.trailingZeroBitCount), radix: .radix2, ofType: DSPSplitComplex.self)!
        window = vDSP.window(
            ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
    }

    /// Энергия `samples` (ровно `size` штук) в полосе `band` Гц. Абсолютное значение роли не играет —
    /// дальше его нормирует `BassLevel`; важно, что громче и ниже — значит больше.
    public func energy(of samples: [Float], sampleRate: Double, band: ClosedRange<Double>) -> Double {
        precondition(samples.count == size, "нужно ровно \(size) сэмплов")
        let half = size / 2
        let windowed = vDSP.multiply(samples, window)
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realp in
            imag.withUnsafeMutableBufferPointer { imagp in
                var split = DSPSplitComplex(realp: realp.baseAddress!, imagp: imagp.baseAddress!)
                // Вещественный сигнал длины N упаковывается в N/2 комплексных чисел: чётные → re, нечётные → im.
                windowed.withUnsafeBufferPointer { input in
                    input.withMemoryRebound(to: DSPComplex.self) { pairs in
                        vDSP.convert(interleavedComplexVector: Array(pairs), toSplitComplexVector: &split)
                    }
                }
                fft.forward(input: split, output: &split)
                vDSP.squareMagnitudes(split, result: &power)
            }
        }

        // Бин k соответствует частоте k × sampleRate / size. Бин 0 (постоянная составляющая
        // + упакованная частота Найквиста) пропускаем.
        let binWidth = sampleRate / Double(size)
        let low = max(1, Int((band.lowerBound / binWidth).rounded(.up)))
        let high = min(half - 1, Int((band.upperBound / binWidth).rounded(.down)))
        guard low <= high else { return 0 }
        return Double(power[low...high].reduce(0, +))
    }
}
