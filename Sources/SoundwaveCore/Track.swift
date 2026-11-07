/// Трек, который сейчас в Music.
public struct Track: Hashable, Sendable {
    public enum State: String, Sendable {
        case playing, paused, stopped
    }

    public var name: String
    public var artist: String
    public var album: String
    public var state: State

    public init(name: String, artist: String, album: String, state: State) {
        self.name = name
        self.artist = artist
        self.album = album
        self.state = state
    }

    public var isPlaying: Bool { state == .playing }

    /// Тот же ли это трек (без учёта паузы): по нему решаем, перечитывать ли обложку.
    public func isSameSong(as other: Track?) -> Bool {
        guard let other else { return false }
        return name == other.name && artist == other.artist && album == other.album
    }

    /// Разбирает `userInfo` уведомления `com.apple.Music.playerInfo`.
    /// Music шлёт его при каждой смене трека, паузе и продолжении.
    /// Возвращает `nil`, если воспроизведение остановлено совсем.
    public init?(playerInfo info: [AnyHashable: Any]) {
        let state = (info["Player State"] as? String).flatMap { State(rawValue: $0.lowercased()) }
        guard let state, state != .stopped else { return nil }
        self.init(
            name: info["Name"] as? String ?? "",
            artist: info["Artist"] as? String ?? "",
            album: info["Album"] as? String ?? "",
            state: state
        )
    }
}
