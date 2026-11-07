import SoundwaveCore
import SwiftUI

/// Окно, которое открывается по клику на иконку в строке меню.
struct MenuView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NowPlayingView(track: state.track, artwork: state.artwork)
            if !state.palette.isEmpty {
                PaletteView(palette: state.palette, dominant: state.dominant)
            }
            Divider()
            HStack {
                Spacer()
                Button("Выход") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

/// Обложка, название и статус трека.
private struct NowPlayingView: View {
    let track: Track?
    let artwork: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                if let track {
                    Text(track.name).font(.headline).lineLimit(1)
                    Text(track.artist).foregroundStyle(.secondary).lineLimit(1)
                    Label(
                        track.isPlaying ? "Играет" : "Пауза",
                        systemImage: track.isPlaying ? "play.fill" : "pause.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Ничего не играет").font(.headline)
                    Text("Включи музыку в Music").foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Цвета обложки слева направо: ширина полоски — доля площади. Под ней — основной цвет.
private struct PaletteView: View {
    let palette: [PaletteColor]
    let dominant: RGB

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { _, entry in
                        Rectangle()
                            .fill(Color(entry.color))
                            .frame(width: geometry.size.width * entry.weight)
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 6) {
                Circle().fill(Color(dominant)).frame(width: 10, height: 10)
                Text("Основной цвет").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }
}
