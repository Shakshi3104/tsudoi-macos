//
//  tsudoi_macosApp.swift
//  tsudoi-macos
//

import SwiftUI
import AppKit
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

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
        FirebaseApp.configure()

        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        // Restore any previous Google sign-in
        GIDSignIn.sharedInstance.restorePreviousSignIn()

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            _ = GIDSignIn.sharedInstance.handle(url)
        }
    }

    // MARK: Window lifecycle

    func attachWindow(_ window: NSWindow) {
        self.window = window
        applySetupWindowStyle()
    }

    private func applySetupWindowStyle() {
        guard let window else { return }
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

    private func applyProjectionWindowStyle() {
        guard let window else { return }
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
        moveToScreen(at: currentScreenIndex)
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

        GIDSignIn.sharedInstance.signIn(withPresenting: window) { [weak self] result, error in
            if let error {
                Task { @MainActor in self?.lastError = error.localizedDescription }
                return
            }
            guard let result else { return }

            let gUser = result.user
            guard let idToken = gUser.idToken?.tokenString else {
                Task { @MainActor in self?.lastError = "Missing ID token" }
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: gUser.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    Task { @MainActor in self?.lastError = error.localizedDescription }
                }
            }
        }
    }

    func signOut() {
        stopProjection()
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: Projection

    func startProjection(with code: String) {
        let normalized = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !normalized.isEmpty else { return }

        eventCode = normalized
        isProjecting = true
        applyProjectionWindowStyle()
        startListening(eventId: normalized)
    }

    func stopProjection() {
        commentsListener?.remove()
        commentsListener = nil
        activeComments = []
        isProjecting = false
        eventCode = nil
        applySetupWindowStyle()
    }

    private func startListening(eventId: String) {
        commentsListener?.remove()
        let db = Firestore.firestore()
        let startTime = Timestamp(date: Date())
        commentsListener = db.collection("events").document(eventId)
            .collection("comments")
            .whereField("createdAt", isGreaterThan: startTime)
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in self?.lastError = error.localizedDescription }
                    return
                }
                guard let snapshot else { return }
                Task { @MainActor in
                    self?.handleSnapshot(snapshot)
                }
            }
    }

    @MainActor
    private func handleSnapshot(_ snapshot: QuerySnapshot) {
        for change in snapshot.documentChanges where change.type == .added {
            let data = change.document.data()
            guard let text = data["text"] as? String else { continue }
            if data["hidden"] as? Bool == true { continue }
            let colorHex = data["color"] as? String ?? "#FFFFFF"
            let comment = FlowingComment(
                text: text,
                color: Color(hex: colorHex),
                // Lanes 0..<2 = top band, 2..<4 = bottom band.
                // The middle of the screen is intentionally left empty so
                // slides stay readable when comments come in fast.
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
}

// MARK: - Menu bar

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

// MARK: - WindowAccessor

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
