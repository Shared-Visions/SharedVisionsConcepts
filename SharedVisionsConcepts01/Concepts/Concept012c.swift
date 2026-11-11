//  Shared Visions Concepts
//
//  Title: Concept012c
//
//  Subtitle: Interview Chooser Dome
//
//  Description: The 012b chooser dome revised against the next round of design feedback. The dome is pulled in tight: the field of view now tops out at 180 degrees so nobody sits behind the viewer's shoulders, and the spacing between orbs is cut by a quarter so the community reads as a crowd rather than a scattering. The spheres are now actually see-through — the blue-green tint is gone and the glass blends at 0.18 rather than 0.68, so the photo inside reads clearly instead of through a semi-opaque shell. Selecting someone no longer opens a panel off to the side with a second copy of their photo in it — the profile unfurls downward out of the bubble you tapped, anchored to that orb on the dome, and the face inside the bubble stays the only picture of that person on screen. Everything else carries over from 012b: the persistent documentary window nearer the viewer than the dome, Vision-lifted portraits layered in depth inside each sphere, app-category bubbles on the app icon's hexagon, working Community and Applications filters, and the in-headset tuning sliders.
//
//  Type: Space
//
//  Featured: true
//
//  Created by Kiro on 11/5/26.

import SwiftUI
import RealityKit
import RealityKitContent
import Vision
import CoreImage

// MARK: - Mock Data

/// Filter roles.
///
/// The first four come from the design comp's wireframe. `producer` is a
/// deliberate addition: the persona roster includes a Studio Founder, a
/// Product Manager and a Live Performance Producer, and filing those under
/// "Videographer" would make that filter return results a reviewer would
/// read as a bug. Fold them back in and drop this case if the design team
/// would rather keep exactly four.
fileprivate enum Role: String, CaseIterable, Identifiable {
    case developer = "Developer"
    case designer = "Designer"
    case artist = "Artist"
    case videographer = "Videographer"
    case producer = "Producer"

    var id: String { rawValue }
}

fileprivate enum ChooserMode: String, CaseIterable, Identifiable {
    case community = "Community"
    case applications = "Applications"

    var id: String { rawValue }
}

/// The "apps this person works in" bubbles clustered under each headshot.
///
/// The workshop note was to replace the flat colour dots in the comp with
/// actual app icons. No app-icon artwork exists in the asset catalogue yet,
/// so these use SF Symbols as stand-ins and keep a per-app tint as the
/// bubble fill; swapping in real icons later only means changing `symbol`
/// to an `Image(_:)` asset lookup.
/// The app categories a community member appears in.
///
/// Twelve rather than six, and that is a filtering decision rather than a
/// content one. People carry four to six categories so the hexagon around
/// their bubble actually reads as a hexagon — but across only six categories
/// that meant any single filter kept about 83% of the roster, and three of
/// the six matched everyone. A filter that excludes nobody is not a filter.
/// Twelve brings it to roughly 40% per category while leaving the hexagon
/// exactly as dense.
fileprivate enum AppTag: String, CaseIterable, Identifiable {
    case design
    case code
    case video
    case photo
    case audio
    case model
    case music
    case education
    case fitness
    case retail
    case gaming
    case productivity

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .design: "pencil.and.ruler"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .video: "video"
        case .photo: "camera"
        case .audio: "waveform"
        case .model: "cube"
        case .music: "music.note"
        case .education: "graduationcap"
        case .fitness: "figure.run"
        case .retail: "bag"
        case .gaming: "gamecontroller"
        case .productivity: "checklist"
        }
    }

    var label: String {
        switch self {
        case .design: "Design tools"
        case .code: "Development"
        case .video: "Video editing"
        case .photo: "Photography"
        case .audio: "Audio production"
        case .model: "3D modeling"
        case .music: "Music"
        case .education: "Education"
        case .fitness: "Fitness"
        case .retail: "Retail"
        case .gaming: "Gaming"
        case .productivity: "Productivity"
        }
    }

    /// Brand accents, cycled. Twelve categories over a seven-colour palette
    /// means some tints repeat — the ordering keeps repeats away from each
    /// other, and the icon carries the distinction where colour cannot.
    var tint: Color {
        switch self {
        case .design: SharedVisionsBrand.orchid
        case .code: SharedVisionsBrand.blue
        case .video: SharedVisionsBrand.rose
        case .photo: SharedVisionsBrand.aqua
        case .audio: SharedVisionsBrand.sand
        case .model: SharedVisionsBrand.spring
        case .music: SharedVisionsBrand.periwinkle
        case .education: SharedVisionsBrand.aqua
        case .fitness: SharedVisionsBrand.spring
        case .retail: SharedVisionsBrand.sand
        case .gaming: SharedVisionsBrand.orchid
        case .productivity: SharedVisionsBrand.blue
        }
    }
}

fileprivate struct Person: Identifiable {
    let id: Int
    let name: String
    /// Actual job title, e.g. "Spatial Audio Composer". Shown to the viewer;
    /// `role` is only the filter bucket it falls into.
    let title: String
    let role: Role
    let headshot: String
    let accentColor: Color
    let apps: [AppTag]
}

/// Forty mock community members. The count is deliberate: at the 200° field
/// of view the design comps imply, twenty orbs read as a sparse scattering
/// rather than a community surrounding the viewer. Only twelve adult
/// headshots are bundled, so faces repeat a little over three times across
/// the dome — the comps repeat faces too, so this matches rather than fights
/// them, but it is the reason to treat the roster as placeholder.
/// The community roster, built from the AVP persona renders.
///
/// Twenty real identities with names, job titles and portraits, replacing the
/// forty invented names and twelve stock headshots this used before. Faces no
/// longer repeat at all, where they previously appeared three or four times
/// around the dome.
///
/// The trade-off is density: twenty orbs across the comp's 200-degree field
/// read sparser than forty did. Repeating the roster would restore the
/// density but duplicate names, which is a worse defect than a thinner dome
/// — two people called Maya is the kind of thing a reviewer reports. The
/// field-of-view slider is the dial if it wants tightening.
fileprivate let mockPeople: [Person] = {
    let accentColors = SharedVisionsBrand.personAccents
    let appPool = AppTag.allCases

    return personaRoster.enumerated().map { index, member in
        // Four to six categories per person. The lower bound matters: the
        // bubbles sit on the app icon's hexagon, and below about four dots
        // the shape reads as an arc rather than a hexagon.
        //
        // Picked deterministically so the dome looks the same on every launch
        // and screenshots stay comparable across review rounds.
        let appCount = 4 + (index % 3)
        let apps = (0..<appCount).map { offset in
            appPool[(index * 2 + offset) % appPool.count]
        }

        return Person(
            id: index,
            name: member.name,
            title: member.title,
            // The generator buckets each job title; falling back to artist
            // keeps a new title visible rather than crashing on it.
            role: Role(rawValue: member.role) ?? .artist,
            headshot: member.asset,
            accentColor: accentColors[index % accentColors.count],
            apps: apps
        )
    }
}()

