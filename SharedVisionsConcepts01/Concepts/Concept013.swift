//  Shared Visions Concepts
//
//  Title: Concept013
//
//  Subtitle: Interview Universe
//
//  Description: A dynamic interview universe. Every interview is a clean portrait bubble
//  inside a larger candy-coated glass shell. The universe is captured relative to the
//  user's starting position and then remains fixed in the room. Portraits always turn
//  toward the viewer, while filtering smoothly brings the relevant cohort forward.
//
//  Type: Space
//
//  Featured: true
//
//  Created by Kiro on 9/24/26.

import SwiftUI
import RealityKit
import UIKit

fileprivate let svBlue13 = UIColor(
    red: 0.0,
    green: 145.0 / 255.0,
    blue: 1.0,
    alpha: 1.0
)

fileprivate let svGold13 = UIColor(
    red: 240.0 / 255.0,
    green: 189.0 / 255.0,
    blue: 118.0 / 255.0,
    alpha: 1.0
)

fileprivate enum Concept13Role: String, CaseIterable, Identifiable {
    case developer = "Developer"
    case designer = "Designer"
    case artist = "Artist"
    case videographer = "Videographer"

    var id: String { rawValue }
}

fileprivate struct Concept13Person: Identifiable {
    let id: Int
    let name: String
    let role: Concept13Role
    let portraitAssetName: String
}

fileprivate let concept13People: [Concept13Person] = {
    let names = [
        "Avery Chen", "Jordan Blake", "Riley Nakamura", "Sam Okafor",
        "Morgan Reyes", "Casey Whitfield", "Drew Sinclair", "Rowan Patel",
        "Elliot Marsh", "Harper Voss", "Quinn Alvarez", "Skyler Duarte",
        "Reese Hallberg", "Finley Okonjo", "Parker Iida", "Sasha Renner",
        "Tatum Osei", "Marlowe Petrov", "Wren Kowalski", "Emerson Kade"
    ]

    return names.enumerated().map { index, name in
        Concept13Person(
            id: index,
            name: name,
            role: Concept13Role.allCases[index % Concept13Role.allCases.count],
            portraitAssetName: String(
                format: "C12Portrait%02d",
                (index % 13) + 1
            )
        )
    }
}()

struct Concept013: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    @State private var selectedRole: Concept13Role?
    @State private var selectedPersonID: Int?
    @State private var controller = Concept13UniverseController()

    private let controlsAttachmentID = "concept13-controls"
    private let videoPanelAttachmentID = "concept13-video-panel"

    private var selectedPerson: Concept13Person? {
        guard let selectedPersonID else { return nil }
        return concept13People.first { $0.id == selectedPersonID }
    }

    var body: some View {
        RealityView { content, attachments in
            await controller.build(
                people: concept13People,
                in: &content
            )

            controller.installControls(
                attachments.entity(for: controlsAttachmentID)
            )

            controller.installVideoPanel(
                attachments.entity(for: videoPanelAttachmentID),
                isVisible: selectedPersonID != nil
            )

            controller.applyFilter(selectedRole)
            controller.setSelected(selectedPersonID)

            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                controller.update(deltaTime: event.deltaTime)
            }
        } update: { _, attachments in
            controller.installControls(
                attachments.entity(for: controlsAttachmentID)
            )

            controller.installVideoPanel(
                attachments.entity(for: videoPanelAttachmentID),
                isVisible: selectedPersonID != nil
            )

            controller.applyFilter(selectedRole)
            controller.setSelected(selectedPersonID)
        } attachments: {
            Attachment(id: controlsAttachmentID) {
                Concept13Controls(
                    selectedRole: $selectedRole,
                    onClose: closeConcept
                )
            }

            Attachment(id: videoPanelAttachmentID) {
                Concept13VideoPanel(person: selectedPerson) {
                    selectedPersonID = nil
                    controller.setSelected(nil)
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let personID = controller.personID(for: value.entity)
                    else { return }

                    selectedPersonID =
                        selectedPersonID == personID ? nil : personID

                    controller.setSelected(selectedPersonID)
                }
        )
        .onChange(of: selectedRole) { _, role in
            // Filtering is a context change. Close the video first, then let the
            // universe reorganize cleanly rather than mixing two layouts.
            selectedPersonID = nil
            controller.setSelected(nil)
            controller.applyFilter(role)
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            dismissWindow(id: "MainWindow")
        }
        .onDisappear {
            openWindow(id: "MainWindow")
        }
    }

    private func closeConcept() {
        Task { @MainActor in
            await dismissImmersiveSpace()
        }
    }
}

