import SwiftUI
import SwiftData

struct NoteWindowView: View {
    let noteID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @Environment(WindowManager.self) private var windowManager
    @State private var note: StickyNote?
    @State private var attributedText = NSAttributedString()
    @State private var plainText = ""
    @State private var editorProxy = TextEditorProxy()
    @State private var audioRecorder = AudioRecorder()
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var showDeleteConfirmation = false
    @State private var dictationAnchor: Int?
    @State private var dictationLength: Int = 0
    @AppStorage("confirmBeforeDelete") private var confirmBeforeDelete = true

    var body: some View {
        Group {
            if let note {
                VStack(spacing: 0) {
                    NoteToolbarView(
                        note: note,
                        proxy: editorProxy,
                        audioRecorder: audioRecorder,
                        speechRecognizer: speechRecognizer,
                        onDelete: { requestDelete() },
                        onAudioSaved: { data in
                            note.addAudioRecording(data)
                            try? modelContext.save()
                        },
                        onStartDictation: { startLiveDictation() },
                        onStopDictation: { stopLiveDictation() },
                        onCreateNote: { createNote() }
                    )

                    NoteTextEditor(
                        attributedText: $attributedText,
                        plainText: $plainText,
                        backgroundColor: NSColor(note.noteColor.backgroundColor(for: colorScheme)),
                        proxy: editorProxy,
                        onTextChange: { saveContent() }
                    )

                    AudioClipView(
                        recordings: note.audioRecordings,
                        audioRecorder: audioRecorder,
                        onDelete: { index in
                            note.removeAudioRecording(at: index)
                            try? modelContext.save()
                        }
                    )
                }
                .background(
                    WindowAccessor(
                        noteID: noteID,
                        noteColor: note.noteColor,
                        windowFrame: NSRect(
                            x: note.windowX, y: note.windowY,
                            width: note.windowWidth, height: note.windowHeight
                        ),
                        onWindowFound: { observeWindowChanges($0) },
                        onClose: {
                            audioRecorder.stopPlayback()
                            speechRecognizer.stopListening()
                            windowManager.markClosed(noteID)
                            note.isOpen = false
                            saveWindowPosition()
                        }
                    )
                )
            } else {
                Text("Note not found")
                    .frame(width: 300, height: 200)
            }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteNote() }
        } message: {
            Text("This note will be permanently deleted.")
        }
        .onAppear { loadNote() }
    }

    // MARK: - Data

    private func loadNote() {
        let id = noteID
        let descriptor = FetchDescriptor<StickyNote>(
            predicate: #Predicate { $0.id == id }
        )
        guard let found = try? modelContext.fetch(descriptor).first else { return }
        self.note = found

        if let data = found.attributedContentData {
            let classes = [NSAttributedString.self, NSFont.self, NSColor.self,
                          NSParagraphStyle.self, NSShadow.self, NSTextAttachment.self]
            if let restored = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? NSAttributedString {
                self.attributedText = restored
            }
        }
        self.plainText = found.plainTextContent
        windowManager.markOpened(noteID)
    }

    private func saveContent() {
        guard let note else { return }
        note.plainTextContent = plainText
        note.attributedContentData = try? NSKeyedArchiver.archivedData(
            withRootObject: attributedText,
            requiringSecureCoding: true
        )
        note.modifiedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Window Position

    private func saveWindowPosition() {
        guard let note else { return }
        if let frame = windowManager.windowFrame(for: noteID) {
            note.windowX = Double(frame.origin.x)
            note.windowY = Double(frame.origin.y)
            note.windowWidth = Double(frame.size.width)
            note.windowHeight = Double(frame.size.height)
        }
        try? modelContext.save()
    }

    private func observeWindowChanges(_ window: NSWindow) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: window, queue: .main
        ) { _ in saveWindowPositionFromWindow(window) }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: window, queue: .main
        ) { _ in saveWindowPositionFromWindow(window) }
    }

    private func saveWindowPositionFromWindow(_ window: NSWindow) {
        guard let note else { return }
        let frame = window.frame
        note.windowX = Double(frame.origin.x)
        note.windowY = Double(frame.origin.y)
        note.windowWidth = Double(frame.size.width)
        note.windowHeight = Double(frame.size.height)
    }

    // MARK: - Dictation

    private func startLiveDictation() {
        guard let textView = editorProxy.textView else { return }
        let cursor = textView.selectedRange()
        var anchor = cursor.location

        if anchor > 0 {
            let prevChar = (textView.string as NSString).substring(with: NSRange(location: anchor - 1, length: 1))
            if prevChar != " " && prevChar != "\n" {
                textView.insertText(" ", replacementRange: NSRange(location: anchor, length: 0))
                anchor += 1
            }
        }

        dictationAnchor = anchor
        dictationLength = 0

        speechRecognizer.onPartialResult = { [self] partialText in
            guard let textView = editorProxy.textView,
                  let anchor = dictationAnchor else { return }
            let replaceRange = NSRange(location: anchor, length: dictationLength)
            textView.insertText(partialText, replacementRange: replaceRange)
            dictationLength = (partialText as NSString).length
            textView.setSelectedRange(NSRange(location: anchor + dictationLength, length: 0))
        }

        speechRecognizer.requestAuthorization { authorized in
            if authorized { speechRecognizer.startListening() }
        }
    }

    private func stopLiveDictation() {
        speechRecognizer.onPartialResult = nil
        speechRecognizer.stopListening()
        dictationAnchor = nil
        dictationLength = 0
        saveContent()
    }

    // MARK: - Create

    private func createNote() {
        let color = NoteColor.allCases.randomElement() ?? .yellow
        let newNote = StickyNote(color: color)
        modelContext.insert(newNote)
        try? modelContext.save()
        openWindow(value: newNote.id)
    }

    // MARK: - Delete

    private func requestDelete() {
        if confirmBeforeDelete {
            showDeleteConfirmation = true
        } else {
            deleteNote()
        }
    }

    private func deleteNote() {
        guard let note else { return }
        audioRecorder.stopPlayback()
        speechRecognizer.stopListening()
        windowManager.closeWindow(for: noteID)
        modelContext.delete(note)
        try? modelContext.save()
    }
}