// MARK: - Design Tuning

/// Live knobs the design team asked for so proportions can be explored
/// in-headset instead of in code. Exposed through `TuningPanel` in the
/// scene's bottom ornament.
fileprivate struct DesignTuning {

    /// Video window size from the comp, before `videoScale` is applied.
    static let baseVideoSize = CGSize(width: 480, height: 270)

    /// Multiplier on the base video window size. Defaults to 1.5 to land the
    /// "increase the video window by ~50%" note from the workshop.
    var videoScale: Double = 1.5

    /// Uniform multiplier on each person orb, face and app bubbles included.
    /// Defaults above 1 after the first device pass — at 1.0 the bubbles read
    /// as too small to pick a face out of across a room.
    var bubbleScale: Double = 1.4

    /// Total horizontal arc, in degrees, that the dome of faces spans.
    ///
    /// 012b defaulted to 200°, which put people roughly 10° past each
    /// shoulder — the feedback was to keep the dome "more like 180 degrees
    /// within your field of view", with nobody behind the viewer. 180° puts
    /// the outermost faces exactly at the shoulder line, and the slider in
    /// `TuningPanel` is capped there so the dome can only be narrowed.
    var fieldOfViewDegrees: Double = 180

    /// How much of the glass sphere is blended over the face inside it.
    ///
    /// 012b inherited `WaterSphereMaterial`'s 0.68, which left only a third
    /// of the photo showing through — the feedback was that the spheres read
    /// as semi-opaque and the faces were unreadable unless you put your head
    /// inside one. At 0.18 the photo comes through clearly and the sphere is
    /// a glass shell around it. Exposed as a slider because RealityKit's
    /// transparent blending dims the specular glint along with the body, so
    /// where "clear glass" stops and "no sphere at all" starts is a judgement
    /// call best made in the headset.
    var glassOpacity: Double = 0.18

    var videoWidth: CGFloat { DesignTuning.baseVideoSize.width * CGFloat(videoScale) }
    var videoHeight: CGFloat { DesignTuning.baseVideoSize.height * CGFloat(videoScale) }
}

// MARK: - Concept012c

struct Concept012c: View {

    @State private var selectedRole: Role? = nil
    /// The Applications-mode counterpart to `selectedRole`. Kept separate
    /// rather than unified into one enum so switching modes returns you to
    /// the filter you last had in that mode.
    @State private var selectedApp: AppTag? = nil
    @State private var mode: ChooserMode = .community
    @State private var selectedPersonID: Int? = nil
    @State private var isVideoVisible = true
    @State private var isFilterPanelVisible = true
    @State private var tuning = DesignTuning()
    @State private var orbEntities: [Int: Entity] = [:]
    @State private var waterController = WaterOrbController()
    @State private var floatController = OrbFloatController()
    @State private var portraitStore = PersonaPortraitStore()

    private let domeRadius: Float = 1.3

    /// The video window sits well inside the dome of faces so it is the
    /// nearest object in the scene. The workshop asked for it to be "closer
    /// in the Z space to increase its prominence"; previously it shared a
    /// depth with the people around it and read as one more panel.
    private let videoDistance: Float = 0.85

    /// How far the filter panel hangs below eye level. It is then pushed out
    /// to `domeRadius` so it shares a depth with the faces.
    private let filterPanelDrop: Float = 0.45

    /// Where the selection overlay sits: directly on the tapped orb, pulled
    /// `selectionPanelLift` meters in from the dome surface so it floats in
    /// front of its own bubble and the bubbles either side of it. 012b yawed
    /// it 34° off to the right instead; the feedback was that the profile
    /// should expand out of the bubble itself.
    private let selectionPanelLift: Float = 0.07

    /// The water sphere's own radius, mirrored from `WaterOrbController` so
    /// the selection panel can be placed clear of the bubble it grows out of.
    private static let orbSphereRadius: Float = 0.05

    /// Half the selection panel's height in metres.
    ///
    /// The attachment is positioned by its centre, so hanging it under the
    /// bubble needs its half-height. RealityKit renders SwiftUI attachments
    /// at 1360 points per metre on visionOS; the panel measures roughly 300
    /// points tall, which is 0.22 m, so half of that is 0.11 m. Approximate
    /// on purpose — the panel's height depends on how many app capsules a
    /// person carries, and this only has to keep it off the face.
    private static let selectionPanelHalfHeight: Float = 0.11

    /// Vertical arc as a fraction of the horizontal arc.
    ///
    /// 012b used 0.46, which at its 200° default gave a 200°×92° field. The
    /// feedback was that the bubbles sat too far apart and wanted the gaps
    /// cut by 25%. Angular spacing on a dome goes as the square root of
    /// (arc area ÷ count), so a 25% tighter dome needs 0.75² = 0.5625 of the
    /// arc product. Dropping to 180° horizontal already takes out some of
    /// it; 180° × (180 × 0.32) = 10,368 against 012b's 200 × 92 = 18,400,
    /// which is 0.563 — the quarter reduction, with the horizontal cap
    /// respected rather than fought.
    private static let verticalArcRatio: Float = 0.32

    /// How far, in meters, the headshot is pushed away from the viewer so a
    /// rim of water sits in front of the face instead of the photo filling
    /// the sphere's silhouette.
    private static let headshotInset: Float = 0.014

    /// Headshot size on top of the `AttachmentAnchor`'s own 1.7 scale in the
    /// `PersonOrb` asset. Raised after the first device pass: at 0.6 the face
    /// occupied under half the sphere and was hard to make out across the
    /// room, even at full opacity.
    private static let headshotScale: Float = 0.78

    /// How far filtered-out people fade. The workshop comp shows them clearly
    /// still present but washed back, so this keeps the silhouette readable
    /// without competing with the people who match the filter. Worth tuning
    /// on device — passthrough brightness changes how much 0.25 reads as.
    private static let filteredOutOpacity: Float = 0.25

    private var domeCenter: SIMD3<Float> {
        SIMD3<Float>(0, DomeLayout.defaultEyeLevel, 0)
    }

    private var filterPanelPosition: SIMD3<Float> {
        // Solve for the depth that puts the panel on the dome's surface at
        // the given drop, so it is visually part of the field of people.
        let depth = sqrt(max(domeRadius * domeRadius - filterPanelDrop * filterPanelDrop, 0.01))
        return SIMD3<Float>(0, DomeLayout.defaultEyeLevel - filterPanelDrop, -depth)
    }

