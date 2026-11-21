import SwiftUI

struct RevealablePasswordField: View {
    @Binding var text: String

    let prompt: String
    var focusOnAppear = false
    var onSubmit: (() -> Void)?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField(prompt, text: $text)
                } else {
                    SecureField(prompt, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onSubmit { onSubmit?() }

            Button {
                isRevealed.toggle()
                isFocused = true
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help(isRevealed ? "隐藏密码" : "显示密码")
            .accessibilityLabel(isRevealed ? "隐藏密码" : "显示密码")
        }
        .onAppear {
            if focusOnAppear {
                isFocused = true
            }
        }
    }
}
