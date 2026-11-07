import Foundation
import Network
import SoundwaveCore

/// Шлёт пакеты на плату по UDP.
///
/// Всё состояние живёт на своей очереди `queue`, поэтому класс можно спокойно дёргать
/// из главного потока: методы только ставят работу в очередь.
final class LightSender: @unchecked Sendable {
    /// Что сейчас со связью — для строки статуса в меню. Вызывается в главном потоке.
    var onStatus: (@MainActor @Sendable (String) -> Void)?

    private let queue = DispatchQueue(label: "com.qu1nqqy.soundwave.sender")
    private var connection: NWConnection?
    private var host = ""
    private var scene: LightScene?
    private var keepalive: DispatchSourceTimer?

    init() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        // Раз в секунду повторяем текущую сцену: у платы таймаут 5 с, после него — радуга.
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.sendState() }
        timer.resume()
        keepalive = timer
    }

    deinit {
        keepalive?.cancel()
        connection?.cancel()
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

    private func sendState() {
        guard let packet = scene?.statePacket else { return }
        send(packet)
    }

    private func send(_ packet: [UInt8]) {
        connection?.send(content: Data(packet), completion: .idempotent)
    }

    private func report(_ status: String) {
        guard let onStatus else { return }
        Task { @MainActor in onStatus(status) }
    }
}