    /// The selection panel is anchored to the orb it belongs to, so the
    /// profile expands out of the bubble the viewer tapped instead of
    /// appearing in a fixed slot beside the documentary.
    ///
    /// The orb's resting dome position is used rather than its live
    /// transform: the float controller gives every orb a slow bob, and a
    /// 420pt panel inheriting that bob reads as drift rather than buoyancy.
    private var selectionPanelPosition: SIMD3<Float> {
        guard let selectedPersonID,
              let index = mockPeople.firstIndex(where: { $0.id == selectedPersonID }) else {
            // Nothing selected, or mid-dismiss. The entity is disabled in
            // this state, but parking it on the dome ahead keeps it off the
            // origin — which is on the floor between the viewer's feet.
            return SIMD3<Float>(0, DomeLayout.defaultEyeLevel, -domeRadius)
        }

        let orbPosition = domePositions()[index]
        let fromCenter = orbPosition - domeCenter
        let lifted = (domeRadius - selectionPanelLift) / domeRadius
        var position = domeCenter + fromCenter * lifted

        // Hang the panel below its bubble so the face stays the thing you
        // look at while the profile unfurls under it. The clearance tracks
        // `bubbleScale` because that slider changes the sphere's radius, and
        // a panel sized for 1.0 cuts across the face at 2.0.
        let sphereClearance = Self.orbSphereRadius * Float(tuning.bubbleScale)
        position.y -= sphereClearance + Self.selectionPanelHalfHeight + 0.02
        return position
    }

    /// Whichever filter the current mode owns.
    ///
    /// Applications filter by the categories a person appears in, exactly as
    /// Community filters by role — previously the mode switch changed what the
    /// bubbles emphasised but left the filter inert, so the Applications half
    /// of the toggle did nothing you could act on.
    private var filteredPeople: [Person] {
        switch mode {
        case .community:
            guard let selectedRole else { return mockPeople }
            return mockPeople.filter { $0.role == selectedRole }
        case .applications:
            guard let selectedApp else { return mockPeople }
            return mockPeople.filter { $0.apps.contains(selectedApp) }
        }
    }

    private var selectedPerson: Person? {
        guard let selectedPersonID else { return nil }
        return mockPeople.first { $0.id == selectedPersonID }
    }

