import SwiftUI

struct FormattingBar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onStrikethrough: () -> Void
    let onBulletList: () -> Void
    let onTodoList: () -> Void
    let onHiddenText: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            formatButton(icon: "bold", label: "Bold", tooltip: "Bold (⌘B)", action: onBold)
            formatButton(icon: "italic", label: "Italic", tooltip: "Italic (⌘I)", action: onItalic)
            formatButton(icon: "underline", label: "Underline", tooltip: "Underline (⌘U)", action: onUnderline)
            formatButton(icon: "strikethrough", label: "Strikethrough", tooltip: "Strikethrough", action: onStrikethrough)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 3)

            formatButton(icon: "list.bullet", label: "Bullet List", tooltip: "Bullet List", action: onBulletList)
            formatButton(icon: "checkmark.square", label: "Todo List", tooltip: "Todo List", action: onTodoList)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 3)

            formatButton(icon: "eye.slash", label: "Hide Text", tooltip: "Hide/Reveal Text", action: onHiddenText)
        }
    }

    private func formatButton(icon: String, label: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(tooltip)
    }
}
