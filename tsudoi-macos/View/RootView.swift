//
//  RootView.swift
//  tsudoi-macos
//

import SwiftUI

/// Top-level view that picks the right screen for the current app state.
struct RootView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        Group {
            if appDelegate.isProjecting {
                ProjectionView()
            } else if appDelegate.user != nil {
                CodeEntryView()
            } else {
                SignInView()
            }
        }
    }
}
