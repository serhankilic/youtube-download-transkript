import AppKit
import SwiftUI

struct URLTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = FocusableURLTextField(string: text)
        textField.placeholderString = placeholder
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBezeled = true
        textField.isBordered = true
        textField.drawsBackground = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 14, weight: .regular)
        textField.backgroundColor = NSColor(red: 0.125, green: 0.138, blue: 0.170, alpha: 1)
        textField.textColor = NSColor(red: 0.930, green: 0.940, blue: 0.970, alpha: 1)
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(red: 0.520, green: 0.560, blue: 0.640, alpha: 1),
                .font: NSFont.systemFont(ofSize: 14, weight: .regular)
            ]
        )
        textField.lineBreakMode = .byTruncatingMiddle
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textDidChangeFromAction(_:))
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        if textField.currentEditor() == nil, textField.stringValue != text {
            textField.stringValue = text
        }

        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(red: 0.520, green: 0.560, blue: 0.640, alpha: isEnabled ? 1 : 0.55),
                .font: NSFont.systemFont(ofSize: 14, weight: .regular)
            ]
        )
        textField.isEnabled = isEnabled
        textField.backgroundColor = NSColor(red: 0.125, green: 0.138, blue: 0.170, alpha: isEnabled ? 1 : 0.55)
        textField.textColor = isEnabled
            ? NSColor(red: 0.930, green: 0.940, blue: 0.970, alpha: 1)
            : NSColor(red: 0.520, green: 0.560, blue: 0.640, alpha: 1)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textDidChangeFromAction(_ sender: NSTextField) {
            text = sender.stringValue
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
        }
    }
}

private final class FocusableURLTextField: NSTextField {
    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        currentEditor()?.selectedRange = NSRange(location: stringValue.count, length: 0)
        return didBecomeFirstResponder
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