fileprivate struct Concept13Controls: View {
    @Binding var selectedRole: Concept13Role?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interview Universe")
                        .font(.headline)

                    Text("Filter to bring the relevant interviews forward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .background(.black.opacity(0.20))
                .clipShape(Circle())
            }

            HStack(spacing: 7) {
                UniverseRoleChip(
                    title: "All",
                    isSelected: selectedRole == nil
                ) {
                    selectedRole = nil
                }

                ForEach(Concept13Role.allCases) { role in
                    UniverseRoleChip(
                        title: role.rawValue,
                        isSelected: selectedRole == role
                    ) {
                        selectedRole = selectedRole == role ? nil : role
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 440)
        .glassBackgroundEffect()
    }
}

fileprivate struct Concept13VideoPanel: View {
    let person: Concept13Person?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(person?.name ?? "Interview")
                        .font(.title3.bold())

                    Text(
                        person.map {
                            "\($0.role.rawValue) · Shared Visions"
                        } ?? "Shared Visions"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .background(.black.opacity(0.20))
                .clipShape(Circle())
            }

            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color(white: 0.62).opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: "play.fill")
                    .font(.system(size: 74, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 560, height: 315)
        }
        .padding(18)
        .frame(width: 600)
        .glassBackgroundEffect()
    }
}