    var body: some View {
        RealityView { content, attachments in
            buildDome(in: &content, attachments: attachments)
            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                waterController.update(deltaTime: event.deltaTime)
                floatController.update(deltaTime: event.deltaTime)
            }
        } update: { content, attachments in
            updateDome(in: &content, attachments: attachments)
        } attachments: {
            ForEach(mockPeople) { person in
                Attachment(id: person.id) {
                    PersonAttachment(
                        person: person,
                        portrait: portraitStore.portrait(for: person),
                        isSelected: person.id == selectedPersonID,
                        appsEmphasized: mode == .applications
                    )
                }
            }

            Attachment(id: "videoPanel") {
                DocumentaryPanel(
                    person: selectedPerson,
                    width: tuning.videoWidth,
                    height: tuning.videoHeight
                ) {
                    isVideoVisible = false
                }
            }

            Attachment(id: "universePanel") {
                InterviewUniversePanel(mode: $mode, selectedRole: $selectedRole, selectedApp: $selectedApp) {
                    isFilterPanelVisible = false
                }
            }

            Attachment(id: "selectionPanel") {
                // Built against the last selected person so the panel keeps
                // its content through the dismiss transition instead of
                // emptying out as it fades. The `id` forces a fresh view
                // when the selection moves to a different person, so the
                // expand animation replays out of the newly tapped bubble
                // instead of the panel simply swapping its text.
                if let person = selectedPerson {
                    ExpandingSelectionPanel(person: person) {
                        isVideoVisible = true
                    } onClose: {
                        selectedPersonID = nil
                    }
                    .id(person.id)
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let personID = personID(for: value.entity) {
                        selectedPersonID = (selectedPersonID == personID) ? nil : personID
                        // Tapping a person is the way back to a dismissed
                        // video window, since the documentary is now the
                        // persistent centre of the scene rather than
                        // something selection summons.
                        if selectedPersonID != nil {
                            isVideoVisible = true
                        }
                    }

                    // Disturb the water at the point actually touched, not
                    // just the orb's center, so the ripple originates from
                    // wherever the viewer pinched — this only works for
                    // entities the water controller is tracking, so tapping
                    // elsewhere on the orb hierarchy (e.g. the headshot
                    // attachment) is a no-op rather than an error.
                    let localPoint = value.convert(value.location3D, from: .local, to: value.entity)
                    waterController.disturb(sphereEntity: value.entity, at: SIMD3<Float>(localPoint))
                }
        )
        .onChange(of: mode) { _, _ in selectedPersonID = nil }
        .onChange(of: selectedRole) { _, _ in selectedPersonID = nil }
        .onChange(of: selectedApp) { _, _ in selectedPersonID = nil }
        .task { portraitStore.loadIfNeeded(for: mockPeople) }
        .persistentSystemOverlays(.hidden)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            TuningPanel(
                tuning: $tuning,
                isVideoVisible: $isVideoVisible,
                isFilterPanelVisible: $isFilterPanelVisible
            )
        }
    }

    /// Walks up from the tapped entity (which may be the water sphere child) to find
    /// the orb root, whose name encodes the person id as "orb-<id>".
    private func personID(for entity: Entity) -> Int? {
        var current: Entity? = entity
        while let candidate = current {
            if candidate.name.hasPrefix("orb-"),
               let id = Int(candidate.name.dropFirst("orb-".count)) {
                return id
            }
            current = candidate.parent
        }
        return nil
    }

    // MARK: Dome construction

    /// Positions for the whole roster at the current field of view. The
    /// vertical arc tracks the horizontal one so widening the view wraps
    /// faces around the viewer instead of stretching them into a thin band.
    private func domePositions() -> [SIMD3<Float>] {
        let horizontalArc = Float(tuning.fieldOfViewDegrees)
        let verticalArc = max(40, horizontalArc * Self.verticalArcRatio)

        return DomeLayout.positions(
            count: mockPeople.count,
            radius: domeRadius,
            verticalArcDegrees: verticalArc,
            horizontalArcDegrees: horizontalArc,
            center: domeCenter
        )
    }

    @MainActor
    private func buildDome(in content: inout RealityViewContent, attachments: RealityViewAttachments) {
        let positions = domePositions()

        for (index, person) in mockPeople.enumerated() {
            guard let orb = makeOrbEntity(for: person, attachments: attachments) else { continue }
            orb.position = positions[index]
            // Point the orb back at the viewer's eye level so every sphere on
            // the dome reads correctly instead of every orb sharing one
            // identical, unrotated pose.
            orb.look(at: domeCenter, from: orb.position, relativeTo: nil)
            orb.name = "orb-\(person.id)"
            orbEntities[person.id] = orb
            floatController.register(
                personID: person.id,
                entity: orb,
                basePosition: positions[index],
                index: index
            )
            content.add(orb)
        }
    }

    @MainActor
    private func makeOrbEntity(for person: Person, attachments: RealityViewAttachments) -> Entity? {
        guard let orb = try? Entity.load(named: "PersonOrb", in: realityKitContentBundle) else { return nil }

        // The loaded asset's own "GlassSphere" geometry/material is replaced
        // with a generated water sphere (see `WaterSphereEffect.swift`); the
        // asset is still used for its `AttachmentAnchor` and `PointLight`
        // children so the headshot placement and backlight logic don't need
        // to change.
        if let glassSphere = orb.findEntity(named: "GlassSphere") {
            glassSphere.removeFromParent()
        }

        let waterSphere = waterController.makeSphereEntity(for: person.id)
        orb.addChild(waterSphere)

        if let anchor = orb.findEntity(named: "AttachmentAnchor"),
           let attachment = attachments.entity(for: person.id) {
            // Billboard the headshot attachment itself (not the orb root) so
            // the photo always faces the viewer no matter where the orb sits
            // on the dome, while the water sphere and its light stay put.
            attachment.components.set(BillboardComponent())
            // `look(at:)` aims the orb's forward (-Z) at the viewer, so a
            // positive Z offset pushes the photo deeper into the sphere,
            // away from the viewer. If it reads as popping out in front of
            // the water on device, flip this sign.
            attachment.position = SIMD3<Float>(0, 0, Self.headshotInset)
            attachment.scale = SIMD3<Float>(repeating: Self.headshotScale)
            anchor.addChild(attachment)
        }

        applyGlow(to: orb, person: person, isActive: false, matchesFilter: true)

        return orb
    }

    @MainActor
    private func updateDome(in content: inout RealityViewContent, attachments: RealityViewAttachments) {
        let visibleIDs = Set(filteredPeople.map(\.id))
        let positions = domePositions()
        let orbScale = Float(tuning.bubbleScale)

        waterController.setGlassOpacity(Float(tuning.glassOpacity))

        for (index, person) in mockPeople.enumerated() {
            guard let orb = orbEntities[person.id] else { continue }
            let matchesFilter = visibleIDs.contains(person.id)
            let isActive = person.id == selectedPersonID
            let basePosition = positions[index]

            // Filtered-out people fade rather than disappear, so the dome
            // stays one continuous surface of faces instead of developing
            // holes where a role was filtered away. `OpacityComponent` fades
            // the whole orb hierarchy — water sphere, face and app bubbles
            // together — so the parts can't drift out of sync.
            orb.components.set(
                OpacityComponent(opacity: matchesFilter ? 1 : Self.filteredOutOpacity)
            )
            // Faded people are background, not targets. Without this they
            // would still take taps and spawn ripples while reading as
            // inactive, which is worse than hiding them was.
            setInputEnabled(matchesFilter, on: orb)

            // The active person swells slightly as well as gaining colour, so
            // focus reads from across the dome and not only up close.
            orb.scale = SIMD3<Float>(repeating: orbScale * (isActive ? 1.28 : 1))
            // Re-aim from the new spot after a field-of-view change. This also
            // reassigns position, which the float controller picks back up on
            // the next frame.
            orb.look(at: domeCenter, from: basePosition, relativeTo: nil)
            floatController.setBasePosition(basePosition, for: person.id)
            applyGlow(to: orb, person: person, isActive: isActive, matchesFilter: matchesFilter)
        }

        if let panelAttachment = attachments.entity(for: "videoPanel") {
            panelAttachment.isEnabled = isVideoVisible
            panelAttachment.position = SIMD3<Float>(0, DomeLayout.defaultEyeLevel, -videoDistance)
            if panelAttachment.parent == nil {
                content.add(panelAttachment)
            }
        }

        if let panelAttachment = attachments.entity(for: "universePanel") {
            panelAttachment.isEnabled = isFilterPanelVisible
            panelAttachment.position = filterPanelPosition
            if panelAttachment.parent == nil {
                content.add(panelAttachment)
            }
        }

        if let panelAttachment = attachments.entity(for: "selectionPanel") {
            panelAttachment.isEnabled = selectedPersonID != nil
            panelAttachment.position = selectionPanelPosition
            if panelAttachment.parent == nil {
                // The panel now sits on whichever orb is selected, anywhere
                // across the dome, so it is off-centre by construction and
                // would present at an angle without billboarding. Set once
                // on insert; the behaviour never changes, only the position.
                panelAttachment.components.set(BillboardComponent())
                content.add(panelAttachment)
            }
        }
    }

    /// Toggles tap and hover targeting for a whole orb. The water sphere is
    /// the only child carrying an `InputTargetComponent`, and disabling it
    /// also suppresses the hover effect, so one switch covers both.
    @MainActor
    private func setInputEnabled(_ isEnabled: Bool, on orb: Entity) {
        guard let sphere = orb.findEntity(named: "GlassSphere"),
              var input = sphere.components[InputTargetComponent.self] else { return }
        input.isEnabled = isEnabled
        sphere.components.set(input)
    }

    /// Dims the sphere's backlight for inactive people and brightens it, tinted to the
    /// person's accent color, for the currently active/selected person. Keeping every
    /// orb's light at a low idle intensity (rather than off) avoids the ~8-light
    /// RealityKit budget being visually obvious as orbs pop on/off.
    @MainActor
    private func applyGlow(to orb: Entity, person: Person, isActive: Bool, matchesFilter: Bool) {
        guard let light = orb.findEntity(named: "PointLight") else { return }
        // `PointLightComponent` needs a `CGColor`, so the brand `Color` is
        // bridged through `UIColor` here.
        let color = isActive ? UIColor(person.accentColor) : UIColor.white

        // The backlight has to track the fade. `OpacityComponent` does not
        // attenuate light a `PointLight` casts, so a filtered-out orb left at
        // full idle intensity stays conspicuous however transparent its
        // geometry becomes.
        let intensity: Float = if isActive {
            4000
        } else if matchesFilter {
            40
        } else {
            8
        }

        light.components[PointLightComponent.self] = PointLightComponent(
            cgColor: color.cgColor,
            intensity: intensity,
            attenuationRadius: 0.3
        )
    }
}

