//  Shared Visions Concepts
//
//  Title: Concept020
//
//  Subtitle: People, Simply
//
//  Description: A blend of 012 and 013: floating circular portraits with one SwiftUI attachment per person. Look at a portrait to reveal colorful tags, then tap for a details card positioned above or below that person. Filter the field by role. The details card is faked as an attachment that is reused on tap.
//
//  Type: Space
//
//  Featured: true
//
//  Created by Joseph Simpson on 11/10/26.

import SwiftUI
import RealityKit

struct Concept020: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter = Concept20Filter()
    @State private var details = Entity()

    init() {
        Concept20FloatComponent.registerComponent()
        Concept20FloatSystem.registerSystem()
    }

    var body: some View {
        RealityView { content in
            // Use the same world-space eye level as Concept 012 for interactive UI.
            let anchor = Entity()
            anchor.position.y = DomeLayout.defaultEyeLevel
            content.add(anchor)

            for person in concept20People {
                let node = Entity()
                node.name = "concept20-person-\(person.id)"
                node.components.set(ViewAttachmentComponent(rootView:
                    Concept20PersonNode(person: person, filter: filter) { [weak node] in
                        guard let node else { return }
                        showDetails(for: person, beside: node)
                    }
                ))
                node.components.set(BillboardComponent())

                let row = person.id / 5
                let column = person.id % 5
                let angle = Float(column - 2) * 0.27 + (row.isMultiple(of: 2) ? -0.045 : 0.045)
                let distance: Float = 1.85 + Float(row % 2) * 0.12
                let position = SIMD3<Float>(
                    sin(angle) * distance,
                    0.62 - Float(row) * 0.38,
                    -cos(angle) * distance
                )
                node.position = position
                node.components.set(Concept20FloatComponent(
                    origin: position,
                    phase: Float(person.id) * 1.7,
                    isEnabled: !reduceMotion
                ))
                anchor.addChild(node)
            }

            let controls = Entity()
            controls.position = [0, -0.65, -1.15]
            controls.components.set(ViewAttachmentComponent(rootView:
                Concept20Controls(filter: filter) {
                    Task { @MainActor in
                        await dismissImmersiveSpace()
                    }
                }
            ))
            anchor.addChild(controls)
        } update: { content in
            // Keep all motion in RealityKit; SwiftUI only updates for interaction.
            for entity in content.entities {
                for node in entity.children {
                    if var motion = node.components[Concept20FloatComponent.self] {
                        motion.isEnabled = !reduceMotion
                        node.components.set(motion)
                    }
                }
            }
        }
        .onChange(of: filter.role) { _, _ in details.isEnabled = false }
        .onAppear { dismissWindow(id: "MainWindow") }
        .onDisappear { openWindow(id: "MainWindow") }
    }

    private func showDetails(for person: Concept20Person, beside node: Entity) {
        if details.parent === node, details.isEnabled {
            details.isEnabled = false
            return
        }

        // Reuse one card, and parent it to the selected portrait so it floats with it.
        details.components.set(ViewAttachmentComponent(rootView:
            Concept20Details(person: person) {
                details.isEnabled = false
            }
            .glassBackgroundEffect()
        ))
        node.addChild(details)
        let nodeHeight = node.components[Concept20FloatComponent.self]?.origin.y ?? node.position.y
        // Upper nodes open downward; lower nodes open upward toward eye level.
        details.position = [0, nodeHeight > 0 ? -0.24 : 0.24, 0.18]
        details.isEnabled = true
    }
}

#Preview {
    Concept020()
}

@MainActor
@Observable
fileprivate final class Concept20Filter {
    var role: Concept20Role?
}

fileprivate enum Concept20Role: String, CaseIterable, Identifiable {
    case developer = "Developer"
    case designer = "Designer"
    case artist = "Artist"
    case videographer = "Videographer"
    case producer = "Producer"

    var id: String { rawValue }
}

fileprivate struct Concept20Person: Identifiable {
    let id: Int
    let member: PersonaMember
    let tags: [Concept20Tag]

    var bio: String {
        "\(member.name) is a \(member.title.lowercased()) exploring new ways to create, connect, and tell stories in spatial computing."
    }
}

fileprivate enum Concept20Tag: String, CaseIterable, Identifiable {
    case design = "Design"
    case development = "Development"
    case film = "Film"
    case audio = "Audio"
    case art = "3D art"
    case community = "Community"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .design: "pencil.and.ruler"
        case .development: "chevron.left.forwardslash.chevron.right"
        case .film: "video.fill"
        case .audio: "waveform"
        case .art: "cube.fill"
        case .community: "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .design: SharedVisionsBrand.orchid
        case .development: SharedVisionsBrand.blue
        case .film: SharedVisionsBrand.rose
        case .audio: SharedVisionsBrand.sand
        case .art: SharedVisionsBrand.spring
        case .community: SharedVisionsBrand.aqua
        }
    }
}

