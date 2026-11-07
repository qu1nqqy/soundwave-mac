import SoundwaveCore
import SwiftUI

/// Окно, которое открывается по клику на иконку в строке меню.
struct MenuView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NowPlayingView(track: state.track, artwork: state.artwork)
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
