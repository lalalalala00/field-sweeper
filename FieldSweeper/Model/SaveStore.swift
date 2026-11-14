import Foundation

/// 진행 중인 게임. 앱을 나갈 때 저장하고, 다음 실행 때 이어서 할지 묻는다.
struct GameSnapshot: Codable {
    var config: BoardConfig
    var cols: Int
    var rows: Int
    var mineIndices: [Int]
    var state: [UInt8]
    var elapsed: TimeInterval
    var savedAt: Date

    var progress: Double {
        let safe = cols * rows - mineIndices.count
        guard safe > 0 else { return 0 }
        return Double(state.filter { $0 == CellState.open.rawValue }.count) / Double(safe)
    }
}

enum SaveStore {
    private static var url: URL { URL.applicationSupportDirectory.appending(path: "savedGame.json") }

    static func save(_ snapshot: GameSnapshot?) {
        guard let snapshot else { return clear() }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    static func load() -> GameSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
