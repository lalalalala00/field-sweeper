import SwiftUI

struct SettingsView: View {
    let current: BoardConfig
    let device: DeviceClass
    let onStart: (BoardConfig) -> Void

    @State private var cols: Double
    @State private var rows: Double
    @State private var mines: Double
    @AppStorage("showTimer") private var showTimer = true
    @Environment(\.dismiss) private var dismiss

    init(current: BoardConfig, device: DeviceClass, onStart: @escaping (BoardConfig) -> Void) {
        self.current = current
        self.device = device
        self.onStart = onStart
        let c = Persist.customConfig ?? current
        _cols = State(initialValue: Double(min(max(c.cols, 5), device.limits.cols)))
        _rows = State(initialValue: Double(min(max(c.rows, 5), device.limits.rows)))
        _mines = State(initialValue: Double(max(c.mines, 1)))
    }

    static let privacyURL = URL(string: "https://lalalalala00.github.io/field-sweeper/privacy.html")!
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    private var maxMines: Int { max(1, Int(Double(Int(cols) * Int(rows)) * 0.4)) }
    private var density: Double { mines / (cols * rows) * 100 }
    private var feel: LocalizedStringKey {
        switch density {
        case ..<15: "쉬움"
        case ..<20: "보통"
        case ..<24: "어려움"
        default: "극악"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("기본 난이도")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                        ForEach(device.presets) { preset in
                            PresetCard(preset: preset,
                                       isCurrent: preset.id == current.id,
                                       best: RecordStore.best(for: preset.recordKey)) { onStart(preset) }
                        }
                    }

                    sectionLabel("커스텀").padding(.top, 6)
                    VStack(spacing: 12) {
                        sliderRow("가로", value: $cols, range: 5...Double(device.limits.cols))
                        sliderRow("세로", value: $rows, range: 5...Double(device.limits.rows))
                        sliderRow("지뢰", value: $mines, range: 1...Double(maxMines))
                        HStack {
                            Text("지뢰 밀도 ") + Text(String(format: "%.1f%%", density)).bold()
                            Spacer()
                            Text(feel)
                        }
                        .font(.footnote)
                        .foregroundStyle(Color(Palette.inkSoft))
                        Button {
                            let config = BoardConfig.custom(cols: Int(cols), rows: Int(rows), mines: Int(mines))
                            Persist.customConfig = config
                            onStart(config)
                        } label: {
                            Text("커스텀으로 시작").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(FieldButtonStyle(prominent: true))
                    }
                    .padding(14)
                    .background(Color(Palette.bg), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(Palette.line)))

                    sectionLabel("모양").padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(SkinKind.allCases) { kind in
                            NavigationLink { SkinPickerView(kind: kind) } label: { skinRow(kind) }
                                .buttonStyle(.plain)
                            if kind == .flag { Divider().padding(.leading, 64) }
                        }
                    }
                    .background(Color(Palette.bg), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(Palette.line)))

                    sectionLabel("필드 색").padding(.top, 6)
                    FieldColorSection()

                    sectionLabel("옵션").padding(.top, 6)
                    Toggle(isOn: $showTimer) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("시간 표시").font(.subheadline.weight(.medium))
                            Text("끄면 시간 없이 느긋하게 플레이해요")
                                .font(.caption)
                                .foregroundStyle(Color(Palette.inkSoft))
                        }
                    }
                    .tint(Color(Palette.moss))
                    .padding(14)
                    .background(Color(Palette.bg), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(Palette.line)))

                    sectionLabel("정보").padding(.top, 6)
                    VStack(spacing: 0) {
                        Link(destination: Self.privacyURL) {
                            HStack {
                                Text("개인정보 처리방침")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(Palette.inkSoft))
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
                            Text(Self.appVersion).foregroundStyle(Color(Palette.inkSoft))
                        }
                        .font(.subheadline)
                        .padding(14)
                    }
                    .background(Color(Palette.bg), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(Palette.line)))
                }
                .padding(20)
            }
            .background(Color(Palette.panel))
            .foregroundStyle(Color(Palette.ink))
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(tr(device.label))
                        .font(.caption)
                        .foregroundStyle(Color(Palette.inkSoft))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color(Palette.moss))
                }
            }
        }
        .onAppear(perform: clampMines)
        .onChange(of: cols) { clampMines() }
        .onChange(of: rows) { clampMines() }
    }

    private func clampMines() {
        if mines > Double(maxMines) { mines = Double(maxMines) }
    }

    private func skinRow(_ kind: SkinKind) -> some View {
        let skin = SkinStore.shared.skin(kind)
        return HStack(spacing: 12) {
            SkinTile(kind: kind, skin: skin, side: 40)
            Text(tr(kind.title)).font(.subheadline.weight(.medium))
            Spacer()
            Text(tr(skin.label)).font(.subheadline).foregroundStyle(Color(Palette.inkSoft))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(Palette.inkSoft))
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(Color(Palette.inkSoft))
    }

    private func sliderRow(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(width: 34, alignment: .leading)
            Slider(value: value, in: range, step: 1)
                .tint(Color(Palette.moss))
            Text("\(Int(value.wrappedValue))")
                .font(.system(.body, design: .monospaced))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct FieldColorSection: View {
    private let store = SkinStore.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let current = store.field
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 10)], spacing: 10) {
                ForEach(FieldPreset.all) { preset in
                    Button { store.setField(.preset(preset.id)) } label: {
                        VStack(spacing: 4) {
                            Swatch(palette: preset.palette)
                            Text(tr(preset.name)).font(.caption)
                        }
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(Palette.moss), lineWidth: current == .preset(preset.id) ? 2.5 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(current == .preset(preset.id) ? .isSelected : [])
                }
            }
            Divider()
            HStack(spacing: 6) {
                Text("직접 고르기").font(.subheadline.weight(.medium))
                if case .custom = current {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(Palette.moss))
                }
            }
            ColorPicker("덮인 칸", selection: color(turf: true), supportsOpacity: false)
                .font(.subheadline)
            ColorPicker("열린 칸", selection: color(turf: false), supportsOpacity: false)
                .font(.subheadline)
        }
        .padding(14)
        .background(Color(Palette.bg), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(Palette.line)))
    }

    /// 한쪽 색만 고르면 다른 쪽은 지금 보이는 색을 그대로 쓴다.
    private func color(turf: Bool) -> Binding<Color> {
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        return Binding(
            get: { Color((turf ? Palette.turf : Palette.ground).resolvedColor(with: traits)) },
            set: { picked in
                var t = Palette.turf.resolvedColor(with: traits).hex
                var g = Palette.ground.resolvedColor(with: traits).hex
                if turf { t = UIColor(picked).hex } else { g = UIColor(picked).hex }
                store.setField(.custom(turf: t, ground: g))
            }
        )
    }
}

private struct Swatch: View {
    let palette: FieldPalette

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 5).fill(Color(palette.turf))
            RoundedRectangle(cornerRadius: 5).fill(Color(palette.ground))
        }
        .padding(4)
        .frame(width: 58, height: 34)
        .background(Color(palette.board), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct PresetCard: View {
    let preset: BoardConfig
    let isCurrent: Bool
    let best: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tr(preset.name))
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Text("\(preset.cols) × \(preset.rows) · 지뢰 \(preset.mines)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color(Palette.inkSoft))
                (best.map { Text("최고 \(clock($0))") } ?? Text("기록 없음"))
                    .font(.caption)
                    .foregroundStyle(Color(Palette.inkSoft))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(Palette.bg), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(isCurrent ? Palette.moss : Palette.line), lineWidth: isCurrent ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
