//
//  MenuBarContent.swift
//  tsudoi-macos
//

import SwiftUI
import AppKit

struct MenuBarContent: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        if appDelegate.isProjecting {
            Text("Projecting")
                .font(.headline)
            if let code = appDelegate.eventCode {
                Text("Code: \(code)").foregroundStyle(.secondary)
            }
            Divider()
            Text("Display").font(.headline)
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
            Button("Stop projection") {
                appDelegate.stopProjection()
            }
        } else {
            Text("Tsudoi").font(.headline)
            if appDelegate.user != nil {
                Text("Enter an event code to begin")
                    .foregroundStyle(.secondary)
            } else {
                Text("Sign in to begin")
                    .foregroundStyle(.secondary)
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
