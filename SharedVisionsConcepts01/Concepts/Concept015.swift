//  Shared Visions Concepts
//
//  Title: Concept015
//
//  Subtitle: Interview Playback with Spatial Captions
//
//  Description: Interview playback with an AVPlayer-backed spatial panel and head-relative captions. Before real footage is bundled, the panel runs a simple animated 1/2/3 stock visual synchronized to the three sample lines of dialogue, then loops, so timing and caption behavior are easy to review.
//
//  Type: Space
//
//  Featured: true
//
//  Created by Kiro on 9/24/26.

import SwiftUI
import RealityKit
import RealityKitContent
import AVFoundation
import ARKit
import QuartzCore
import simd

fileprivate extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }

    var forward: SIMD3<Float> {
        simd_normalize(SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z))
    }

    var up: SIMD3<Float> {
        simd_normalize(SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z))
    }
}

// MARK: - Concept015

struct Concept015: View {

    @State private var coordinator = InterviewPlaybackCoordinator()

    var body: some View {
        RealityView { content, attachments in
            await coordinator.install(into: content, attachments: attachments)
        } update: { _, attachments in
            coordinator.updateAttachments(attachments)
        } attachments: {
            Attachment(id: InterviewPlaybackCoordinator.controlsAttachmentID) {
                InterviewPlaybackControls(coordinator: coordinator)
            }
            Attachment(id: InterviewPlaybackCoordinator.captionAttachmentID) {
                HeadRelativeCaptionView(coordinator: coordinator)
            }
            Attachment(id: InterviewPlaybackCoordinator.placeholderVisualAttachmentID) {
                PlaceholderInterviewVisual(coordinator: coordinator)
            }
        }
        .task {
            await coordinator.start()
        }
        .onDisappear {
            coordinator.stop()
        }
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Captions data

struct InterviewCaptionCue: Sendable, Equatable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    func contains(_ time: TimeInterval) -> Bool {
        time >= startTime && time < endTime
    }
}

enum InterviewCaptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .japanese: "日本語"
        }
    }

    var shortName: String {
        switch self {
        case .english: "EN"
        case .spanish: "ES"
        case .japanese: "日本語"
        }
    }
}

/// Parses the standard SRT timed-text format used by real subtitle files.
///
/// Kept as a plain parser (rather than something Bundle-specific) so it can
/// run identically against bundled `.srt` files once real interview footage
/// exists, or against the in-memory sample captions used for now.
enum InterviewSRTParser {
    static func parse(_ source: String) -> [InterviewCaptionCue] {
        let normalized = source
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [InterviewCaptionCue] = []

        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }

            let timingParts = lines[timingIndex]
                .components(separatedBy: "-->")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard timingParts.count == 2,
                  let start = parseTimestamp(timingParts[0]),
                  let end = parseTimestamp(timingParts[1]),
                  end > start else { continue }

            let text = lines.dropFirst(timingIndex + 1).joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            cues.append(InterviewCaptionCue(startTime: start, endTime: end, text: text))
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    private static func parseTimestamp(_ source: String) -> TimeInterval? {
        let timestamp = source.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? source
        let components = timestamp.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}

/// Sample multi-language captions in real SRT format, run through
/// `InterviewSRTParser` exactly like a bundled file would be. This keeps the
/// caption engine exercised end-to-end before real interview SRTs exist —
/// swap `sampleSRT(for:)` for a bundled-file lookup once footage is added.
fileprivate func sampleSRT(for language: InterviewCaptionLanguage) -> String {
    switch language {
    case .english:
        return """
        1
        00:00:00,000 --> 00:00:04,000
        Hi, I'm one of the people behind Shared Visions.

        2
        00:00:04,200 --> 00:00:08,500
        We wanted to tell the story of this community, not just the app.

        3
        00:00:08,700 --> 00:00:13,000
        Every orb in that dome is somebody who showed up for someone else.
        """
    case .spanish:
        return """
        1
        00:00:00,000 --> 00:00:04,000
        Hola, soy parte del equipo detrás de Shared Visions.

        2
        00:00:04,200 --> 00:00:08,500
        Queríamos contar la historia de esta comunidad, no solo de la app.

        3
        00:00:08,700 --> 00:00:13,000
        Cada esfera en esa cúpula es alguien que apareció por otra persona.
        """
    case .japanese:
        return """
        1
        00:00:00,000 --> 00:00:04,000
        こんにちは、Shared Visionsを作ったメンバーの一人です。

        2
        00:00:04,200 --> 00:00:08,500
        アプリだけでなく、このコミュニティの物語を伝えたかったんです。

        3
        00:00:08,700 --> 00:00:13,000
        ドームの中のすべての球は、誰かのために現れた人です。
        """
    }
}

// MARK: - Coordinator

@MainActor
@Observable
final class InterviewPlaybackCoordinator {
    static let controlsAttachmentID = "interview-playback-controls"
    static let captionAttachmentID = "interview-caption-text"
    static let placeholderVisualAttachmentID = "interview-placeholder-visual"

