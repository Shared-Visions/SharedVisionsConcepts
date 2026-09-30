//  Shared Visions Concepts
//
//  Title: Concept011
//
//  Subtitle: Welcome / Living Constellation
//
//  Description: A pitch-black 360° intro space where evenly spaced dots around the user breathe in and out, then compress into electric-blue points that briefly connect like a constellation or a neural net. Lightning-like blue connections build in small batches, then the Shared Visions title fades in. Begin returns to the main menu.
//
//  Type: Space Full
//
//  Featured: true
//
//  Created by Kiro on 9/23/26.

import SwiftUI
import RealityKit

struct Concept011: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var hasBegun = false
    @State private var showWelcome = false
    @State private var field = LivingConstellationController()

    private let welcomeAttachmentID = "shared-visions-welcome"

    var body: some View {
        RealityView { content, attachments in
            field.build(in: &content) {
                guard !showWelcome else { return }
                withAnimation(.easeOut(duration: 1.2)) {
                    showWelcome = true
                }
            }

            if let welcome = attachments.entity(for: welcomeAttachmentID) {
                welcome.position = [0, 1.48, -1.05]
                welcome.components.set(BillboardComponent())
                content.add(welcome)
            }
        } attachments: {
            Attachment(id: welcomeAttachmentID) {
                WelcomeAttachment(
                    hasBegun: hasBegun,
                    isVisible: showWelcome,
                    onBegin: begin,
                    onExit: exit
                )
            }
        }
        .persistentSystemOverlays(.hidden)
    }

    private func begin() {
        guard !hasBegun else { return }
        hasBegun = true

        Task { @MainActor in
            field.bloom()

            // The host closes MainWindow when this full immersive concept opens.
            // Re-create it *before* tearing down the immersive space so returning
            // feels like a continuous transition instead of a terminate/relaunch.
            openWindow(id: "MainWindow")
            try? await Task.sleep(for: .milliseconds(180))
            await dismissImmersiveSpace()
        }
    }

    private func exit() {
        Task { @MainActor in
            openWindow(id: "MainWindow")
            try? await Task.sleep(for: .milliseconds(120))
            await dismissImmersiveSpace()
        }
    }
}

fileprivate struct ConstellationConnection {
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    let midpoint: SIMD3<Float>
    let length: Float
    let seed: Int
}

