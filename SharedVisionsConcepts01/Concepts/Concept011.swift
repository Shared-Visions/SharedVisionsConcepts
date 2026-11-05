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

    /// Mid tier of the bolt, between the blue haze and the white core. Brand
    /// aqua (`77D6EE`), which also matches the cyan in the reference art.
    private let boltCyan = UIColor(red: 119.0 / 255.0, green: 214.0 / 255.0, blue: 238.0 / 255.0, alpha: 1.0)

    private let root = Entity()
    private var built = false
    private var sequenceStarted = false
    private var nodes: [(dot: ModelEntity, halo: ModelEntity)] = []
    private var nodePositions: [SIMD3<Float>] = []

    /// Randomised once per controller — so once per entry into the space —
    /// and mixed into every bolt seed and every strike-selection decision.
    ///
    /// Without this the whole sequence was byte-identical on every launch:
    /// the same dots lit in the same order with the same bolt shapes, because
    /// `ConstellationConnection.seed` and the wave offsets are all fixed.
    /// Determinism is useful for comparing screenshots across review rounds,
    /// but here it made the intro read as a canned animation.
    ///
    /// Kept to four digits deliberately. `hashUnit` feeds its seed through
    /// `sin(Float(...))`, which loses precision once the argument gets large,
    /// so the salt stays in the same magnitude as the existing seeds.
    private let runSalt = Int.random(in: 0..<10_000)
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
        // The dense "hero" network is concentrated directly behind and around
        // the title-card area so the lightning is impossible to miss
        // in-headset. Every other dot gets a ~30% chance to throw one strike
        // to its nearest neighbour during the sequence.
        let hero = heroLightningConnections()
        let ambient = ambientThirtyPercentConnections()

        guard !hero.isEmpty else { return }

        // Five hero waves. Each lights a different random share of the central
        // cluster rather than all of it — lighting every connection on every
        // wave is what made the sequence read as one animation on loop
        // instead of a storm.
        for wave in 0..<5 {
            let waveHero = hero
                .shuffled()
                .prefix(max(2, Int(Float(hero.count) * Float.random(in: 0.5...0.85))))

            for (index, connection) in waveHero.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed &+ runSalt &+ wave * 211 &+ index * 19,
                    delayMilliseconds: Int.random(in: 0...40) + index * 24,
                    includeBranch: true
                )
            }

            // Peripheral strikes split across waves so the room stays alive
            // between hero flashes instead of everything firing at once.
            let ambientSlice = ambient.shuffled().prefix(max(1, ambient.count / 5))

            for (index, connection) in ambientSlice.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed &+ runSalt &+ wave * 307 &+ index * 23,
                    delayMilliseconds: 120 + index * 42 + Int.random(in: 0...60),
                    includeBranch: Bool.random()
                )
            }

            try? await Task.sleep(for: .milliseconds(Int.random(in: 360...470)))
        }

        // One last dense front flash immediately before the title fades in.
        for (index, connection) in hero.shuffled().enumerated() {
            spawnLightningBolt(
                for: connection,
                seed: connection.seed &+ runSalt &+ 9001 &+ index * 31,
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

            // The strike follows the shape of the pixel-art reference: a
            // flickering leader, a bright return stroke, then a fade that
            // breaks the channel into fragments. Dimming uniformly from a
            // single static bolt is what made the old version read as a
            // drawn line rather than a discharge.

            // Leader: coarse path, no forks, dim. Appears and vanishes before
            // the eye resolves it, which is what makes the main stroke land.
            let leader = makeLightningBolt(
                for: connection,
                seed: seed,
                includeBranch: false,
                intensity: 0.4,
                depth: 2
            )
            root.addChild(leader)
            try? await Task.sleep(for: .milliseconds(Int.random(in: 20...34)))
            leader.removeFromParent()
            try? await Task.sleep(for: .milliseconds(Int.random(in: 14...28)))

            // Return stroke: full subdivision, forks, full intensity.
            let bolt = makeLightningBolt(
                for: connection,
                seed: seed,
                includeBranch: includeBranch,
                intensity: 1
            )
            // A hot point where the channel attaches. In the reference art the
            // bolt leaves a glowing source rather than simply starting.
            addSourceFlash(at: connection.start, to: bolt)
            root.addChild(bolt)

            // Hold the brightest frame just long enough to register.
            try? await Task.sleep(for: .milliseconds(Int.random(in: 28...46)))

            // Decay. Each step dims the whole bolt and kills more of its
            // segments, so the channel comes apart as it dies.
            for remaining in [0.7, 0.45, 0.22, 0.0] as [Float] {
                bolt.components.set(OpacityComponent(opacity: remaining))
                fragmentBolt(bolt, keeping: remaining, seed: seed &+ Int(remaining * 1000))
                try? await Task.sleep(for: .milliseconds(Int.random(in: 22...34)))
            }

            bolt.removeFromParent()
        }
    }

    /// A bright point with a soft halo where a bolt attaches.
    private func addSourceFlash(at position: SIMD3<Float>, to parent: Entity) {
        let core = ModelEntity(
            mesh: .generateSphere(radius: 0.0055),
            materials: [material(color: .white, opacity: 0.9)]
        )
        core.position = position
        parent.addChild(core)

        let halo = ModelEntity(
            mesh: .generateSphere(radius: 0.019),
            materials: [material(color: brandBlue, opacity: 0.12)]
        )
        halo.position = position
        parent.addChild(halo)
    }

    /// Disables a growing random share of a bolt's segments so it breaks into
    /// pieces as it fades rather than dimming as one solid line.
    private func fragmentBolt(_ bolt: Entity, keeping fraction: Float, seed: Int) {
        for (index, segment) in bolt.children.enumerated() {
            segment.isEnabled = hashUnit(seed: seed, step: index) < fraction
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
        includeBranch: Bool,
        intensity: Float = 1,
        depth: Int = 4
    ) -> Entity {
        let bolt = Entity()
        let points = displacedBoltPath(
            from: connection.start,
            to: connection.end,
            seed: seed,
            depth: depth
        )
        addBoltSegments(points: points, to: bolt, intensity: intensity)

        if includeBranch {
            // Vary how heavily forked each strike is. A storm where every bolt
            // carries the same fork tree reads as a repeated asset, which is
            // the thing this whole pass is trying to avoid.
            let generations = hashUnit(seed: seed, step: 77) < 0.45 ? 2 : 1

            for branch in boltBranches(
                along: points,
                seed: seed,
                generation: generations,
                intensity: intensity
            ) {
                addBoltSegments(
                    points: branch.points,
                    to: bolt,
                    intensity: branch.intensity,
                    slim: true
                )
            }
        }

        return bolt
    }

    /// Draws a path as concentric tiers: a wide dim blue haze, a tighter cyan
    /// body, and a thin near-opaque white core.
    ///
    /// Stacking translucent emissive layers approximates the additive bloom of
    /// a real bolt, which is what sells it as light rather than as geometry.
    /// An earlier two-tier version ran the core at 0.10 opacity, so the
    /// brightest part of a lightning strike was nearly transparent.
    ///
    /// `slim` drops the haze tier and thins the rest, for forks. They should
    /// read as fine filaments beside the channel, and it keeps the entity
    /// count sane now that a bolt can carry a dozen of them.
    private func addBoltSegments(
        points: [SIMD3<Float>],
        to parent: Entity,
        intensity: Float,
        slim: Bool = false
    ) {
        guard points.count >= 2 else { return }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]

            if !slim {
                parent.addChild(lineEntity(
                    from: start, to: end,
                    color: brandBlue, opacity: 0.085 * intensity, radius: 0.0050
                ))
            }

            parent.addChild(lineEntity(
                from: start, to: end,
                color: boltCyan,
                opacity: (slim ? 0.24 : 0.30) * intensity,
                radius: slim ? 0.0009 : 0.0017
            ))
            parent.addChild(lineEntity(
                from: start, to: end,
                color: .white,
                opacity: (slim ? 0.80 : 0.95) * intensity,
                radius: slim ? 0.00032 : 0.00055
            ))
        }
    }

    /// Builds a bolt path by **recursive midpoint displacement**: displace a
    /// segment's midpoint perpendicular by a random amount, then recurse on
    /// both halves with the displacement halved.
    ///
    /// This is what the previous version got wrong. It placed points at even
    /// intervals along the line and offset each under a sine envelope, which
    /// gives a regular zigzag — every kink the same size, tapering to nothing
    /// at the ends. Real lightning is self-similar: a large deviation near the
    /// middle carries smaller deviations along its length, which is precisely
    /// what halving the offset at each level produces.
    ///
    /// Displacement is perpendicular to the *current* segment rather than to
    /// the overall bolt, so each subdivision inherits its parent's direction
    /// instead of everything leaning the same way.
    ///
    /// `roughness` and `falloff` were picked by measuring mean turn angle
    /// across a parameter sweep, not by eye. Halving the offset per level —
    /// the textbook choice — holds the turn angle near 10°, which renders as a
    /// gentle wave rather than a bolt. A 0.65 falloff keeps enough fine detail
    /// to read as jagged while the path still stays close to the straight line
    /// between its endpoints, which matters here because these bolts have to
    /// read as *connections* between two constellation nodes.
    ///
    /// Measured over eight seeds at depth 4: roughness 0.13 gives a ~34° mean
    /// turn and strays under 9% of the bolt's length. Raising it to 0.18 pushes
    /// the turn past 44° and starts to look like scribble; dropping to 0.10
    /// flattens back toward a wave.
    ///
    /// Note these numbers are for the 3D case specifically. The perpendicular
    /// plane has two dimensions, so consecutive displacements can turn
    /// out-of-plane and compound — the same roughness that gives 34° on paper
    /// gives 44° here.
    private func displacedBoltPath(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        seed: Int,
        depth: Int = 4,
        roughness: Float = 0.13,
        falloff: Float = 0.65
    ) -> [SIMD3<Float>] {
        var points = [start, end]
        var offset = simd_distance(start, end) * roughness
        var step = 0

        for _ in 0..<depth {
            var refined: [SIMD3<Float>] = [points[0]]
            refined.reserveCapacity(points.count * 2 - 1)

            for index in 0..<(points.count - 1) {
                let a = points[index]
                let b = points[index + 1]
                var mid = (a + b) / 2

                // Degenerate segments have no meaningful perpendicular, so
                // leave their midpoint where it is rather than normalising a
                // near-zero vector.
                if simd_distance(a, b) > 0.0005 {
                    let basis = orthonormalBasis(for: simd_normalize(b - a))
                    // One random direction within the perpendicular plane and
                    // one signed magnitude. Displacing both axes
                    // independently instead would give a combined magnitude
                    // around 1.5x `offset`, making roughness mean something
                    // different in 3D than it does on paper.
                    let bearing = hashUnit(seed: seed, step: step) * 2 * .pi
                    let magnitude = hashSigned(seed: seed, step: step + 1) * offset
                    let direction = basis.right * cos(bearing) + basis.up * sin(bearing)
                    mid += direction * magnitude
                }
                step += 2

                refined.append(mid)
                refined.append(b)
            }

            points = refined
            offset *= falloff
        }

        return points
    }

    /// A forked child bolt: shorter than its parent, angled away from it, and
    /// dimmer so forks read as secondary rather than competing with the main
    /// channel.
    private struct BoltBranch {
        let points: [SIMD3<Float>]
        let intensity: Float
    }

    /// Spawns forks at split points along a path.
    ///
    /// Shaped from the reference art, where bolts carry many forks clustered
    /// toward the source and thinning toward the tip, each trailing along the
    /// parent's direction rather than stabbing out sideways. An earlier pass
    /// with one or two near-perpendicular forks read as a lightning *symbol*
    /// rather than a discharge.
    ///
    /// `generation` bounds the recursion, and fork count drops with it: every
    /// branch multiplies the segment count, so an unbounded version is a
    /// performance problem long before it is a visual one.
    private func boltBranches(
        along points: [SIMD3<Float>],
        seed: Int,
        generation: Int,
        intensity: Float
    ) -> [BoltBranch] {
        guard generation > 0, points.count >= 5 else { return [] }

        var result: [BoltBranch] = []
        let forkCount = generation >= 2
            ? 3 + Int(hashUnit(seed: seed, step: 900) * 2.99)
            : 1 + Int(hashUnit(seed: seed, step: 901) * 1.99)

        for fork in 0..<forkCount {
            let interior = points.count - 2
            guard interior >= 2 else { continue }

            // Squaring the pick biases fork origins toward the start of the
            // channel, which is where the reference bolts branch most.
            let bias = hashUnit(seed: seed, step: 950 + fork)
            let pick = 1 + Int(bias * bias * Float(interior - 1))
            let origin = points[pick]

            let ahead = points[min(pick + 1, points.count - 1)]
            let behind = points[max(pick - 1, 0)]
            guard simd_distance(ahead, behind) > 0.0005 else { continue }
            let forward = simd_normalize(ahead - behind)
            let basis = orthonormalBasis(for: forward)

            // 15 to 45 degrees off the parent, so forks trail alongside the
            // main channel instead of shooting out at right angles.
            let angle = 0.26 + hashUnit(seed: seed, step: 920 + fork) * 0.52
            let side: Float = hashSigned(seed: seed, step: 930 + fork) >= 0 ? 1 : -1
            let roll = hashUnit(seed: seed, step: 960 + fork) * 2 * .pi
            // Spread forks around the channel rather than confining them to
            // one plane, which looks flat from the side in a 360 space.
            let lateral = basis.right * cos(roll) + basis.up * sin(roll)
            let direction = simd_normalize(forward * cos(angle) + lateral * side * sin(angle))

            let remaining = simd_distance(origin, points[points.count - 1])
            // Each generation is a shorter stub than the last, so the fork
            // tree tapers out instead of rivalling the channel it came from.
            let reach = 0.22 + hashUnit(seed: seed, step: 940 + fork) * 0.24
            let length = max(remaining * reach, 0.012)

            let childPoints = displacedBoltPath(
                from: origin,
                to: origin + direction * length,
                seed: seed &+ 1700 &+ fork * 31,
                depth: generation >= 2 ? 2 : 1
            )
            let childIntensity = intensity * 0.5

            result.append(BoltBranch(points: childPoints, intensity: childIntensity))
            result.append(contentsOf: boltBranches(
                along: childPoints,
                seed: seed &+ 2300 &+ fork * 17,
                generation: generation - 1,
                intensity: childIntensity
            ))
        }

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

            // Mixed with the run salt so a different ~30% of the periphery
            // participates on each entry into the space.
            guard hashUnit(seed: index + 1 + runSalt, step: 30_013) < 0.30 else { continue }

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
