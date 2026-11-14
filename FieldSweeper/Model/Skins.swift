import UIKit
import Observation

enum SkinKind: String, CaseIterable, Identifiable {
    case flag, mine

    var id: String { rawValue }
    var title: String { self == .flag ? "깃발" : "지뢰" }

    var emojiChoices: [String] {
        switch self {
        case .flag: ["🚩", "⛳️", "📍", "🎌", "⭐️", "❤️", "🍋", "🔖"]
        case .mine: ["💣", "💥", "☠️", "👻", "🐛", "🍄", "🦠", "🔥"]
        }
    }
}

enum Skin: Codable, Equatable {
    case classic
    case emoji(String)
    case photo(String) // Application Support/Skins 안의 파일 이름

    var label: String {
        switch self {
        case .classic: "기본"
        case .emoji(let e): e
        case .photo: "내 사진"
        }
    }
}

@MainActor
@Observable
final class SkinStore {
    static let shared = SkinStore()

    private(set) var flag: Skin
    private(set) var mine: Skin
    private(set) var field: FieldStyle
    /// 모양이나 필드 색이 바뀔 때마다 증가. 보드 뷰와 미리보기가 다시 그릴 때 쓴다.
    private(set) var version = 0
    @ObservationIgnored private(set) var fieldPalette: FieldPalette
    @ObservationIgnored private var images: [String: UIImage] = [:]

    private init() {
        flag = Self.load(.flag)
        mine = Self.load(.mine)
        let field = UserDefaults.standard.data(forKey: "field")
            .flatMap { try? JSONDecoder().decode(FieldStyle.self, from: $0) } ?? .preset("grass")
        self.field = field
        fieldPalette = field.palette
    }

    func setField(_ style: FieldStyle) {
        field = style
        fieldPalette = style.palette
        UserDefaults.standard.set(try? JSONEncoder().encode(style), forKey: "field")
        version += 1
    }

    func skin(_ kind: SkinKind) -> Skin { kind == .flag ? flag : mine }

    func set(_ skin: Skin, for kind: SkinKind) {
        let old = self.skin(kind)
        if case .photo(let name) = old, old != skin {
            try? FileManager.default.removeItem(at: Self.url(name))
            images[name] = nil
        }
        switch kind {
        case .flag: flag = skin
        case .mine: mine = skin
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(skin), forKey: "skin." + kind.rawValue)
        version += 1
    }

    /// 사진을 가운데 기준 정사각형으로 잘라 256px로 저장한다.
    func setPhoto(_ data: Data, for kind: SkinKind) -> Bool {
        guard let source = UIImage(data: data),
              let png = Self.squareThumbnail(source, side: 256).pngData() else { return false }
        let name = "\(kind.rawValue)-\(UUID().uuidString).png"
        do {
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            try png.write(to: Self.url(name), options: .atomic)
        } catch {
            return false
        }
        set(.photo(name), for: kind)
        return true
    }

    func image(named name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        let image = UIImage(contentsOfFile: Self.url(name).path)
        images[name] = image
        return image
    }

    private static var folder: URL { URL.applicationSupportDirectory.appending(path: "Skins") }
    private static func url(_ name: String) -> URL { folder.appending(path: name) }

    private static func load(_ kind: SkinKind) -> Skin {
        guard let data = UserDefaults.standard.data(forKey: "skin." + kind.rawValue),
              let skin = try? JSONDecoder().decode(Skin.self, from: data) else { return .classic }
        return skin
    }

    private static func squareThumbnail(_ image: UIImage, side: CGFloat) -> UIImage {
        let scale = side / min(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                                  width: size.width, height: size.height))
        }
    }
}
