// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Soundwave",
    platforms: [.macOS(.v15)],
    targets: [
        // Чистая логика без системных API: протокол, палитра, анализ звука. Всё под тестами.
        .target(name: "SoundwaveCore"),
        // Само приложение в строке меню.
        .executableTarget(name: "Soundwave", dependencies: ["SoundwaveCore"]),
        .testTarget(name: "SoundwaveCoreTests", dependencies: ["SoundwaveCore"]),
    ]
)
