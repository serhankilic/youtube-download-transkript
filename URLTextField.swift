import SwiftUI

struct URLTextField: View {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(isEnabled ? DS.Color.fg1 : DS.Color.fg3)
            .disabled(!isEnabled)
    }
}
