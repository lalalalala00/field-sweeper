import SwiftUI

/// 게임 규칙 창: 한 줄 설명, 규칙, 조작법. 어느 게임에서나 같은 메모지 색으로 보인다(웹 규칙 창과 같다).
/// 화면보다 길면 창 안에서 스크롤된다.
struct RulesCard: View {
    let kind: GameKind
    let onClose: () -> Void

    var body: some View {
        let r = kind.rules
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea().onTapGesture(perform: onClose)
            // 화면에 다 들어가면 그대로, 넘치면 내용만 스크롤하고 확인 버튼은 아래에 남긴다.
            ViewThatFits(in: .vertical) {
                VStack(spacing: 0) {
                    content(r)
                    closeButton
                }
                VStack(spacing: 0) {
                    ScrollView { content(r) }
                        .scrollBounceBehavior(.basedOnSize)
                    closeButton
                }
            }
            .foregroundStyle(Color(Paper.ink))
            .frame(maxWidth: 440)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
    }

    private func content(_ r: GameRules) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                GameSymbol(kind: kind, size: 24, color: Color(Paper.ink))
                Text(verbatim: kind.title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text(verbatim: tr(r.line))
                .font(.subheadline)
                .foregroundStyle(Color(Paper.inkSoft))
                .fixedSize(horizontal: false, vertical: true)
            section("규칙", r.rules)
            section("조작", r.howto)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closeButton: some View {
        Button(action: onClose) { Text("확인").frame(maxWidth: .infinity) }
            .buttonStyle(PaperButtonStyle(prominent: true))
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .padding(.top, 4)
    }

    private func section(_ title: LocalizedStringKey, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").foregroundStyle(Color(Paper.inkSoft))
                    Text(verbatim: tr(line))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
