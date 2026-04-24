//
//  TransparentWindow.swift
//  tsudoi-macos
//

import SwiftUI
import AppKit

/// Hands the underlying NSWindow back to SwiftUI so we can reconfigure it.
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Two canonical window configurations: the standard setup window used for
/// sign-in / code entry, and the transparent click-through projection window.
enum WindowStyle {
    static func applySetup(to window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.level = .normal
        window.ignoresMouseEvents = false
        window.collectionBehavior = []
        window.setContentSize(NSSize(width: 480, height: 320))
        window.center()
        window.title = "Tsudoi"
    }

    static func applyProjection(to window: NSWindow) {
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]
    }
}
