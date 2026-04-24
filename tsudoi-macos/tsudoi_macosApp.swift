//
//  tsudoi_macosApp.swift
//  tsudoi-macos
//

import SwiftUI
import AppKit
import Combine
import FirebaseAuth
import FirebaseFirestore

@main
struct tsudoi_macosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appDelegate)
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

// MARK: - AppDelegate

/// App-scoped state container. Owns the NSWindow reference, the auth /
/// Firestore subscriptions, and the list of comments currently on screen.
/// Views observe it via @EnvironmentObject.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private weak var window: NSWindow?

    @Published var currentScreenIndex: Int = 0
    @Published var topInset: CGFloat = 0
    @Published var bottomInset: CGFloat = 0
    @Published var user: User?
    @Published var eventCode: String?
    @Published var activeComments: [FlowingComment] = []
    @Published var isProjecting: Bool = false
    @Published var lastError: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var commentsListener: ListenerRegistration?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AuthService.configure()
        authStateHandle = AuthService.addAuthStateListener { [weak self] user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AuthService.handle(url: url)
        }
    }

    // MARK: Window lifecycle

    func attachWindow(_ window: NSWindow) {
        self.window = window
        WindowStyle.applySetup(to: window)
    }

    func moveToScreen(at index: Int) {
        let screens = NSScreen.screens
        guard index < screens.count, let window else { return }
        currentScreenIndex = index
        let screen = screens[index]
        // visibleFrame excludes the menu bar and Dock; subtract to get insets.
        topInset = screen.frame.maxY - screen.visibleFrame.maxY
        bottomInset = screen.visibleFrame.minY - screen.frame.minY
        if isProjecting {
            window.setFrame(screen.frame, display: true, animate: false)
        }
    }

    // MARK: Auth

    func signIn() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else {
            lastError = "No presenting window available"
            return
        }
        AuthService.signInWithGoogle(presenting: window) { [weak self] result in
            if case let .failure(error) = result {
                Task { @MainActor in self?.lastError = error.localizedDescription }
            }
        }
    }

    func signOut() {
        stopProjection()
        AuthService.signOut()
    }

    // MARK: Projection

    func startProjection(with code: String) {
        let normalized = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !normalized.isEmpty, let window else { return }
        eventCode = normalized
        isProjecting = true
        WindowStyle.applyProjection(to: window)
        moveToScreen(at: currentScreenIndex)
        startListening(eventId: normalized)
    }

    func stopProjection() {
        commentsListener?.remove()
        commentsListener = nil
        activeComments = []
        isProjecting = false
        eventCode = nil
        if let window {
            WindowStyle.applySetup(to: window)
        }
    }

    private func startListening(eventId: String) {
        commentsListener?.remove()
        commentsListener = FirestoreService.listenForNewComments(
            eventId: eventId,
            onAdded: { [weak self] payload in
                Task { @MainActor in
                    self?.append(payload)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.lastError = error.localizedDescription
                }
            }
        )
    }

    @MainActor
    private func append(_ payload: IncomingComment) {
        let comment = FlowingComment(
            text: payload.text,
            color: Color(hex: payload.colorHex),
            // Lanes 0..<2 = top band, 2..<4 = bottom band.
            lane: Int.random(in: 0..<4),
            duration: 10.0
        )
        activeComments.append(comment)

        DispatchQueue.main.asyncAfter(deadline: .now() + comment.duration + 0.5) { [weak self] in
            Task { @MainActor in
                self?.activeComments.removeAll { $0.id == comment.id }
            }
        }
    }
}
