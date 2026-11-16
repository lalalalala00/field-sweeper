import SwiftUI
import UIKit

/// 판 위에 깔아 Apple Pencil 손글씨(Scribble)로 칸에 숫자를 쓰게 한다.
/// 탭은 칸 선택으로 넘긴다. Scribble을 지원하지 않는 기기에서는 탭만 동작한다.
struct ScribbleGridInput: UIViewRepresentable {
    /// 칸 수(가로 = 세로).
    let size: Int
    /// 칸 크기 대비 칸 사이 틈의 비율. 스도쿠는 0, 후토시키는 부등호 자리만큼.
    var gapRatio: CGFloat = 0
    var isEnabled: Bool = true
    /// 펜슬 손글씨를 받을지. 끄면 탭만 동작한다.
    var handwriting: Bool = true
    /// 손가락이나 펜슬로 칸을 탭했을 때.
    let onTap: (Int) -> Void
    /// 펜슬로 칸에 쓰기 시작했을 때. 그 칸을 선택해 강조가 따라오게 한다.
    let onFocus: (Int) -> Void
    /// 쓴 숫자를 알아봤을 때 (칸, 숫자).
    let onWrite: (Int, Int) -> Void

    func makeUIView(context: Context) -> ScribbleGridView {
        let view = ScribbleGridView()
        update(view)
        return view
    }

    func updateUIView(_ view: ScribbleGridView, context: Context) {
        update(view)
    }

    private func update(_ view: ScribbleGridView) {
        view.size = size
        view.gapRatio = gapRatio
        view.isEnabled = isEnabled
        view.handwriting = handwriting
        view.onTap = onTap
        view.onFocus = onFocus
        view.onWrite = onWrite
    }
}

final class ScribbleGridView: UIView, UIIndirectScribbleInteractionDelegate, UITextFieldDelegate {
    typealias ElementIdentifier = Int

    var size = 9
    var gapRatio: CGFloat = 0
    var isEnabled = true
    var handwriting = true
    var onTap: (Int) -> Void = { _ in }
    var onFocus: (Int) -> Void = { _ in }
    var onWrite: (Int, Int) -> Void = { _, _ in }

    /// Scribble이 글자를 넣을 보이지 않는 입력칸.
    private let field = UITextField()
    private var writingCell: Int?
    /// 펜슬로 쓰기 시작했을 때만 입력칸이 포커스를 받게 한다(손가락 탭으로는 키보드·커서가 뜨지 않게).
    private var allowFocus = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false

        field.borderStyle = .none
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.keyboardType = .numberPad
        // 화면 키보드는 띄우지 않는다. 하드웨어 키보드로 숫자를 쳐도 같은 칸에 들어간다.
        field.inputView = UIView(frame: .zero)
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        field.delegate = self
        // 글자가 대리자를 거치지 않고 들어오는 경우에도 받는다.
        field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        addSubview(field)

        addInteraction(UIIndirectScribbleInteraction(delegate: self))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: 칸 위치

    private var cell: CGFloat {
        let side = min(bounds.width, bounds.height)
        return side / (CGFloat(size) + CGFloat(size - 1) * gapRatio)
    }

    private func frame(of index: Int) -> CGRect {
        let step = cell * (1 + gapRatio)
        return CGRect(x: CGFloat(index % size) * step, y: CGFloat(index / size) * step, width: cell, height: cell)
    }

    private func index(at point: CGPoint) -> Int? {
        let step = cell * (1 + gapRatio)
        guard step > 0 else { return nil }
        // 틈을 누르면 가까운 칸으로 본다.
        let c = Int((point.x + cell * gapRatio / 2) / step)
        let r = Int((point.y + cell * gapRatio / 2) / step)
        guard (0..<size).contains(c), (0..<size).contains(r) else { return nil }
        return r * size + c
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        guard isEnabled, let i = index(at: g.location(in: self)) else { return }
        onTap(i)
    }

    // MARK: 손글씨

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool { allowFocus }

    @objc private func textChanged() {
        guard let text = field.text, !text.isEmpty else { return }
        field.text = ""
        deliver(text)
    }

    private func deliver(_ text: String) {
        // 쓴 글자 중 첫 숫자만 쓴다(0과 판 크기를 넘는 숫자는 무시).
        guard isEnabled, let i = writingCell,
              let digit = text.compactMap({ $0.wholeNumberValue }).first(where: { (1...size).contains($0) }) else { return }
        onWrite(i, digit)
    }

    /// Scribble이 알아본 글자가 들어오려는 순간 가로채서 숫자로 넘긴다. 입력칸에는 아무것도 남기지 않는다.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        deliver(string)
        return false
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, requestElementsIn rect: CGRect,
                                     completion: @escaping ([Int]) -> Void) {
        guard isEnabled, handwriting else { return completion([]) }
        completion((0..<(size * size)).filter { frame(of: $0).intersects(rect) })
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, shouldDelayFocusForElement elementIdentifier: Int) -> Bool {
        false
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, isElementFocused elementIdentifier: Int) -> Bool {
        field.isFirstResponder && writingCell == elementIdentifier
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, frameForElement elementIdentifier: Int) -> CGRect {
        frame(of: elementIdentifier)
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, focusElementIfNeeded elementIdentifier: Int,
                                     referencePoint focusReferencePoint: CGPoint,
                                     completion: @escaping ((UIResponder & UITextInput)?) -> Void) {
        guard isEnabled, handwriting else { return completion(nil) }
        writingCell = elementIdentifier
        field.frame = frame(of: elementIdentifier)
        field.text = ""
        allowFocus = true
        if !field.isFirstResponder { field.becomeFirstResponder() }
        allowFocus = false
        onFocus(elementIdentifier)
        completion(field)
    }

    func indirectScribbleInteraction(_ interaction: UIInteraction, didFinishWritingInElement elementIdentifier: Int) {
        // 다 쓰고 나면 입력칸을 놓아 준다. 인식 결과가 늦게 들어올 수 있어 넉넉히 기다린다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.writingCell == elementIdentifier else { return }
            self.field.resignFirstResponder()
            self.writingCell = nil
        }
    }
}
