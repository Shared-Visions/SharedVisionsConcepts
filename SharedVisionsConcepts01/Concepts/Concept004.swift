//  Step Into Vision - Example Code
//
//  Title: Concept004
//
//  Subtitle: Cover Flow
//
//  Description: A horizontally scrolling cover flow layout using `rotation3DLayout` modifier for proper frame handling, `onGeometryChange` for position tracking without GeometryReader, and an animated demo mode with bidirectional auto-scrolling. Features dynamic rotation based on distance from center and opacity fade on edges.
//
//  Type: Window Alt
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/6/26.

import SwiftUI
import RealityKit
import RealityKitContent

struct Concept004: View {
    let nodeSize: CGFloat = 200
    private let itemSpacing: CGFloat = 100
    private let containerWidth: CGFloat = 800
    private let containerHeight: CGFloat = 400
    private let itemCount = 20

    @State private var showDebug = true
    @State private var isDemoMode = false
    @State private var currentIndex = 0
    @State private var isReversing = false
    @State private var demoTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            Text("Cover Flow Concept")
                .font(.largeTitle)
                .padding()
                .glassBackgroundEffect(in: .capsule, displayMode: .always)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: itemSpacing) {
                        ForEach(0..<itemCount, id: \.self) { index in
                            CoverFlowItem(nodeSize: nodeSize, index: index, showDebug: $showDebug)
                                .frame(width: nodeSize, height: nodeSize)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, containerWidth / 2 - nodeSize / 2)
                }
                .scrollTargetBehavior(.viewAligned)
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            
            HStack(spacing: 16) {
                Toggle(isOn: $showDebug, label: {
                    Text("Debug Lines")
                })
                .toggleStyle(.button)
                
                Toggle(isOn: $isDemoMode, label: {
                    Text(isDemoMode ? "Stop Demo" : "Play Demo")
                })
                .toggleStyle(.button)
            }
            .padding()
            .glassBackgroundEffect(in: .capsule, displayMode: .always)
        }
        .frame(width: containerWidth, height: containerHeight)
        .onChange(of: isDemoMode) { _, isActive in
            if isActive {
                startDemo()
            } else {
                stopDemo()
            }
        }
        .onDisappear {
            stopDemo()
        }
    }
    
    private func startDemo() {
        demoTask = Task {
            while !Task.isCancelled && isDemoMode {
                // Wait 3 seconds on current node
                try? await Task.sleep(for: .seconds(3))
                
                guard !Task.isCancelled && isDemoMode else { break }
                
                // Move to next node (animation handled by onChange)
                if isReversing {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    } else {
                        isReversing = false
                        currentIndex = 1
                    }
                } else {
                    if currentIndex < itemCount - 1 {
                        currentIndex += 1
                    } else {
                        isReversing = true
                        currentIndex = itemCount - 2
                    }
                }
                
                // Wait for animation to complete
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
    }
    
    private func stopDemo() {
        demoTask?.cancel()
        demoTask = nil
    }
}

private struct CoverFlowLayout: Layout {
    let itemSize: CGSize
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let count = CGFloat(subviews.count)
        let totalWidth = count * itemSize.width + max(0, count - 1) * spacing

        return CGSize(width: totalWidth, height: itemSize.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let itemProposal = ProposedViewSize(width: itemSize.width, height: itemSize.height)
        var nextX = bounds.minX + itemSize.width / 2

        for subview in subviews {
            subview.place(
                at: CGPoint(x: nextX, y: bounds.midY),
                anchor: .center,
                proposal: itemProposal
            )
            nextX += itemSize.width + spacing
        }
    }
}

private struct CoverFlowItem: View {
    let nodeSize: CGFloat
    let index: Int
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    @Binding var showDebug: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .foregroundStyle(.black)
            .padding()
            .frame(width: nodeSize, height: nodeSize)
            .frame(depth: 40)
            .debugBorder3D(showDebug ? .white : .clear)
            .shadow(radius: 24)
            .offset(z: 60)
            .rotation3DLayout(.degrees(rotation), axis: .y)
            .opacity(opacity)
            .onGeometryChange(for: CoverFlowGeometry.self) { geometryProxy in
                let frame = geometryProxy.frame(in: .scrollView)
                let scrollViewBounds = geometryProxy.bounds(of: .scrollView) ?? .zero
                let scrollViewMidX = scrollViewBounds.width / 2
                let itemCenterX = frame.midX
                let distance = itemCenterX - scrollViewMidX
                
                // Calculate rotation
                let deadZone = nodeSize * 0.28
                let calculatedRotation = abs(distance) < deadZone ? 0 : -Double(distance) / 8
                
                // Calculate opacity
                let maxDistance = scrollViewMidX
                let fadeThreshold = maxDistance * 0.4
                let absDistance = abs(distance)
                let calculatedOpacity = absDistance < fadeThreshold
                    ? 1.0
                    : max(0.1, 1.0 - (absDistance - fadeThreshold) / (maxDistance - fadeThreshold))
                
                return CoverFlowGeometry(rotation: calculatedRotation, opacity: calculatedOpacity)
            } action: { newValue in
                rotation = newValue.rotation
                opacity = newValue.opacity
            }
    }
}

private struct CoverFlowGeometry: Sendable {
    let rotation: Double
    let opacity: Double
}

extension CoverFlowGeometry: Equatable {
    nonisolated static func == (lhs: CoverFlowGeometry, rhs: CoverFlowGeometry) -> Bool {
        lhs.rotation == rhs.rotation && lhs.opacity == rhs.opacity
    }
}

#Preview {
    Concept004()
}
