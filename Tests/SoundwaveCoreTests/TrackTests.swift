import Testing

@testable import SoundwaveCore

@Suite("Трек")
struct TrackTests {
    let playing: [AnyHashable: Any] = [
        "Name": "Madam",
        "Artist": "Kai Angel",
        "Album": "Madam",
        "Player State": "Playing",
        "PersistentID": 123_456,
    ]

    @Test("Разбирает уведомление о воспроизведении")
    func parsesPlaying() {
        #expect(
            Track(playerInfo: playing)
                == Track(name: "Madam", artist: "Kai Angel", album: "Madam", state: .playing))
    }

    @Test("Пауза — это всё ещё трек, но не играет")
    func parsesPaused() throws {
        var info = playing
        info["Player State"] = "Paused"
        let track = try #require(Track(playerInfo: info))
        #expect(track.state == .paused)
        #expect(!track.isPlaying)
    }

    @Test("Остановка или непонятное состояние — трека нет", arguments: ["Stopped", "Rewinding", ""])
    func stoppedIsNil(state: String) {
        var info = playing
        info["Player State"] = state
        #expect(Track(playerInfo: info) == nil)
    }

    @Test("Без состояния — трека нет")
    func missingStateIsNil() {
        #expect(Track(playerInfo: ["Name": "Madam"]) == nil)
    }

    @Test("Пропущенные поля становятся пустыми строками")
    func missingFieldsAreEmpty() throws {
        let track = try #require(Track(playerInfo: ["Player State": "Playing"]))
        #expect(track.name.isEmpty && track.artist.isEmpty && track.album.isEmpty)
    }

    @Test("Пауза того же трека — та же песня, другой трек — нет")
    func sameSong() {
        let a = Track(name: "Madam", artist: "Kai Angel", album: "Madam", state: .playing)
        var paused = a
        paused.state = .paused
        var other = a
        other.name = "Другая"
        #expect(a.isSameSong(as: paused))
        #expect(!a.isSameSong(as: other))
        #expect(!a.isSameSong(as: nil))
    }
}
