import AppKit

/// Держит отвод звука от Music включённым: запускает, когда Music открыт и уже выводил звук,
/// перезапускает после перезапуска Music и останавливает, когда Music закрыт.
@MainActor
final class AudioMonitor {
    nonisolated static let musicBundleID = "com.apple.Music"

    /// Строка для меню: что сейчас со звуком.
    var onStatus: ((String) -> Void)?

    let tap = AudioTap()
    private var observers: [NSObjectProtocol] = []
    private var retry: Timer?
    private var pid: pid_t?

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
        ] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    guard app?.bundleIdentifier == Self.musicBundleID else { return }
                    MainActor.assumeIsolated { self?.refresh() }
                })
        }
        // Аудио-объект Music появляется только после первого звука — до тех пор пробуем раз в 2 секунды.
        retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    private func refresh() {
        let music = NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleID).first
        guard let music else {
            if pid != nil { tap.stop() }
            pid = nil
            onStatus?("Звук: Music закрыт")
            return
        }
        if music.processIdentifier == pid, tap.isRunning { return }

        do {
            try tap.start(pid: music.processIdentifier)
            pid = music.processIdentifier
            onStatus?("Звук: слушаю Music")
        } catch let error as AudioTap.TapError {
            pid = nil
            onStatus?("Звук: \(error)")
        } catch {
            pid = nil
            onStatus?("Звук: \(error.localizedDescription)")
        }
    }
}
