//  Step Into Vision - Example Code
//
//  Title: Concept008
//
//  Subtitle: Shared Visions Community Events
//
//  Description:
//
//  Type: Window
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/14/26.

import SwiftUI
import RealityKit
import RealityKitContent

struct Concept008: View {
    var body: some View {
        ZStack {
            SharedVisionsBackground()
            VStack(alignment: .leading, spacing : 24) {
                VStack(alignment: .leading, spacing : 12) {
                    Text("Shared Visions")
                        .font(.largeTitle)

                    Text("Weekly Community Meeting")
                }

                VStack(alignment: .leading, spacing : 12) {
                    Text("• Every Wednesday")
                    Text("• Story Updates")
                    Text("• UX Work")
                    Text("• App Development")
                    Text("• Video Production")
                }


            }
//            .glassBackgroundEffect(.automatic, in: .circle, displayMode: .always)
            .padding(24)
            .background(.black)
            .clipShape(.rect(cornerRadius: 24))
//            .glassBackgroundEffect()
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    Concept008()
}

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
    let emoji: [String] = ["🧑🏻‍💻", "📖", "📢", "📺", "💻", "🎉", "🚀", "🤔", "💡"]
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
//                .grayscale(0.8) // Desaturated
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
