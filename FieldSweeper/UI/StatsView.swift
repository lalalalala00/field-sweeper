import SwiftUI

/// 게임별 기록. 게임마다 따로 센다.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(GameKind.allCases) { kind in
                        StatsCard(kind: kind, stats: StatsStore.load(kind))
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(Paper.bg))
            .foregroundStyle(Color(Paper.ink))
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color(Paper.ink))
                }
            }
        }
        .environment(\.locale, AppLanguage.locale)
    }
}

private struct StatsCard: View {
    let kind: GameKind
    let stats: GameStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    GameSymbol(kind: kind, size: 17, color: Color(kind.text))
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                    Text(verbatim: kind.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color(kind.text))
                }
                Spacer()
                Text(verbatim: kind.number)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Color(kind.text))
            }

            if !kind.isAvailable {
                Text("준비 중").font(.system(size: 12)).foregroundStyle(Color(kind.text))
            } else if stats.plays == 0 {
                Text("아직 기록이 없어요").font(.system(size: 12)).foregroundStyle(Color(kind.text))
            } else {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        cell("플레이", "\(stats.plays)")
                        cell("완료", "\(stats.completions)")
                    }
                    GridRow {
                        cell("완료율", stats.completionRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        cell("평균 시간", stats.averageSeconds.map(clock) ?? "—")
                    }
                }
                if !stats.difficulties.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(stats.difficulties, id: \.self) { name in
                            HStack {
                                Text(tr(name))
                                Spacer()
                                Text("완료 \(stats.completionsByDifficulty[name] ?? 0)")
                                    .foregroundStyle(Color(kind.text))
                                Text(verbatim: stats.bestByDifficulty[name].map(clock) ?? "—")
                                    .monospacedDigit()
                                    .frame(minWidth: 52, alignment: .trailing)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Color(kind.text))
                            .padding(.vertical, 8)
                            .overlay(alignment: .top) { Rectangle().fill(Color(kind.text).opacity(0.3)).frame(height: 1) }
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(kind.fill), in: RoundedRectangle(cornerRadius: 4))
    }

    private func cell(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).foregroundStyle(Color(kind.text))
            Text(verbatim: value).foregroundStyle(Color(kind.text)).monospacedDigit()
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
