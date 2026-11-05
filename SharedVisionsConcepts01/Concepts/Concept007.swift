//  Shared Visions Concepts
//
//  Title: Concept007
//
//  Subtitle: Tab View Circle Window
//
//  Description:
//
//  Type: Window Alt
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/10/26.

import SwiftUI

struct Concept007: View {
    let circleWindowSize: CGFloat = 800
    var body: some View {
        TabView {
            Tab("Shared Visions", systemImage: "circle.hexagongrid.fill") {
                ZStack {
                    SharedVisionsBackground()
                    SharedVisionsTitleView()
                }
            }
            
            Tab("Library", systemImage: "circle.fill") {
                Text("Library Content")
            }
            
            Tab("Credits", systemImage: "ellipsis") {
                Text("Credits Content")
            }
        }
        .frame(width: circleWindowSize, height: circleWindowSize)
        .glassBackgroundEffect(in: .capsule, displayMode: .always)
    }
}

#Preview {
    Concept007()
        .environment(AppModel())
}
// MARK: - Supporting Views

fileprivate struct SharedVisionsBackground: View {
    var body: some View {
        HoneycombLayout {
            ForEach(0..<72, id: \.self) { index in
                PersonNode()
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
