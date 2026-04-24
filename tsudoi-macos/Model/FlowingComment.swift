//
//  FlowingComment.swift
//  tsudoi-macos
//

import SwiftUI

/// A comment currently animating across the projection surface.
struct FlowingComment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
    let lane: Int
    let duration: Double
}

extension Color {
    /// Parses a hex color string such as "#1d1d1f" or "#abc".
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
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
            b = Double(value & 0xFF) / 15.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
