import AppKit

extension NSAttributedString.Key {
    static let hiddenText = NSAttributedString.Key("com.stickynotes.hiddenText")
}

@Observable
final class TextEditorProxy {
    weak var textView: NSTextView?

    // MARK: - Focus Management

    /// Return the textView's current selection, restoring first-responder so the
    /// caret remains where the user left it. NSTextView preserves its selection
    /// across focus loss (e.g. when a toolbar button briefly takes focus), so we
    /// trust `selectedRange()` directly instead of caching a stale range.
    private func restoreFocusAndRange() -> NSRange? {
        guard let textView else { return nil }
        textView.window?.makeFirstResponder(textView)
        return textView.selectedRange()
    }

    // MARK: - Font Trait Formatting (DRY: single method for B/I)

    func toggleBold() { toggleFontTrait(.boldFontMask, symbolicTrait: .bold) }
    func toggleItalic() { toggleFontTrait(.italicFontMask, symbolicTrait: .italic) }

    private func toggleFontTrait(_ trait: NSFontTraitMask, symbolicTrait: NSFontDescriptor.SymbolicTraits) {
        guard let textView, let storage = textView.textStorage else { return }
        guard let range = restoreFocusAndRange() else { return }

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
            if font.fontDescriptor.symbolicTraits.contains(symbolicTrait) {
                attrs[.font] = NSFontManager.shared.convert(font, toNotHaveTrait: trait)
            } else {
                attrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: trait)
            }
            textView.typingAttributes = attrs
            return
        }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let newFont = font.fontDescriptor.symbolicTraits.contains(symbolicTrait)
                ? NSFontManager.shared.convert(font, toNotHaveTrait: trait)
                : NSFontManager.shared.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
        storage.endEditing()
        textView.setSelectedRange(range)
        notifyChange(textView)
    }

    // MARK: - Attribute Style Formatting (DRY: single method for U/S)

    func toggleUnderline() { toggleAttributeStyle(.underlineStyle) }
    func toggleStrikethrough() { toggleAttributeStyle(.strikethroughStyle) }

    private func toggleAttributeStyle(_ key: NSAttributedString.Key) {
        guard let textView, let storage = textView.textStorage else { return }
        guard let range = restoreFocusAndRange() else { return }

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let current = (attrs[key] as? Int) ?? 0
            attrs[key] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes = attrs
            return
        }

        storage.beginEditing()
        storage.enumerateAttribute(key, in: range) { value, attrRange, _ in
            let current = (value as? Int) ?? 0
            let newValue = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            storage.addAttribute(key, value: newValue, range: attrRange)
        }
        storage.endEditing()
        textView.setSelectedRange(range)
        notifyChange(textView)
    }

    // MARK: - List Formatting (DRY: generic prefix toggle)

    func toggleBulletList() { toggleLinePrefix(prefix: "• ", matchPrefixes: ["• "]) }

    func toggleTodoList() { toggleLinePrefix(prefix: "☐ ", matchPrefixes: ["☐ ", "☑ "]) }

    private func toggleLinePrefix(prefix: String, matchPrefixes: [String]) {
        guard let textView, let range = restoreFocusAndRange() else { return }
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: range)
        let lineText = text.substring(with: lineRange)

        let lines = lineText.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.isEmpty }

        // Cursor on a blank line (or selection of only blank lines): insert the
        // prefix at the caret so the user can start typing a list item.
        if nonEmpty.isEmpty {
            textView.insertText(prefix, replacementRange: NSRange(location: range.location, length: 0))
            notifyChange(textView)
            return
        }

        let allPrefixed = nonEmpty.allSatisfy { line in
            matchPrefixes.contains(where: { line.hasPrefix($0) })
        }

        let newLines = lines.map { line -> String in
            guard !line.isEmpty else { return line }
            if allPrefixed {
                for mp in matchPrefixes where line.hasPrefix(mp) {
                    return String(line.dropFirst(mp.count))
                }
                return line
            } else {
                return matchPrefixes.contains(where: { line.hasPrefix($0) }) ? line : prefix + line
            }
        }

        textView.insertText(newLines.joined(separator: "\n"), replacementRange: lineRange)
        notifyChange(textView)
    }

    // MARK: - Todo Toggle

    func toggleTodoAt(characterIndex: Int) {
        guard let textView else { return }
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: NSRange(location: characterIndex, length: 0))
        let lineText = text.substring(with: lineRange)

        let newLine: String
        if lineText.hasPrefix("☐ ") {
            newLine = "☑ " + String(lineText.dropFirst(2))
        } else if lineText.hasPrefix("☑ ") {
            newLine = "☐ " + String(lineText.dropFirst(2))
        } else {
            return
        }

        textView.insertText(newLine, replacementRange: lineRange)

        let newLineRange = NSRange(location: lineRange.location, length: (newLine as NSString).length)
        if newLine.hasPrefix("☑ ") {
            textView.textStorage?.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: newLineRange)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: newLineRange)
        } else {
            textView.textStorage?.removeAttribute(.strikethroughStyle, range: newLineRange)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: newLineRange)
        }
        notifyChange(textView)
    }

    // MARK: - Hidden/Spoiler Text

    func toggleHiddenText() {
        guard let textView, let storage = textView.textStorage else { return }
        guard let range = restoreFocusAndRange(), range.length > 0 else { return }

        var isHidden = false
        if range.location < storage.length {
            let checkLen = min(1, storage.length - range.location)
            storage.enumerateAttribute(.hiddenText, in: NSRange(location: range.location, length: checkLen)) { value, _, stop in
                if value as? Bool == true { isHidden = true; stop.pointee = true }
            }
        }

        storage.beginEditing()
        if isHidden {
            storage.removeAttribute(.hiddenText, range: range)
            storage.removeAttribute(.backgroundColor, range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        } else {
            let blockColor = NSColor(white: 0.15, alpha: 1.0)
            storage.addAttribute(.hiddenText, value: true, range: range)
            storage.addAttribute(.backgroundColor, value: blockColor, range: range)
            storage.addAttribute(.foregroundColor, value: blockColor, range: range)
        }
        storage.endEditing()
        textView.setSelectedRange(NSRange(location: range.location + range.length, length: 0))
        notifyChange(textView)
    }

    func revealHiddenTextAt(characterIndex: Int) {
        guard let textView, let storage = textView.textStorage else { return }
        guard characterIndex < storage.length else { return }

        // Search a bounded range around the click point, not the entire document
        let searchStart = max(0, characterIndex - 500)
        let searchEnd = min(storage.length, characterIndex + 500)
        let searchRange = NSRange(location: searchStart, length: searchEnd - searchStart)

        var foundRange: NSRange?
        storage.enumerateAttribute(.hiddenText, in: searchRange) { value, attrRange, stop in
            guard value as? Bool == true, NSLocationInRange(characterIndex, attrRange) else { return }
            foundRange = attrRange
            stop.pointee = true
        }

        guard let range = foundRange else { return }
        storage.beginEditing()
        storage.removeAttribute(.hiddenText, range: range)
        storage.removeAttribute(.backgroundColor, range: range)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        storage.endEditing()
        notifyChange(textView)
    }

    // MARK: - Private

    private func notifyChange(_ textView: NSTextView) {
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: textView)
    }
}
