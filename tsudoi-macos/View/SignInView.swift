//
//  SignInView.swift
//  tsudoi-macos
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Tsudoi")
                .font(.largeTitle.bold())
            Text("Sign in to project comments on your slides")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                appDelegate.signIn()
            } label: {
                Text("Sign in with Google")
                    .frame(minWidth: 200)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            if let error = appDelegate.lastError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
