import Foundation
import Network
import SoundwaveCore

/// Шлёт пакеты на плату по UDP.
///
/// Два ритма:
/// - **раз в секунду** — «что показывать» (`LightScene.statePacket`), чтобы плата не ушла в радугу;
/// - **60 раз в секунду, пока идёт звук** — реакция на музыку: в «Одном цвете» цвет × вспышка
///   (`Fill`), в «Сочетании» — уровень басов (`Level`), а рисует уже плата.
///
/// Всё состояние живёт на своей очереди `queue`, поэтому класс можно спокойно дёргать
/// из главного потока: методы только ставят работу в очередь.
final class LightSender: @unchecked Sendable {
    static let fps = 60.0
    /// Если звука нет дольше этого, считаем, что его нет вовсе, и светим ровно.
    static let audioTimeout = 0.3

    /// Что сейчас со связью — для строки статуса в меню. Вызывается в главном потоке.
    var onStatus: (@MainActor @Sendable (String) -> Void)?

    private let queue = DispatchQueue(label: "com.qu1nqqy.soundwave.sender")
    private var connection: NWConnection?
    private var host = ""
    private var scene: LightScene?
    private var timers: [DispatchSourceTimer] = []

    private var level = 0.0
    private var envelope = Envelope()
    private var lastAudio: DispatchTime?

    init() {
        timers = [
            timer(every: 1) { $0.keepalive() },
            timer(every: 1 / Self.fps) { $0.frame() },
        ]
    }

    deinit {
        for timer in timers { timer.cancel() }
        connection?.cancel()
    }

    /// Новое окно звука от анализатора: уровень басов и был ли удар.
    func audioFrame(level: Double, beat: Bool) {
        queue.async { [self] in
            self.level = level
            if beat { envelope.beat() }
            lastAudio = .now()
        }
    }

    /// IP или имя платы. Пустая строка — никуда не шлём.
    func setHost(_ host: String) {
        queue.async { [self] in
            let host = host.trimmingCharacters(in: .whitespaces)
            guard host != self.host else { return }
            self.host = host
            connect()
            sendState()
        }
    }

    /// Новая сцена уходит на плату сразу, не дожидаясь keepalive.
    func setScene(_ scene: LightScene) {
        queue.async { [self] in
            guard scene != self.scene else { return }
            self.scene = scene
            sendState()
        }
    }

    // MARK: - На очереди `queue`

    private func connect() {
        connection?.cancel()
        connection = nil
        guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: LightProtocol.port) else {
            report("Не указан адрес платы")
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
        connection.stateUpdateHandler = { [weak self, host] state in
            switch state {
            case .ready: self?.report("Шлю на \(host)")
            case .waiting(let error), .failed(let error):
                self?.report("Нет связи: \(error.localizedDescription)")
            default: break
            }
        }
        connection.start(queue: queue)
        self.connection = connection
    }

    private var hasAudio: Bool {
        guard let lastAudio else { return false }
        return Double(DispatchTime.now().uptimeNanoseconds - lastAudio.uptimeNanoseconds) / 1e9
            < Self.audioTimeout
    }

    private func sendState() {
        guard let packet = scene?.statePacket else { return }
        send(packet)
    }

    /// Раз в секунду. В «Одном цвете» под музыку Fill и так идёт 60 раз в секунду — ровный цвет
    /// на полной яркости посреди пульса дал бы вспышку, поэтому тогда пропускаем.
    private func keepalive() {
        if scene?.mode == .single, hasAudio { return }
        sendState()
    }

    /// 60 раз в секунду.
    private func frame() {
        envelope.advance(1 / Self.fps)
        guard let scene, scene.isActive, hasAudio else { return }
        switch scene.mode {
        case .single: send(LightProtocol.fill(scene.dominant.dimmed(envelope.brightness)))
        case .palette: send(LightProtocol.level(level))
        }
    }

    private func timer(every interval: Double, _ action: @escaping (LightSender) -> Void)
        -> DispatchSourceTimer
    {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self.map(action) }
        timer.resume()
        return timer
    }

    private func send(_ packet: [UInt8]) {
        connection?.send(content: Data(packet), completion: .idempotent)
    }

    private func report(_ status: String) {
        guard let onStatus else { return }
        Task { @MainActor in onStatus(status) }
    }
}