    private(set) var isPlaying = false
    private(set) var currentCaptionText = ""
    private(set) var availableLanguages: [InterviewCaptionLanguage] = InterviewCaptionLanguage.allCases
    private(set) var statusMessage = "No interview footage bundled yet — showing placeholder with sample captions."
    private(set) var hasRealVideo = false
    private(set) var currentPlaceholderNumber = 1
    var selectedLanguage: InterviewCaptionLanguage = .english

    @ObservationIgnored private let root = Entity()
    @ObservationIgnored private let panelRoot = Entity()
    /// Exposes the video panel root so other views reusing this coordinator
    /// can anchor transient visuals directly on the panel without
    /// duplicating placement logic.
    var panelRootEntity: Entity { panelRoot }
    @ObservationIgnored private var videoPlane: ModelEntity?
    @ObservationIgnored private weak var controlsEntity: ViewAttachmentEntity?
    @ObservationIgnored private weak var captionEntity: ViewAttachmentEntity?
    @ObservationIgnored private weak var placeholderVisualEntity: ViewAttachmentEntity?

    @ObservationIgnored private let arSession = ARKitSession()
    @ObservationIgnored private let worldTracking = WorldTrackingProvider()
    @ObservationIgnored private var didPlacePanel = false
    @ObservationIgnored private var smoothedCaptionPosition: SIMD3<Float>?

    @ObservationIgnored private var player: AVQueuePlayer?
    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var cuesByLanguage: [InterviewCaptionLanguage: [InterviewCaptionCue]] = [:]
    @ObservationIgnored private var lastDisplayedCue: InterviewCaptionCue?

    // Drives caption timing when there's no real player to read currentTime
    // from, so the sample captions still advance and loop convincingly.
    @ObservationIgnored private var placeholderClockStart: CFTimeInterval?

    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false

    private let panelSize = SIMD2<Float>(0.95, 0.534)
    private let panelDistance: Float = 1.30
    private let captionDistance: Float = 0.78
    private let captionDrop: Float = 0.17
    private let captionSmoothing: Float = 0.24
    private let sampleLoopDuration: TimeInterval = 13.0

    func install(into content: RealityViewContent, attachments: RealityViewAttachments) async {
        guard root.parent == nil else {
            attachViewsIfNeeded(attachments)
            return
        }

        content.add(root)
        root.addChild(panelRoot)
        panelRoot.position = [0, 1.25, -1.5]

        let mesh = MeshResource.generateBox(size: [panelSize.x, panelSize.y, 0.001])
        var placeholderMaterial = UnlitMaterial()
        placeholderMaterial.color = .init(tint: .black)

        let plane = ModelEntity(mesh: mesh, materials: [placeholderMaterial])
        plane.name = "interview-video-plane"
        panelRoot.addChild(plane)
        videoPlane = plane

        attachViewsIfNeeded(attachments)
    }

    func updateAttachments(_ attachments: RealityViewAttachments) {
        attachViewsIfNeeded(attachments)
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        do {
            try await arSession.run([worldTracking])
        } catch {
            print("Concept015: failed to start ARKitSession: \(error)")
        }

        loadCaptions()
        configureVideoIfBundled()
        placePanelIfPossible()

        if let player {
            player.play()
            isPlaying = true
        } else {
            placeholderClockStart = CACurrentMediaTime()
            isPlaying = true
        }

        startUpdateLoop()
    }

