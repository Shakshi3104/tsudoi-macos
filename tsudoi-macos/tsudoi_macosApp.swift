//
//  tsudoi_macosApp.swift
//  tsudoi-macos
//

import SwiftUI
import AppKit
import Combine

@main
struct tsudoi_macosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowAccessor { window in
                    appDelegate.attachWindow(window)
                })
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("Tsudoi", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarContent(appDelegate: appDelegate)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private weak var transparentWindow: NSWindow?
    @Published var currentScreenIndex: Int = 0

    func attachWindow(_ window: NSWindow) {
        transparentWindow = window
        configure(window)
        moveToScreen(at: currentScreenIndex)
    }

    private func configure(_ window: NSWindow) {
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    func moveToScreen(at index: Int) {
        let screens = NSScreen.screens
        guard index < screens.count, let window = transparentWindow else { return }
        currentScreenIndex = index
        window.setFrame(screens[index].frame, display: true, animate: false)
    }
}

struct MenuBarContent: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        Text("Display")
            .font(.headline)
        ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
            Button {
                appDelegate.moveToScreen(at: index)
            } label: {
                let label = displayLabel(for: screen, index: index)
                if appDelegate.currentScreenIndex == index {
                    Label(label, systemImage: "checkmark")
                } else {
                    Text(label)
                }
            }
        }
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func displayLabel(for screen: NSScreen, index: Int) -> String {
        let base = screen.localizedName.isEmpty ? "Display \(index + 1)" : screen.localizedName
        return screen == NSScreen.main ? "\(base) (Main)" : base
    }
}

/// Bridges SwiftUI to the underlying NSWindow so we can reconfigure it.
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
