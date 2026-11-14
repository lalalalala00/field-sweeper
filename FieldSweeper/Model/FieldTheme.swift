import UIKit

struct FieldPalette {
    let turf, turfHi, turfLo, ground, board: UIColor
}

enum FieldStyle: Codable, Equatable {
    case preset(String)
    case custom(turf: UInt32, ground: UInt32)

    var palette: FieldPalette {
        switch self {
        case .preset(let id):
            return (FieldPreset.all.first { $0.id == id } ?? FieldPreset.all[0]).palette
        case .custom(let turf, let ground):
            return FieldPalette(turf: UIColor(hex: turf),
                                turfHi: UIColor(hex: mixHex(turf, 0xffffff, 0.25)),
                                turfLo: UIColor(hex: mixHex(turf, 0x000000, 0.25)),
                                ground: UIColor(hex: ground),
                                board: UIColor(hex: mixHex(ground, 0x000000, 0.18)))
        }
    }
}

/// 덮인 칸 / 열린 칸 / 보드 바탕. 앞은 라이트, 뒤는 다크 모드 색.
struct FieldPreset: Identifiable {
    let id: String
    let name: String
    let turf: (UInt32, UInt32)
    let ground: (UInt32, UInt32)
    let board: (UInt32, UInt32)

    static let all: [FieldPreset] = [
        FieldPreset(id: "grass", name: "잔디", turf: (0x79a259, 0x3e6331), ground: (0xe3e8db, 0x1d2519), board: (0xc5cfb8, 0x0b0f09)),
        FieldPreset(id: "sea", name: "바다", turf: (0x4f8fc0, 0x2c5878), ground: (0xe1eaf0, 0x172029), board: (0xbfd0dc, 0x0a0f14)),
        FieldPreset(id: "sand", name: "모래", turf: (0xd2a35b, 0x8a6631), ground: (0xf1ebdf, 0x231e17), board: (0xd9ccb4, 0x0f0c08)),
        FieldPreset(id: "blossom", name: "벚꽃", turf: (0xe58fa8, 0x9a4a63), ground: (0xf6e9ed, 0x24191c), board: (0xe3c9d1, 0x100a0c)),
        FieldPreset(id: "lavender", name: "라벤더", turf: (0x9a86d0, 0x5a4a8c), ground: (0xebe8f4, 0x1c1a26), board: (0xcfc8e3, 0x0c0b12)),
        FieldPreset(id: "stone", name: "돌", turf: (0x8c9399, 0x4a5056), ground: (0xe9eaeb, 0x1b1d1f), board: (0xc8cbce, 0x0b0c0d)),
    ]

    var palette: FieldPalette {
        FieldPalette(turf: .dynamic(turf.0, turf.1),
                     turfHi: .dynamic(mixHex(turf.0, 0xffffff, 0.25), mixHex(turf.1, 0xffffff, 0.15)),
                     turfLo: .dynamic(mixHex(turf.0, 0x000000, 0.25), mixHex(turf.1, 0x000000, 0.3)),
                     ground: .dynamic(ground.0, ground.1),
                     board: .dynamic(board.0, board.1))
    }
}

func mixHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    func ch(_ v: UInt32, _ s: UInt32) -> Double { Double((v >> s) & 0xff) }
    func mixed(_ s: UInt32) -> UInt32 { UInt32((ch(a, s) * (1 - t) + ch(b, s) * t).rounded()) << s }
    return mixed(16) | mixed(8) | mixed(0)
}

extension UIColor {
    var hex: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return c(r) << 16 | c(g) << 8 | c(b)
    }

    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