@MainActor
@Observable
fileprivate final class LivingConstellationController {
    private let brandBlue = UIColor(red: 0.0, green: 145.0 / 255.0, blue: 1.0, alpha: 1.0)

    private let root = Entity()
    private var built = false
    private var sequenceStarted = false
    private var nodes: [(dot: ModelEntity, halo: ModelEntity)] = []
    private var nodePositions: [SIMD3<Float>] = []
    private var connections: [ConstellationConnection] = []

    func build(in content: inout RealityViewContent, onRevealTitle: @escaping @MainActor () -> Void) {
        guard !built else { return }
        built = true
        content.add(root)

        let positions = DomeLayout.positions(
            count: 72,
            radius: 2.35,
            verticalArcDegrees: 150,
            horizontalArcDegrees: 360
        )
        nodePositions = positions

        for position in positions {
            let dot = ModelEntity(
                mesh: .generateSphere(radius: 0.016),
                materials: [material(color: .white, opacity: 0.0)]
            )
            dot.position = position
            root.addChild(dot)

            let halo = ModelEntity(
                mesh: .generateSphere(radius: 0.042),
                materials: [material(color: brandBlue, opacity: 0.0)]
            )
            halo.position = position
            root.addChild(halo)

            nodes.append((dot: dot, halo: halo))
        }

        connections = makeEdges(for: positions).enumerated().map { index, edge in
            ConstellationConnection(
                start: edge.0,
                end: edge.1,
                midpoint: (edge.0 + edge.1) / 2,
                length: simd_distance(edge.0, edge.1),
                seed: index + 1
            )
        }
        .sorted { lhs, rhs in
            frontPriority(for: lhs) > frontPriority(for: rhs)
        }

        guard !sequenceStarted else { return }
        sequenceStarted = true

        Task { @MainActor in
            await runIntroSequence(onRevealTitle: onRevealTitle)
        }
    }

    func bloom() {
        for (index, node) in nodes.enumerated() {
            var target = node.dot.transform
            target.scale *= index % 5 == 0 ? 1.45 : 1.22
            let animation = FromToByAnimation(
                to: target,
                duration: 0.38,
                timing: .easeOut,
                bindTarget: .transform
            )
            if let resource = try? AnimationResource.generate(with: animation) {
                node.dot.playAnimation(resource)
            }
        }
    }

    private func runIntroSequence(onRevealTitle: @escaping @MainActor () -> Void) async {
        await animateBreathingDots()
        await compressToBluePoints()
        await animateConnectionSequence()
        onRevealTitle()
        startIdleBlueBreathing()
    }

    private func animateBreathingDots() async {
        let steps = 14

        for step in 0...steps {
            let t = Float(step) / Float(steps)
            let eased = easeInOut(t)
            applyNodeState(
                color: .white,
                dotOpacity: 0.10 + 0.75 * eased,
                haloOpacity: 0.0,
                dotScale: 0.55 + 0.70 * eased,
                haloScale: 1.0
            )
            try? await Task.sleep(for: .milliseconds(90))
        }

        for step in 0...steps {
            let t = Float(step) / Float(steps)
            let eased = easeInOut(t)
            applyNodeState(
                color: .white,
                dotOpacity: 0.85 - 0.68 * eased,
                haloOpacity: 0.0,
                dotScale: 1.25 - 0.38 * eased,
                haloScale: 1.0
            )
            try? await Task.sleep(for: .milliseconds(85))
        }
    }

    private func compressToBluePoints() async {
        let steps = 12
        for step in 0...steps {
            let t = Float(step) / Float(steps)
            let eased = easeInOut(t)
            let blue = interpolateColor(from: .white, to: brandBlue, t: eased)
            applyNodeState(
                color: blue,
                dotOpacity: 0.18 + 0.72 * eased,
                haloOpacity: 0.0 + 0.15 * eased,
                dotScale: 0.88 - 0.38 * eased,
                haloScale: 0.95 + 0.10 * eased
            )
            try? await Task.sleep(for: .milliseconds(68))
        }
    }

    private func animateConnectionSequence() async {
        // Make the lightning impossible to miss in-headset. The dense "hero"
        // network is concentrated directly behind/around the title-card area.
        // Every other dot independently gets a deterministic ~30% chance to
        // throw one strike to its nearest neighbor during the sequence.
        let hero = heroLightningConnections()
        let ambient = ambientThirtyPercentConnections()

        guard !hero.isEmpty else { return }

        // Five strong hero waves. Every wave lights the whole central cluster,
        // with the peripheral 30% strikes layered in between.
        for wave in 0..<5 {
            for (index, connection) in hero.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed + wave * 211 + index * 19,
                    delayMilliseconds: index * 24,
                    includeBranch: true
                )
            }

            let ambientSlice = ambient.enumerated().filter { pair in
                // Split peripheral strikes across waves so the room feels alive
                // instead of flashing everything at exactly the same instant.
                pair.offset % 5 == wave
            }

            for (index, pair) in ambientSlice.enumerated() {
                spawnLightningBolt(
                    for: pair.element,
                    seed: pair.element.seed + wave * 307 + index * 23,
                    delayMilliseconds: 120 + index * 42,
                    includeBranch: wave.isMultiple(of: 2)
                )
            }

            try? await Task.sleep(for: .milliseconds(420))
        }

        // One last dense front flash immediately before the title fades in.
        for (index, connection) in hero.enumerated() {
            spawnLightningBolt(
                for: connection,
                seed: connection.seed + 9001 + index * 31,
                delayMilliseconds: index * 18,
                includeBranch: true
            )
        }

        try? await Task.sleep(for: .milliseconds(260))
    }

    private func startIdleBlueBreathing() {
        for (index, node) in nodes.enumerated() {
            let phaseOffset = Float(index % 9) * 0.015

            var targetDot = node.dot.transform
            targetDot.scale *= 1.08 + phaseOffset
            let dotAnimation = FromToByAnimation(
                to: targetDot,
                duration: 2.6 + Double(index % 5) * 0.18,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let resource = try? AnimationResource.generate(with: dotAnimation) {
                node.dot.playAnimation(resource)
            }

            var targetHalo = node.halo.transform
            targetHalo.scale *= 1.14 + phaseOffset
            let haloAnimation = FromToByAnimation(
                to: targetHalo,
                duration: 2.8 + Double(index % 4) * 0.22,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let resource = try? AnimationResource.generate(with: haloAnimation) {
                node.halo.playAnimation(resource)
            }
        }
    }

    private func applyNodeState(
        color: UIColor,
        dotOpacity: Float,
        haloOpacity: Float,
        dotScale: Float,
        haloScale: Float
    ) {
        for node in nodes {
            setMaterial(on: node.dot, color: color, opacity: dotOpacity)
            setMaterial(on: node.halo, color: brandBlue, opacity: haloOpacity)
            node.dot.scale = SIMD3<Float>(repeating: dotScale)
            node.halo.scale = SIMD3<Float>(repeating: haloScale)
        }
    }

    private func setMaterial(on entity: ModelEntity, color: UIColor, opacity: Float) {
        guard var model = entity.model else { return }
        model.materials = [material(color: color, opacity: opacity)]
        entity.model = model
    }

    private func spawnLightningBolt(
        for connection: ConstellationConnection,
        seed: Int,
        delayMilliseconds: Int,
        includeBranch: Bool
    ) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))

            let bolt = makeLightningBolt(for: connection, seed: seed, includeBranch: includeBranch)
            root.addChild(bolt)

            // Keep each flash extremely brief. The geometry should read as a
            // transient electrical impression, never as something the viewer
            // has time to inspect as cylinders and spheres.
            try? await Task.sleep(for: .milliseconds(78))
            bolt.removeFromParent()

            if includeBranch {
                let reflicker = makeLightningBolt(
                    for: connection,
                    seed: seed + 97,
                    includeBranch: false
                )
                root.addChild(reflicker)
                try? await Task.sleep(for: .milliseconds(54))
                reflicker.removeFromParent()
            }
        }
    }

    private func animatePulse(on connection: ConstellationConnection) {
        let pulse = ModelEntity(
            mesh: .generateSphere(radius: 0.011),
            materials: [material(color: .white, opacity: 0.08)]
        )
        pulse.position = connection.start
        root.addChild(pulse)

        let glow = ModelEntity(
            mesh: .generateSphere(radius: 0.022),
            materials: [material(color: brandBlue, opacity: 0.025)]
        )
        glow.position = .zero
        pulse.addChild(glow)

        var target = pulse.transform
        target.translation = connection.end
        let animation = FromToByAnimation(
            to: target,
            duration: 0.22,
            timing: .easeInOut,
            bindTarget: .transform
        )
        if let resource = try? AnimationResource.generate(with: animation) {
            pulse.playAnimation(resource)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            pulse.removeFromParent()
        }
    }

    private func makeLightningBolt(
        for connection: ConstellationConnection,
        seed: Int,
        includeBranch: Bool
    ) -> Entity {
        let bolt = Entity()
        let points = jaggedPoints(from: connection.start, to: connection.end, seed: seed)
        addLightningSegments(points: points, to: bolt)

        if includeBranch, points.count >= 4 {
            let branchIndex = min(max(2, points.count / 2), points.count - 2)
            let branchStart = points[branchIndex]
            let branchDirection = simd_normalize(points[branchIndex + 1] - points[branchIndex - 1])
            let basis = orthonormalBasis(for: branchDirection)
            let branchLength = connection.length * 0.28
            let branchEnd = branchStart + basis.right * branchLength * 0.55 + basis.up * branchLength * 0.28
            let branchPoints = jaggedPoints(from: branchStart, to: branchEnd, seed: seed + 401, segments: 3)
            addLightningSegments(points: branchPoints, to: bolt, glowOpacity: 0.018, coreOpacity: 0.055)
        }

        return bolt
    }

    private func addLightningSegments(
        points: [SIMD3<Float>],
        to parent: Entity,
        glowOpacity: Float = 0.035,
        coreOpacity: Float = 0.10
    ) {
        guard points.count >= 2 else { return }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let glow = lineEntity(from: start, to: end, color: brandBlue, opacity: glowOpacity, radius: 0.0015)
            let core = lineEntity(from: start, to: end, color: .white, opacity: coreOpacity, radius: 0.00028)
            parent.addChild(glow)
            parent.addChild(core)
        }

        for point in points.dropFirst().dropLast() {
            let glowNode = ModelEntity(
                mesh: .generateSphere(radius: 0.0010),
                materials: [material(color: brandBlue, opacity: 0.0)]
            )
            glowNode.position = point
            parent.addChild(glowNode)

            let hotCore = ModelEntity(
                mesh: .generateSphere(radius: 0.0024),
                materials: [material(color: .white, opacity: 0.08)]
            )
            hotCore.position = point
            parent.addChild(hotCore)
        }
    }

    private func jaggedPoints(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        seed: Int,
        segments: Int? = nil
    ) -> [SIMD3<Float>] {
        let segmentCount = segments ?? 5 + Int(hashUnit(seed: seed, step: 0) * 3)
        let direction = simd_normalize(end - start)
        let basis = orthonormalBasis(for: direction)
        let amplitude = simd_distance(start, end) * 0.085

        var result: [SIMD3<Float>] = [start]
        result.reserveCapacity(segmentCount + 1)

        for index in 1..<segmentCount {
            let t = Float(index) / Float(segmentCount)
            let center = simd_mix(start, end, SIMD3<Float>(repeating: t))
            let envelope = sin(t * .pi)
            let horizontal = (hashSigned(seed: seed, step: index * 2 + 1)) * amplitude * envelope
            let vertical = (hashSigned(seed: seed, step: index * 2 + 2)) * amplitude * 0.55 * envelope
            let offset = basis.right * horizontal + basis.up * vertical
            result.append(center + offset)
        }

        result.append(end)
        return result
    }

    private func orthonormalBasis(for direction: SIMD3<Float>) -> (right: SIMD3<Float>, up: SIMD3<Float>) {
        let reference = abs(simd_dot(direction, SIMD3<Float>(0, 1, 0))) > 0.88
            ? SIMD3<Float>(1, 0, 0)
            : SIMD3<Float>(0, 1, 0)
        let right = simd_normalize(simd_cross(direction, reference))
        let up = simd_normalize(simd_cross(right, direction))
        return (right, up)
    }

    private func heroLightningConnections() -> [ConstellationConnection] {
        let eyeLevel = DomeLayout.defaultEyeLevel

        let heroIndices = nodePositions.indices.filter { index in
            let p = nodePositions[index]
            return p.z < -1.35
                && abs(p.x) < 1.20
                && abs(p.y - eyeLevel) < 0.90
        }

        var seen = Set<String>()
        var result: [ConstellationConnection] = []

        for index in heroIndices {
            let nearest = heroIndices
                .filter { $0 != index }
                .map { other in
                    (other, simd_distance(nodePositions[index], nodePositions[other]))
                }
                .sorted { $0.1 < $1.1 }
                .prefix(2)

            for (other, _) in nearest {
                let low = min(index, other)
                let high = max(index, other)
                let key = "\(low)-\(high)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                let start = nodePositions[index]
                let end = nodePositions[other]
                result.append(
                    ConstellationConnection(
                        start: start,
                        end: end,
                        midpoint: (start + end) / 2,
                        length: simd_distance(start, end),
                        seed: 10_000 + low * 101 + high
                    )
                )
            }
        }

        return result
    }

    private func ambientThirtyPercentConnections() -> [ConstellationConnection] {
        let eyeLevel = DomeLayout.defaultEyeLevel
        var result: [ConstellationConnection] = []

        for index in nodePositions.indices {
            let p = nodePositions[index]
            let isHero = p.z < -1.35
                && abs(p.x) < 1.20
                && abs(p.y - eyeLevel) < 0.90
            if isHero { continue }

            // Deterministic probability so the effect is stable between runs,
            // while still behaving like a 30% random strike chance per dot.
            guard hashUnit(seed: index + 1, step: 30_013) < 0.30 else { continue }

            let nearest = nodePositions.indices
                .filter { $0 != index }
                .map { other in
                    (other, simd_distance(p, nodePositions[other]))
                }
                .min { $0.1 < $1.1 }

            guard let (other, _) = nearest else { continue }
            let end = nodePositions[other]
            result.append(
                ConstellationConnection(
                    start: p,
                    end: end,
                    midpoint: (p + end) / 2,
                    length: simd_distance(p, end),
                    seed: 20_000 + index * 131 + other
                )
            )
        }

        return result
    }

    private func frontFacingConnections() -> [ConstellationConnection] {
        let eyeLevel = DomeLayout.defaultEyeLevel

        let front = connections.filter { connection in
            let p = connection.midpoint
            return p.z < -1.25
                && abs(p.x) < 1.45
                && abs(p.y - eyeLevel) < 1.05
        }
        .sorted { lhs, rhs in
            frontPriority(for: lhs) > frontPriority(for: rhs)
        }

        // Keep a healthy pool so repeated waves feel organic instead of
        // repeatedly flashing the same two links.
        if front.count >= 12 {
            return Array(front.prefix(30))
        }

        // Fallback for a future layout change: still prefer the most frontal
        // connections rather than allowing activity to disappear behind the user.
        return Array(
            connections
                .sorted { frontPriority(for: $0) > frontPriority(for: $1) }
                .prefix(24)
        )
    }

    private func frontPriority(for connection: ConstellationConnection) -> Float {
        let eyeLevel = DomeLayout.defaultEyeLevel
        let midpoint = connection.midpoint
        let lateralPenalty = abs(midpoint.x) * 1.65
        let verticalPenalty = abs(midpoint.y - eyeLevel) * 0.95
        let depthBonus = max(0, -midpoint.z)
        return depthBonus - lateralPenalty - verticalPenalty
    }

    private func makeEdges(for positions: [SIMD3<Float>]) -> [(SIMD3<Float>, SIMD3<Float>)] {
        var seen = Set<String>()
        var result: [(SIMD3<Float>, SIMD3<Float>)] = []

        for index in positions.indices {
            let nearest = positions.indices
                .filter { $0 != index }
                .map { ($0, simd_distance(positions[index], positions[$0])) }
                .sorted { $0.1 < $1.1 }
                .prefix(2)

            for (other, distance) in nearest where distance < 0.92 {
                let low = min(index, other)
                let high = max(index, other)
                let key = "\(low)-\(high)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                result.append((positions[index], positions[other]))
            }
        }

        return result.sorted {
            let left = simd_length($0.0) + simd_length($0.1)
            let right = simd_length($1.0) + simd_length($1.1)
            return left < right
        }
    }

    private func lineEntity(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        color: UIColor,
        opacity: Float,
        radius: Float
    ) -> ModelEntity {
        let vector = end - start
        let distance = max(simd_length(vector), 0.001)
        let line = ModelEntity(
            mesh: .generateCylinder(height: distance, radius: radius),
            materials: [material(color: color, opacity: opacity)]
        )
        line.position = (start + end) / 2

        let direction = simd_normalize(vector)
        let yAxis = SIMD3<Float>(0, 1, 0)
        let dot = simd_clamp(simd_dot(yAxis, direction), -1, 1)
        if dot < 0.9999 {
            let axis = simd_normalize(simd_cross(yAxis, direction))
            line.orientation = simd_quatf(angle: acos(dot), axis: axis)
        }
        return line
    }

    private func material(color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    private func interpolateColor(from: UIColor, to: UIColor, t: Float) -> UIColor {
        var fr: CGFloat = 0
        var fg: CGFloat = 0
        var fb: CGFloat = 0
        var fa: CGFloat = 0
        var tr: CGFloat = 0
        var tg: CGFloat = 0
        var tb: CGFloat = 0
        var ta: CGFloat = 0
        from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        let tt = CGFloat(t)
        return UIColor(
            red: fr + (tr - fr) * tt,
            green: fg + (tg - fg) * tt,
            blue: fb + (tb - fb) * tt,
            alpha: fa + (ta - fa) * tt
        )
    }

    private func hashUnit(seed: Int, step: Int) -> Float {
        let value = sin(Float(seed * 97 + step * 57) * 12.9898) * 43758.5453
        return value - floor(value)
    }

    private func hashSigned(seed: Int, step: Int) -> Float {
        hashUnit(seed: seed, step: step) * 2 - 1
    }

    private func easeInOut(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }
}

