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

    /// Mid tier of the bolt. Brand aqua (`77D6EE`), which also matches the
    /// cyan in the reference art.
    private let boltCyan = UIColor(red: 119.0 / 255.0, green: 214.0 / 255.0, blue: 238.0 / 255.0, alpha: 1.0)

    /// Core of the bolt. Pulled further toward cyan and away from white: a
    /// near-white core at this thickness blew out and flattened the channel
    /// into a drawn line.
    private let coreWhite = UIColor(red: 0.78, green: 0.94, blue: 1.0, alpha: 1.0)

    /// Concentric tiers making up a channel's cross-section, widest first.
    ///
    /// Four nested cylinders with a graduated opacity ramp stand in for a
    /// radial falloff. RealityKit gives no post-process bloom on visionOS and
    /// no control over anti-aliasing, and an `UnlitMaterial` cylinder has a
    /// hard geometric edge, so a ramp of nested tiers is the available way to
    /// soften it. A soft-edged textured ribbon would do better and is the
    /// real fix if this still reads as line art.
    ///
    /// Radii are in metres and chosen against the cluster's ~1.5m distance,
    /// where one device pixel is about 0.00038m of radius: roughly 3px core,
    /// 8px body, 16px outer, 35px haze.
    private var boltTiers: [(radius: Float, opacity: Float, color: UIColor)] {
        [
            (0.0135, 0.10, brandBlue),
            (0.0062, 0.17, brandBlue),
            (0.0031, 0.30, boltCyan),
            (0.0012, 0.68, coreWhite),
        ]
    }

    /// Fork cross-section: body and core only, and thinner. Forks should read
    /// as filaments beside the channel, and this keeps the entity count sane
    /// now that a bolt can carry a dozen of them.
    private var forkTiers: [(radius: Float, opacity: Float, color: UIColor)] {
        [
            (0.0020, 0.22, boltCyan),            (0.0008, 0.52, coreWhite),
        ]
    }

    private let root = Entity()
    private var built = false
    private var sequenceStarted = false
    private var nodes: [(dot: ModelEntity, halo: ModelEntity)] = []
    private var nodePositions: [SIMD3<Float>] = []

    /// Randomised once per controller — so once per entry into the space —
    /// and mixed into every bolt seed and every strike-selection decision.
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

    // MARK: Audio

    /// Dramatic swell under the whole intro, peaking as the title lands.
    private var swell: AudioFileResource?
    /// Spatialised crack, played from the bolt's own entity.
    private var nearThunder: AudioFileResource?
    private var farThunder: AudioFileResource?
    /// Quiet looping weather bed under the storm.
    private var stormBed: AudioFileResource?

    /// Carries the non-positional audio. Ambient rather than spatial so the
    /// swell sits around the viewer instead of coming from a point.
    private let audioHost = Entity()

    /// Throttle for thunder. A hero wave fires a dozen bolts inside a few
    /// hundred milliseconds, and a crack on each is both mush and expensive.
    private var lastThunder: Date = .distantPast

    /// Loads the four clips.
    ///
    /// Spatialisation is not set here. On visionOS the resource no longer
    /// carries an input mode — whether a sound is ambient or positional comes
    /// from the audio component on the entity that plays it, so `audioHost`
    /// gets `AmbientAudioComponent` and each bolt gets `SpatialAudioComponent`.
    private func loadAudio() async {
        // Non-fatal throughout: the sequence should run silently rather than
        // fail outright if an asset is missing.
        swell = try? await AudioFileResource(named: "intro-swell.wav")
        stormBed = try? await AudioFileResource(
            named: "storm-bed.wav",
            configuration: .init(shouldLoop: true)
        )
        nearThunder = try? await AudioFileResource(named: "thunder-near.wav")
        farThunder = try? await AudioFileResource(named: "thunder-far.wav")

        audioHost.components.set(AmbientAudioComponent(gain: -6))
        root.addChild(audioHost)
    }

    /// Starts the swell. Its plateau begins around 4.0s, which is close to
    /// when the title reveals, so the arrival and the title land together.
    private func startIntroAudio() {
        if let swell {
            audioHost.playAudio(swell)
        }
        if let stormBed {
            let bed = audioHost.playAudio(stormBed)
            bed.gain = -22
        }
    }

    /// Plays a crack from the bolt itself, so the sound arrives from the
    /// direction the viewer saw the flash.
    private func playThunder(on bolt: Entity, near: Bool) {
        guard let resource = near ? nearThunder : farThunder else { return }
        guard Date.now.timeIntervalSince(lastThunder) > 0.11 else { return }
        lastThunder = .now

        bolt.components.set(SpatialAudioComponent(gain: near ? -9 : -17))
        bolt.playAudio(resource)
    }

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
        await loadAudio()
        startIntroAudio()
        await animateBreathingDots()
        await compressToBluePoints()
        await animateConnectionSequence()
        onRevealTitle()
        startIdleBlueBreathing()
    }

    private func animateBreathingDots() async {
        // Step count and interval both trimmed — this is the pre-roll before
        // anything happens, and at 14 steps of 90ms it ran 2.6 seconds before
        // the first bolt.
        let steps = 10

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
            try? await Task.sleep(for: .milliseconds(70))
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
            try? await Task.sleep(for: .milliseconds(62))
        }
    }

    private func compressToBluePoints() async {
        let steps = 10
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
            try? await Task.sleep(for: .milliseconds(55))
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

        // Four hero waves, down from five. Each lights a different random
        // share of the cluster.
        for wave in 0..<4 {
            let waveHero = hero
                .shuffled()
                .prefix(max(2, Int(Float(hero.count) * Float.random(in: 0.5...0.85))))

            for (index, connection) in waveHero.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed &+ runSalt &+ wave * 211 &+ index * 19,
                    delayMilliseconds: Int.random(in: 0...26) + index * 14,
                    includeBranch: true
                )
            }

            // Peripheral strikes split across waves so the room stays alive
            // between hero flashes instead of everything firing at once.
            let ambientSlice = ambient.shuffled().prefix(max(1, ambient.count / 4))

            for (index, connection) in ambientSlice.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed &+ runSalt &+ wave * 307 &+ index * 23,
                    delayMilliseconds: 70 + index * 26 + Int.random(in: 0...40),
                    includeBranch: Bool.random()
                )
            }

            try? await Task.sleep(for: .milliseconds(Int.random(in: 240...320)))
        }

        // One last dense front flash immediately before the title fades in.
        for (index, connection) in hero.shuffled().enumerated() {
            spawnLightningBolt(
                for: connection,
                seed: connection.seed &+ runSalt &+ 9001 &+ index * 31,
                delayMilliseconds: index * 10,
                includeBranch: true
            )
        }

        try? await Task.sleep(for: .milliseconds(180))
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
            // Branching strikes are the hero ones, so they get the near crack.
            playThunder(on: bolt, near: includeBranch)

            // Hold the brightest frame just long enough to register.
            try? await Task.sleep(for: .milliseconds(Int.random(in: 28...46)))

            // Re-strikes. A real channel fires several times down roughly the
            // same path, each a little different — that flicker is as much of
            // the organic feel as the geometry is, and a single static stroke
            // is what makes one look drawn.
            let restrikes = Int.random(in: 1...2)
            for strike in 0..<restrikes {
                let repeated = makeLightningBolt(
                    for: connection,
                    seed: seed &+ 5100 &+ strike * 71,
                    includeBranch: includeBranch && strike == 0,
                    intensity: 0.85
                )
                root.addChild(repeated)
                bolt.components.set(OpacityComponent(opacity: 0.35))
                try? await Task.sleep(for: .milliseconds(Int.random(in: 22...34)))
                repeated.removeFromParent()
                bolt.components.set(OpacityComponent(opacity: 1))
                try? await Task.sleep(for: .milliseconds(Int.random(in: 14...24)))
            }

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

    /// A bright point with a soft halo where a bolt attaches. Scaled to the
    /// thickened channel so it reads as the source rather than a stray dot.
    private func addSourceFlash(at position: SIMD3<Float>, to parent: Entity) {
        let core = ModelEntity(
            mesh: .generateSphere(radius: 0.011),
            materials: [material(color: coreWhite, opacity: 0.95)]
        )
        core.position = position
        parent.addChild(core)

        let halo = ModelEntity(
            mesh: .generateSphere(radius: 0.040),
            materials: [material(color: brandBlue, opacity: 0.22)]
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
        addBoltSegments(points: points, to: bolt, intensity: intensity, widthSeed: seed)

        if includeBranch {
            // Vary how heavily forked each strike is. A storm where every bolt
            // carries the same fork tree reads as a repeated asset, which is
            // the thing this whole pass is trying to avoid.
            let generations = hashUnit(seed: seed, step: 77) < 0.45 ? 2 : 1

            for (branchIndex, branch) in boltBranches(
                along: points,
                seed: seed,
                generation: generations,
                intensity: intensity
            ).enumerated() {
                addBoltSegments(
                    points: branch.points,
                    to: bolt,
                    intensity: branch.intensity,
                    slim: true,
                    widthSeed: seed &+ 7000 &+ branchIndex * 13
                )
            }
        }

        return bolt
    }

    /// Draws a path as a tapering channel of nested tiers.
    ///
    /// Two things here matter more than the tier radii, and their absence is
    /// why earlier passes still read as line art:
    ///
    /// **Taper.** A real channel is widest where it attaches and narrows
    /// toward the tip. Every segment being the same width is the strongest
    /// single cue that something was drawn rather than discharged.
    ///
    /// **Per-segment variation.** Tapering uniformly still looks machined, so
    /// each segment's width is jittered around the taper curve.
    private func addBoltSegments(
        points: [SIMD3<Float>],
        to parent: Entity,
        intensity: Float,
        slim: Bool = false,
        widthSeed: Int = 0
    ) {
        guard points.count >= 2 else { return }

        let tiers = slim ? forkTiers : boltTiers
        let lastIndex = Float(max(points.count - 2, 1))

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]

            let t = Float(index) / lastIndex
            // Forks taper harder, so they thin to filaments rather than
            // stopping abruptly.
            let taper = 1 - (slim ? 0.68 : 0.60) * t
            let jitter = 0.84 + hashUnit(seed: widthSeed, step: 500 + index) * 0.32
            let width = taper * jitter

            for tier in tiers {
                parent.addChild(lineEntity(
                    from: start,
                    to: end,
                    color: tier.color,
                    opacity: tier.opacity * intensity,
                    radius: tier.radius * width
                ))
            }
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

    /// Connections through the dense central cluster, rebuilt fresh on every
    /// run of the sequence.
    ///
    /// The earlier version was the reason the same dots lit every single time.
    /// `heroIndices` is a geometric filter over fixed node positions, so the
    /// candidate set never changed, and each node was paired with its *two
    /// nearest* neighbours, so the pairs never changed either. Salting the
    /// bolt seeds varied the shapes but not the endpoints, and shuffling the
    /// draw order did nothing once the final flash fired every connection
    /// anyway.
    ///
    /// Now a random share of the cluster takes part, and each participant
    /// picks a random partner from among its nearest few rather than always
    /// the closest. The cluster still sits in front of the viewer, so the
    /// lightning stays where it will be seen.
    private func heroLightningConnections() -> [ConstellationConnection] {
        let eyeLevel = DomeLayout.defaultEyeLevel

        let heroIndices = nodePositions.indices.filter { index in
            let p = nodePositions[index]
            return p.z < -1.35
                && abs(p.x) < 1.20
                && abs(p.y - eyeLevel) < 0.90
        }

        guard heroIndices.count >= 4 else { return [] }

        // Only part of the cluster participates, so a given dot is often
        // absent entirely rather than merely firing later than before.
        let participants = heroIndices
            .shuffled()
            .prefix(max(4, Int(Double(heroIndices.count) * Double.random(in: 0.5...0.75))))

        var seen = Set<Int>()
        var result: [ConstellationConnection] = []

        for index in participants {
            // Pick from among the nearest few rather than locking onto the
            // closest, so the network rewires between runs.
            let candidates = heroIndices
                .filter { $0 != index }
                .map { (other: $0, distance: simd_distance(nodePositions[index], nodePositions[$0])) }
                .sorted { $0.distance < $1.distance }
                .prefix(5)

            guard let chosen = candidates.randomElement() else { continue }

            let low = min(index, chosen.other)
            let high = max(index, chosen.other)
            // Pair key as an Int rather than a formatted string — this runs
            // over every participant on every sequence.
            let key = low * 100_000 + high
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let start = nodePositions[index]
            let end = nodePositions[chosen.other]
            result.append(
                ConstellationConnection(
                    start: start,
                    end: end,
                    midpoint: (start + end) / 2,
                    length: simd_distance(start, end),
                    seed: 10_000 &+ runSalt &+ low * 101 &+ high
                )
            )
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

            // A different ~30% of the periphery participates on each run.
            guard Double.random(in: 0..<1) < 0.30 else { continue }

            // Same reasoning as the hero cluster: pick among the nearest few
            // so peripheral links are not identical run to run either.
            let candidates = nodePositions.indices
                .filter { $0 != index }
                .map { (other: $0, distance: simd_distance(p, nodePositions[$0])) }
                .sorted { $0.distance < $1.distance }
                .prefix(4)

            guard let chosen = candidates.randomElement() else { continue }
            let end = nodePositions[chosen.other]
            result.append(
                ConstellationConnection(
                    start: p,
                    end: end,
                    midpoint: (p + end) / 2,
                    length: simd_distance(p, end),
                    seed: 20_000 &+ runSalt &+ index * 131 &+ chosen.other
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
