//  Shared Visions Concepts
//
//  Title: Concept012
//
//  Subtitle: Interview Chooser Comp
//
//  Description: A deliberately literal implementation of the creative-director comp: a field of portrait bubbles with small colored role dots surrounding a central video chooser. This concept is intentionally conservative and does not add the more experimental Interview Universe behavior.
//
//  Type: Space
//
//  Featured: true
//
//  Created by Kiro on 9/23/26.

import SwiftUI
import RealityKit
import UIKit

fileprivate enum Concept12Role: String, CaseIterable, Identifiable {
    case developer = "Developer"
    case designer = "Designer"
    case artist = "Artist"
    case videographer = "Videographer"

    var id: String { rawValue }

    var color: UIColor {
        switch self {
        case .developer:
            return UIColor(red: 0.17, green: 0.62, blue: 0.90, alpha: 1.0)
        case .designer:
            return UIColor(red: 0.64, green: 0.22, blue: 0.74, alpha: 1.0)
        case .artist:
            return UIColor(red: 0.23, green: 0.73, blue: 0.35, alpha: 1.0)
        case .videographer:
            return UIColor(red: 0.84, green: 0.70, blue: 0.22, alpha: 1.0)
        }
    }
}

fileprivate enum Concept12Mode: String, CaseIterable, Identifiable {
    case community = "Community"
    case applications = "Applications"
    var id: String { rawValue }
}

fileprivate struct Concept12Person: Identifiable {
    let id: Int
    let name: String
    let role: Concept12Role
    let portraitAssetName: String
    let tagColors: [UIColor]
}

fileprivate let concept12People: [Concept12Person] = {
    let names = [
        "Avery Chen", "Jordan Blake", "Riley Nakamura", "Sam Okafor", "Morgan Reyes", "Casey Whitfield",
        "Drew Sinclair", "Rowan Patel", "Elliot Marsh", "Harper Voss", "Quinn Alvarez", "Skyler Duarte",
        "Reese Hallberg", "Finley Okonjo", "Parker Iida", "Sasha Renner", "Tatum Osei", "Marlowe Petrov",
        "Wren Kowalski", "Emerson Kade", "Remy Flores", "Dakota Price", "Alex Mercer", "Taylor Boone",
        "Jules Han", "Cameron Shah", "Blake Mercer", "Micah Stone", "Noa Kim", "Robin Vega",
        "Ari Santos", "Shawn Brooks", "Kai Mullins", "Jamie Frost", "Devin Hsu", "Peyton Cole"
    ]

    let neutralTags: [UIColor] = [
        UIColor(red: 0.77, green: 0.20, blue: 0.22, alpha: 1.0),
        UIColor(white: 0.86, alpha: 1.0),
        UIColor(white: 0.20, alpha: 1.0)
    ]

    return names.enumerated().map { index, name in
        let role = Concept12Role.allCases[index % Concept12Role.allCases.count]
        var tags = [role.color]
        if index % 2 == 0 {
            tags.append(neutralTags[index % neutralTags.count])
        }
        if index % 5 == 0 {
            tags.append(Concept12Role.allCases[(index + 1) % Concept12Role.allCases.count].color)
        }

        return Concept12Person(
            id: index,
            name: name,
            role: role,
            portraitAssetName: String(format: "C12Portrait%02d", (index % 13) + 1),
            tagColors: Array(tags.prefix(3))
        )
    }
}()

