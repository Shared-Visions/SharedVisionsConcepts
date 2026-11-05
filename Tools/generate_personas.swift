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
let side = 512

// MARK: - Roster parsing

struct Persona {
    let index: Int
    let asset: String
    let name: String
    /// The person's actual job title, e.g. "Spatial Audio Composer".
    let title: String
    /// Which filter bucket they fall into. See `bucket(for:)`.
    let role: String
}

/// Maps a job title onto one of Concept 012's filter roles.
///
/// The design comp specified four — Developer, Designer, Artist,
/// Videographer — and twenty job titles do not divide cleanly into them.
/// Four of the five buckets are obvious; the problem is the production
/// people. A Studio Founder and a Product Manager are not videographers in
/// any sense, and filing them there would make "Videographer" return results
/// a reviewer would read as a bug.
///
/// So this adds a fifth bucket, **Producer**, which is a deliberate
/// deviation from the comp's four. Flagged rather than hidden: drop
/// `producer` and fold those three into `videographer` if the design team
/// would rather keep exactly four.
func bucket(for title: String) -> String {
    let t = title.lowercased()

    if t.contains("developer") || t.contains("engineer") || t.contains("dev") {
        return "Developer"
    }
    if t.contains("designer") || t.contains("architect") || t.contains("researcher") {
        return "Designer"
    }
    if t.contains("artist") || t.contains("composer") || t.contains("curator") {
        return "Artist"
    }
    if t.contains("filmmaker") || t.contains("film") || t.contains("streamer") {
        return "Videographer"
    }
    if t.contains("producer") || t.contains("founder") || t.contains("manager") {
        return "Producer"
    }
    // Unreachable for the current roster; a new title lands here rather than
    // being silently misfiled.
    return "Artist"
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
        title: role,
        role: bucket(for: role)
    )
}

// MARK: - Masking

/// Re-encodes a persona render at `side` square, full frame.
///
/// Deliberately *not* masked to a circle. Concept 012 lifts the subject with
/// Vision's foreground-instance mask at runtime, exactly as it does for the
/// stock headshots, and that needs the original background to cut against —
/// handing it a pre-masked circle would mean cutting out an already-cut
/// shape. Verified the lift succeeds on these renders: one foreground
/// instance each, real alpha, transparent corners.
func resized(_ image: NSImage) -> Data? {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: side * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    var rect = NSRect(x: 0, y: 0, width: side, height: side)
    guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    else { return nil }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

    guard let out = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:])
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
          let png = resized(image) else {
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
    print("  \(persona.asset)  \(persona.name) — \(persona.title)  [\(persona.role)]")
}

// Emit the roster as Swift so names and roles cannot drift from the assets.
let entries = roster
    .sorted { $0.index < $1.index }
    .map { "    PersonaMember(asset: \"\($0.asset)\", name: \"\($0.name)\", title: \"\($0.title)\", role: \"\($0.role)\")," }
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
    /// Actual job title, shown to the viewer.
    let title: String
    /// Filter bucket, one of Concept 012's `Role` values.
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
