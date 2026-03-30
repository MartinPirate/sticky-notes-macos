import SwiftUI

struct NoteTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var plainText: String
    let backgroundColor: NSColor
    let proxy: TextEditorProxy
    let onTextChange: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = ClickableTextView()
        textView.proxy = proxy
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticDataDetectionEnabled = true
        textView.allowsImageEditing = true
        textView.importsGraphics = true
        textView.drawsBackground = true
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.font = NSFont.systemFont(ofSize: 14)
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]

        if !attributedText.string.isEmpty {
            textView.textStorage?.setAttributedString(attributedText)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        proxy.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.backgroundColor = backgroundColor

        if proxy.textView !== textView {
            proxy.textView = textView
        }

        if context.coordinator.isUpdatingFromUI { return }

        let currentText = textView.attributedString()
        if currentText.string != attributedText.string {
            let selectedRanges = textView.selectedRanges
            textView.textStorage?.setAttributedString(attributedText)
            textView.selectedRanges = selectedRanges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: NoteTextEditor
        weak var textView: NSTextView?
        var isUpdatingFromUI = false

        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdatingFromUI = true
            parent.attributedText = textView.attributedString()
            parent.plainText = textView.string
            parent.onTextChange()
            isUpdatingFromUI = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.proxy.updateSelection(textView.selectedRange())
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            if let urlString = link as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}

// MARK: - Custom NSTextView for click handling

final class ClickableTextView: NSTextView {
    var proxy: TextEditorProxy?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)

        if charIndex < string.count {
            let text = string as NSString
            let clickRange = NSRange(location: charIndex, length: 0)
            let lineRange = text.lineRange(for: clickRange)
            let lineText = text.substring(with: lineRange)

            // Handle todo checkbox clicks (click near beginning of line)
            if lineText.hasPrefix("☐ ") || lineText.hasPrefix("☑ ") {
                let lineStartPoint = layoutManager!.boundingRect(
                    forGlyphRange: NSRange(location: lineRange.location, length: 1),
                    in: textContainer!
                )
                let relativeX = point.x - textContainerOrigin.x - lineStartPoint.origin.x
                if relativeX < 20 {
                    proxy?.toggleTodoAt(characterIndex: charIndex)
                    return
                }
            }

            // Handle hidden text reveal
            if let storage = textStorage {
                var isHidden = false
                let attrRange = NSRange(location: charIndex, length: 1)
                if attrRange.location + attrRange.length <= storage.length {
                    storage.enumerateAttribute(.hiddenText, in: attrRange) { value, _, _ in
                        if value as? Bool == true {
                            isHidden = true
                        }
                    }
                }
                if isHidden {
                    proxy?.revealHiddenTextAt(characterIndex: charIndex)
                    return
                }
            }
        }

        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        let text = string as NSString
        let cursorLocation = selectedRange().location
        let lineRange = text.lineRange(for: NSRange(location: cursorLocation, length: 0))
        let lineText = text.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if lineText.hasPrefix("☐ ") || lineText.hasPrefix("☑ ") {
            let content = String(lineText.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                insertText("", replacementRange: lineRange)
                resetTypingAttributesToDefault()
                return
            }
            super.insertNewline(sender)
            insertText("☐ ", replacementRange: selectedRange())
        } else if lineText.hasPrefix("• ") {
            let content = String(lineText.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                insertText("", replacementRange: lineRange)
                resetTypingAttributesToDefault()
                return
            }
            super.insertNewline(sender)
            insertText("• ", replacementRange: selectedRange())
        } else if lineText.isEmpty {
            // Double-enter: previous line was already empty — clear all formatting
            super.insertNewline(sender)
            resetTypingAttributesToDefault()
        } else {
            super.insertNewline(sender)
        }
    }

    private func resetTypingAttributesToDefault() {
        typingAttributes = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]
    }
}
