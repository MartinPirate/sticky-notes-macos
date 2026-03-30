import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Keep app alive when the notes list window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Always re-open the notes list when clicking the dock icon
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Always show the list window — floating note windows don't count as "the main window"
        for window in sender.windows where window.title == "Sticky Notes" {
            window.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }
}

@main
struct StickyNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var windowManager = WindowManager()
    @State private var activeWindowTracker = ActiveWindowTracker()
    @Environment(\.openWindow) private var openWindow

    let sharedContainer: ModelContainer = {
        let schema = Schema([StickyNote.self])
        // Use the sandboxed container path so we keep existing notes data
        let containerStore = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.shenanigans.sticky-notes/Data/Library/Application Support/default.store")
        let storeURL: URL
        if FileManager.default.fileExists(atPath: containerStore.path) {
            storeURL = containerStore
        } else {
            storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
        }
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            NSLog("ModelContainer failed, resetting store: \(error)")
            let storeURL = config.url
            for ext in ["", ".wal", ".shm"] {
                let url = ext.isEmpty ? storeURL : storeURL.appendingPathExtension(ext)
                try? FileManager.default.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup("Sticky Notes") {
            NotesListView()
                .environment(windowManager)
                .environment(activeWindowTracker)
                .onAppear { activeWindowTracker.start() }
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 320, height: 500)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    let context = sharedContainer.mainContext
                    let color = NoteColor.allCases.randomElement() ?? .yellow
                    let note = StickyNote(color: color)
                    context.insert(note)
                    try? context.save()
                    openWindow(value: note.id)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Format") {
                Button("Bold") {
                    NotificationCenter.default.post(name: .formatBold, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    NotificationCenter.default.post(name: .formatItalic, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Underline") {
                    NotificationCenter.default.post(name: .formatUnderline, object: nil)
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }

        WindowGroup("Note", for: UUID.self) { $noteID in
            if let noteID {
                NoteWindowView(noteID: noteID)
                    .environment(windowManager)
            }
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 300, height: 350)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatUnderline = Notification.Name("formatUnderline")
}