    func stop() {
        isRunning = false
        updateTask?.cancel()
        updateTask = nil
        player?.pause()
    }

    func togglePlayback() {
        if let player {
            if isPlaying {
                player.pause()
            } else {
                player.play()
            }
        } else {
            // Placeholder clock: pausing just stops advancing time; resuming
            // re-anchors the clock so playback continues from where it left
            // off rather than jumping back to zero.
            if isPlaying {
                placeholderClockStart = nil
            } else {
                placeholderClockStart = CACurrentMediaTime() - currentPlaceholderTime
            }
        }
        isPlaying.toggle()
    }

    func selectLanguage(_ language: InterviewCaptionLanguage) {
        guard availableLanguages.contains(language) else { return }
        selectedLanguage = language
        lastDisplayedCue = nil
        updateCaptionText(at: currentPlaybackTime())
    }

    // MARK: Setup

    private func attachViewsIfNeeded(_ attachments: RealityViewAttachments) {
        if controlsEntity == nil,
           let controls = attachments.entity(for: Self.controlsAttachmentID) {
            controls.name = Self.controlsAttachmentID
            controls.position = [0, -0.34, -0.018]
            // A SwiftUI attachment's visible face points the opposite way
            // from RealityKit's `look(at:)` forward axis; rotate just the
            // controls so they face the same direction as the video panel.
            controls.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
            panelRoot.addChild(controls)
            controlsEntity = controls
        }

        if captionEntity == nil,
           let caption = attachments.entity(for: Self.captionAttachmentID) {
            caption.name = Self.captionAttachmentID
            caption.components.set(BillboardComponent())
            root.addChild(caption)
            captionEntity = caption
        }

        if placeholderVisualEntity == nil,
           let placeholder = attachments.entity(for: Self.placeholderVisualAttachmentID) {
            placeholder.name = Self.placeholderVisualAttachmentID
            placeholder.position = [0, 0, -0.010]
            placeholder.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
            panelRoot.addChild(placeholder)
            placeholderVisualEntity = placeholder
        }
    }

    private func configureVideoIfBundled() {
        guard player == nil else { return }

        guard let url = bundledResourceURL(named: "interview01", extension: "mp4") else {
            // No footage yet — keep the black placeholder plane and drive
            // captions from the synthetic clock instead.
            hasRealVideo = false
            return
        }

        let templateItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)

        player = queuePlayer
        looper = playerLooper
        videoPlane?.model?.materials = [VideoMaterial(avPlayer: queuePlayer)]
        hasRealVideo = true
        placeholderVisualEntity?.isEnabled = false
        statusMessage = "Playing interview01.mp4"
    }

    private func loadCaptions() {
        cuesByLanguage.removeAll(keepingCapacity: true)

        for language in InterviewCaptionLanguage.allCases {
            if let url = bundledSRTURL(for: language) {
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    cuesByLanguage[language] = InterviewSRTParser.parse(text)
                    continue
                } catch {
                    print("Concept015: unable to read \(url.lastPathComponent): \(error)")
                }
            }

            // Fall back to the bundled sample script, parsed through the same
            // SRT pipeline a real file would go through.
            cuesByLanguage[language] = InterviewSRTParser.parse(sampleSRT(for: language))
        }

