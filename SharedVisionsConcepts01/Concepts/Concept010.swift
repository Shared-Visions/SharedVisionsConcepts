//  Shared Visions Concepts
//
//  Title: Concept010
//
//  Subtitle: Active Profile Orbs
//
//  Description: Three glass profile orbs with selective backlight control
//
//  Type: Volume
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/25/26.

import SwiftUI
import RealityKit
import RealityKitContent

struct Concept010: View {
    
    @State private var sphereEntities: [Entity] = []
    @State private var selectedSphere: Int = 0
    
    private let profiles = ["🧑🏻‍💻", "🤔", "🐸"]
    private let emojiColors: [UIColor] = [.blue, .orange, .cyan]
    
    // Positions for the three spheres - one on top, two underneath
    private let spherePositions: [SIMD3<Float>] = [
        SIMD3(x: 0, y: 0.15, z: 0),      // Top
        SIMD3(x: -0.15, y: -0.15, z: 0), // Bottom left
        SIMD3(x: 0.15, y: -0.15, z: 0)   // Bottom right
    ]
    
    var body: some View {
        RealityView { content in
            // Create three glass spheres
            for i in 0..<3 {
                guard let glassSphere = try? await Entity(named: "GlassSphere", in: realityKitContentBundle) else { continue }
                
                // Position the sphere
                glassSphere.position = spherePositions[i]
                
                // Add attachment with profile image
                if let attachmentAnchor = glassSphere.findEntity(named: "AttachmentAnchor") {
                    let attachment = ViewAttachmentComponent(rootView: ProfileImage(emoji: profiles[i], index: i, selectedSphere: $selectedSphere))
                    attachmentAnchor.components.set(attachment)
                }
                
                // Initially set light state
                if let light = glassSphere.findEntity(named: "PointLight") {
                    if i == selectedSphere {
                        light.components[PointLightComponent.self]?.color = emojiColors[i]
                    } else {
                        // Turn off light by setting intensity to 0
                        light.components[PointLightComponent.self]?.intensity = 0
                    }
                }
                
                sphereEntities.append(glassSphere)
                content.add(glassSphere)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomOrnament) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        Button {
                            selectSphere(index)
                        } label: {
                            VStack(spacing: 4) {
                                Text(profiles[index])
                                    .font(.title)
                                if selectedSphere == index {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 6, height: 6)
                                } else {
                                    Circle()
                                        .fill(.clear)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .controlSize(.large)
        .ornament(attachmentAnchor: .scene(.trailing), contentAlignment: .leading, ornament: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Three profile orbs with selective lighting.")
                Text("Use the toolbar buttons to switch which sphere is illuminated.")
            }
            .frame(width: 220)
            .padding()
            .glassBackgroundEffect()
        })
    }
    
    private func selectSphere(_ index: Int) {
        selectedSphere = index
        updateLights()
    }
    
    private func updateLights() {
        for (i, sphere) in sphereEntities.enumerated() {
            guard let light = sphere.findEntity(named: "PointLight") else { continue }
            
            if i == selectedSphere {
                // Turn on the selected light
                light.components[PointLightComponent.self]?.color = emojiColors[i]
                light.components[PointLightComponent.self]?.intensity = 1000
            } else {
                // Turn off other lights
                light.components[PointLightComponent.self]?.intensity = 0
            }
        }
    }
}

fileprivate struct ProfileImage: View {
    let emoji: String
    let index: Int
    @Binding var selectedSphere: Int
    
    var body: some View {
        Text(emoji)
            .font(.extraLargeTitle2)
            .grayscale(selectedSphere == index ? 0.0 : 1.0)
    }
}

#Preview {
    Concept010()
}
