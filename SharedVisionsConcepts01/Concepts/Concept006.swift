//  Shared Visions Concepts
//
//  Title: Concept006
//
//  Subtitle: Radial Ring
//
//  Description: A volumetric ring of emoji spheres using RadialLayout with rotation controls and Z-axis offset animation for depth effects.
//
//  Type: Volume
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/9/26.

import SwiftUI
import RealityKit
import RealityKitContent

struct Concept006: View {
    
    @State private var showDebugLines = false
    @State private var layoutRotation: Double = 90
    @State private var angleOffset: Angle = .zero
    @State private var isAutoPlaying = false
    @State private var autoPlayTask: Task<Void, Never>?
    
    let emoji: [String] = ["🌸", "🐸", "❤️", "🔥", "💻", "🐶", "🥸", "📱", "🎉", "🚀", "🤔", "💡"]

    private var frontIndex: Int {
        let totalItems = emoji.count
        let degreesPerItem = 360.0 / Double(totalItems)
        let normalizedAngle = -angleOffset.degrees.truncatingRemainder(dividingBy: 360)
        let rawIndex = Int(round(normalizedAngle / degreesPerItem))
        return (rawIndex % totalItems + totalItems) % totalItems
    }
    
    var body: some View {
        VStack {
            Spacer()
            RadialLayout(angleOffset: angleOffset) {
                ForEach(0..<emoji.count, id: \.self) { index in
                    ModelViewEmoji(name: "UISphere01", emoji: emoji[index], bundle: realityKitContentBundle)
                        .rotation3DLayout(Rotation3D(angle: .degrees(360 - layoutRotation), axis: .x))
                        .scaleEffect(index == frontIndex ? 1.0 : 0.5)
                }
            }
            .rotation3DLayout(Rotation3D(angle: .degrees(layoutRotation), axis: .x))

            .debugBorder3D(showDebugLines ? .white : .clear)
        }
        .frame(width: 1000, height: 1000)
        .frame(depth: 1000)
        .debugBorder3D(showDebugLines ? .white : .clear)
        .ornament(attachmentAnchor: .scene(.trailing), ornament: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            angleOffset += .degrees(-30)
                        }
                    }, label: {
                        Image(systemName: "arrow.counterclockwise")
                    })
                    .disabled(isAutoPlaying)


                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            angleOffset += .degrees(30)
                        }
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                    })
                    .disabled(isAutoPlaying)
                }

                Button(action: {
                    isAutoPlaying.toggle()
                }, label: {
                    Label(isAutoPlaying ? "Stop" : "Auto Play", systemImage: isAutoPlaying ? "stop.fill" : "play.fill")
                })
                
                Button(action: {
                    showDebugLines.toggle()
                }, label: {
                    Text("Debug")
                })
            }
            .padding()
            .controlSize(.small)
            .glassBackgroundEffect()
        })
        .onChange(of: isAutoPlaying) { _, isActive in
            if isActive {
                startAutoPlay()
            } else {
                stopAutoPlay()
            }
        }
        .onDisappear {
            stopAutoPlay()
        }
    }
    
    private func startAutoPlay() {
        autoPlayTask = Task {
            while !Task.isCancelled && isAutoPlaying {
                // Wait 2 seconds on current item
                try? await Task.sleep(for: .seconds(2))
                
                guard !Task.isCancelled && isAutoPlaying else { break }
                
                // Move to next item
                withAnimation(.easeInOut(duration: 0.5)) {
                    angleOffset += .degrees(30)
                }
                
                // Wait for animation to complete
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
    }
    
    private func stopAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
    }
}

#Preview {
    Concept006()
}

// MARK: - Supporting Views

fileprivate struct ModelViewEmoji: View {
    
    let name: String
    let emoji: String
    let bundle: Bundle
    
    var body: some View {
        Model3D(named: name, bundle: bundle) { phase in
            if let model = phase.model {
                model
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .spatialOverlay(alignment: .center) {
                        Text(emoji)
                            .font(.system(size: 60))
                    }
            } else if phase.error != nil {
                Text(emoji)
            } else {
                ProgressView()
            }
        }
    }
}
