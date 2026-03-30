import AppKit

@MainActor
@Observable
final class ActiveWindowTracker {
    var isEnabled = true

    private var observer: NSObjectProtocol?
    private let bundleID = Bundle.main.bundleIdentifier ?? ""

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            Task { @MainActor in
                if app.bundleIdentifier == self.bundleID {
                    self.bringNotesToFront()
                } else if self.isEnabled {
                    self.repositionNotes(below: app)
                }
            }
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private var noteWindows: [NSWindow] {
        NSApplication.shared.windows.filter {
            guard let id = $0.identifier?.rawValue, !id.isEmpty,
                  UUID(uuidString: id) != nil,
                  $0.isVisible else { return false }
            return true
        }
    }

    private func bringNotesToFront() {
        for window in noteWindows {
            window.orderFront(nil)
        }
    }

    private func repositionNotes(below app: NSRunningApplication) {
        guard let frame = frontWindowFrame(for: app) else { return }

        let windows = noteWindows
        guard !windows.isEmpty else { return }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 8
        let targetTop = frame.origin.y - gap

        var xCursor = frame.origin.x

        for window in windows {
            let noteSize = window.frame.size
            let newY = targetTop - noteSize.height

            if xCursor + noteSize.width > frame.origin.x + frame.width + gap && xCursor != frame.origin.x {
                xCursor = frame.origin.x
            }

            let clampedX = min(max(xCursor, screen.origin.x), screen.origin.x + screen.width - noteSize.width)
            let clampedY = min(max(newY, screen.origin.y), screen.origin.y + screen.height - noteSize.height)

            window.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))

            xCursor += noteSize.width + gap
        }
    }

    private func frontWindowFrame(for app: NSRunningApplication) -> NSRect? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let axWindow = windowRef {
            return frameOf(axWindow as! AXUIElement)
        }

        var windowListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowListRef) == .success,
              let windows = windowListRef as? [AXUIElement],
              let first = windows.first else {
            return nil
        }
        return frameOf(first)
    }

    private func frameOf(_ axWindow: AXUIElement) -> NSRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        let screenHeight = NSScreen.main?.frame.height ?? 900
        let appKitY = screenHeight - position.y - size.height

        return NSRect(x: position.x, y: appKitY, width: size.width, height: size.height)
    }
}
