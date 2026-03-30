import SwiftUI

struct NoteToolbarView: View {
    let note: StickyNote
    let proxy: TextEditorProxy
    let audioRecorder: AudioRecorder
    let speechRecognizer: SpeechRecognizer
    let onDelete: () -> Void
    let onAudioSaved: (Data) -> Void
    let onStartDictation: () -> Void
    let onStopDictation: () -> Void
    let onCreateNote: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            FormattingBar(
                onBold: { proxy.toggleBold() },
                onItalic: { proxy.toggleItalic() },
                onUnderline: { proxy.toggleUnderline() },
                onStrikethrough: { proxy.toggleStrikethrough() },
                onBulletList: { proxy.toggleBulletList() },
                onTodoList: { proxy.toggleTodoList() },
                onHiddenText: { proxy.toggleHiddenText() }
            )

            Spacer()

            if audioRecorder.isRecording {
                recordingIndicator
            } else if speechRecognizer.isListening {
                dictationIndicator
            } else {
                audioMenu
            }

            noteMenu
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(note.noteColor.toolbarColor(for: colorScheme))
    }

    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(.red).frame(width: 6, height: 6)
            Text(audioRecorder.recordingDuration.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.red)
            Button {
                if let data = audioRecorder.stopRecording() { onAudioSaved(data) }
            } label: {
                Image(systemName: "stop.circle.fill").font(.system(size: 14)).foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    private var dictationIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.system(size: 11)).foregroundStyle(.blue)
                .symbolEffect(.variableColor.iterative)
            Text("Listening...")
                .font(.system(size: 10)).foregroundStyle(.blue)
            Button { onStopDictation() } label: {
                Image(systemName: "stop.circle.fill").font(.system(size: 14)).foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var audioMenu: some View {
        Menu {
            Button { onStartDictation() } label: {
                Label("Dictate (Speech to Text)", systemImage: "text.bubble")
            }
            Button { audioRecorder.startRecording() } label: {
                Label("Record Audio Clip", systemImage: "waveform.circle")
            }
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel("Audio Input")
        .help("Audio Input")
    }

    private var noteMenu: some View {
        Menu {
            Button { onCreateNote() } label: {
                Label("New Note", systemImage: "plus")
            }
            Divider()
            Section {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    Button {
                        note.setColor(color)
                    } label: {
                        Label {
                            Text(color.displayName)
                        } icon: {
                            Image(systemName: note.noteColor == color ? "checkmark.circle.fill" : "circle.fill")
                                .foregroundStyle(color.background)
                        }
                    }
                }
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete Note", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}