fileprivate struct WelcomeAttachment: View {
    let hasBegun: Bool
    let isVisible: Bool
    let onBegin: () -> Void
    let onExit: () -> Void

    private let blue = Color(red: 0.0, green: 145.0 / 255.0, blue: 1.0)

    var body: some View {
        VStack(spacing: 24) {
            NeuralMark()
                .frame(width: 112, height: 72)

            VStack(spacing: 10) {
                Text("Shared\nVisions")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(
                        LinearGradient(colors: [.white, blue.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text("The story of spatial computing,\ntold by the people who were there.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 420)
            }

            if hasBegun {
                ProgressView()
                    .controlSize(.large)
                    .tint(blue)
            } else {
                Button(action: onBegin) {
                    HStack(spacing: 13) {
                        Text("Begin")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(blue.opacity(0.88))
                            .shadow(color: blue.opacity(0.78), radius: 24)
                    )
                    .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
            }

            Button("Return to concepts", action: onExit)
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 36)
        .background {
            RoundedRectangle(cornerRadius: 38)
                .fill(.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 38)
                        .stroke(
                            LinearGradient(colors: [blue.opacity(0.78), .white.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.25
                        )
                )
        }
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 38))
        .shadow(color: blue.opacity(0.25), radius: 42)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.92)
        .animation(.easeOut(duration: 1.15), value: isVisible)
        .animation(.easeInOut(duration: 0.22), value: hasBegun)
    }
}

fileprivate struct NeuralMark: View {
    private let blue = Color(red: 0.0, green: 145.0 / 255.0, blue: 1.0)

    private let points: [CGPoint] = [
        .init(x: 10, y: 36), .init(x: 31, y: 13), .init(x: 56, y: 22),
        .init(x: 82, y: 9), .init(x: 101, y: 34), .init(x: 82, y: 61),
        .init(x: 54, y: 52), .init(x: 29, y: 63)
    ]

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 112
            let sy = size.height / 72
            func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * sx, y: p.y * sy) }

            let links = [(0,1),(1,2),(2,3),(3,4),(4,5),(5,6),(6,7),(7,0),(2,6),(0,6),(2,4)]
            for (a, b) in links {
                var path = Path()
                path.move(to: point(points[a]))
                path.addLine(to: point(points[b]))
                context.stroke(path, with: .color(blue.opacity(0.54)), lineWidth: 1.4)
            }

            for index in points.indices {
                let p = point(points[index])
                let r: CGFloat = 5.2
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(blue))
            }
        }
        .shadow(color: blue.opacity(0.9), radius: 12)
    }
}

#Preview {
    Concept011()
}
