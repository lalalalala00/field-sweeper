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

/// 앱 안에서 고른 언어. "system"이면 기기 설정을 따른다.
enum AppLanguage {
    static let storageKey = "appLanguage"
    static let options: [(code: String, name: String)] = [
        ("ko", "한국어"), ("ja", "日本語"), ("zh-Hans", "中文"), ("en", "English"),
    ]

    static var code: String? {
        let code = UserDefaults.standard.string(forKey: storageKey) ?? "system"
        return code == "system" ? nil : code
    }

    static var locale: Locale { code.map(Locale.init(identifier:)) ?? .current }

    /// 고른 언어의 .lproj 번들. 문자열을 찾을 때 쓴다.
    static var bundle: Bundle {
        guard let code else { return .main }
        if let cached = bundles[code] { return cached }
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        bundles[code] = bundle
        return bundle
    }
    private static var bundles: [String: Bundle] = [:]
}

/// 변수에 담긴 한국어 문구(난이도 이름 등)를 현재 언어로 바꾼다. 번역이 없으면 그대로 쓴다.
func tr(_ key: String) -> String {
    AppLanguage.bundle.localizedString(forKey: key, value: key, table: nil)
}

func pad3(_ n: Int) -> String {
    n < 0 ? "-" + String(format: "%02d", min(-n, 99)) : String(format: "%03d", min(n, 999))
}

func clock(_ seconds: Int) -> String {
    "\(seconds / 60):" + String(format: "%02d", seconds % 60)
}
