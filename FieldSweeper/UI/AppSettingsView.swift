import SwiftUI

/// 모든 게임에 함께 적용되는 설정. 게임마다 다른 설정(보드 크기, 모양 등)은 각 게임 안에 있다.
struct AppSettingsView: View {
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.dismiss) private var dismiss

    static let privacyURL = URL(string: "https://lalalalala00.github.io/field-sweeper/privacy.html")!
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("옵션")
                    VStack(spacing: 12) {
                        Toggle(isOn: $showTimer) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("시간 표시").font(.subheadline.weight(.medium))
                                Text("끄면 시간 없이 느긋하게 플레이해요")
                                    .font(.caption)
                                    .foregroundStyle(Color(Paper.inkSoft))
                            }
                        }
                        Divider()
                        HStack {
                            Text("언어").font(.subheadline.weight(.medium))
                            Spacer()
                            Picker("언어", selection: $language) {
                                Text("기기 설정").tag("system")
                                ForEach(AppLanguage.options, id: \.code) { option in
                                    Text(verbatim: option.name).tag(option.code)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Color(Paper.ink))
                        }
                        Divider()
                        HStack {
                            Text("화면").font(.subheadline.weight(.medium))
                            Spacer()
                            Picker("화면", selection: $appearance) {
                                Text("기기 설정").tag("system")
                                Text("라이트").tag("light")
                                Text("다크").tag("dark")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Color(Paper.ink))
                        }
                    }
                    .tint(Color(GameKind.minesweeper.fill))
                    .padding(14)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(Paper.rule)))

                    sectionLabel("정보").padding(.top, 6)
                    VStack(spacing: 0) {
                        Link(destination: Self.privacyURL) {
                            HStack {
                                Text("개인정보 처리방침")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(Paper.inkSoft))
                            }
                            .font(.subheadline)
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 14)
                        HStack {
                            Text("버전")
                            Spacer()
                            Text(verbatim: Self.appVersion).foregroundStyle(Color(Paper.inkSoft))
                        }
                        .font(.subheadline)
                        .padding(14)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(Paper.rule)))
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .id(language)
            }
            .background(Color(Paper.bg))
            .foregroundStyle(Color(Paper.ink))
            .navigationTitle("설정")
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

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(Color(Paper.inkSoft))
    }
}
