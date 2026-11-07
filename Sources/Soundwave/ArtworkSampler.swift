import AppKit
import SoundwaveCore

/// Превращает обложку в пиксели для `Palette`: уменьшает до `size × size` и читает цвета.
/// 32 × 32 = 1024 пикселя — для палитры хватает с запасом, а считается мгновенно.
enum ArtworkSampler {
    static let size = 32

    static func pixels(of image: NSImage) -> [Pixel] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let bytesPerRow = size * 4
        var buffer = [UInt8](repeating: 0, count: size * bytesPerRow)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard
                let context = CGContext(
                    data: raw.baseAddress, width: size, height: size, bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            // Без сглаживания: иначе на стыках цветов появляются «смешанные» пиксели, которых нет на обложке.
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return [] }

        var pixels: [Pixel] = []
        pixels.reserveCapacity(size * size)
        for row in 0..<size {
            for column in 0..<size {
                let i = row * bytesPerRow + column * 4
                guard buffer[i + 3] >= 128 else { continue }  // прозрачное не считаем
                let x = (Double(column) + 0.5) / Double(size)
                pixels.append(Pixel(RGB(buffer[i], buffer[i + 1], buffer[i + 2]), x: x))
            }
        }
        return pixels
    }
}
