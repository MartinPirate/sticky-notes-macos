import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let noteID: UUID?
    let noteColor: NoteColor
    let onWindowFound: ((NSWindow) -> Void)?
    let onClose: (() -> Void)?
    let windowFrame: NSRect?

    init(
        noteID: UUID? = nil,
        noteColor: NoteColor = .yellow,
        windowFrame: NSRect? = nil,
        onWindowFound: ((NSWindow) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.noteID = noteID
        self.noteColor = noteColor
        self.windowFrame = windowFrame
        self.onWindowFound = onWindowFound
        self.onClose = onClose
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.configureWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.updateWindowAppearance(window, color: noteColor)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSWindowDelegate {
        let parent: WindowAccessor

        init(_ parent: WindowAccessor) {
            self.parent = parent
        }

        func configureWindow(_ window: NSWindow) {
            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 200, height: 150)
            window.backgroundColor = NSColor(parent.noteColor.background)

            if let noteID = parent.noteID {
                window.identifier = NSUserInterfaceItemIdentifier(noteID.uuidString)
            }

            if let frame = parent.windowFrame {
                window.setFrame(frame, display: true)
            }

            window.level = .normal
            parent.onWindowFound?(window)
        }

        func updateWindowAppearance(_ window: NSWindow, color: NoteColor) {
            let isDark = window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let bgColor = isDark ? color.darkBackground : color.background
            window.backgroundColor = NSColor(bgColor)
        }

        func windowWillClose(_ notification: Notification) {
            parent.onClose?()
        }
    }
}
