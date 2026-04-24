//
//  CodeEntryView.swift
//  tsudoi-macos
//

import SwiftUI
import FirebaseAuth

struct CodeEntryView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var code: String = ""

    private var trimmed: String {
        code.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Tsudoi").font(.title.bold())
            if let user = appDelegate.user {
                Text("Signed in as \(user.displayName ?? user.email ?? "user")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Event code", text: $code)
                .textFieldStyle(.roundedBorder)
                .textCase(.uppercase)
                .frame(width: 220)
                .onSubmit { startIfValid() }
            Button("Start projection") {
                startIfValid()
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(trimmed.isEmpty)
            Button("Sign out") {
                appDelegate.signOut()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            if let error = appDelegate.lastError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startIfValid() {
        guard !trimmed.isEmpty else { return }
        appDelegate.startProjection(with: trimmed)
    }
}
