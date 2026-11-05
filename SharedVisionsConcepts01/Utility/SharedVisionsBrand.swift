//  Shared Visions Concepts
//
//  The Shared Visions brand: palette, typography and the hexagon mark, taken
//  from the design team's style guide (4 Nov 2026).
//
//  Lives in Utility/ rather than inside a concept file because every concept
//  should be drawing from the same palette — the per-concept "keep it all in
//  one file" convention applies to concept-specific code, not shared identity.
//
//  Created by Kiro on 11/4/26.

import SwiftUI

// MARK: - Palette

enum SharedVisionsBrand {

    // MARK: Primary

    /// `0091FF` — the blue of the five minor dots in the app icon.
    static let blue = Color(hex: 0x0091FF)

    /// `F0BD76` — the sand/gold of the icon's emphasised upper-right dot.
    static let sand = Color(hex: 0xF0BD76)

    /// `F0BD76` at 50%, listed as its own entry in the style guide. Reads as a
    /// muted olive over a dark ground, which is how it appears in the guide.
    static let sandMuted = Color(hex: 0xF0BD76).opacity(0.5)

    static let white = Color.white
    static let black = Color.black

    // MARK: Secondary

    /// `D99DF1`
    static let orchid = Color(hex: 0xD99DF1)
    /// `6D7CFF`
    static let periwinkle = Color(hex: 0x6D7CFF)
    /// `77D6EE`
    static let aqua = Color(hex: 0x77D6EE)
    /// `4D4D4D`
    static let graphite = Color(hex: 0x4D4D4D)
    /// `CCCCCC`
    static let mist = Color(hex: 0xCCCCCC)

    // The style guide's last two secondary swatches carry hex labels that do
    // not match what they show — a dusty pink labelled `349CF2` (a mid blue)
    // and a light green labelled `3CD3FE` (a cyan). Per the designers, the
    // swatches are right and the labels are wrong, so these two are recovered
    // from the guide's own pixels.
    //
    // The guide is a visionOS glass panel, so every swatch renders lighter
    // than its true value. Fitting that shift across the seven swatches whose
    // label and appearance *do* agree gives
    // `rendered = 0.778 x true + 51.9` (R^2 = 0.974); inverting it on the two
    // sampled pixels (#E393A7, #ADEDA1) yields the values below. They are
    // therefore accurate to a few units rather than exact — replace with the
    // designers' real hex when it is available.

    /// Recovered from the guide (sampled `#E393A7`); mislabelled `349CF2`.
    static let rose = Color(hex: 0xE17A94)
    /// Recovered from the guide (sampled `#ADEDA1`); mislabelled `3CD3FE`.
    static let spring = Color(hex: 0x9CEE8C)

    /// Accent colours cycled across the community roster.
    static let personAccents: [Color] = [blue, sand, orchid, rose, spring, periwinkle, aqua]

    /// Near-black ground the hexagon mark sits on in the app icon.
    static let markGround = Color(hex: 0x1C1A18)

    // MARK: Hexagon geometry

    /// Offset of one vertex of the brand hexagon, in points from its centre.
    ///
    /// Index 0 is the **upper-right** vertex and the sequence proceeds
    /// **clockwise**, matching the dot order in the app icon. Used by both
    /// `SharedVisionsMark` and the per-person app bubbles so the motif is
    /// literally the same geometry in both places.
    ///
    /// `height` is negated because SwiftUI's y axis grows downward.
    static func hexagonVertex(_ index: Int, radius: Double) -> CGSize {
        let degrees = 60 - Double(index % 6) * 60
        let radians = degrees * .pi / 180
        return CGSize(
            width: cos(radians) * radius,
            height: -sin(radians) * radius
        )
    }
}

// MARK: - Typography

/// The brand face is **Inter** (SemiBold / Medium / Light).
///
/// Inter is not a system face on visionOS and the font files are not in the
/// repo yet, so every call falls back to the system face at the matching
/// weight. Drop the Inter family into the bundle, list it under `UIAppFonts`
/// in Info.plist, and flip `isInterBundled` — nothing else needs to change.
enum SharedVisionsFont {

