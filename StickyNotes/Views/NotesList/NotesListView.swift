import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(WindowManager.self) private var windowManager
    @Environment(ActiveWindowTracker.self) private var activeWindowTracker
    @Query(sort: \StickyNote.modifiedAt, order: .reverse) private var notes: [StickyNote]
    @State private var searchText = ""
    @State private var noteToDelete: StickyNote?
    @State private var showDeleteConfirmation = false
    @State private var isCollapsed = false
    @AppStorage("confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage("followActiveApp") private var followActiveApp = true

    private var filteredNotes: [StickyNote] {
        if searchText.isEmpty { return notes }
        let query = searchText.lowercased()
        return notes.filter { $0.plainTextContent.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            SearchBar(text: $searchText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if filteredNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 400)
        .background(Color(.windowBackgroundColor))
        .onChange(of: followActiveApp) { _, newValue in
            activeWindowTracker.isEnabled = newValue
        }
        .onAppear {
            activeWindowTracker.isEnabled = followActiveApp
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { noteToDelete = nil }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete { deleteNote(note) }
                noteToDelete = nil
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }

    private var header: some View {
        HStack {
            Text("Sticky Notes")
                .font(.system(size: 18, weight: .bold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
            } label: {
                Image(systemName: isCollapsed ? "list.bullet" : "rectangle.grid.1x2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expanded View" : "Compact View")

            Button { createNote() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .help("New Note (⌘N)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No notes yet" : "No matching notes")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if searchText.isEmpty {
                Text("Click + to create a new note")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: isCollapsed ? 4 : 8) {
                ForEach(filteredNotes) { note in
                    NoteCardView(
                        note: note,
                        isCollapsed: isCollapsed,
                        onOpen: { openNote(note) },
                        onDelete: { requestDelete(note) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func createNote() {
        let color = NoteColor.allCases.randomElement() ?? .yellow
        let note = StickyNote(color: color)
        modelContext.insert(note)
        try? modelContext.save()
        openNote(note)
    }

    private func openNote(_ note: StickyNote) {
        if windowManager.isOpen(note.id) {
            windowManager.bringToFront(note.id)
        } else {
            note.isOpen = true
            windowManager.markOpened(note.id)
            openWindow(value: note.id)
        }
    }

    private func requestDelete(_ note: StickyNote) {
        if confirmBeforeDelete {
            noteToDelete = note
            showDeleteConfirmation = true
        } else {
            deleteNote(note)
        }
    }

    private func deleteNote(_ note: StickyNote) {
        windowManager.closeWindow(for: note.id)
        modelContext.delete(note)
        try? modelContext.save()
    }
}
