//
//  ContentView.swift
//  tsudoi-macos
//

import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Model

struct FlowingComment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
    let lane: Int
    let duration: Double
}

// MARK: - Root

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

// Kept for backward compatibility with the default scene.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

// MARK: - Setup views

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

// MARK: - Projection

// Lanes 0..<lanesPerZone fill the top band; lanes lanesPerZone..<2*lanesPerZone
// fill the bottom band. The middle of the screen is left empty so the slides
// stay readable even when comments are coming in thick and fast.
let lanesPerZone = 2
let laneHeight: CGFloat = 80
// Small breathing room on top of whatever inset the menu bar / Dock impose.
let zoneBreathingRoom: CGFloat = 16

struct ProjectionView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(appDelegate.activeComments) { comment in
                    FlowingCommentView(
                        comment: comment,
                        screenWidth: geo.size.width,
                        screenHeight: geo.size.height,
                        topInset: appDelegate.topInset,
                        bottomInset: appDelegate.bottomInset
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

struct FlowingCommentView: View {
    let comment: FlowingComment
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    @State private var xOffset: CGFloat
    @State private var hasStarted = false

    init(
        comment: FlowingComment,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) {
        self.comment = comment
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.topInset = topInset
        self.bottomInset = bottomInset
        _xOffset = State(initialValue: screenWidth)
    }

    private var yOffset: CGFloat {
        if comment.lane < lanesPerZone {
            // Top band — clear the menu bar / notch
            return topInset + zoneBreathingRoom + CGFloat(comment.lane) * laneHeight
        } else {
            // Bottom band — stack upward from just above the Dock
            let indexFromBottom = comment.lane - lanesPerZone
            let distanceFromBottom = bottomInset + zoneBreathingRoom
                + CGFloat(lanesPerZone - indexFromBottom) * laneHeight
            return screenHeight - distanceFromBottom
        }
    }

    var body: some View {
        Text(comment.text)
            .font(.system(size: 52, weight: .bold))
            .foregroundColor(comment.color)
            // White halo — 4-direction shadow approximates a stroke so
            // dark text stays readable on dark slides.
            .shadow(color: .white, radius: 1.2, x: 1.5, y: 0)
            .shadow(color: .white, radius: 1.2, x: -1.5, y: 0)
            .shadow(color: .white, radius: 1.2, x: 0, y: 1.5)
            .shadow(color: .white, radius: 1.2, x: 0, y: -1.5)
            // Subtle drop for depth on light slides.
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
            .fixedSize()
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                withAnimation(.linear(duration: comment.duration)) {
                    xOffset = -800
                }
            }
    }
}

// MARK: - Color(hex:) helper

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        case 3:
            r = Double((value >> 8) & 0xF) / 15.0
            g = Double((value >> 4) & 0xF) / 15.0
            b = Double(value & 0xF) / 15.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDelegate())
        .frame(width: 480, height: 320)
}