struct Concept012: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    @State private var mode: Concept12Mode = .community
    @State private var selectedRole: Concept12Role?
    @State private var selectedPersonID: Int?
    @State private var controller = Concept12CompController()

    private let centralPanelAttachmentID = "concept12-central-panel"

    var body: some View {
        RealityView { content, attachments in
            await controller.build(people: concept12People, in: &content)
            controller.installCentralPanel(
                attachments.entity(for: centralPanelAttachmentID)
            )
            controller.applyFilter(selectedRole)
            controller.setSelected(selectedPersonID)
        } update: { _, attachments in
            controller.installCentralPanel(
                attachments.entity(for: centralPanelAttachmentID)
            )
            controller.applyFilter(selectedRole)
            controller.setSelected(selectedPersonID)
        } attachments: {
            Attachment(id: centralPanelAttachmentID) {
                Concept12CentralPanel(
                    mode: $mode,
                    selectedRole: $selectedRole,
                    onClose: closeConcept
                )
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let personID = controller.personID(for: value.entity) else { return }
                    selectedPersonID = selectedPersonID == personID ? nil : personID
                    controller.setSelected(selectedPersonID)
                }
        )
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // The comp is meant to be viewed by itself. Hiding the directory
            // window also prevents it from covering the central chooser in
            // Simulator and on device.
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

fileprivate struct Concept12CentralPanel: View {
    @Binding var mode: Concept12Mode
    @Binding var selectedRole: Concept12Role?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.62).opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: "play.fill")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .background(.black.opacity(0.20))
                .clipShape(Circle())
                .padding(12)
            }
            .frame(width: 520, height: 300)

            Picker("Mode", selection: $mode) {
                ForEach(Concept12Mode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Menu {
                Button("All Roles") { selectedRole = nil }
                Divider()
                ForEach(Concept12Role.allCases) { role in
                    Button(role.rawValue) { selectedRole = role }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Filter: \(selectedRole?.rawValue ?? "All Roles")")
                    Image(systemName: "chevron.down")
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.22))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassBackgroundEffect()
    }
}

