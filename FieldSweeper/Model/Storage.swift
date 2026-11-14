import Foundation

enum RecordStore {
    private static let key = "bestTimes"

    static func best(for recordKey: String) -> Int? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int])?[recordKey]
    }

    /// 최고 기록을 갱신했으면 true.
    static func submit(_ seconds: Int, for recordKey: String) -> Bool {
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        if let best = all[recordKey], best <= seconds { return false }
        all[recordKey] = seconds
        UserDefaults.standard.set(all, forKey: key)
        return true
    }
}

enum Persist {
    static var lastConfig: BoardConfig? {
        get { load("lastConfig") }
        set { save(newValue, "lastConfig") }
    }

    static var customConfig: BoardConfig? {
        get { load("customConfig") }
        set { save(newValue, "customConfig") }
    }

    private static func load(_ key: String) -> BoardConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BoardConfig.self, from: data)
    }

    private static func save(_ value: BoardConfig?, _ key: String) {
        UserDefaults.standard.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }
}

func pad3(_ n: Int) -> String {
    n < 0 ? "-" + String(format: "%02d", min(-n, 99)) : String(format: "%03d", min(n, 999))
}

func clock(_ seconds: Int) -> String {
    "\(seconds / 60):" + String(format: "%02d", seconds % 60)
}
