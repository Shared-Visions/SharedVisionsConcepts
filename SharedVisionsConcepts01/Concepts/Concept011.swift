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
import OSLog

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

    private let audioLog = Logger(subsystem: "com.sharedvisions.concepts", category: "Concept011Audio")

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

    /// Connections with a strike currently in flight, so the same pair of
    /// dots is never lit twice at once.
    private var activeConnections = Set<Int>()

    /// Where the viewer's head is, for cylindrical billboarding.
    ///
    /// The node field is built with `DomeLayout`'s default centre, which is
    /// `(0, defaultEyeLevel, 0)` — the viewer stands at the centre of their
    /// own dome by construction. So the view position is known without
    /// querying head pose through ARKit at all.
    private var viewerPosition: SIMD3<Float> {
        SIMD3<Float>(0, DomeLayout.defaultEyeLevel, 0)
    }

    /// Loads the four clips.
    ///
    /// Spatialisation is not set here. On visionOS the resource no longer
    /// carries an input mode — whether a sound is ambient or positional comes
    /// from the audio component on the entity that plays it, so `audioHost`
    /// gets `AmbientAudioComponent` and each bolt gets `SpatialAudioComponent`.
    private func loadAudio() async {
        // Loads are non-fatal — the sequence should run silently rather than
        // fail outright — but they are logged. A capture of the previous
        // build showed a flat -55 dBFS track with no envelope at all, which
        // is either a load failure or a recording that never captured app
        // audio. `try?` alone made those two indistinguishable.
        do {
            swell = try await AudioFileResource(named: "intro-swell.wav")
            stormBed = try await AudioFileResource(
                named: "storm-bed.wav",
                configuration: .init(shouldLoop: true)
            )
            nearThunder = try await AudioFileResource(named: "thunder-near.wav")
            farThunder = try await AudioFileResource(named: "thunder-far.wav")
            audioLog.info("Concept011 audio loaded: swell, bed, near, far")
        } catch {
            audioLog.error("Concept011 audio failed to load: \(error.localizedDescription, privacy: .public)")
        }

        audioHost.components.set(AmbientAudioComponent(gain: -6))
        root.addChild(audioHost)
    }

    /// Starts the swell. Its plateau begins around 4.0s, which is close to
    /// when the title reveals, so the arrival and the title land together.
    private func startIntroAudio() {
        guard swell != nil || stormBed != nil else {
            audioLog.error("Concept011 startIntroAudio: no resources available")
            return
        }
        if let swell {
            audioHost.playAudio(swell)
            audioLog.info("Concept011 swell started")
        }
        if let stormBed {
            let bed = audioHost.playAudio(stormBed)
            bed.gain = -22
        }
    }

    /// Plays a crack from the bolt itself, so the sound arrives from the
    /// direction the viewer saw the flash.
    /// Plays a crack from the strike's own position in the room.
    ///
    /// This was broken, and subtly. A ribbon's vertices are world-space, so
    /// `bolt.root` keeps an identity transform at the origin — attaching
    /// `SpatialAudioComponent` there put every crack at the centre of the
    /// room, dead ahead, no matter where its bolt actually was. The thunder
    /// was spatialised the whole time; it just had one position.
    ///
    /// The emitter is now its own child entity placed at the strike, so a
    /// bolt behind the viewer cracks behind them.
    private func playThunder(at position: SIMD3<Float>, on parent: Entity, near: Bool) {
        guard let resource = near ? nearThunder : farThunder else { return }
        // Loosened from 110ms: with strikes spread around the viewer, several
        // cracks at once read as a storm rather than as mush.
        guard Date.now.timeIntervalSince(lastThunder) > 0.07 else { return }
        lastThunder = .now

        let emitter = Entity()
        emitter.position = position
        emitter.components.set(SpatialAudioComponent(gain: near ? -6 : -14))
        parent.addChild(emitter)
        emitter.playAudio(resource)
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
        // Every link, ordered by how far it sits from straight ahead, so the
        // storm can be steered from "all around you" to "right in front".
        let pool = (heroLightningConnections() + ambientThirtyPercentConnections())
            .map { (connection: $0, offAxis: offAxisDistance(for: $0)) }
            .sorted { $0.offAxis > $1.offAxis }          // outermost first
            .map(\.connection)

        guard pool.count >= 6 else { return }

        // --- Phase A: scatter -------------------------------------------
        // Isolated sparks anywhere on the dome, behind the viewer included,
        // drawn from the whole pool at random. The point is that the storm
        // has no location yet — it is all around and nothing is in front.
        for pass in 0..<3 {
            let sparks = pool.shuffled().prefix(Int.random(in: 4...7))
            for (index, connection) in sparks.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed &+ runSalt &+ pass * 97 &+ index * 29,
                    delayMilliseconds: Int.random(in: 0...180),
                    // Scattered sparks stay simple; the forked ones come later
                    // so the escalation has somewhere to go.
                    includeBranch: Bool.random() && Bool.random()
                )
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 270...360)))
        }

        // --- Phase B: coalesce forward, accelerating --------------------
        // Windows slide from the periphery to dead ahead while the gap
        // between waves shortens, so the storm both closes in and speeds up.
        let windows: [(lower: Double, upper: Double, gap: Int, stagger: Int)] = [
            (0.55, 1.00, 300, 14),
            (0.38, 0.82, 235, 11),
            (0.20, 0.60, 175, 9),
            (0.08, 0.40, 130, 7),
            (0.00, 0.24,  95, 5),
        ]

        for (wave, window) in windows.enumerated() {
            let lower = Int(Double(pool.count) * window.lower)
            let upper = Int(Double(pool.count) * window.upper)
            guard upper > lower else { continue }

            let slice = Array(pool[lower..<upper])
                .shuffled()
                .prefix(max(3, Int(Double(upper - lower) * Double.random(in: 0.68...0.92))))

            for (index, connection) in slice.enumerated() {
                spawnLightningBolt(
                    for: connection,
                    seed: connection.seed &+ runSalt &+ wave * 211 &+ index * 19,
                    delayMilliseconds: Int.random(in: 0...22) + index * window.stagger,
                    // Fork the nearer waves richly; distant strikes read as
                    // silhouettes and the detail is wasted on them.
                    includeBranch: wave >= 2 || Bool.random()
                )
            }

            try? await Task.sleep(for: .milliseconds(window.gap))
        }

        // --- Phase C: front crescendo ----------------------------------
        // The innermost third, fired almost together, directly where the
        // title is about to appear.
        let front = Array(pool.suffix(max(3, pool.count / 3))).shuffled()
        for (index, connection) in front.enumerated() {
            spawnLightningBolt(
                for: connection,
                seed: connection.seed &+ runSalt &+ 9001 &+ index * 31,
                delayMilliseconds: index * 6,
                includeBranch: true
            )
        }

        try? await Task.sleep(for: .milliseconds(240))
    }

    /// How far a connection sits from straight ahead, in metres.
    ///
    /// Measured against the point directly in front of the viewer, so larger
    /// means further round toward the sides and behind — which is what lets
    /// the sequence march from everywhere to dead ahead.
    private func offAxisDistance(for connection: ConstellationConnection) -> Float {
        let ahead = SIMD3<Float>(0, DomeLayout.defaultEyeLevel, -1.6)
        return simd_distance(connection.midpoint, ahead)
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

            // One strike at a time per connection. Overlapping strikes on the
            // same pair of dots just read as a brighter static shape, which is
            // the opposite of what they are for.
            guard !activeConnections.contains(connection.seed) else { return }
            activeConnections.insert(connection.seed)
            defer { activeConnections.remove(connection.seed) }

            // --- Competing leaders -------------------------------------
            // A real strike puts out several probing branches and abandons
            // all but the one that arrives first. Running a single leader
            // down the final path, as this did before, has it backwards: the
            // winner is only known in hindsight.
            let contenders = makeLeaders(for: connection, seed: seed)
            for leader in contenders.entities {
                root.addChild(leader)
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 30...44)))

            // All but the winner die. The survivor is the one that got
            // nearest the target, which is the physical criterion too.
            for (index, leader) in contenders.entities.enumerated() where index != contenders.winner {
                leader.removeFromParent()
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 12...20)))
            contenders.entities[contenders.winner].removeFromParent()

            // --- Return stroke -----------------------------------------
            let bolt = makeBoltShapes(
                for: connection,
                seed: seed,
                includeBranch: includeBranch,
                intensity: 1
            )
            addSourceFlash(at: connection.start, to: bolt.root)
            root.addChild(bolt.root)
            playThunder(at: connection.midpoint, on: bolt.root, near: includeBranch)

            // --- Writhe ------------------------------------------------
            // Cycle shapes at roughly 20Hz while the channel is lit. This is
            // the cheap half of looking alive: the geometry is already built,
            // so each step is two `isEnabled` writes.
            let litSteps = Int.random(in: 5...8)
            for step in 0..<litSteps {
                bolt.show(step % bolt.shapes.count)
                try? await Task.sleep(for: .milliseconds(Int.random(in: 42...58)))
            }

            // --- Decay -------------------------------------------------
            for remaining in [0.62, 0.34, 0.14, 0.0] as [Float] {
                bolt.root.components.set(OpacityComponent(opacity: remaining))
                try? await Task.sleep(for: .milliseconds(Int.random(in: 20...30)))
            }

            bolt.root.removeFromParent()
        }
    }

    /// Several short probing leaders from the strike's origin, plus which one
    /// wins.
    ///
    /// Each heads roughly toward the target but with a wide angular spread
    /// and a short reach, so they fan out. The winner is whichever ends up
    /// closest to the target.
    private func makeLeaders(
        for connection: ConstellationConnection,
        seed: Int
    ) -> (entities: [Entity], winner: Int) {
        let count = Int.random(in: 3...5)
        let span = connection.end - connection.start
        let distance = simd_length(span)
        guard distance > 1e-5 else { return ([], 0) }

        let forward = simd_normalize(span)
        let basis = orthonormalBasis(for: forward)

        var entities: [Entity] = []
        var bestIndex = 0
        var bestDistance = Float.greatestFiniteMagnitude

        for index in 0..<count {
            // Fan of up to ~40 degrees, reaching 45-80% of the way across.
            let angle = Float.random(in: -0.70...0.70)
            let roll = Float.random(in: 0..<(2 * .pi))
            let lateral = basis.right * cos(roll) + basis.up * sin(roll)
            let direction = simd_normalize(forward * cos(angle) + lateral * sin(angle))
            let reach = distance * Float.random(in: 0.45...0.80)
            let tip = connection.start + direction * reach

            let gap = simd_distance(tip, connection.end)
            if gap < bestDistance {
                bestDistance = gap
                bestIndex = index
            }

            let probe = Entity()
            let points = displacedBoltPath(
                from: connection.start,
                to: tip,
                seed: seed &+ 3300 &+ index * 47,
                depth: 2,
                roughness: 0.17
            )
            addChannel(
                points: points,
                to: probe,
                intensity: 0.30,
                widthSeed: seed &+ 3400 &+ index,
                slim: true
            )
            entities.append(probe)
        }

        return (entities, bestIndex)
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

    // MARK: Ribbon rendering

    /// Soft-edged falloff texture for the bolt ribbons, built once.
    ///
    /// The falloff is written into **both** luminance and alpha. Alpha alone
    /// would depend on how `UnlitMaterial` blends a textured tint; luminance
    /// alone is enough here anyway, because the space is pitch black, so a
    /// ribbon fading to black reads as fading to nothing.
    /// `@ObservationIgnored` so it stays a stored property — `@Observable`
    /// rewrites stored properties into computed ones, and `lazy` cannot apply
    /// to a computed property.
    @ObservationIgnored
    private lazy var ribbonTexture: TextureResource? = {
        let width = 64
        let height = 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        for x in 0..<width {
            // Gaussian across the ribbon's width: opaque white core, falling
            // to transparent black at both edges.
            let u = (Double(x) / Double(width - 1)) * 2 - 1
            let v = exp(-u * u * 5.5)
            context.setFillColor(red: v, green: v, blue: v, alpha: v)
            context.fill(CGRect(x: x, y: 0, width: 1, height: height))
        }

        guard let image = context.makeImage() else { return nil }
        return try? TextureResource.generate(from: image, options: .init(semantic: .color))
    }()

    /// Builds a viewer-facing ribbon along a path.
    ///
    /// This is *cylindrical billboarding*: each quad faces the viewer but
    /// rotates only about the beam's own axis, so the strip stays continuous.
    /// Billboarding each quad freely — the obvious approach — pivots them
    /// about their own centres and tears the chain apart.
    ///
    /// Two things make it cheap. The viewer sits at the dome's centre by
    /// construction, so the view direction is `domeCenter - point` and no
    /// head-pose query is needed. And a bolt lives about 250ms, far too short
    /// for the viewer to move enough to break the illusion, so the ribbon is
    /// oriented once at spawn and never updated.
    ///
    /// One ribbon replaces a per-segment stack of cylinders: a channel that
    /// cost 64 entities is now 1 mesh, which is what makes reshaping during
    /// the strike affordable at all.
    private func ribbonEntity(
        points: [SIMD3<Float>],
        halfWidth: Float,
        taperTo: Float,
        color: UIColor,
        opacity: Float,
        widthSeed: Int
    ) -> ModelEntity? {
        guard points.count >= 2, let texture = ribbonTexture else { return nil }

        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity(points.count * 2)
        uvs.reserveCapacity(points.count * 2)

        let lastIndex = Float(points.count - 1)

        for (index, point) in points.enumerated() {
            let t = Float(index) / lastIndex

            // Average the directions either side so the strip does not kink
            // at the joints.
            let ahead = points[min(index + 1, points.count - 1)]
            let behind = points[max(index - 1, 0)]
            var axis = ahead - behind
            axis = simd_length(axis) > 1e-6 ? simd_normalize(axis) : SIMD3<Float>(0, 1, 0)

            let toViewer = viewerPosition - point
            var side = simd_cross(axis, simd_length(toViewer) > 1e-6 ? simd_normalize(toViewer) : SIMD3<Float>(0, 0, 1))
            if simd_length(side) < 1e-6 {
                // Degenerate only when the channel points straight at the
                // viewer; any perpendicular will do.
                side = simd_cross(axis, SIMD3<Float>(0, 1, 0))
            }
            side = simd_normalize(side)

            let jitter = 0.84 + hashUnit(seed: widthSeed, step: 600 + index) * 0.32
            let width = halfWidth * (1 - (1 - taperTo) * t) * jitter

            positions.append(point - side * width)
            positions.append(point + side * width)
            uvs.append(SIMD2<Float>(0, t))
            uvs.append(SIMD2<Float>(1, t))
        }

        var indices: [UInt32] = []
        indices.reserveCapacity((points.count - 1) * 12)
        for index in 0..<(points.count - 1) {
            let a = UInt32(index * 2)
            // Both windings, so the ribbon is visible whichever way the
            // normal ends up facing.
            indices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
            indices += [a + 2, a + 1, a, a + 2, a + 3, a + 1]
        }

        var descriptor = MeshDescriptor(name: "bolt-ribbon")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)

        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }

        var material = UnlitMaterial()
        material.color = .init(tint: color, texture: .init(texture))
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return ModelEntity(mesh: mesh, materials: [material])
    }

    /// One strike's geometry, pre-built as several interchangeable shapes.
    ///
    /// Real channels writhe continuously while they are lit. Rebuilding the
    /// mesh every frame to achieve that would be wasteful, so instead a few
    /// complete shapes are built once at spawn and the strike cycles which
    /// one is visible. Reshaping then costs a pair of `isEnabled` writes
    /// rather than a mesh build.
    private struct BoltShapes {
        let root: Entity
        let shapes: [Entity]

        func show(_ index: Int) {
            for (i, shape) in shapes.enumerated() {
                shape.isEnabled = (i == index)
            }
        }
    }

    /// Builds a strike as `variantCount` alternative shapes between the same
    /// endpoints.
    private func makeBoltShapes(
        for connection: ConstellationConnection,
        seed: Int,
        includeBranch: Bool,
        intensity: Float = 1,
        depth: Int = 4,
        variantCount: Int = 3
    ) -> BoltShapes {
        let root = Entity()
        var shapes: [Entity] = []

        // Only the main channel gets alternative shapes. Forks are built once
        // and shared across all of them: mesh generation is the expensive part
        // of a spawn, and multiplying a dozen fork ribbons by the variant
        // count is most of that cost for very little visible gain — the eye
        // tracks the main channel's movement, not each filament's.
        for variant in 0..<max(1, variantCount) {
            let shape = Entity()
            let variantSeed = seed &+ variant * 613

            let points = displacedBoltPath(
                from: connection.start,
                to: connection.end,
                seed: variantSeed,
                depth: depth
            )
            addChannel(points: points, to: shape, intensity: intensity, widthSeed: variantSeed)

            shape.isEnabled = (variant == 0)
            root.addChild(shape)
            shapes.append(shape)
        }

        if includeBranch {
            // Forks hang off the first variant's path, which is the one the
            // strike opens on.
            let basePoints = displacedBoltPath(
                from: connection.start,
                to: connection.end,
                seed: seed,
                depth: depth
            )
            // Vary fork density per strike; a storm where every bolt carries
            // the same tree reads as a repeated asset.
            let generations = hashUnit(seed: seed, step: 77) < 0.45 ? 2 : 1

            for (branchIndex, branch) in boltBranches(
                along: basePoints,
                towards: connection.end,
                seed: seed,
                generation: generations,
                intensity: intensity
            ).enumerated() {
                addChannel(
                    points: branch.points,
                    to: root,
                    intensity: branch.intensity,
                    widthSeed: seed &+ 7000 &+ branchIndex * 13,
                    slim: true
                )
            }
        }

        return BoltShapes(root: root, shapes: shapes)
    }

    /// Draws one channel as a pair of ribbons: a wide soft glow and a tight
    /// bright core.
    ///
    /// Two meshes, where the cylinder version needed four stacked tubes per
    /// segment. The soft edge now comes from the texture's falloff rather
    /// than from nested geometry, which is what a cylinder could never do —
    /// its edge is geometric and always hard.
    private func addChannel(
        points: [SIMD3<Float>],
        to parent: Entity,
        intensity: Float,
        widthSeed: Int,
        slim: Bool = false
    ) {
        let glowWidth: Float = slim ? 0.0075 : 0.022
        let coreWidth: Float = slim ? 0.0013 : 0.0034

        if let glow = ribbonEntity(
            points: points,
            halfWidth: glowWidth,
            taperTo: slim ? 0.3 : 0.4,
            color: brandBlue,
            opacity: (slim ? 0.16 : 0.26) * intensity,
            widthSeed: widthSeed
        ) {
            parent.addChild(glow)
        }

        if let core = ribbonEntity(
            points: points,
            halfWidth: coreWidth,
            taperTo: slim ? 0.28 : 0.38,
            color: slim ? boltCyan : coreWhite,
            opacity: (slim ? 0.5 : 0.72) * intensity,
            widthSeed: widthSeed &+ 31
        ) {
            parent.addChild(core)
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
        towards target: SIMD3<Float>,
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
            var direction = simd_normalize(forward * cos(angle) + lateral * side * sin(angle))

            // Lean toward the far endpoint. Real forks still head broadly
            // where the discharge is going; without this bias they wander off
            // sideways and the bolt loses its sense of travelling somewhere.
            let toTarget = target - origin
            if simd_length(toTarget) > 1e-5 {
                direction = simd_normalize(direction * 0.68 + simd_normalize(toTarget) * 0.32)
            }

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
                towards: target,
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
            .prefix(max(4, Int(Double(heroIndices.count) * Double.random(in: 0.66...0.88))))

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
            guard Double.random(in: 0..<1) < 0.44 else { continue }

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
