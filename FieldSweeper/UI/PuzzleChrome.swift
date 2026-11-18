import SwiftUI

// 스도쿠·시카쿠·후토시키가 함께 쓰는 화면 부품. 메모지 색(Paper) 위에 게임마다 대표 색을 얹는다.

/// 상단: 뒤로, 게임 이름과 난이도, 시간, 일시정지, 더보기 메뉴.
struct PuzzleTopBar<MenuContent: View>: View {
    /// 이름(영어 그대로)과 상징을 보여줄 게임.
    let kind: GameKind
    let subtitle: String
    let showTimer: Bool
    let isPlaying: Bool
    let elapsed: (Date) -> TimeInterval
    let onBack: () -> Void
    let onPause: () -> Void
    /// 있으면 '새 퍼즐' 버튼을 둔다(웹 헤더와 같은 동그란 화살표).
    var onNew: (() -> Void)? = nil
    @ViewBuilder let menu: () -> MenuContent
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        // iPhone에서는 버튼과 간격을 줄여 이름 자리를 남긴다.
        HStack(spacing: compact ? 6 : 8) {
            PuzzleIconButton(icon: "chevron.left", label: "뒤로", action: onBack)
            GameSymbol(kind: kind, size: 20, color: Color(Paper.ink))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: kind.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(verbatim: subtitle).font(.caption2).foregroundStyle(Color(Paper.inkSoft))
            }
            // 폭이 모자라면 이름이 먼저 줄어들고, 타이머는 꺾이지 않는다.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            if showTimer && isPlaying {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let seconds = Int(elapsed(context.date))
                    HStack(spacing: 4) {
                        // 폭이 좁은 iPhone에서는 아이콘을 빼서 이름이 잘리지 않게 한다.
                        if sizeClass != .compact {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(Paper.inkSoft))
                        }
                        Text(verbatim: clock(seconds))
                            .font(.system(size: 17, weight: .medium))
                            .monospacedDigit()
                    }
                    .fixedSize()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("시간 \(seconds)초")
                }
                .fixedSize()
            }
            if let onNew {
                PuzzleIconButton(icon: "arrow.counterclockwise", label: "새 퍼즐", action: onNew)
            }
            PuzzleIconButton(icon: "pause.circle", label: "일시정지", action: onPause)
                .disabled(!isPlaying)
                .opacity(isPlaying ? 1 : 0.4)
            Menu(content: menu) { PuzzleIconButton.face("ellipsis", width: compact ? 36 : 40) }
                .accessibilityLabel("더보기")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(Paper.sheet), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: 760)
    }
}

struct PuzzleIconButton: View {
    let icon: String
    let label: LocalizedStringKey
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Button(action: action) { Self.face(icon, width: sizeClass == .compact ? 36 : 40) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    static func face(_ icon: String, width: CGFloat = 40) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color(Paper.ink))
            .frame(width: width, height: 38)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle().inset(by: -3))
    }
}

/// 상단 바 바로 아래 왼쪽의 '처음부터 다시': 같은 문제를 처음 상태로 돌린다(시간은 이어서 흐른다).
/// 모든 퍼즐에서 이 자리 한 곳에만 둔다. 시간까지 새로 재려면 상단의 새 퍼즐을 쓴다.
struct StartOverButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Label("처음부터 다시", systemImage: "backward.end")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(Paper.sheet), in: Capsule())
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
            Spacer()
        }
    }
}

/// 하단 도구 버튼(되돌리기, 지우기…). active면 게임 대표 색으로 칠한다.
struct PuzzleTool: View {
    /// 되돌리기 버튼 이름. 횟수가 정해진 난이도에서는 남은 횟수를 붙인다.
    static func undoTitle(_ left: Int?) -> LocalizedStringKey {
        if let left { return "되돌리기 \(left)" }
        return "되돌리기"
    }

    let title: LocalizedStringKey
    let icon: String
    var active = false
    var accent: UIColor = Paper.sheet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(Color(Paper.ink))
            .background(Color(active ? accent : Paper.sheet), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 판을 가리는 일시정지 화면.
struct PuzzlePauseCover: View {
    let subtitle: String
    let time: String?
    let accent: UIColor
    let onResume: () -> Void

    var body: some View {
        ZStack {
            Color(Paper.bg).opacity(0.97).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(accent))
                Text("일시정지").font(.system(.title2, design: .rounded, weight: .heavy))
                Text(verbatim: subtitle).font(.subheadline).foregroundStyle(Color(Paper.inkSoft))
                if let time {
                    Text(verbatim: time).font(.system(size: 32, weight: .medium, design: .monospaced))
                }
                Button(action: onResume) { Text("계속하기").frame(maxWidth: .infinity) }
                    .buttonStyle(PaperButtonStyle(prominent: true))
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 320)
        }
    }
}

