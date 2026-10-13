import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    let board = Clipboard()
    private var peekUntil = Date.distantPast
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        panel = NSPanel(
            contentRect: frame(on: NSScreen.main!),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.contentView = NSHostingView(rootView: LineView(board: board))
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        board.start()
        addMenuBarItem()
        board.onHang = { [unowned self] in
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
                move(to: screen)
            }
            peekUntil = Date() + 2.5
            setShown(true)
        }

        // shortcut: polls cursor at 20Hz; event monitors missed moves over other apps
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated { self.mouseMoved() }
        }
    }

    /// Hitting the top edge of any screen reveals the line there; leaving the panel hides it.
    private func mouseMoved() {
        let p = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) && p.y >= $0.frame.maxY - 2 }) {
            move(to: screen)
            setShown(true)
        } else if board.shown && Date() > peekUntil && !panel.frame.insetBy(dx: 0, dy: -NSStatusBar.system.thickness).contains(p) {
            setShown(false)
        }
    }

    /// No Dock icon, so the menu bar item is the only way to quit.
    private func addMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "tshirt", accessibilityDescription: "Saaclipboard")
        let menu = NSMenu()
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Saaclipboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // SMAppService only works when run from a .app bundle
    @objc private func toggleLogin(_ item: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
        item.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func move(to screen: NSScreen) {
        if panel.screen != screen { panel.setFrame(frame(on: screen), display: true) }
    }

    private func setShown(_ show: Bool) {
        guard show != board.shown else { return }
        board.shown = show
        panel.ignoresMouseEvents = !show
    }

    private func frame(on screen: NSScreen) -> NSRect {
        let f = screen.frame
        let height: CGFloat = 160
        return NSRect(x: f.minX, y: f.maxY - NSStatusBar.system.thickness - height, width: f.width, height: height)
    }
}

// One instance at a time (dev and release share the lock); the OS drops it when the process exits.
let lock = open(NSTemporaryDirectory() + "saaclipboard.lock", O_CREAT | O_RDWR, 0o600)
guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { exit(0) }

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