@MainActor
fileprivate final class Concept12CompController {
    private struct BubbleState {
        let person: Concept12Person
        let root: Entity
        let sphere: ModelEntity
        let portraitEntity: ModelEntity
        let tagEntities: [ModelEntity]
    }

    private var bubbles: [Int: BubbleState] = [:]
    private let headAnchor = AnchorEntity(.head)
    private var anchorInstalled = false
    private var centralPanelInstalled = false
    private var selectedPersonID: Int?
    private var selectedRole: Concept12Role?

    func build(people: [Concept12Person], in content: inout RealityViewContent) async {
        guard bubbles.isEmpty else { return }

        if !anchorInstalled {
            headAnchor.anchoring.trackingMode = .once
            content.add(headAnchor)
            anchorInstalled = true
        }

        let positions = portraitPositions(count: people.count)

        for (person, position) in zip(people, positions) {
            let root = Entity()
            root.name = "person-\(person.id)"
            root.position = position
            // Rotate the entire bubble toward the viewer. This is the important
            // difference from the previous checkpoint: the backing sphere and
            // portrait now share the same camera-facing coordinate system, so
            // the sphere can no longer swing in front of the face.
            root.components.set(BillboardComponent())

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.108),
                materials: [SimpleMaterial(
                    color: UIColor(white: 0.76, alpha: 0.82),
                    roughness: 0.34,
                    isMetallic: false
                )]
            )
            sphere.name = "bubble-sphere"
            sphere.components.set(InputTargetComponent())
            sphere.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.12)]))
            root.addChild(sphere)

            let portraitEntity = await makePortraitEntity(for: person)
            portraitEntity.position = [0, 0, 0.111]
            root.addChild(portraitEntity)

            let offsets: [SIMD3<Float>] = [
                [-0.067, -0.105, 0.040],
                [0.000, -0.112, 0.045],
                [0.067, -0.105, 0.040]
            ]

            var tags: [ModelEntity] = []
            for (index, color) in person.tagColors.enumerated() {
                let tag = ModelEntity(
                    mesh: .generateSphere(radius: 0.024),
                    materials: [SimpleMaterial(color: color, roughness: 0.42, isMetallic: false)]
                )
                tag.position = offsets[min(index, offsets.count - 1)]
                root.addChild(tag)
                tags.append(tag)
            }

            bubbles[person.id] = BubbleState(
                person: person,
                root: root,
                sphere: sphere,
                portraitEntity: portraitEntity,
                tagEntities: tags
            )
            headAnchor.addChild(root)
        }

        refreshVisuals()
    }

    func installCentralPanel(_ panel: ViewAttachmentEntity?) {
        guard let panel else { return }
        panel.position = [0, 0.02, -1.18]
        panel.components.set(BillboardComponent())

        if panel.parent == nil {
            headAnchor.addChild(panel)
        }
        centralPanelInstalled = true
    }

    func setSelected(_ id: Int?) {
        selectedPersonID = id
        refreshVisuals()
    }

    func applyFilter(_ role: Concept12Role?) {
        selectedRole = role
        refreshVisuals()
    }

    func personID(for entity: Entity) -> Int? {
        var current: Entity? = entity
        while let candidate = current {
            if candidate.name.hasPrefix("person-"),
               let id = Int(candidate.name.dropFirst("person-".count)) {
                return id
            }
            current = candidate.parent
        }
        return nil
    }

    private func refreshVisuals() {
        for (id, state) in bubbles {
            let selected = selectedPersonID == id
            let dimmed = selectedRole != nil && state.person.role != selectedRole

            state.root.scale = SIMD3<Float>(repeating: selected ? 1.10 : 1.0)
            state.root.components.set(OpacityComponent(opacity: dimmed ? 0.32 : 1.0))

            let bubbleColor = selected
                ? UIColor(white: 0.90, alpha: 0.90)
                : UIColor(white: 0.76, alpha: 0.82)
            state.sphere.model?.materials = [SimpleMaterial(
                color: bubbleColor,
                roughness: selected ? 0.24 : 0.34,
                isMetallic: false
            )]
        }
    }

    private func makePortraitEntity(for person: Concept12Person) async -> ModelEntity {
        guard let image = UIImage(named: person.portraitAssetName),
              let cgImage = image.cgImage else {
            assertionFailure("Missing Concept 12 portrait asset: \(person.portraitAssetName)")
            return missingPortraitEntity(label: person.portraitAssetName)
        }

        do {
            let texture = try await TextureResource(
                image: cgImage,
                withName: "concept12-\(person.portraitAssetName)",
                options: TextureResource.CreateOptions(semantic: .color)
            )

            var material = UnlitMaterial(texture: texture)
            material.blending = .transparent(opacity: .init(floatLiteral: 1.0))

            return ModelEntity(
                mesh: .generatePlane(width: 0.205, height: 0.205, cornerRadius: 0),
                materials: [material]
            )
        } catch {
            assertionFailure("Could not create Concept 12 portrait texture \(person.portraitAssetName): \(error)")
            return missingPortraitEntity(label: person.portraitAssetName)
        }
    }

    private func missingPortraitEntity(label: String) -> ModelEntity {
        let material = UnlitMaterial(color: UIColor.magenta)
        let entity = ModelEntity(
            mesh: .generatePlane(width: 0.205, height: 0.205, cornerRadius: 0),
            materials: [material]
        )
        entity.name = "MISSING-PORTRAIT-\(label)"
        return entity
    }

    private func portraitPositions(count: Int) -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []

        // Positions are now relative to a head anchor captured once at launch,
        // so Simulator and the headset begin with the comp centered in front of
        // the viewer instead of using an arbitrary world-space origin.
        let leftXs: [Float] = [-1.00, -0.76, -0.52]
        let rightXs: [Float] = [0.52, 0.76, 1.00]
        let verticalYs: [Float] = [0.48, 0.20, -0.08]

        for x in leftXs {
            for y in verticalYs {
                positions.append([x, y, -1.22])
            }
        }
        for x in rightXs {
            for y in verticalYs {
                positions.append([x, y, -1.22])
            }
        }

        let rowOneXs: [Float] = [-1.02, -0.78, -0.54, -0.30, -0.06, 0.18, 0.42, 0.66, 0.90, 1.14]
        for x in rowOneXs {
            positions.append([x, -0.40, -1.16])
        }

        let rowTwoXs: [Float] = [-0.94, -0.68, -0.42, -0.16, 0.10, 0.36, 0.62, 0.88]
        for x in rowTwoXs {
            positions.append([x, -0.66, -1.10])
        }

        return Array(positions.prefix(count))
    }
}

#Preview {
    Concept012()
}