// MARK: - Persona Portrait Store

/// Lifts each headshot's subject off its background so faces can be rendered
/// as persona-style cut-outs rather than flat photos.
///
/// Uses Vision's `GenerateForegroundInstanceMaskRequest` — the same
/// subject-lifting model behind "lift subject from background" in Photos —
/// rather than hand-rolling segmentation or shipping pre-cut assets, so the
/// treatment keeps working when the design team swaps the photo pool.
///
/// Keyed by asset name, not person id: the roster is forty people drawn from
/// twelve bundled images, so caching per asset does twelve lifts instead of
/// forty.
@MainActor
@Observable
fileprivate final class PersonaPortraitStore {

    private(set) var portraits: [String: UIImage] = [:]

    /// Assets whose lift failed or produced no foreground instance. Tracked
    /// so a failure falls back to the circular crop permanently instead of
    /// being retried on every view update.
    private var unavailable: Set<String> = []
    private var inFlight: Set<String> = []

    func portrait(for person: Person) -> UIImage? {
        portraits[person.headshot]
    }

    /// Kicks off a lift for any asset not already done, failed or running.
    /// Safe to call repeatedly.
    func loadIfNeeded(for people: [Person]) {
        let names = Set(people.map(\.headshot))
        for name in names where portraits[name] == nil
            && !unavailable.contains(name)
            && !inFlight.contains(name) {
            inFlight.insert(name)
            Task { await lift(assetName: name) }
        }
    }

    private func lift(assetName: String) async {
        defer { inFlight.remove(assetName) }

        guard let cgImage = UIImage(named: assetName)?.cgImage else {
            unavailable.insert(assetName)
            return
        }

        if let lifted = await Self.liftSubject(from: cgImage) {
            portraits[assetName] = lifted
        } else {
            unavailable.insert(assetName)
        }
    }

    /// Runs off the main actor — segmentation on a dozen images would
    /// otherwise stutter the dome while it builds.
    private nonisolated static func liftSubject(from cgImage: CGImage) async -> UIImage? {
        let handler = ImageRequestHandler(cgImage)

        do {
            guard let observation = try await handler.perform(GenerateForegroundInstanceMaskRequest()),
                  !observation.allInstances.isEmpty else { return nil }

            // Cropping to the subject's extent means the returned image is
            // the head and shoulders, so the view can size it directly
            // instead of guessing where in the frame the person sat.
            let masked = try observation.generateMaskedImage(
                for: observation.allInstances,
                imageFrom: handler,
                croppedToInstancesExtent: true
            )

            let ciImage = CIImage(cvPixelBuffer: masked)
            guard let output = sharedContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: output)
        } catch {
            // Deliberately quiet: there is a designed fallback (the circular
            // crop in `PersonaPortrait`), this runs without user action, and
            // the asset is recorded in `unavailable` so it is not retried.
            return nil
        }
    }

    /// One context for all lifts. `CIContext` is expensive to build and is
    /// safe to share, so creating one per image would waste most of the work.
    private nonisolated static let sharedContext = CIContext()
}

// MARK: - Water Orb Controller

/// Owns one `WaterSphereMesh`/`ModelEntity` per person and regenerates its
/// mesh only while that orb has active ripples, so idle orbs (the common
/// case) cost nothing extra per frame beyond a resting sphere.
@MainActor
fileprivate final class WaterOrbController {

    private struct WaterState {
        let mesh: WaterSphereMesh
        let entity: ModelEntity
        var ripples: [WaterRipple] = []
    }

    private var statesByPersonID: [Int: WaterState] = [:]
    private var elapsedTime: Float = 0
    private let sphereRadius: Float = 0.05

    /// Neutral water. 012b used `WaterSphereMaterial`'s blue-green default,
    /// and the feedback on that round was to get the tint off the bubbles —
    /// so the only colour on an orb now comes from the person's own accent
    /// when they are selected. Kept just off white so the sphere still has a
    /// surface to catch highlights on rather than vanishing into the room.
    private let waterTint = UIColor(white: 0.78, alpha: 1.0)

    /// Uniform glow on the sphere's surface.
    ///
    /// Nearly off, where 012b ran it at 0.12. Emissive light is added across
    /// the whole sphere and is *not* attenuated by the transparency, so at
    /// 0.12 it veiled the face regardless of how clear the blending was —
    /// half the reason the spheres read as semi-opaque milk rather than
    /// glass. A trace is kept so the surface does not disappear entirely
    /// against a dark room.
    private let waterEmissiveIntensity: Float = 0.03

    /// How much of the glass is blended over the face behind it. Driven by
    /// `DesignTuning.glassOpacity` so it can be settled in-headset.
    private var glassOpacity: Float = 0.18

    /// Rebuilds every sphere's material when the glass opacity changes.
    ///
    /// Compared before assigning: this is called from the `RealityView`
    /// update closure, which runs on every state change in the concept, and
    /// rebuilding twenty materials per frame would be wasted work.
    func setGlassOpacity(_ opacity: Float) {
        guard abs(opacity - glassOpacity) > 0.001 else { return }
        glassOpacity = opacity

        let material = makeMaterial()
        for state in statesByPersonID.values {
            state.entity.model?.materials = [material]
        }
    }

    private func makeMaterial() -> PhysicallyBasedMaterial {
        WaterSphereMaterial.make(
            tint: waterTint,
            opacity: glassOpacity,
            emissiveIntensity: waterEmissiveIntensity
        )
    }

    /// Creates the water sphere entity for a person's orb. Named "GlassSphere"
    /// (matching the original asset's part name) so existing input-target /
    /// hover-effect / tap-lookup code elsewhere in this file keeps working
    /// unmodified.
    func makeSphereEntity(for personID: Int) -> ModelEntity {
        let mesh = WaterSphereMesh(radius: sphereRadius)
        let resource = try? mesh.generate(ripples: [], elapsedTime: 0)
        let entity = ModelEntity(
            mesh: resource ?? .generateSphere(radius: sphereRadius),
            materials: [makeMaterial()]
        )
        entity.name = "GlassSphere"
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: sphereRadius)]))

        statesByPersonID[personID] = WaterState(mesh: mesh, entity: entity)
        return entity
    }

    /// Starts a new ripple at `localPoint` (in the sphere entity's own local
    /// space) if `sphereEntity` is a water sphere this controller owns.
    func disturb(sphereEntity: Entity, at localPoint: SIMD3<Float>) {
        guard let (personID, _) = statesByPersonID.first(where: { $0.value.entity === sphereEntity }) else { return }
        guard var state = statesByPersonID[personID] else { return }

        let direction = simd_length(localPoint) > 0.0001 ? simd_normalize(localPoint) : SIMD3<Float>(0, 0, 1)
        state.ripples.append(WaterRipple(originDirection: direction, startTime: elapsedTime))
        // Cap concurrent ripples per orb so a flurry of taps can't make mesh
        // regeneration arbitrarily expensive.
        if state.ripples.count > 4 {
            state.ripples.removeFirst(state.ripples.count - 4)
        }
        statesByPersonID[personID] = state
    }

    func update(deltaTime: TimeInterval) {
        elapsedTime += Float(min(deltaTime, 1.0 / 20.0))

        for personID in Array(statesByPersonID.keys) {
            guard var state = statesByPersonID[personID] else { continue }

            state.ripples.removeAll { elapsedTime - $0.startTime > state.mesh.rippleLifetime }
            guard !state.ripples.isEmpty else { continue }

            if let resource = try? state.mesh.generate(ripples: state.ripples, elapsedTime: elapsedTime) {
                state.entity.model?.mesh = resource
            }
            statesByPersonID[personID] = state
        }
    }
}

