//  Shared Visions Concepts
//
//  Title: Concept001
//
//  Subtitle: Profile Honeycomb Background
//
//  Description: The original honeycomb grid with person nodes and hover effects
//
//  Type: Window Alt
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/1/26.

import SwiftUI

struct Concept001: View {
    let circleWindowSize: CGFloat = 800
    var body: some View {
        ZStack {
            SharedVisionsBackground()
            SharedVisionsTitleView()
        }
        .frame(width: circleWindowSize, height: circleWindowSize)
        .glassBackgroundEffect(in: .capsule, displayMode: .always)

        .ornament(attachmentAnchor: .scene(.trailing), contentAlignment: .leading, ornament: {
            VStack(alignment: .leading, spacing: 6) {
                Text("• The emoji here are intended to stand in for profile photos for each person.")
                Text("• Hover over each circle to see a full color version.")
            }
            .frame(width: 220)
            .padding()
            .glassBackgroundEffect()
        })
    }
}

#Preview {
    Concept001()
        .environment(AppModel())
}
// MARK: - Supporting Views

fileprivate struct SharedVisionsBackground: View {
    @State private var spacing: CGFloat = 100

    var body: some View {
        HoneycombLayout(hexSize: 100, radius: 50, spacing: spacing) {
            ForEach(0..<72, id: \.self) { index in
                PersonNode()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                spacing = 20
            }
        }
    }
}

fileprivate struct SharedVisionsTitleView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Shared Visions")
                .font(.extraLargeTitle)
            VStack {
                Text("An immersive story about the")
                Text("Apple Vision Pro Community")
            }
            .font(.caption)
            .offset(y: 30)
        }
        .frame(width: 320, height: 320)
        .glassBackgroundEffect(.automatic, in: .circle, displayMode: .always)
    }
}

fileprivate struct PersonNode: View {
    @Namespace private var hoverNamespace
    
    // Mock profile image using emoji
    let emoji: [String] = ["🌸", "🐸", "❤️", "🔥", "💻", "🐶", "🥸", "📱", "🎉", "🚀", "🤔", "💡"]
    private let profileEmoji: String
    
    init() {
        profileEmoji = emoji.randomElement() ?? "😀"
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.thinMaterial)
                .frame(width: 80, height: 80)
            
            // Desaturated profile image (visible when not hovered)
            Text(profileEmoji)
                .font(.system(size: 50))
                .grayscale(1.0) // Desaturated
                .hoverEffect(in: HoverEffectGroup(hoverNamespace)) { effect, isActive, proxy in
                    effect.opacity(isActive ? 0 : 1.0)
                }
            
            // Full color profile image (visible when hovered)
            Text(profileEmoji)
                .font(.system(size: 50))
                .hoverEffect(in: HoverEffectGroup(hoverNamespace)) { effect, isActive, proxy in
                    effect.opacity(isActive ? 1.0 : 0)
                }
        }
        .padding(12)
        .hoverEffect(in: HoverEffectGroup(hoverNamespace)) { effect, isActive, proxy in
            effect.scaleEffect(isActive ? 1.2 : 1.0)
        }
    }
}

// MARK: - Layout


