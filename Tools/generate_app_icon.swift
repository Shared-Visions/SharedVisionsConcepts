#!/usr/bin/env swift

//  Generates the three visionOS app icon layers from the Shared Visions mark.
//
//  The icon is a layered `.solidimagestack`, so visionOS parallaxes the layers
//  as the viewer's head moves. Splitting the mark across them means the dots
//  float above the hexagon ring, which floats above the ground — the depth is
//  free, and it only works if the layers are separate images.
//
//  Drawn rather than exported from a design tool so it stays in sync with
//  `SharedVisionsBrand.hexagonVertex`. Re-run after changing the mark:
//
//      xcrun --sdk macosx swift Tools/generate_app_icon.swift
//
//  Created by Kiro on 11/5/26.

import SwiftUI
import AppKit

// MARK: - Brand values (mirrors SharedVisionsBrand)

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

let blue = Color(hex: 0x0091FF)
let sand = Color(hex: 0xF0BD76)
let mist = Color(hex: 0xCCCCCC)
let ground = Color(hex: 0x1C1A18)

/// Index 0 is the upper-right vertex, proceeding clockwise — the dot order in
/// the style guide's icon. Must stay identical to the app's version.
func hexagonVertex(_ index: Int, radius: Double) -> CGSize {
    let degrees = 60 - Double(index % 6) * 60
    let radians = degrees * .pi / 180
    return CGSize(width: cos(radians) * radius, height: -sin(radians) * radius)
}

/// Icon canvas in points. Rendered at scale 2 for a 1024x1024 px layer.
let side: Double = 512
let ringRadius = side * 0.29
let dotDiameter = side * 0.13

// MARK: - Layers

/// Opaque ground. Slightly lifted in the upper left so the icon has some form
/// under visionOS's specular treatment rather than reading as a flat disc.
struct BackLayer: View {
    var body: some View {
        RadialGradient(
            colors: [Color(hex: 0x2A2724), ground],
            center: UnitPoint(x: 0.34, y: 0.28),
            startRadius: 0,
            endRadius: side * 0.78
        )
        .frame(width: side, height: side)
    }
}

/// The hexagon that joins the dots.
struct MiddleLayer: View {
    var body: some View {
        Path { path in
            for index in 0..<6 {
                let vertex = hexagonVertex(index, radius: ringRadius)
                let point = CGPoint(x: side / 2 + vertex.width, y: side / 2 + vertex.height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
        .stroke(mist.opacity(0.34), style: StrokeStyle(lineWidth: side * 0.045, lineJoin: .round))
        .frame(width: side, height: side)
    }
}

/// The six dots, upper-right emphasised in sand.
struct FrontLayer: View {
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                let isEmphasised = index == 0
                let d = dotDiameter * (isEmphasised ? 1.5 : 1)
                Circle()
                    .fill(isEmphasised ? sand : blue)
                    .frame(width: d, height: d)
                    .offset(hexagonVertex(index, radius: ringRadius))
            }
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Render

let iconRoot = "SharedVisionsConcepts01/Assets.xcassets/AppIcon.solidimagestack"

@MainActor
func write<V: View>(_ view: V, layer: String, filename: String) throws {
    let renderer = ImageRenderer(content: view.frame(width: side, height: side))
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    let dir = "\(iconRoot)/\(layer).solidimagestacklayer/Content.imageset"
    try png.write(to: URL(fileURLWithPath: "\(dir)/\(filename)"))

    // Point the imageset at the file we just wrote.
    let contents = """
    {
      "images" : [
        {
          "filename" : "\(filename)",
          "idiom" : "vision",
          "scale" : "2x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    try contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    print("  \(layer): \(filename) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

try MainActor.assumeIsolated {
    print("writing app icon layers:")
    try write(BackLayer(), layer: "Back", filename: "icon-back.png")
    try write(MiddleLayer(), layer: "Middle", filename: "icon-middle.png")
    try write(FrontLayer(), layer: "Front", filename: "icon-front.png")
    print("done")
}
