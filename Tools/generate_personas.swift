#!/usr/bin/env swift

//  Imports the AVP persona renders into an asset catalogue for Concept 011.
//
//  The source files are 768x768 with no alpha, so they would render as hard
//  squares floating in the constellation. Each one is masked to a circle with
//  a soft edge and written out at 256x256 — the faces sit on a 2.35m dome and
//  never occupy many pixels, so the extra resolution is weight for nothing.
//
//  Names and roles are taken from the filenames
//  (`01-maya-spatial-ux-designer.png`), so the roster stays in step with the
//  assets rather than being retyped into Swift.
//
//      xcrun --sdk macosx swift Tools/generate_personas.swift ~/Desktop/avp-personas-v2
//
//  Created by Kiro on 11/5/26.

import Foundation
import AppKit

let args = Array(CommandLine.arguments.dropFirst())
guard let sourceDir = args.first else {
    print("usage: generate_personas.swift <source-directory>")
    exit(1)
}

let outputRoot = "SharedVisionsConcepts01/Assets.xcassets/Personas"
let side = 256

// MARK: - Roster parsing

struct Persona {
    let index: Int
    let asset: String
    let name: String
    let role: String
}

/// `01-maya-spatial-ux-designer` -> index 1, name "Maya", role "Spatial UX Designer".
func parse(_ stem: String) -> Persona? {
    let parts = stem.split(separator: "-").map(String.init)
    guard parts.count >= 3, let index = Int(parts[0]) else { return nil }

    let name = parts[1].capitalized
    let role = parts[2...]
        .map { word -> String in
            // Keep initialisms as initialisms, and platform names cased the
            // way Apple cases them.
            let upper = ["ux", "ui", "3d", "pm", "ar", "vr"]
            let exact = ["visionos": "visionOS", "ios": "iOS", "macos": "macOS", "tvos": "tvOS"]
            let lowered = word.lowercased()
            if let fixed = exact[lowered] { return fixed }
            return upper.contains(lowered) ? word.uppercased() : word.capitalized
        }
        .joined(separator: " ")

    return Persona(
        index: index,
        asset: String(format: "Persona%02d", index),
        name: name,
        role: role
    )
}

// MARK: - Masking

func circularMasked(_ image: NSImage) -> Data? {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: side * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    guard var rect = NSRect(x: 0, y: 0, width: side, height: side) as NSRect?,
          let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    else { return nil }

    // Soft-edged circular clip: a hard clip aliases badly once the face is
    // only a few dozen pixels across on the dome.
    let inset = Double(side) * 0.02
    let diameter = Double(side) - inset * 2
    context.saveGState()
    context.addEllipse(in: CGRect(x: inset, y: inset, width: diameter, height: diameter))
    context.clip()
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
    context.restoreGState()

    // Feather the rim by drawing a few progressively fainter black rings
    // outside the face, so the edge fades instead of cutting.
    let feather = Double(side) * 0.055
    let steps = 8
    for step in 0..<steps {
        let t = Double(step) / Double(steps)
        let ringInset = inset + feather * t
        let ringDiameter = Double(side) - ringInset * 2
        context.setStrokeColor(CGColor(gray: 0, alpha: 0))
        context.setBlendMode(.destinationOut)
        context.setLineWidth(feather / Double(steps) + 0.6)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.26 * (1 - t)))
        context.strokeEllipse(in: CGRect(
            x: ringInset,
            y: ringInset,
            width: ringDiameter,
            height: ringDiameter
        ))
    }
    context.setBlendMode(.normal)

    guard let out = context.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: out)
    return rep.representation(using: .png, properties: [:])
}

// MARK: - Run

let files = (try? FileManager.default.contentsOfDirectory(atPath: sourceDir))?
    .filter { $0.lowercased().hasSuffix(".png") }
    .sorted() ?? []

guard !files.isEmpty else {
    print("no PNGs in \(sourceDir)")
    exit(1)
}

try? FileManager.default.createDirectory(atPath: outputRoot, withIntermediateDirectories: true)
try """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

""".write(toFile: "\(outputRoot)/Contents.json", atomically: true, encoding: .utf8)

var roster: [Persona] = []

for file in files {
    let stem = (file as NSString).deletingPathExtension
    guard let persona = parse(stem) else {
        print("  skipped (unparsed name): \(file)")
        continue
    }
    guard let image = NSImage(contentsOfFile: "\(sourceDir)/\(file)"),
          let png = circularMasked(image) else {
        print("  skipped (unreadable): \(file)")
        continue
    }

    let setDir = "\(outputRoot)/\(persona.asset).imageset"
    try? FileManager.default.createDirectory(atPath: setDir, withIntermediateDirectories: true)
    try png.write(to: URL(fileURLWithPath: "\(setDir)/\(persona.asset).png"))
    try """
    {
      "images" : [
        {
          "filename" : "\(persona.asset).png",
          "idiom" : "universal",
          "scale" : "1x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """.write(toFile: "\(setDir)/Contents.json", atomically: true, encoding: .utf8)

    roster.append(persona)
    print("  \(persona.asset)  \(persona.name) — \(persona.role)")
}

// Emit the roster as Swift so names and roles cannot drift from the assets.
let entries = roster
    .sorted { $0.index < $1.index }
    .map { "    PersonaMember(asset: \"\($0.asset)\", name: \"\($0.name)\", role: \"\($0.role)\")," }
    .joined(separator: "\n")

let generated = """
//  Shared Visions Concepts
//
//  Generated by Tools/generate_personas.swift — do not edit.
//
//  The AVP persona renders, masked to soft circles and catalogued. Names and
//  roles come from the source filenames so this file cannot drift out of step
//  with the images beside it.

import Foundation

struct PersonaMember: Sendable {
    let asset: String
    let name: String
    let role: String
}

/// The \(roster.count) community members used by Concept 011.
let personaRoster: [PersonaMember] = [
\(entries)
]

"""
try generated.write(
    toFile: "SharedVisionsConcepts01/App/Generated/PersonaRoster.swift",
    atomically: true,
    encoding: .utf8
)

print("\nwrote \(roster.count) personas + App/Generated/PersonaRoster.swift")