fileprivate let concept20People = personaRoster.enumerated().map { index, member in
    let tags: [Concept20Tag]
    switch member.role {
    case "Developer": tags = [.development, .design, .art]
    case "Designer": tags = [.design, .art, .community]
    case "Videographer": tags = [.film, .audio, .art]
    case "Producer": tags = [.community, .film, .audio]
    default: tags = [.art, .audio, .design]
    }
    // Keep role-related interests first, then fill out a unique set of 1–6 tags.
    let orderedTags = tags + Concept20Tag.allCases.filter { !tags.contains($0) }
    return Concept20Person(id: index, member: member, tags: Array(orderedTags.prefix(index % 6 + 1)))
}

fileprivate struct Concept20PersonNode: View {
    let person: Concept20Person
    let filter: Concept20Filter
    let onSelect: () -> Void
    @Namespace private var hoverNamespace

    private var matchesFilter: Bool {
        filter.role == nil || filter.role?.rawValue == person.member.role
    }

    var body: some View {
        ZStack {
            Image(person.member.asset)
                .resizable()
                .scaledToFill()
                .frame(width: 144, height: 144)
                .background(.black.opacity(0.18), in: Circle())
                .clipShape(Circle())
                .padding(8)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                }
                .hoverEffect(in: HoverEffectGroup(hoverNamespace)) { effect, active, _ in
                    effect.animation(.easeInOut(duration: 0.2)) {
                        $0.scaleEffect(active ? 1.06 : 1)
                    }
                }

            // All tags remain inside this person's single attachment.
            ForEach(Array(person.tags.enumerated()), id: \.element.id) { index, tag in
                let centeredIndex = Double(index) - Double(person.tags.count - 1) / 2.0
                let angle: Double = centeredIndex * (27.0 * Double.pi / 180.0)
                let x = CGFloat(cos(angle) * 112)
                let y = CGFloat(sin(angle) * 112)
                Concept20TagCircle(tag: tag)
                    .offset(x: x, y: y)
                    .hoverEffect(in: HoverEffectGroup(hoverNamespace)) { effect, active, _ in
                        effect.animation(.easeInOut(duration: 0.22)) {
                            $0.opacity(active ? 1 : 0)
                                .offset(x: active ? 0 : -12)
                        }
                    }
            }
        }
        .frame(width: 160, height: 160)
        .contentShape(.interaction, Circle())
        .hoverEffectGroup(HoverEffectGroup(hoverNamespace))
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.member.name), \(person.member.title)")
        .accessibilityHint("Opens profile and interests")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect() }
        // Symmetric space keeps the attachment origin at the portrait center.
        .frame(width: 280, height: 260)
        .opacity(matchesFilter ? 1 : 0.18)
        .allowsHitTesting(matchesFilter)
        .accessibilityHidden(!matchesFilter)
        .animation(.easeInOut(duration: 0.25), value: matchesFilter)
    }
}

fileprivate struct Concept20TagCircle: View {
    let tag: Concept20Tag

    var body: some View {
        Image(systemName: tag.symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.black.opacity(0.8))
            .frame(width: 40, height: 40)
            .background(tag.color, in: Circle())
            .overlay { Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1) }
            .accessibilityLabel(tag.rawValue)
    }
}

fileprivate struct Concept20Details: View {
    let person: Concept20Person
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 18) {
                Image(person.member.asset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .background(.white.opacity(0.08), in: Circle())
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(person.member.name)
                        .font(.largeTitle.bold())
                    Text(person.member.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Close profile", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
            }

            Text(person.bio)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 14) {
                ForEach(person.tags) { tag in
                    VStack(spacing: 8) {
                        Concept20TagCircle(tag: tag)
                        Text(tag.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Sample profile")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 480)
    }
}

fileprivate struct Concept20Controls: View {
    let filter: Concept20Filter
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interview Universe").font(.headline)
                    Text("Look to discover interests. Tap to meet someone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close concept", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
            }

            HStack(spacing: 8) {
                Concept20RoleChip(title: "All", isSelected: filter.role == nil) {
                    filter.role = nil
                }
                ForEach(Concept20Role.allCases) { role in
                    Concept20RoleChip(title: role.rawValue, isSelected: filter.role == role) {
                        filter.role = filter.role == role ? nil : role
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 660)
        .glassBackgroundEffect()
    }
}

fileprivate struct Concept20RoleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? SharedVisionsBrand.blue : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(.hoverEffect, Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

fileprivate struct Concept20FloatComponent: Component {
    let origin: SIMD3<Float>
    let phase: Float
    var isEnabled: Bool
    var elapsed: Float = 0
}

fileprivate struct Concept20FloatSystem: System {
    static let query = EntityQuery(where: .has(Concept20FloatComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var motion = entity.components[Concept20FloatComponent.self] else { continue }
            if motion.isEnabled {
                motion.elapsed += Float(min(context.deltaTime, 0.1))
                let time = motion.elapsed * 0.45 + motion.phase
                entity.position = motion.origin + SIMD3<Float>(
                    sin(time * 0.7) * 0.012,
                    sin(time) * 0.018,
                    cos(time * 0.6) * 0.008
                )
            } else {
                entity.position = motion.origin
            }
            entity.components.set(motion)
        }
    }
}