// MARK: - Orb Float Controller

/// Gives every orb a slow, independent drift so the field of faces reads as
/// floating in the space rather than pinned to an invisible lattice — the
/// workshop note was that the faces should feel like they are floating. A
/// small vertical bob plus a slower, smaller lateral sway is enough to break
/// the lattice read without making the dome feel unstable.
@MainActor
fileprivate final class OrbFloatController {

    private struct FloatState {
        let entity: Entity
        var basePosition: SIMD3<Float>
        let phase: Float
    }

    private var statesByPersonID: [Int: FloatState] = [:]
    private var elapsedTime: Float = 0

    /// Peak vertical travel, in meters.
    private let bobAmplitude: Float = 0.022
    /// Peak lateral travel, in meters. Deliberately smaller and slower than
    /// the bob so the motion reads as buoyancy rather than orbiting.
    private let swayAmplitude: Float = 0.010
    private let bobSpeed: Float = 0.6
    private let swaySpeed: Float = 0.23

    func register(personID: Int, entity: Entity, basePosition: SIMD3<Float>, index: Int) {
        // Golden-angle phase spread keeps neighbors out of sync so the dome
        // never bobs in visible unison.
        statesByPersonID[personID] = FloatState(
            entity: entity,
            basePosition: basePosition,
            phase: Float(index) * 2.399963
        )
    }

    func setBasePosition(_ position: SIMD3<Float>, for personID: Int) {
        guard var state = statesByPersonID[personID] else { return }
        state.basePosition = position
        statesByPersonID[personID] = state
    }

    func update(deltaTime: TimeInterval) {
        elapsedTime += Float(min(deltaTime, 1.0 / 20.0))

        for state in statesByPersonID.values {
            let bob = sin(elapsedTime * bobSpeed + state.phase) * bobAmplitude
            let sway = cos(elapsedTime * swaySpeed + state.phase) * swayAmplitude
            state.entity.position = state.basePosition + SIMD3<Float>(sway, bob, 0)
        }
    }
}

// MARK: - Attachments

/// The face as it hangs inside a water sphere.
///
/// This is the "spatial persona photo instead of a 2D photo" note from the
/// workshop. Real Spatial Personas are a FaceTime-only API with no way to
/// render an arbitrary person, so the treatment is photographic rather than
/// avatar-based: the subject is lifted out of its background (see
/// `PersonaPortraitStore`) and the cut-out is layered in front of a soft
/// accent-tinted disc using `offset(z:)`. The gap between those two layers
/// parallaxes as the viewer moves, which is what sells the face as occupying
/// the inside of the sphere instead of being printed on it.
fileprivate struct PersonaPortrait: View {
    let person: Person
    let portrait: UIImage?
    let isSelected: Bool
    var diameter: Double = 70

    var body: some View {
        ZStack {
            // Neutral backing first. The accent tint alone washes out against
            // a bright room — on device the faces read as barely-there against
            // a white wall — so a dark disc sits directly behind the head to
            // give the cut-out something to separate from.
            Circle()
                .fill(.black.opacity(isSelected ? 0.5 : 0.34))
                .blur(radius: diameter * 0.1)
                .frame(width: diameter * 0.9, height: diameter * 0.9)

            // Stands in for light scattering through the water behind the
            // head, and reads as a rim glow around the darker backing. Only
            // the active face gets the accent; inactive ones take a neutral
            // grey so nothing competes with the person in focus.
            Circle()
                .fill(isSelected
                      ? person.accentColor.opacity(0.62)
                      : SharedVisionsBrand.mist.opacity(0.2))
                .blur(radius: diameter * 0.17)
                .frame(width: diameter, height: diameter)

            if let portrait {
                Image(uiImage: portrait)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: diameter * 0.94, height: diameter * 0.94)
                    .shadow(color: .black.opacity(0.4), radius: diameter * 0.07, y: diameter * 0.03)
                    // Toward the viewer, so the head sits proud of the
                    // backing disc rather than coplanar with it.
                    .offset(z: isSelected ? diameter * 0.26 : diameter * 0.13)
            } else {
                // Until the lift finishes — or if it fails on a given photo —
                // fall back to the circular crop so the dome is never empty.
                Image(person.headshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: diameter, height: diameter)
                    .clipShape(.circle)
                    .offset(z: diameter * 0.08)
            }
        }
        // Colour is the signal for focus: the active face is full colour and
        // slightly over-saturated, everyone else is monochrome. Filter state
        // is carried separately, by `OpacityComponent` on the orb.
        .grayscale(isSelected ? 0 : 1)
        .saturation(isSelected ? 1.25 : 1)
        .animation(.easeInOut(duration: 0.28), value: isSelected)
    }
}

