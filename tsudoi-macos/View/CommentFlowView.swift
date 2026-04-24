//
//  CommentFlowView.swift
//  tsudoi-macos
//

import SwiftUI

// Lanes 0..<lanesPerZone fill the top band; lanes lanesPerZone..<2*lanesPerZone
// fill the bottom band. The middle of the screen is left empty so the slides
// stay readable even when comments are coming in thick and fast.
let lanesPerZone = 2
let laneHeight: CGFloat = 80
/// Small breathing room on top of whatever inset the menu bar / Dock impose.
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