    /// Flip to `true` once Inter-SemiBold / -Medium / -Light are bundled.
    static let isInterBundled = false

    static func semiBold(_ style: Font.TextStyle) -> Font {
        font(named: "Inter-SemiBold", weight: .semibold, style: style)
    }

    static func medium(_ style: Font.TextStyle) -> Font {
        font(named: "Inter-Medium", weight: .medium, style: style)
    }

    static func light(_ style: Font.TextStyle) -> Font {
        font(named: "Inter-Light", weight: .light, style: style)
    }

    private static func font(named name: String, weight: Font.Weight, style: Font.TextStyle) -> Font {
        guard isInterBundled else {
            // `.system(_:weight:)` keeps Dynamic Type working, which a fixed
            // point size would not.
            return .system(style, weight: weight)
        }
        return .custom(name, size: pointSize(for: style), relativeTo: style)
    }

    /// Point sizes at the default Dynamic Type setting. `Font.custom` needs an
    /// explicit size even when given `relativeTo:`, so the mapping has to be
    /// stated somewhere.
    private static func pointSize(for style: Font.TextStyle) -> Double {
        switch style {
        case .extraLargeTitle2: 48
        case .extraLargeTitle: 36
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}

// MARK: - Mark

/// The Shared Visions hexagon mark, drawn rather than loaded.
///
/// There is no logo asset in the repo yet, and the mark is pure geometry — a
/// hexagon of six dots with the upper-right one emphasised in sand — so
/// drawing it costs less than an asset and stays sharp at any size. Swap in
/// the official artwork when it arrives; the call sites take a diameter and
/// nothing else.
struct SharedVisionsMark: View {

    var diameter: Double = 44

    /// Draw the near-black ground. Off when placing the mark on a surface that
    /// already reads as the icon's ground, e.g. the black video panel.
    var showsGround = true

    private var ringRadius: Double { diameter * 0.29 }
    private var dotDiameter: Double { diameter * 0.13 }

    var body: some View {
        ZStack {
            if showsGround {
                Circle().fill(SharedVisionsBrand.markGround)
            }

            Path { path in
                for index in 0..<6 {
                    let vertex = SharedVisionsBrand.hexagonVertex(index, radius: ringRadius)
                    let point = CGPoint(
                        x: diameter / 2 + vertex.width,
                        y: diameter / 2 + vertex.height
                    )
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.closeSubpath()
            }
            .stroke(SharedVisionsBrand.mist.opacity(0.32), lineWidth: diameter * 0.045)

            ForEach(0..<6, id: \.self) { index in
                let isEmphasised = index == 0
                Circle()
                    .fill(isEmphasised ? SharedVisionsBrand.sand : SharedVisionsBrand.blue)
                    .frame(
                        width: dotDiameter * (isEmphasised ? 1.5 : 1),
                        height: dotDiameter * (isEmphasised ? 1.5 : 1)
                    )
                    .offset(SharedVisionsBrand.hexagonVertex(index, radius: ringRadius))
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel("Shared Visions")
    }
}

// MARK: - Hex convenience

extension Color {
    /// Builds a colour from a packed `0xRRGGBB` literal, so style-guide hex
    /// values can be written exactly as the designers wrote them.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            SharedVisionsMark(diameter: 64)
            Text("Shared Visions")
                .font(SharedVisionsFont.semiBold(.title))
        }

        HStack(spacing: 10) {
            ForEach(Array(SharedVisionsBrand.personAccents.enumerated()), id: \.offset) { _, color in
                Circle().fill(color).frame(width: 40, height: 40)
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("We're gathering a community")
                .font(SharedVisionsFont.semiBold(.title3))
            Text("Of volunteers and collaborators to create")
                .font(SharedVisionsFont.medium(.body))
            Text("To create an immersive documentary about the Apple Vision Pro community.")
                .font(SharedVisionsFont.light(.body))
        }
    }
    .padding(40)
}