/// A person's face with their app categories ringing it.
///
/// The app icon is a hexagon of dots around an empty centre; here the person's
/// face *is* that centre, with one dot per category on the hexagon's vertices.
///
/// Face and dots share a single attachment deliberately. It keeps the ring
/// radius expressed in points relative to the face — no points-to-metres
/// guesswork — and costs one attachment per person instead of two, which on a
/// forty-person dome is forty fewer entities.
fileprivate struct PersonAttachment: View {
    let person: Person
    let portrait: UIImage?
    let isSelected: Bool
    let appsEmphasized: Bool

    /// Face diameter in points. Its world size comes from the attachment's
    /// own scale (`headshotScale`), so this only sets the proportions between
    /// the face and the ring around it.
    private let faceDiameter: Double = 70

    /// Distance from the face's centre out to a dot's centre.
    ///
    /// The face renders at `headshotScale` (0.78) of the water sphere's
    /// diameter, so the sphere's edge sits at roughly `faceDiameter / 0.78 / 2`
    /// — about 45pt — in this view's coordinates. A radius of 0.95 puts the
    /// dots comfortably outside the glass rather than embedded in it.
    private var ringRadius: Double { faceDiameter * 0.95 }

    private var extent: Double {
        let outermost = ringRadius * AppBubbleRing.radiusMultiplier(forRing: ringCount - 1)
        return (outermost + AppBubbleRing.dotDiameter(isEmphasized: appsEmphasized)) * 2
    }

    private var ringCount: Int {
        max(1, Int((Double(person.apps.count) / 6).rounded(.up)))
    }

    var body: some View {
        ZStack {
            AppBubbleRing(
                apps: person.apps,
                isEmphasized: appsEmphasized,
                ringRadius: ringRadius
            )

            PersonaPortrait(
                person: person,
                portrait: portrait,
                isSelected: isSelected,
                diameter: faceDiameter
            )
            .overlay(
                Circle()
                    .stroke(person.accentColor, lineWidth: isSelected ? 3 : 0)
                    .frame(width: faceDiameter, height: faceDiameter)
            )
        }
        .frame(width: extent, height: extent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(person.name), \(person.title)")
    }
}

/// The category dots arranged around a person's bubble.
///
/// Uses the brand hexagon: index 0 at the upper-right vertex, proceeding
/// clockwise, the same geometry and order as the dots in the app icon. A
/// seventh category starts a second, wider concentric ring — "another loop"
/// outside the first, since in this arrangement the dots surround the face
/// rather than stacking below it.
fileprivate struct AppBubbleRing: View {
    let apps: [AppTag]
    let isEmphasized: Bool
    let ringRadius: Double

    static func dotDiameter(isEmphasized: Bool) -> Double {
        isEmphasized ? 28 : 21
    }

    /// Each further loop sits proportionally outside the one before it.
    static func radiusMultiplier(forRing ring: Int) -> Double {
        1 + Double(ring) * 0.46
    }

    private var dotDiameter: Double { Self.dotDiameter(isEmphasized: isEmphasized) }

    private var ringCount: Int {
        max(1, Int((Double(apps.count) / 6).rounded(.up)))
    }

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { ring in
                let start = ring * 6
                let end = min(start + 6, apps.count)
                let radius = ringRadius * Self.radiusMultiplier(forRing: ring)

                // Fixed ranges over a constant per-person collection, so
                // index identity is safe here.
                ForEach(start..<end, id: \.self) { index in
                    bubble(apps[index])
                        .offset(SharedVisionsBrand.hexagonVertex(index - start, radius: radius))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isEmphasized)
    }

    private func bubble(_ app: AppTag) -> some View {
        Image(systemName: app.symbol)
            .font(.system(size: dotDiameter * 0.52, weight: .semibold))
            .foregroundStyle(SharedVisionsBrand.white)
            .frame(width: dotDiameter, height: dotDiameter)
            .background(app.tint.opacity(0.95), in: .circle)
            .accessibilityLabel(app.label)
    }
}


/// The documentary window at the centre of the dome. Persistent rather than
/// summoned by selection, carrying its own title frame, and sized from the
/// `videoScale` tuning slider.
fileprivate struct DocumentaryPanel: View {
    let person: Person?
    let width: CGFloat
    let height: CGFloat
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.black)

            // Scrim behind the title so it stays legible once real footage
            // replaces the placeholder fill.
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.36)
            .clipShape(
                UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
            )

            HStack(alignment: .top, spacing: 14) {
                // No ground behind the mark here — the video panel is already
                // the near-black the icon sits on.
                SharedVisionsMark(diameter: 40, showsGround: false)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch the Shared Visions Documentary")
                        .font(SharedVisionsFont.semiBold(.title3))
                        .foregroundStyle(SharedVisionsBrand.white)
                    if let person {
                        Text("\(person.name) · \(person.title)")
                            .font(SharedVisionsFont.medium(.subheadline))
                            // Explicit white rather than `.secondary`, which
                            // renders near-invisible over the black video.
                            .foregroundStyle(SharedVisionsBrand.white.opacity(0.82))
                    }
                }
            }
            // Extra trailing room so a long name never runs under the close
            // button in the opposite corner.
            .padding(.init(top: 20, leading: 22, bottom: 20, trailing: 64))

            Image(systemName: "play.circle.fill")
                .font(.system(size: min(width, height) * 0.22))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topTrailing) {
            Button("Close video", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .padding(12)
        }
        .padding(20)
        .glassBackgroundEffect()
    }
}