        availableLanguages = InterviewCaptionLanguage.allCases.filter { cuesByLanguage[$0] != nil }
        if !availableLanguages.contains(selectedLanguage), let first = availableLanguages.first {
            selectedLanguage = first
        }
    }

    private func bundledSRTURL(for language: InterviewCaptionLanguage) -> URL? {
        bundledResourceURL(named: "interview01.\(language.rawValue)", extension: "srt")
    }

    private func bundledResourceURL(named name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources")
            ?? Bundle.main.url(forResource: name, withExtension: fileExtension)
    }

    // MARK: Update loop

    private func startUpdateLoop() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isRunning {
                self.tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func tick() {
        placePanelIfPossible()
        updateCaptionPlacement()
        updateCaptionText(at: currentPlaybackTime())
    }

    private var currentPlaceholderTime: TimeInterval {
        guard let placeholderClockStart else { return 0 }
        return CACurrentMediaTime() - placeholderClockStart
    }

    private func currentPlaybackTime() -> TimeInterval {
        if let player {
            return player.currentTime().seconds
        }
        return currentPlaceholderTime.truncatingRemainder(dividingBy: sampleLoopDuration)
    }

    private func placePanelIfPossible() {
        guard !didPlacePanel else { return }
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }

        let matrix = anchor.originFromAnchorTransform
        let head = matrix.translation
        let forward = -matrix.forward
        let target = head + forward * panelDistance + matrix.up * 0.02

        panelRoot.position = target
        panelRoot.look(at: head, from: target, relativeTo: nil)
        didPlacePanel = true
    }

    private func updateCaptionPlacement() {
        guard let captionEntity,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }

        let matrix = anchor.originFromAnchorTransform
        let desiredPosition = matrix.translation + (-matrix.forward * captionDistance) - (matrix.up * captionDrop)

        let nextPosition: SIMD3<Float>
        if let current = smoothedCaptionPosition {
            nextPosition = simd_mix(current, desiredPosition, SIMD3<Float>(repeating: captionSmoothing))
        } else {
            nextPosition = desiredPosition
        }

        smoothedCaptionPosition = nextPosition
        captionEntity.setPosition(nextPosition, relativeTo: nil)
    }

    private func updateCaptionText(at time: TimeInterval) {
        guard let cues = cuesByLanguage[selectedLanguage] else {
            setDisplayedCue(nil)
            return
        }
        setDisplayedCue(cue(at: time, in: cues))
    }

    private func setDisplayedCue(_ cue: InterviewCaptionCue?) {
        guard cue != lastDisplayedCue else { return }
        lastDisplayedCue = cue
        currentCaptionText = cue?.text ?? ""
        captionEntity?.isEnabled = cue != nil

        if !hasRealVideo,
           let cue,
           let cues = cuesByLanguage[selectedLanguage],
           let index = cues.firstIndex(of: cue) {
            currentPlaceholderNumber = index + 1
            placeholderVisualEntity?.isEnabled = true
        }
    }

    private func cue(at time: TimeInterval, in cues: [InterviewCaptionCue]) -> InterviewCaptionCue? {
        var lowerBound = 0
        var upperBound = cues.count

        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if cues[midpoint].startTime <= time {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        let candidateIndex = lowerBound - 1
        guard candidateIndex >= 0, candidateIndex < cues.count else { return nil }
        let candidate = cues[candidateIndex]
        return candidate.contains(time) ? candidate : nil
    }
}

// MARK: - Attachments

fileprivate struct InterviewPlaybackControls: View {
    let coordinator: InterviewPlaybackCoordinator

    var body: some View {
        HStack(spacing: 12) {
            Button {
                coordinator.togglePlayback()
            } label: {
                Image(systemName: coordinator.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(coordinator.isPlaying ? "Pause" : "Play")

            Divider().frame(height: 24)

            Menu {
                ForEach(coordinator.availableLanguages) { language in
                    Button {
                        coordinator.selectLanguage(language)
                    } label: {
                        if language == coordinator.selectedLanguage {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "globe")
                    Text(coordinator.selectedLanguage.shortName)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .menuStyle(.button)

            Divider().frame(height: 24)

            Text(coordinator.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: 300)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassBackgroundEffect(in: Capsule())
    }
}

fileprivate struct PlaceholderInterviewVisual: View {
    let coordinator: InterviewPlaybackCoordinator

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black)

            VStack(spacing: 10) {
                Text("\(coordinator.currentPlaceholderNumber)")
                    .font(.system(size: 124, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.35), value: coordinator.currentPlaceholderNumber)

                Text("placeholder interview motion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 760, height: 427)
        .opacity(coordinator.hasRealVideo ? 0 : 1)
    }
}

struct HeadRelativeCaptionView: View {
    let coordinator: InterviewPlaybackCoordinator

    var body: some View {
        Text(coordinator.currentCaptionText)
            .font(.system(size: 30, weight: .semibold))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .frame(maxWidth: 700)
            .foregroundStyle(.white)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
            .opacity(coordinator.currentCaptionText.isEmpty ? 0 : 1)
            .animation(.easeOut(duration: 0.08), value: coordinator.currentCaptionText)
    }
}

#Preview {
    Concept015()
}
