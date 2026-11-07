import AppKit
import SoundwaveCore

/// Следит за тем, что играет в Music.
///
/// Music сам рассылает уведомление `com.apple.Music.playerInfo` при каждой смене трека, паузе и
/// продолжении — опрашивать его не нужно. Обложки в уведомлении нет, её забираем через AppleScript.
@MainActor
final class NowPlaying {
    /// Вызывается при любом изменении: новый трек, пауза, продолжение, остановка.
    /// Обложка — `nil`, если её нет или трек остановлен.
    var onChange: ((Track?, NSImage?) -> Void)?

    private(set) var track: Track?
    private(set) var artwork: NSImage?
    private var observer: NSObjectProtocol?

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main
        ) { [weak self] note in
            let track = note.userInfo.flatMap(Track.init(playerInfo:))
            MainActor.assumeIsolated { self?.update(track) }
        }
        // Уведомление придёт только при следующем изменении — текущее состояние спрашиваем сами.
        update(Self.currentTrack())
    }

    private func update(_ new: Track?) {
        if new == nil {
            artwork = nil
        } else if !(new?.isSameSong(as: track) ?? false) {
            artwork = Self.currentArtwork()
        }
        track = new
        onChange?(track, artwork)
    }

    // MARK: - AppleScript

    // `if application "Music" is running` — чтобы не запускать Music, если он закрыт.

    private static func currentTrack() -> Track? {
        let result = run(
            """
            if application "Music" is running then
                tell application "Music"
                    set s to player state as string
                    if s is "stopped" then return {s}
                    set t to current track
                    return {s, name of t, artist of t, album of t}
                end tell
            end if
            return {"stopped"}
            """)
        guard let result, result.numberOfItems >= 4,
            let state = result.atIndex(1)?.stringValue.flatMap({ Track.State(rawValue: $0) }),
            state != .stopped
        else { return nil }
        return Track(
            name: result.atIndex(2)?.stringValue ?? "",
            artist: result.atIndex(3)?.stringValue ?? "",
            album: result.atIndex(4)?.stringValue ?? "",
            state: state
        )
    }

    private static func currentArtwork() -> NSImage? {
        let result = run(
            """
            if application "Music" is running then
                tell application "Music"
                    if player state is stopped then return missing value
                    try
                        set t to current track
                        if (count of artworks of t) > 0 then return raw data of artwork 1 of t
                    end try
                end tell
            end if
            return missing value
            """)
        // raw data приходит как JPEG или PNG — NSImage разберётся сам.
        guard let data = result?.data, !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Soundwave: AppleScript error: \(error)")
            return nil
        }
        return result
    }
}
