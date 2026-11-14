import PhotosUI
import SwiftUI

struct SkinPickerView: View {
    let kind: SkinKind
    private let store = SkinStore.shared
    @State private var custom = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoFailed = false
    @State private var loadingPhoto = false

    var body: some View {
        let current = store.skin(kind)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    SkinTile(kind: kind, skin: current, side: 96)
                    Text("고르면 바로 적용돼요")
                        .font(.caption)
                        .foregroundStyle(Color(Palette.inkSoft))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                label("기본 모양과 이모지")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 10)], spacing: 10) {
                    choice(.classic, current: current)
                    ForEach(kind.emojiChoices, id: \.self) { choice(.emoji($0), current: current) }
                }

                label("이모지 직접 입력").padding(.top, 6)
                HStack(spacing: 8) {
                    TextField("예: 🐸", text: $custom)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(applyCustom)
                    Button("적용", action: applyCustom)
                        .buttonStyle(FieldButtonStyle(prominent: true))
                        .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                label("내 사진").padding(.top, 6)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(loadingPhoto ? LocalizedStringKey("불러오는 중…") : LocalizedStringKey("사진에서 고르기"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FieldButtonStyle())
                Text(photoFailed ? LocalizedStringKey("이 사진은 불러올 수 없어요. 다른 사진을 골라 주세요.") : LocalizedStringKey("사진의 가운데를 정사각형으로 잘라서 칸 안에 넣어요."))
                    .font(.caption)
                    .foregroundStyle(Color(photoFailed ? Palette.flag : Palette.inkSoft))
            }
            .padding(20)
        }
        .background(Color(Palette.panel))
        .foregroundStyle(Color(Palette.ink))
        .navigationTitle(kind == .flag ? LocalizedStringKey("깃발 모양") : LocalizedStringKey("지뢰 모양"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            loadingPhoto = true
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                photoFailed = !(data.map { store.setPhoto($0, for: kind) } ?? false)
                loadingPhoto = false
                photoItem = nil
            }
        }
    }

    private func applyCustom() {
        guard let first = custom.trimmingCharacters(in: .whitespaces).first else { return }
        store.set(.emoji(String(first)), for: kind)
        custom = ""
    }

    private func choice(_ skin: Skin, current: Skin) -> some View {
        Button { store.set(skin, for: kind) } label: {
            SkinTile(kind: kind, skin: skin, side: 52)
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(Palette.moss), lineWidth: skin == current ? 2.5 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    if skin == current {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(Palette.moss), Color(Palette.panel))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr(skin.label))
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(Color(Palette.inkSoft))
    }
}