fileprivate struct UniverseRoleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color(svBlue13) : Color.clear
                )
                .foregroundStyle(
                    isSelected ? .white : .primary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
fileprivate final class Concept13UniverseController {
    private struct OrbState {
        let person: Concept13Person
        let root: Entity
        let bubbleVisual: Entity
        let faceCarrier: Entity
        let portrait: ModelEntity
        let glassShell: ModelEntity
        let blueHalo: ModelEntity
        let goldHalo: ModelEntity
        let hitTarget: Entity
        let restPosition: SIMD3<Float>
        let filteredPosition: SIMD3<Float>
        let peripheralPosition: SIMD3<Float>
        let phaseOffset: Float
        var currentPosition: SIMD3<Float>
    }

    // Capture the user's starting head pose once, then freeze it. This gives us
    // a predictable layout in front of the user at launch without making the
    // universe follow them around the room afterward.
    private let frozenStartAnchor = AnchorEntity(.head)
    private let orbsRoot = Entity()
    private let uiRoot = Entity()

    private var anchorInstalled = false
    private var orbs: [Int: OrbState] = [:]
    private var selectedRole: Concept13Role?
    private var selectedPersonID: Int?
    private var elapsed: Float = 0

    func build(
        people: [Concept13Person],
        in content: inout RealityViewContent
    ) async {
        guard orbs.isEmpty else { return }

        if !anchorInstalled {
            frozenStartAnchor.anchoring.trackingMode = .once
            content.add(frozenStartAnchor)
            frozenStartAnchor.addChild(orbsRoot)
            frozenStartAnchor.addChild(uiRoot)
            anchorInstalled = true
        }

        let restPositions =
            sphericalUniversePositions(count: people.count)

        let filteredPositions =
            filteredCenterPositions(for: people)

        let peripheralPositions =
            outsidePositions(for: people)

        // One shared glass texture for every bubble. Crucially, the center of
        // this texture is transparent. There is NO translucent sphere mesh in
        // front of the photograph, so nothing can turn into the giant gray disc
        // seen in the headset screenshots.
        let glassTexture = await makeGlassShellTexture()
        let blueHaloTexture = await makeHaloTexture(color: svBlue13)
        let goldHaloTexture = await makeHaloTexture(color: svGold13)

        for (index, person) in people.enumerated() {
            let root = Entity()
            root.name = "orb-\(person.id)"
            root.position = restPositions[index]

            let bubbleVisual = Entity()
            root.addChild(bubbleVisual)

            // Only the 2D visual card billboards. Its world-space POSITION does
            // not change when the user walks; it simply turns to face the camera.
            let faceCarrier = Entity()
            faceCarrier.components.set(BillboardComponent())
            bubbleVisual.addChild(faceCarrier)

            let blueHalo = makeTexturedPlane(
                texture: blueHaloTexture,
                width: 0.190,
                name: "blue-halo"
            )
            blueHalo.position = [0, 0, -0.004]
            blueHalo.components.set(OpacityComponent(opacity: 0.0))
            faceCarrier.addChild(blueHalo)

            let goldHalo = makeTexturedPlane(
                texture: goldHaloTexture,
                width: 0.190,
                name: "gold-halo"
            )
            goldHalo.position = [0, 0, -0.003]
            goldHalo.components.set(OpacityComponent(opacity: 0.0))
            faceCarrier.addChild(goldHalo)

            let portrait = await makePortraitEntity(for: person)
            portrait.position = [0, 0, 0.000]
            faceCarrier.addChild(portrait)

            let glassShell = makeTexturedPlane(
                texture: glassTexture,
                width: 0.166,
                name: "glass-shell"
            )
            // Draw the glass ring a millimeter in front of the portrait. The
            // middle is fully transparent, so it can never cover the face.
            glassShell.position = [0, 0, 0.001]
            faceCarrier.addChild(glassShell)

            // Invisible interaction target: collision without visible geometry.
            let hitTarget = Entity()
            hitTarget.name = "hit-target"
            hitTarget.components.set(InputTargetComponent())
            hitTarget.components.set(
                CollisionComponent(
                    shapes: [.generateSphere(radius: 0.088)]
                )
            )
            bubbleVisual.addChild(hitTarget)

            let state = OrbState(
                person: person,
                root: root,
                bubbleVisual: bubbleVisual,
                faceCarrier: faceCarrier,
                portrait: portrait,
                glassShell: glassShell,
                blueHalo: blueHalo,
                goldHalo: goldHalo,
                hitTarget: hitTarget,
                restPosition: restPositions[index],
                filteredPosition:
                    filteredPositions[person.id]
                    ?? restPositions[index],
                peripheralPosition:
                    peripheralPositions[person.id]
                    ?? restPositions[index],
                phaseOffset: Float(index) * 0.137,
                currentPosition: restPositions[index]
            )

            orbs[person.id] = state
            orbsRoot.addChild(root)
        }
    }

    func installControls(_ controls: ViewAttachmentEntity?) {
        guard let controls else { return }

        // Fixed relative to the captured starting pose, not live head tracking.
        controls.position = [0, -0.50, -1.04]

        if controls.parent == nil {
            uiRoot.addChild(controls)
        }
    }

    func installVideoPanel(
        _ panel: ViewAttachmentEntity?,
        isVisible: Bool
    ) {
        guard let panel else { return }

        panel.position = [0, 0.01, -1.08]
        panel.isEnabled = isVisible

        if panel.parent == nil {
            uiRoot.addChild(panel)
        }
    }

    func setSelected(_ id: Int?) {
        selectedPersonID = id
    }

    func applyFilter(_ role: Concept13Role?) {
        selectedRole = role
    }

    func personID(for entity: Entity) -> Int? {
        var current: Entity? = entity

        while let candidate = current {
            if candidate.name.hasPrefix("orb-"),
               let id = Int(candidate.name.dropFirst(4)) {
                return id
            }

            current = candidate.parent
        }

        return nil
    }

    func update(deltaTime: TimeInterval) {
        let dt = Float(min(deltaTime, 1.0 / 20.0))
        elapsed += dt

        let filteredIDs = idsMatchingCurrentFilter()
        let selectedCohortIDs = cohortForSelectedPerson(
            filteredIDs: filteredIDs
        )

        for id in Array(orbs.keys) {
            guard var state = orbs[id] else { continue }

            let isFilteredIn =
                selectedRole == nil
                || filteredIDs.contains(id)

            let isSelected =
                selectedPersonID == id

            let isSelectedCohort =
                selectedPersonID != nil
                && selectedCohortIDs.contains(id)

            let targetPosition: SIMD3<Float>

            if let selectedID = selectedPersonID {
                targetPosition = selectedLayoutPosition(
                    for: id,
                    selectedID: selectedID,
                    cohortIDs: selectedCohortIDs,
                    fallback: state
                )
            } else if selectedRole == nil {
                targetPosition = state.restPosition
            } else if isFilteredIn {
                targetPosition = state.filteredPosition
            } else {
                targetPosition = state.peripheralPosition
            }

            // Calmly interpolate instead of snapping / exploding around the player.
            let movementAmount = min(1, dt * 1.65)

            state.currentPosition +=
                (targetPosition - state.currentPosition)
                * movementAmount

            state.root.position = state.currentPosition

            let breath =
                0.5
                - 0.5
                * cos(
                    (elapsed * 0.44 + state.phaseOffset)
                    * 2
                    * .pi
                )

            let activity: Float =
                isSelected
                ? 1.0
                : (isSelectedCohort ? 0.30 : 0.0)

            let scale =
                1.0
                + activity * 0.075
                + (0.006 + activity * 0.020)
                * (breath - 0.5)
                * 2

            state.bubbleVisual.scale =
                SIMD3<Float>(repeating: scale)

            let dimmed =
                selectedRole != nil
                && !isFilteredIn
                && !isSelected

            state.root.components.set(
                OpacityComponent(
                    opacity: dimmed ? 0.22 : 1.0
                )
            )

            state.blueHalo.components.set(
                OpacityComponent(
                    opacity:
                        isSelected
                        ? 0.0
                        : (isSelectedCohort ? 0.30 : 0.0)
                )
            )

            state.goldHalo.components.set(
                OpacityComponent(
                    opacity: isSelected ? 0.48 : 0.0
                )
            )

            orbs[id] = state
        }
    }

    // MARK: - Selection / filtering

    private func idsMatchingCurrentFilter() -> [Int] {
        guard let selectedRole else { return [] }

        return orbs.values
            .filter { $0.person.role == selectedRole }
            .map { $0.person.id }
            .sorted()
    }

    private func cohortForSelectedPerson(
        filteredIDs: [Int]
    ) -> [Int] {
        guard let selectedPersonID,
              let selected = orbs[selectedPersonID]
        else {
            return []
        }

        if selectedRole != nil {
            return filteredIDs
        }

        return orbs.values
            .filter {
                $0.person.role == selected.person.role
            }
            .map { $0.person.id }
            .sorted()
    }

    private func selectedLayoutPosition(
        for id: Int,
        selectedID: Int,
        cohortIDs: [Int],
        fallback state: OrbState
    ) -> SIMD3<Float> {
        // Give the player a completely clear center region.
        if id == selectedID {
            return [-0.53, 0.34, -0.98]
        }

        let otherIDs = cohortIDs.filter { $0 != selectedID }

        if let index = otherIDs.firstIndex(of: id) {
            let slots: [SIMD3<Float>] = [
                [ 0.53,  0.34, -1.00],
                [-0.57, -0.34, -1.00],
                [ 0.57, -0.34, -1.00],
                [ 0.00,  0.51, -1.04],
                [ 0.00, -0.49, -1.04]
            ]

            return slots[min(index, slots.count - 1)]
        }

        return state.peripheralPosition
    }

    // MARK: - Portrait / bubble visuals

    private func makePortraitEntity(
        for person: Concept13Person
    ) async -> ModelEntity {
        guard let image = UIImage(named: person.portraitAssetName),
              let cgImage = image.cgImage
        else {
            assertionFailure(
                "Missing Concept 13 portrait asset: \(person.portraitAssetName)"
            )

            return missingPortraitEntity(
                label: person.portraitAssetName
            )
        }

        do {
            let texture = try await TextureResource(
                image: cgImage,
                withName: "concept13-\(person.portraitAssetName)",
                options: TextureResource.CreateOptions(
                    semantic: .color
                )
            )

            var material = UnlitMaterial(texture: texture)
            material.blending = .transparent(
                opacity: .init(floatLiteral: 1.0)
            )

            // 12.8 cm portrait inside a 16.6 cm shell graphic. This leaves a
            // visible but modest candy-coated glass margin around the person.
            return ModelEntity(
                mesh: .generatePlane(
                    width: 0.128,
                    height: 0.128,
                    cornerRadius: 0
                ),
                materials: [material]
            )
        } catch {
            assertionFailure(
                "Could not create Concept 13 portrait texture \(person.portraitAssetName): \(error)"
            )

            return missingPortraitEntity(
                label: person.portraitAssetName
            )
        }
    }

    private func makeTexturedPlane(
        texture: TextureResource?,
        width: Float,
        name: String
    ) -> ModelEntity {
        let entity: ModelEntity

        if let texture {
            var material = UnlitMaterial(texture: texture)
            material.blending = .transparent(
                opacity: .init(floatLiteral: 1.0)
            )

            entity = ModelEntity(
                mesh: .generatePlane(
                    width: width,
                    height: width,
                    cornerRadius: 0
                ),
                materials: [material]
            )
        } else {
            var fallback = UnlitMaterial()
            fallback.color = .init(
                tint: UIColor.white.withAlphaComponent(0.10)
            )
            fallback.blending = .transparent(
                opacity: .init(floatLiteral: 0.10)
            )

            entity = ModelEntity(
                mesh: .generatePlane(
                    width: width,
                    height: width,
                    cornerRadius: 0
                ),
                materials: [fallback]
            )
        }

        entity.name = name
        return entity
    }

    private func makeGlassShellTexture() async -> TextureResource? {
        let image = glassShellUIImage()

        guard let cgImage = image.cgImage else { return nil }

        return try? await TextureResource(
            image: cgImage,
            withName: "concept13-glass-shell",
            options: TextureResource.CreateOptions(
                semantic: .color
            )
        )
    }

    private func makeHaloTexture(
        color: UIColor
    ) async -> TextureResource? {
        let image = haloUIImage(color: color)

        guard let cgImage = image.cgImage else { return nil }

        return try? await TextureResource(
            image: cgImage,
            withName: "concept13-halo-\(color.hash)",
            options: TextureResource.CreateOptions(
                semantic: .color
            )
        )
    }

    private func glassShellUIImage() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            cg.clear(CGRect(origin: .zero, size: size))

            let center = CGPoint(x: 256, y: 256)
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let colors = [
                UIColor.white.withAlphaComponent(0.0).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor,
                UIColor(red: 0.82, green: 0.90, blue: 0.98, alpha: 0.055).cgColor,
                UIColor.white.withAlphaComponent(0.18).cgColor,
                UIColor.white.withAlphaComponent(0.035).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray

            let locations: [CGFloat] = [
                0.00,
                0.72,
                0.79,
                0.88,
                0.96,
                1.00
            ]

            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) {
                cg.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: 250,
                    options: []
                )
            }

            // Tiny internal reflection: part of the glass texture, never a bead
            // floating in front of the face.
            cg.setStrokeColor(
                UIColor.white.withAlphaComponent(0.33).cgColor
            )
            cg.setLineWidth(8)
            cg.setLineCap(.round)
            cg.addArc(
                center: center,
                radius: 216,
                startAngle: CGFloat.pi * 1.10,
                endAngle: CGFloat.pi * 1.48,
                clockwise: false
            )
            cg.strokePath()

            cg.setStrokeColor(
                UIColor.white.withAlphaComponent(0.10).cgColor
            )
            cg.setLineWidth(3)
            cg.addEllipse(
                in: CGRect(x: 25, y: 25, width: 462, height: 462)
            )
            cg.strokePath()
        }
    }

    private func haloUIImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            cg.clear(CGRect(origin: .zero, size: size))

            let center = CGPoint(x: 256, y: 256)
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let colors = [
                color.withAlphaComponent(0.0).cgColor,
                color.withAlphaComponent(0.0).cgColor,
                color.withAlphaComponent(0.12).cgColor,
                color.withAlphaComponent(0.30).cgColor,
                color.withAlphaComponent(0.0).cgColor
            ] as CFArray

            let locations: [CGFloat] = [
                0.00,
                0.57,
                0.70,
                0.83,
                1.00
            ]

            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) {
                cg.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: 250,
                    options: []
                )
            }
        }
    }

    private func missingPortraitEntity(
        label: String
    ) -> ModelEntity {
        let material = UnlitMaterial(color: .magenta)

        let entity = ModelEntity(
            mesh: .generatePlane(
                width: 0.128,
                height: 0.128,
                cornerRadius: 0
            ),
            materials: [material]
        )

        entity.name = "MISSING-PORTRAIT-\(label)"
        return entity
    }

    // MARK: - Layout math

    private func sphericalUniversePositions(
        count: Int
    ) -> [SIMD3<Float>] {
        // Use the project's Fibonacci dome helper instead of a row/column grid.
        // This is intentionally more organic and guarantees generous spacing.
        return DomeLayout.positions(
            count: count,
            radius: 1.48,
            verticalArcDegrees: 102,
            horizontalArcDegrees: 250,
            center: .zero
        )
    }

    private func filteredCenterPositions(
        for people: [Concept13Person]
    ) -> [Int: SIMD3<Float>] {
        let slots: [SIMD3<Float>] = [
            sphericalPosition(radius: 1.08, yawDegrees:   0, pitchDegrees:   5),
            sphericalPosition(radius: 1.10, yawDegrees: -23, pitchDegrees: 15),
            sphericalPosition(radius: 1.10, yawDegrees:  23, pitchDegrees: 15),
            sphericalPosition(radius: 1.10, yawDegrees: -24, pitchDegrees: -14),
            sphericalPosition(radius: 1.10, yawDegrees:  24, pitchDegrees: -14),
            sphericalPosition(radius: 1.13, yawDegrees:   0, pitchDegrees: -28)
        ]

        var roleIndex: [Concept13Role: Int] = [:]
        var result: [Int: SIMD3<Float>] = [:]

        for person in people {
            let index = roleIndex[person.role, default: 0]

            result[person.id] =
                slots[min(index, slots.count - 1)]

            roleIndex[person.role, default: 0] += 1
        }

        return result
    }

    private func outsidePositions(
        for people: [Concept13Person]
    ) -> [Int: SIMD3<Float>] {
        var result: [Int: SIMD3<Float>] = [:]

        let widePositions = DomeLayout.positions(
            count: people.count,
            radius: 1.72,
            verticalArcDegrees: 118,
            horizontalArcDegrees: 330,
            center: .zero
        )

        for (index, person) in people.enumerated() {
            result[person.id] = widePositions[index]
        }

        return result
    }

    private func sphericalPosition(
        radius: Float,
        yawDegrees: Float,
        pitchDegrees: Float
    ) -> SIMD3<Float> {
        let yaw = yawDegrees * .pi / 180
        let pitch = pitchDegrees * .pi / 180

        let x = radius * sin(yaw) * cos(pitch)
        let y = radius * sin(pitch)
        let z = -radius * cos(yaw) * cos(pitch)

        return [x, y, z]
    }
}

#Preview {
    Concept013()
}
