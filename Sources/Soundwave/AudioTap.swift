import AudioToolbox
import CoreAudio
import Foundation

/// Слушает звук одного процесса (у нас — Music) через Core Audio process tap (macOS 14.2+).
///
/// Как это устроено:
/// 1. PID процесса → его аудио-объект в Core Audio.
/// 2. `CATapDescription` + `AudioHardwareCreateProcessTap` — «отвод» звука этого процесса.
///    `muteBehavior = .unmuted`: звук при этом продолжает играть в колонках как обычно.
/// 3. Приватное aggregate-устройство, в которое входит этот отвод, — его можно читать как микрофон.
/// 4. IO-блок на этом устройстве получает сэмплы; мы сводим их в моно и отдаём в `onSamples`.
///
/// Разрешение на запись звука macOS спрашивает при первом старте. Если его не дали,
/// сэмплы приходят, но в них тишина.
final class AudioTap: @unchecked Sendable {
    enum TapError: Error, CustomStringConvertible {
        case noAudioProcess
        case coreAudio(String, OSStatus)

        var description: String {
            switch self {
            case .noAudioProcess: "Music ещё не выводил звук"
            case .coreAudio(let step, let status): "\(step): ошибка Core Audio \(status)"
            }
        }
    }

    /// Моно-сэмплы и частота дискретизации. Вызывается на очереди звука.
    var onSamples: (@Sendable (UnsafeBufferPointer<Float>, Double) -> Void)?

    let queue = DispatchQueue(label: "com.qu1nqqy.soundwave.audio", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var sampleRate = 48_000.0
    private var mono: [Float] = []

    var isRunning: Bool { procID != nil }

    deinit { stop() }

    func start(pid: pid_t) throws {
        stop()
        do {
            let process = try processObject(for: pid)

            let description = CATapDescription(stereoMixdownOfProcesses: [process])
            description.uuid = UUID()
            description.name = "Soundwave"
            description.isPrivate = true
            description.muteBehavior = .unmuted
            try check("Создание отвода звука", AudioHardwareCreateProcessTap(description, &tapID))

            var format = AudioStreamBasicDescription()
            try read(kAudioTapPropertyFormat, of: tapID, into: &format)
            sampleRate = format.mSampleRate

            let outputUID = try defaultOutputUID()
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Soundwave",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [
                    [kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: description.uuid.uuidString]
                ],
            ]
            try check(
                "Создание устройства",
                AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID))

            try check(
                "Подписка на звук",
                AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) {
                    [weak self] _, input, _, _, _ in
                    self?.receive(input)
                })
            try check("Старт", AudioDeviceStart(aggregateID, procID))
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
            self.procID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    // MARK: - Сэмплы (очередь `queue`)

    /// Сводит каналы в моно. Формат отвода — Float32; каналы бывают как в одном буфере
    /// вперемешку (L R L R …), так и в отдельных буферах.
    private func receive(_ input: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = buffers.first, first.mDataByteSize > 0 else { return }

        let frames: Int
        if buffers.count == 1 {
            let channels = max(1, Int(first.mNumberChannels))
            frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / channels
            let samples = first.mData!.assumingMemoryBound(to: Float.self)
            resize(frames)
            for f in 0..<frames {
                var sum: Float = 0
                for c in 0..<channels { sum += samples[f * channels + c] }
                mono[f] = sum / Float(channels)
            }
        } else {
            frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size
            resize(frames)
            for f in 0..<frames { mono[f] = 0 }
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let samples = data.assumingMemoryBound(to: Float.self)
                for f in 0..<frames { mono[f] += samples[f] / Float(buffers.count) }
            }
        }
        mono.withUnsafeBufferPointer { onSamples?(UnsafeBufferPointer(rebasing: $0[0..<frames]), sampleRate) }
    }

    private func resize(_ frames: Int) {
        if mono.count < frames { mono = [Float](repeating: 0, count: frames) }
    }
}

// MARK: - Обёртки над свойствами Core Audio

private func check(_ step: String, _ status: OSStatus) throws {
    guard status == noErr else { throw AudioTap.TapError.coreAudio(step, status) }
}

private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
}

private func read<T>(_ selector: AudioObjectPropertySelector, of object: AudioObjectID, into value: inout T)
    throws
{
    var address = address(selector)
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)
    }
    try check("Чтение свойства \(selector)", status)
}

/// Аудио-объект процесса. Появляется только после того, как процесс хоть раз выводил звук.
private func processObject(for pid: pid_t) throws -> AudioObjectID {
    var address = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
    var pid = pid
    var object = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    try check(
        "Поиск процесса",
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size,
            &object))
    guard object != kAudioObjectUnknown else { throw AudioTap.TapError.noAudioProcess }
    return object
}

/// UID устройства, через которое сейчас играет звук: aggregate-устройство тактируется от него.
private func defaultOutputUID() throws -> String {
    var device = AudioObjectID(kAudioObjectUnknown)
    try read(
        kAudioHardwarePropertyDefaultSystemOutputDevice, of: AudioObjectID(kAudioObjectSystemObject),
        into: &device)
    var uid: Unmanaged<CFString>?
    try read(kAudioDevicePropertyDeviceUID, of: device, into: &uid)
    guard let uid else {
        throw AudioTap.TapError.coreAudio("UID устройства вывода", kAudioHardwareUnknownPropertyError)
    }
    return uid.takeRetainedValue() as String
}