/// The mode switch and role filter, moved off the video window into their own
/// panel sitting at the same depth as the faces so they read as belonging to
/// the community rather than to the documentary. Modeled on the "Interview
/// Universe" overlay from the earlier wireframes.
fileprivate struct InterviewUniversePanel: View {
    @Binding var mode: ChooserMode
    @Binding var selectedRole: Role?
    @Binding var selectedApp: AppTag?
    let onClose: () -> Void

    /// The subtitle names what the chips below will actually do, since the
    /// same row of buttons means two different things depending on mode.
    private var subtitle: String {
        switch mode {
        case .community: "Filter by what people do"
        case .applications: "Filter by the apps they appear in"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Universe")
                        .font(SharedVisionsFont.semiBold(.title3))
                    Text(subtitle)
                        .font(SharedVisionsFont.light(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close filters", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
            }

            Picker("Mode", selection: $mode) {
                ForEach(ChooserMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // The chips belong to whichever mode is active. They used to be
            // role-only and simply disabled in Applications mode, which left
            // half the toggle with nothing behind it.
            //
            // Wrapped two rows deep because six app categories do not fit
            // across the panel in one line the way four roles do.
            switch mode {
            case .community:
                HStack(spacing: 8) {
                    RoleFilterChip(title: "All", isSelected: selectedRole == nil) {
                        selectedRole = nil
                    }
                    ForEach(Role.allCases) { role in
                        RoleFilterChip(title: role.rawValue, isSelected: selectedRole == role) {
                            // Tapping the active chip clears it, so the filter
                            // can be undone without reaching for "All".
                            selectedRole = selectedRole == role ? nil : role
                        }
                    }
                }

            case .applications:
                VStack(alignment: .leading, spacing: 8) {
                    // Chunked three to a row; twelve categories will not fit
                    // across the panel in one line the way four roles do.
                    HStack(spacing: 8) {
                        RoleFilterChip(title: "All", isSelected: selectedApp == nil) {
                            selectedApp = nil
                        }
                        ForEach(Array(AppTag.allCases.prefix(2))) { app in
                            AppFilterChip(app: app, isSelected: selectedApp == app) {
                                selectedApp = selectedApp == app ? nil : app
                            }
                        }
                    }
                    ForEach(Array(stride(from: 2, to: AppTag.allCases.count, by: 3)), id: \.self) { start in
                        HStack(spacing: 8) {
                            ForEach(Array(AppTag.allCases[start..<min(start + 3, AppTag.allCases.count)])) { app in
                                AppFilterChip(app: app, isSelected: selectedApp == app) {
                                    selectedApp = selectedApp == app ? nil : app
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 440, alignment: .leading)
        .padding(24)
        .glassBackgroundEffect()
    }
}

/// Filter chip for an app category. Carries the category's icon and tint so
/// the chips match the bubbles they filter, which role chips have no need to.
fileprivate struct AppFilterChip: View {
    let app: AppTag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(app.label, systemImage: app.symbol)
                .font(SharedVisionsFont.medium(.caption))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? app.tint : app.tint.opacity(0.22))
                .foregroundStyle(isSelected ? SharedVisionsBrand.white : Color.primary)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct RoleFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SharedVisionsFont.medium(.caption))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? SharedVisionsBrand.blue : Color.clear)
                .foregroundStyle(isSelected ? SharedVisionsBrand.white : Color.primary)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selection Overlay

/// The per-person detail panel, opened by selecting a face.
///
/// This is the workshop's "add in the selection with the overlay, from the
/// previous wireframes" note, anchored to the Filter: Designer screenshot.
/// `InterviewUniversePanel` already covers filtering, so this covers the
/// other half — what selecting someone actually gets you — and deliberately
/// borrows that panel's title/subtitle/close layout so the two read as one
/// family rather than two unrelated windows.
///
/// No portrait. 012b opened with a 104pt `PersonaPortrait` at the top left,
/// which meant the same person's face was on screen twice — once in their
/// bubble and once in the panel. The feedback was that there should only be
/// one picture of a person, and the bubble's is the one that is already
/// spatial, so the panel carries their name and work instead.
fileprivate struct PersonSelectionOverlay: View {
    let person: Person
    let onWatch: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(SharedVisionsFont.semiBold(.title2))
                    Text(person.title)
                        .font(SharedVisionsFont.medium(.callout))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close profile", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Appears in")
                    .font(SharedVisionsFont.light(.caption))
                    .foregroundStyle(.secondary)

                // Wrapped three to a row. People now carry up to six apps so
                // the dome's hexagon motif reads, and six of these capsules
                // in one row would overflow the panel's 420pt width.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(stride(from: 0, to: person.apps.count, by: 3)), id: \.self) { start in
                        HStack(spacing: 10) {
                            ForEach(start..<min(start + 3, person.apps.count), id: \.self) { index in
                                let app = person.apps[index]
                                Label(app.label, systemImage: app.symbol)
                                    .font(SharedVisionsFont.medium(.caption))
                                    .labelStyle(.titleAndIcon)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(app.tint.opacity(0.28), in: .capsule)
                            }
                        }
                    }
                }
            }

            // The person's name sits directly above, so repeating it here
            // would be redundant — and splitting a display name to get a
            // first name is wrong for mononyms and multi-part given names.
            Button("Watch interview", systemImage: "play.fill", action: onWatch)
                .buttonStyle(.borderedProminent)
        }
        .frame(width: 420, alignment: .leading)
        .padding(24)
        .glassBackgroundEffect()
        .accessibilityLabel("Profile for \(person.name), \(person.title)")
    }
}

/// Grows `PersonSelectionOverlay` out of the bubble it belongs to.
///
/// The feedback asked for the panel to animate open from inside the bubble
/// rather than appearing beside it. The attachment entity is already hung
/// just under the selected orb (see `selectionPanelPosition`), so the motion
/// itself is done here in SwiftUI: the panel starts at a few percent scale,
/// anchored at its own top edge, and springs out to full size — so the growth
/// originates at the bubble's lower edge and unfurls downward.
///
/// Only `scaleEffect` and `opacity` are used, both render-time transforms
/// that stay inside the view's layout bounds. A SwiftUI `offset` would push
/// content outside the bounds RealityKit sized the attachment to, where it
/// risks being clipped; the equivalent displacement is done in metres on the
/// entity instead.
fileprivate struct ExpandingSelectionPanel: View {
    let person: Person
    let onWatch: () -> Void
    let onClose: () -> Void

    @State private var isExpanded = false

    var body: some View {
        PersonSelectionOverlay(person: person, onWatch: onWatch, onClose: onClose)
            .scaleEffect(isExpanded ? 1 : 0.04, anchor: .top)
            .opacity(isExpanded ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                    isExpanded = true
                }
            }
    }
}

// MARK: - Prototype Tuning

/// Lives in the scene's bottom ornament — the slot the mode switch used to
/// occupy — so the knobs are reachable without sitting inside the concept's
/// visual field.
fileprivate struct TuningPanel: View {
    @Binding var tuning: DesignTuning
    @Binding var isVideoVisible: Bool
    @Binding var isFilterPanelVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prototype Tuning")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TuningSlider(title: "Video size", value: $tuning.videoScale, range: 0.5...2.5)
            TuningSlider(title: "Bubble size", value: $tuning.bubbleScale, range: 0.5...2.0)
            TuningSlider(
                title: "Glass opacity",
                value: $tuning.glassOpacity,
                // Floor is not zero: at 0 the sphere vanishes and the faces
                // read as photos pinned in mid-air rather than people in
                // bubbles, which is a different concept.
                range: 0.05...0.7,
                unit: "",
                fractionLength: 2
            )
            TuningSlider(
                title: "Field of view",
                value: $tuning.fieldOfViewDegrees,
                // Capped at 180 rather than 012b's 300: past 180 the dome
                // wraps behind the viewer's shoulders, which the feedback
                // ruled out. The slider can narrow the dome, not widen it
                // past the brief.
                range: 90...180,
                unit: "°",
                fractionLength: 0
            )

            HStack(spacing: 10) {
                Toggle("Video", isOn: $isVideoVisible)
                Toggle("Filters", isOn: $isFilterPanelVisible)
            }
            .toggleStyle(.button)
            .font(.caption)
        }
        .frame(width: 340, alignment: .leading)
        .padding(18)
        .glassBackgroundEffect()
    }
}

fileprivate struct TuningSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String = "×"
    var fractionLength: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(fractionLength)))
                    + Text(unit)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Slider(value: $value, in: range)
                .accessibilityLabel(title)
        }
    }
}

#Preview {
    Concept012c()
}