/// 완성 화면.
struct PuzzleResultCard: View {
    let title: LocalizedStringKey
    let subtitle: String
    /// 시간 위에 한 줄 더(거울네모·스위치네모: "최소 조작으로 풀었어요 · 조작 4회").
    var note: String? = nil
    let time: String?
    let isNewBest: Bool
    let accent: UIColor
    let onClose: () -> Void
    let onOtherLevel: () -> Void
    let onAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                Text(title).font(.system(.title2, design: .rounded, weight: .heavy))
                Text(verbatim: subtitle).font(.subheadline).foregroundStyle(Color(Paper.inkSoft))
                if let note {
                    Text(verbatim: note).font(.subheadline.weight(.semibold))
                }
                if let time {
                    Text(verbatim: time).font(.system(size: 44, weight: .medium, design: .monospaced))
                    if isNewBest {
                        Text("최고 기록")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(accent), in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Button(action: onOtherLevel) { Text("다른 난이도").frame(maxWidth: .infinity) }
                        .buttonStyle(PaperButtonStyle())
                    Button(action: onAgain) { Text("새 퍼즐").frame(maxWidth: .infinity) }
                        .buttonStyle(PaperButtonStyle(prominent: true))
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
    }
}

/// 판을 끝내 만들지 못했을 때(아주 드물다). 같은 난이도로 다시 만들거나 다른 난이도를 고른다.
struct PuzzleFailedCard: View {
    let onRetry: () -> Void
    let onOtherLevel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("퍼즐을 만들지 못했어요").font(.system(.title3, design: .rounded, weight: .heavy))
                HStack(spacing: 8) {
                    Button(action: onOtherLevel) { Text("다른 난이도").frame(maxWidth: .infinity) }
                        .buttonStyle(PaperButtonStyle())
                    Button(action: onRetry) { Text("다시 만들기").frame(maxWidth: .infinity) }
                        .buttonStyle(PaperButtonStyle(prominent: true))
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
    }
}

/// 퍼즐을 만드는 동안 보여주는 작은 창.
/// 오래 걸리는 난이도(expected가 있을 때)는 도는 표시 대신 진행 막대와 안내를 보여준다.
/// 막대는 예상 시간에 맞춰 차오르되, 끝나기 전에는 꽉 차지 않고 거의 다 찬 채로 기다린다.
struct PuzzleWorkingCard: View {
    let text: String
    var expected: TimeInterval? = nil

    @State private var start = Date()

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                if let expected {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSince(start)
                        ProgressView(value: 0.96 * (1 - exp(-2.5 * t / expected)))
                            .tint(Color(Paper.ink))
                            .frame(width: 200)
                    }
                } else {
                    ProgressView().tint(Color(Paper.ink))
                }
                Text(verbatim: text).font(.subheadline)
                if expected != nil {
                    Text("어려운 퍼즐이라 몇 초 걸릴 수 있어요")
                        .font(.caption)
                        .foregroundStyle(Color(Paper.inkSoft))
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

/// 만드는 데 1초 넘게 걸릴 수 있는 난이도의 예상 시간(초). 엔진이 퍼즐을 골라 보는 시간에 맞춘다.
enum GenerationTime {
    static func expected(_ kind: GameKind, levelID: Int) -> TimeInterval? {
        switch (kind, levelID) {
        case (.star, StarLevel.expert.rawValue): 6
        case (.star, StarLevel.hard.rawValue): 2
        case (.calc, CalcLevel.hell.rawValue): 4
        case (.pair, PairLevel.expert.rawValue): 2.5
        case (.mirror, MirrorLevel.expert.rawValue): 1.5
        case (.sudoku, SudokuLevel.hard.rawValue): 1.3
        default: nil
        }
    }
}

/// 난이도 고르기.
struct PuzzleLevelPicker: View {
    struct Item: Identifiable {
        let id: Int
        let name: String
        let detail: String
        let best: Int?
    }

    let items: [Item]
    let current: Int
    let accent: UIColor
    let canCancel: Bool
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("난이도를 골라 주세요")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        Button { onPick(item.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: item.name).font(.subheadline.weight(.semibold))
                                    Text(verbatim: item.detail).font(.caption).foregroundStyle(Color(Paper.inkSoft))
                                }
                                Spacer()
                                if let best = item.best {
                                    Text(verbatim: clock(best)).font(.caption.monospacedDigit()).foregroundStyle(Color(Paper.inkSoft))
                                }
                            }
                            .foregroundStyle(Color(Paper.ink))
                            .padding(14)
                            .background(Color(item.id == current ? accent : Paper.sheet), in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(canCancel ? "취소" : "돌아가기", action: onCancel)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .padding(22)
            .frame(maxWidth: 380)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
    }
}

struct PaperButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(Color(prominent ? Paper.bg : Paper.ink))
            .background(Color(prominent ? Paper.ink : Paper.sheet), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
