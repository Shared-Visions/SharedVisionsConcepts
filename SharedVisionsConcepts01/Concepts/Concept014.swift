//  Shared Visions Concepts
//
//  Title: Concept014
//
//  Subtitle: Living Palm Infographic
//
//  Description: Close then reopen your left hand to toggle a miniature Jeffrey
//  infographic standing directly on your upward-facing palm. The full-body PNG
//  stays transparent, the figure stands perpendicular to the palm, and playful
//  callouts point to specific parts of the body. Rotating the palm away from up
//  fades the hologram without changing the toggle state.
//
//  Type: Space
//
//  Featured: true
//
//  Created by Kiro on 9/24/26.

import SwiftUI
import RealityKit
import ARKit
import Foundation
import UIKit

fileprivate let svBlue14 = UIColor(
    red: 0.0,
    green: 145.0 / 255.0,
    blue: 1.0,
    alpha: 1.0
)

struct Concept014: View {
    @State private var handTracking = PalmHandTrackingService()
    @State private var controller = PalmInfographicController()

    var body: some View {
        RealityView { content, attachments in
            content.add(handTracking.anchor)
            controller.attach(
                to: handTracking.anchor,
                attachments: attachments
            )

            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                controller.sync(
                    handPose: handTracking.pose,
                    palmUpAmount: handTracking.palmUpAmount
                )
                controller.update(deltaTime: event.deltaTime)
            }
        } update: { _, attachments in
            controller.refresh(attachments: attachments)
        } attachments: {
            Attachment(id: PalmInfographicController.standeeAttachmentID) {
                PalmStandee()
            }

            ForEach(PalmInfographicController.Callout.allCases) { callout in
                Attachment(id: callout.attachmentID) {
                    FunnyCallout(callout: callout)
                }
            }
        }
        .upperLimbVisibility(.automatic)
        .task { await handTracking.start() }
        .onDisappear { handTracking.stop() }
        .persistentSystemOverlays(.hidden)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            VStack(spacing: 7) {
                Text("Close → open toggles the palm hologram")
                    .font(.headline)

                Text(handTracking.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
            }
            .padding(14)
            .glassBackgroundEffect()
        }
    }
}

// MARK: - Hologram content

fileprivate struct PalmStandee: View {
    var body: some View {
        Image("JeffreyStanding")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 174)
            .background(Color.clear)
            .accessibilityHidden(true)
    }
}

