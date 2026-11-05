//  Shared Visions Concepts
//
//  Title: Concept009
//
//  Subtitle: Glass Profile Orbs
//
//  Description: Inverted glass orbs with a backlight and an attachment for content
//
//  Type: Volume
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/23/26.

import SwiftUI
import RealityKit
import RealityKitContent

struct Concept009: View {
    
    @State private var profileEntity = Entity()
    @State private var profile = "🧑🏻‍💻"
    
    private let emojiColors: [String: UIColor] = [
        "🧑🏻‍💻": .blue,
        "🤔": .orange,
        "🐸": .cyan
    ]
    
    var body: some View {
        RealityView { content in
            guard let glassSphere = try? await Entity(named: "GlassSphere", in: realityKitContentBundle) else { return }
            profileEntity = glassSphere
            content.add(glassSphere)
            
            if let attachmentAnchor = glassSphere.findEntity(named: "AttachmentAnchor") {
                let attachment = ViewAttachmentComponent(rootView: ProfileImage(emoji: $profile))
                attachmentAnchor.components.set(attachment)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomOrnament) {
                HStack(spacing: 6) {
                    ForEach(Array(emojiColors.keys.sorted()), id: \.self) { emoji in
                        Button(emoji) {
                            profile = emoji
                            updateLight()
                        }
                    }
                }
            }
        }
        .controlSize(.large)
        .ornament(attachmentAnchor: .scene(.trailing), contentAlignment: .leading, ornament: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Profile images inside an inverted glass sphere.")
                Text("Each image can have a matching or primary color to tint the glass using a point light")
            }
            .frame(width: 220)
            .padding()
            .glassBackgroundEffect()
        })
    }
    
    private func updateLight() {
        guard let light = profileEntity.findEntity(named: "PointLight"),
              let color = emojiColors[profile] else { return }
        
        light.components[PointLightComponent.self]?.color = color
    }
}

fileprivate struct ProfileImage: View {
    @Binding var emoji: String
    
    var body: some View {
        Text(emoji)
            .font(.extraLargeTitle2)
    }
}

#Preview {
    Concept009()
}
