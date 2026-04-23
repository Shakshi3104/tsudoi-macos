//
//  ContentView.swift
//  tsudoi-macos
//

import SwiftUI
import Combine

// MARK: - Model

struct FlowingComment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
    let lane: Int
    let duration: Double
}

// MARK: - Mock stream

@MainActor
final class MockCommentViewModel: ObservableObject {
    @Published var activeComments: [FlowingComment] = []

    private var timer: Timer?
    private let sampleTexts = [
        "いいね！",
        "素晴らしい",
        "ナイスプレゼン",
        "勉強になります",
        "わかる",
        "最高！",
        "これは面白い",
        "👏👏👏",
        "なるほど",
        "テンポがいい",
        "続きが気になる",
        "確かに"
    ]
    private let sampleColors: [Color] = [
        .white, .cyan, .yellow, .green, .orange, .pink, .mint
    ]

    init() {
        start()
    }

    deinit {
        timer?.invalidate()
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pushRandom()
            }
        }
    }

    private func pushRandom() {
        let comment = FlowingComment(
            text: sampleTexts.randomElement() ?? "Hello",
            color: sampleColors.randomElement() ?? .white,
            lane: Int.random(in: 0..<10),
            duration: 10.0
        )
        activeComments.append(comment)

        // Auto-remove after the animation finishes.
        DispatchQueue.main.asyncAfter(deadline: .now() + comment.duration + 0.5) { [weak self] in
            self?.activeComments.removeAll { $0.id == comment.id }
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var viewModel = MockCommentViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(viewModel.activeComments) { comment in
                    FlowingCommentView(
                        comment: comment,
                        screenWidth: geo.size.width
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

    @State private var xOffset: CGFloat
    @State private var hasStarted = false

    init(comment: FlowingComment, screenWidth: CGFloat) {
        self.comment = comment
        self.screenWidth = screenWidth
        _xOffset = State(initialValue: screenWidth)
    }

    private var yOffset: CGFloat {
        CGFloat(comment.lane) * 80 + 40
    }

    var body: some View {
        Text(comment.text)
            .font(.system(size: 52, weight: .bold))
            .foregroundColor(comment.color)
            .shadow(color: .black.opacity(0.85), radius: 3, x: 2, y: 2)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
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

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
        .background(Color.black) // preview だけ背景を黒くして読みやすくする
}
