# Sticky Notes for macOS

A native macOS Sticky Notes app built with Swift and SwiftUI, inspired by Microsoft Sticky Notes. Create colorful floating notes, format text with rich styling, and keep them pinned on your desktop.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5-blue?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

## Origin Story

I switched from Windows to Mac and my biggest culture shock wasn't the dock or the keyboard shortcuts — it was realizing macOS doesn't ship with a proper Sticky Notes app. So instead of complaining, I built one. Native SwiftUI, floating notes, rich text, dictation, dark mode — the works.

Need a fix, a new feature, or just a simple sticky note on your Mac? Open an issue, send a PR, or just grab it and use it. It's free and open source.

## Features

- **Floating Notes** — Each note opens as its own borderless floating window, always on top
- **Rich Text Editing** — Bold, italic, underline, strikethrough, and bullet lists
- **7 Color Themes** — Yellow, green, blue, purple, pink, orange, and gray with matching toolbar tints
- **Notes List** — Central window to browse, search, and manage all your notes
- **Window Memory** — Note positions and sizes persist across app restarts
- **Dark Mode** — Full dark mode support with custom color palettes for each note color
- **Image Support** — Paste or drag images directly into notes
- **Auto-Link Detection** — URLs are automatically detected and made clickable
- **Keyboard Shortcuts** — `Cmd+N` new note, `Cmd+B/I/U` formatting, `Cmd+W` close

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

## Getting Started

### Clone and Build

```bash
git clone https://github.com/MartinPirate/sticky-notes-macos.git
cd sticky-notes-macos
```

### Option A: Open in Xcode

```bash
open StickyNotes.xcodeproj
```

Then press `Cmd+R` to build and run.

### Option B: Build from Command Line

```bash
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes -destination 'platform=macOS' build
```

### Regenerating the Xcode Project

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project file generation. If you modify the project structure:

```bash
brew install xcodegen  # if not already installed
xcodegen generate
```

## Architecture

```
StickyNotes/
├── App/
│   └── StickyNotesApp.swift              # Entry point, two WindowGroups
├── Models/
│   ├── StickyNote.swift                  # SwiftData @Model with content, color, position
│   └── NoteColor.swift                   # 7-color enum with light/dark variants
├── Views/
│   ├── NotesList/
│   │   ├── NotesListView.swift           # Main list window with search + note cards
│   │   ├── NoteCardView.swift            # Colored card with title, preview, date
│   │   └── SearchBar.swift               # Filter notes by content
│   ├── NoteWindow/
│   │   ├── NoteWindowView.swift          # Individual floating note window
│   │   ├── NoteToolbarView.swift         # Toolbar with formatting + menu
│   │   ├── NoteTextEditor.swift          # NSViewRepresentable wrapping NSTextView
│   │   ├── FormattingBar.swift           # B / I / U / S / Bullets
│   │   └── ColorPickerMenu.swift         # 7 color circles with selection
│   └── Shared/
│       ├── WindowAccessor.swift          # NSWindow configuration helper
│       └── SettingsView.swift            # Default color + delete confirmation
├── Services/
│   ├── WindowManager.swift              # Multi-window tracking and position persistence
│   └── TextEditorProxy.swift            # Bridges NSTextView formatting to SwiftUI
├── Utilities/
│   ├── ColorExtensions.swift            # Hex color initializers
│   ├── DateFormatting.swift             # Relative date display
│   └── URLDetector.swift                # Auto-linkify URLs in text
└── Resources/
    └── Assets.xcassets/                 # App icon and colors
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI with `NSViewRepresentable` for rich text |
| Data Persistence | SwiftData (`@Model`) |
| Rich Text | `NSTextView` via AppKit bridge |
| Text Storage | `NSAttributedString` archived as `Data` |
| Multi-Window | `WindowGroup(for: UUID.self)` |
| Project Gen | XcodeGen (`project.yml`) |

## Key Design Decisions

**NSTextView over SwiftUI TextEditor** — SwiftUI's `TextEditor` doesn't support attributed strings, inline images, or URL detection. Wrapping `NSTextView` via `NSViewRepresentable` gives full rich text capabilities.

**TextEditorProxy pattern** — SwiftUI's `NSViewRepresentable` coordinator isn't directly accessible from sibling views. A shared `@Observable` proxy holds a weak reference to the `NSTextView`, letting the toolbar trigger formatting commands.

**Dual content storage** — Rich text is stored as archived `NSAttributedString` data for full formatting fidelity. A parallel `plainTextContent` field enables SwiftData search queries, since you can't query inside archived blobs.

**WindowAccessor** — SwiftUI doesn't expose `NSWindow` configuration directly. A hidden `NSViewRepresentable` walks the view hierarchy to find the hosting window and configure titlebar transparency, floating level, and frame persistence.

## Color Palette

| Color | Light Background | Dark Background |
|-------|-----------------|-----------------|
| Yellow | `#FFF9B1` | `#4C4A17` |
| Green | `#C6EFB6` | `#1E3A1E` |
| Blue | `#B8D4E8` | `#1E2D3A` |
| Purple | `#D5C4E0` | `#2D1E3A` |
| Pink | `#F5C4D0` | `#3A1E2D` |
| Orange | `#FDDCB5` | `#3A2D1E` |
| Gray | `#D9D9D9` | `#2D2D2D` |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + N` | Create new note |
| `Cmd + B` | Toggle bold |
| `Cmd + I` | Toggle italic |
| `Cmd + U` | Toggle underline |
| `Cmd + W` | Close current window |

## License

MIT