fileprivate struct FunnyCallout: View {
    let callout: PalmInfographicController.Callout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(callout.title)
                .font(.system(size: 7, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(svBlue14))

            Text(callout.punchline)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Hand tracking

@MainActor
@Observable
final class PalmHandTrackingService {
    enum Pose: Equatable {
        case unknown
        case open
        case closed
        case intermediate
    }

    private(set) var pose: Pose = .unknown
    private(set) var palmUpAmount: Float = 0
    private(set) var statusMessage = "Close, then reopen your left hand with the palm facing up."

    // Use the actual PALM anchor, not .aboveHand. Apple's palm anchor sits at the
    // center of the palm and its +Y axis points out of the palm. This is what lets
    // the standee appear to physically stand on the hand instead of hovering above it.
    let anchor = AnchorEntity(
        .hand(.left, location: .palm),
        trackingMode: .predicted
    )

    private var session: ARKitSession?
    private var provider: HandTrackingProvider?
    private var trackingTask: Task<Void, Never>?

    private var candidatePose: Pose = .unknown
    private var candidateSampleCount = 0
    private let samplesRequired = 2

    func start() async {
        guard trackingTask == nil else { return }

        guard HandTrackingProvider.isSupported else {
            statusMessage = "Hand tracking requires Apple Vision Pro."
            return
        }

        let newSession = ARKitSession()
        let newProvider = HandTrackingProvider()
        session = newSession
        provider = newProvider

        let authorization = await newSession.requestAuthorization(for: [.handTracking])
        guard authorization[.handTracking] == .allowed else {
            statusMessage = "Hand-tracking permission wasn't granted."
            return
        }

        trackingTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await newSession.run([newProvider])
                self.statusMessage = "Close → open toggles it. Palm up reveals it."

                for await update in newProvider.anchorUpdates {
                    if Task.isCancelled { break }

                    let hand = update.anchor
                    guard hand.chirality == .left,
                          hand.isTracked,
                          let skeleton = hand.handSkeleton
                    else { continue }

                    self.updatePalmUpAmount(from: hand)
                    self.stabilize(self.classify(skeleton))
                }
            } catch {
                if !Task.isCancelled {
                    self.statusMessage = "Hand tracking error: \(error.localizedDescription)"
                }
            }
        }
    }

    func stop() {
        trackingTask?.cancel()
        trackingTask = nil
        session?.stop()
        session = nil
        provider = nil
        pose = .unknown
        palmUpAmount = 0
    }

    private func updatePalmUpAmount(from hand: HandAnchor) {
        // On device this sign matches the left-palm-up pose from the previous pass.
        let localPalmNormal = SIMD4<Float>(0, 1, 0, 0)
        let worldPalm4 = simd_mul(
            hand.originFromAnchorTransform,
            localPalmNormal
        )
        let worldPalm = simd_normalize(
            SIMD3<Float>(worldPalm4.x, worldPalm4.y, worldPalm4.z)
        )
        let upDot = simd_clamp(worldPalm.y, -1, 1)

        // Fully hidden by vertical/downward. Begins appearing on a reasonably
        // upward palm; reaches full visibility before the hand must be perfectly flat.
        let t = simd_clamp((upDot - 0.08) / 0.56, 0, 1)
        palmUpAmount = t * t * (3 - 2 * t)
    }

    private func classify(_ skeleton: HandSkeleton) -> Pose {
        let wrist = jointPosition(skeleton, .wrist)
        let pairs: [(HandSkeleton.JointName, HandSkeleton.JointName)] = [
            (.indexFingerTip, .indexFingerKnuckle),
            (.middleFingerTip, .middleFingerKnuckle),
            (.ringFingerTip, .ringFingerKnuckle),
            (.littleFingerTip, .littleFingerKnuckle)
        ]

        var totalRatio: Float = 0
        for (tipName, knuckleName) in pairs {
            let tip = jointPosition(skeleton, tipName)
            let knuckle = jointPosition(skeleton, knuckleName)
            let baseDistance = max(simd_distance(knuckle, wrist), 0.001)
            totalRatio += simd_distance(tip, wrist) / baseDistance
        }

        let averageRatio = totalRatio / Float(pairs.count)

        if averageRatio >= 1.28 { return .open }
        if averageRatio <= 1.10 { return .closed }
        return .intermediate
    }

    private func jointPosition(
        _ skeleton: HandSkeleton,
        _ name: HandSkeleton.JointName
    ) -> SIMD3<Float> {
        let transform = skeleton.joint(name).anchorFromJointTransform
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    private func stabilize(_ next: Pose) {
        guard next != .intermediate else {
            candidateSampleCount = max(0, candidateSampleCount - 1)
            return
        }

        if next == candidatePose {
            candidateSampleCount += 1
        } else {
            candidatePose = next
            candidateSampleCount = 1
        }

        guard candidateSampleCount >= samplesRequired else { return }

        if next != pose {
            pose = next
            switch next {
            case .open:
                statusMessage = "OPEN detected · palm up controls visibility"
            case .closed:
                statusMessage = "CLOSED detected · reopen to toggle"
            case .unknown, .intermediate:
                break
            }
        }
    }
}

// MARK: - Living palm infographic

@MainActor
fileprivate final class PalmInfographicController {
    static let standeeAttachmentID = "palm-standee"

    enum Callout: Int, CaseIterable, Identifiable {
        case brain
        case heart
        case battery

        var id: Int { rawValue }
        var attachmentID: String { "palm-callout-\(rawValue)" }

        var title: String {
            switch self {
            case .brain: "IDEA GENERATOR"
            case .heart: "LUV PROCESSOR"
            case .battery: "INTERNAL BATTERY"
            }
        }

        var punchline: String {
            switch self {
            case .brain: "No off switch"
            case .heart: "Runs suspiciously hot"
            case .battery: "Cherry Coca-Cola compatible"
            }
        }
    }

    private let presentationRoot = Entity()
    private let infographicRoot = Entity()
    private let standeeRoot = Entity()
    private let lineRoot = Entity()

    private var standeeEntity: ViewAttachmentEntity?
    private var calloutEntities: [Callout: ViewAttachmentEntity] = [:]

    private var targetVisibility: Float = 0
    private var visibility: Float = 0
    private var hologramEnabled = false
    private var sawClosed = false
    private var handIsOpen = false
    private var palmUpAmount: Float = 0
    private var lastSyncedPose: PalmHandTrackingService.Pose = .unknown
    private var elapsed: Float = 0
    private var isAttached = false

    func attach(
        to handAnchor: AnchorEntity,
        attachments: RealityViewAttachments
    ) {
        guard !isAttached else {
            refresh(attachments: attachments)
            return
        }

        isAttached = true

        // Palm anchor is already at the physical palm center. Keep this almost at
        // zero so Jeffrey's shoes visually land on the hand instead of hovering.
        presentationRoot.position = [0, 0.003, 0]
        handAnchor.addChild(presentationRoot)

        // One shared camera-facing coordinate system for the entire infographic.
        // Previously the person and each label billboarded independently while the
        // leader lines stayed in palm coordinates, which made the lines point to
        // the back of the head / pocket / below the feet as the viewing angle moved.
        infographicRoot.components.set(BillboardComponent())
        presentationRoot.addChild(infographicRoot)
        infographicRoot.addChild(standeeRoot)
        infographicRoot.addChild(lineRoot)

        installStandee(attachments)
        installCallouts(attachments)
        rebuildLines()

        presentationRoot.components.set(OpacityComponent(opacity: 0))
        presentationRoot.isEnabled = false
    }

    func refresh(attachments: RealityViewAttachments) {
        if standeeEntity == nil {
            installStandee(attachments)
        }

        if calloutEntities.count < Callout.allCases.count {
            installCallouts(attachments)
            rebuildLines()
        }
    }

    private func installStandee(_ attachments: RealityViewAttachments) {
        guard standeeEntity == nil,
              let standee = attachments.entity(for: Self.standeeAttachmentID)
        else { return }

        // The SwiftUI attachment is about 17 cm tall. Put its center ~8.3 cm above
        // palm center so the soles sit essentially on the palm plane.
        standee.position = [0, 0.083, 0]

        // The entire infographicRoot faces the viewer, so the standee, labels,
        // and leader lines all share exactly the same coordinate system.
        standeeRoot.addChild(standee)
        standeeEntity = standee
    }

    private func installCallouts(_ attachments: RealityViewAttachments) {
        for callout in Callout.allCases {
            guard calloutEntities[callout] == nil,
                  let entity = attachments.entity(for: callout.attachmentID)
            else { continue }

            entity.position = calloutPosition(callout)
            infographicRoot.addChild(entity)
            calloutEntities[callout] = entity
        }
    }

    func sync(
        handPose: PalmHandTrackingService.Pose,
        palmUpAmount: Float
    ) {
        self.palmUpAmount = simd_clamp(palmUpAmount, 0, 1)

        if handPose != lastSyncedPose {
            lastSyncedPose = handPose
            handle(handPose)
        }

        updateTargetVisibility()
    }

    private func handle(_ pose: PalmHandTrackingService.Pose) {
        switch pose {
        case .closed:
            handIsOpen = false
            sawClosed = true

        case .open:
            if !handIsOpen && sawClosed {
                hologramEnabled.toggle()
                sawClosed = false
            }
            handIsOpen = true

        case .unknown, .intermediate:
            break
        }
    }

    private func updateTargetVisibility() {
        targetVisibility =
            (hologramEnabled && handIsOpen)
            ? palmUpAmount
            : 0

        if targetVisibility > 0.001 {
            presentationRoot.isEnabled = true
        }
    }

    func update(deltaTime: TimeInterval) {
        let dt = Float(min(deltaTime, 1.0 / 20.0))
        elapsed += dt

        let speed: Float =
            targetVisibility > visibility ? 7.5 : 10.0

        visibility +=
            (targetVisibility - visibility)
            * min(1, dt * speed)

        presentationRoot.components.set(
            OpacityComponent(opacity: visibility)
        )

        presentationRoot.scale = SIMD3<Float>(
            repeating: 0.94 + 0.06 * visibility
        )

        if targetVisibility < 0.001 && visibility < 0.005 {
            presentationRoot.isEnabled = false
        }

        // Very subtle "alive" motion, without making the standee float off the palm.
        let breath = 1.0 + 0.006 * sin(elapsed * 1.8)
        standeeRoot.scale = SIMD3<Float>(1.0, breath, 1.0)
    }

    private func calloutPosition(_ callout: Callout) -> SIMD3<Float> {
        // Bring the cards in tighter so they read as annotations on the standee,
        // not floating UI islands. Keep them in left/right columns, but position
        // each card closer to the body part it describes.
        switch callout {
        case .brain:
                return [-0.090, 0.143, 0.010]

            case .heart:
                return [0.090, 0.116, 0.010]

            case .battery:
                return [-0.090, 0.081, 0.010]
        }
    }

    private func bodyAnchor(_ callout: Callout) -> SIMD3<Float> {
        // Final tuning against the JeffreyStanding asset. Values are in the same
        // billboarded coordinate space as the standee, so the line ends should
        // stay attached to the intended body parts as the user moves around.
        switch callout {
        case .brain:
            return [0.000, 0.130, 0.006]

        case .heart:
            return [0.004, 0.110, 0.006]

        case .battery:
            return [-0.004, 0.100, 0.006]
        }
    }

    private func rebuildLines() {
        for child in Array(lineRoot.children) {
            child.removeFromParent()
        }

        for callout in Callout.allCases {
            lineRoot.addChild(
                makeLine(
                    from: bodyAnchor(callout),
                    to: calloutPosition(callout)
                )
            )
        }
    }

    private func makeLine(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>
    ) -> ModelEntity {
        let vector = end - start
        let distance = max(simd_length(vector), 0.001)

        let line = ModelEntity(
            mesh: .generateCylinder(
                height: distance,
                radius: 0.00055
            ),
            materials: [
                lineMaterial(
                    svBlue14,
                    opacity: 0.58
                )
            ]
        )

        line.position = (start + end) / 2

        let direction = simd_normalize(vector)
        let yAxis = SIMD3<Float>(0, 1, 0)
        let dot = simd_clamp(
            simd_dot(yAxis, direction),
            -1,
            1
        )

        if dot < 0.9999 {
            let axis = simd_normalize(
                simd_cross(yAxis, direction)
            )
            line.orientation = simd_quatf(
                angle: acos(dot),
                axis: axis
            )
        }

        return line
    }

    private func lineMaterial(
        _ color: UIColor,
        opacity: Float
    ) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        material.blending = .transparent(
            opacity: .init(floatLiteral: opacity)
        )
        return material
    }
}

#Preview {
    Concept014()
}
