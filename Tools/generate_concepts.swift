#!/usr/bin/env swift

import Foundation

struct ParsedConcept {
    let title: String
    let subtitle: String
    let description: String
    let typeCase: String
    let dateString: String
    let structName: String
    let isFeatured: Bool
    let success: Bool
    /// Concept number parsed from the title, when the title follows the "Concept NNN" shape.
    let number: Int?
    /// Optional letter suffix for variants of the same concept, e.g. the "b" in "Concept 012b".
    let suffix: String
}

func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: text) else {
        return nil
    }
    let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    let slashTrimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
    return slashTrimmed.isEmpty ? nil : value
}

func matchGroups(in text: String, pattern: String, groups: Int) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range),
          match.numberOfRanges > groups else {
        return nil
    }
    return (1...groups).map { index in
        guard let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
    }
}

func normalizedTitle(from raw: String?, structName: String) -> (title: String, number: Int?, suffix: String) {
    let candidates = [raw, structName]
    for candidate in candidates.compactMap({ $0 }) {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        // A concept may carry a letter suffix to mark a variant: Concept012b, Concept012c.
        if let groups = matchGroups(in: trimmed, pattern: "Concept\\s*0*([0-9]+)([a-zA-Z]?)", groups: 2),
           let number = Int(groups[0]) {
            let suffix = groups[1].lowercased()
            let title = String(format: "Concept %03d", number) + suffix
            return (title, number, suffix)
        }
    }
    let fallback = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? structName
    return (fallback, nil, "")
}

func normalizedDate(_ raw: String?) -> String {
    guard let raw else { return "01/01/2024" }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "/")
    guard parts.count == 3 else { return trimmed }
    let yearPart = parts[2]
    let fourDigitYear: String
    if yearPart.count == 2, let value = Int(yearPart) {
        fourDigitYear = String(2000 + value)
    } else {
        fourDigitYear = String(yearPart)
    }
    return "\(parts[0])/\(parts[1])/\(fourDigitYear)"
}

func typeCase(from raw: String?) -> String {
    let trimmed = (raw ?? "Window").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch trimmed {
    case "volume", "volume content":
        return ".VOLUME"
    case "space", "immersive space", "mixed immersive space":
        return ".SPACE"
    case "space full", "full immersive space", "immersive full":
        return ".SPACE_FULL"
    case "window alt", "window_alt", "plain window content", "plain window":
        return ".WINDOW_ALT"
    case "window", "window content":
        fallthrough
    default:
        return ".WINDOW"
    }
}

func boolFlag(from raw: String?, default defaultValue: Bool) -> Bool {
    guard let raw else { return defaultValue }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return value == "true" || value == "yes" || value == "1"
}

func swiftStringLiteral(_ value: String) -> String {
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escaped)\""
}

func parseConcept(from content: String, fileName: String) -> ParsedConcept? {
    guard let structName = firstMatch(in: content, pattern: "struct\\s+([A-Za-z0-9_]+)\\s*:\\s*View") else { return nil }

    let rawTitle = firstMatch(in: content, pattern: "//\\s*Title:\\s*(.+)")
    let subtitle = firstMatch(in: content, pattern: "//\\s*Subtitle:\\s*(.+)") ?? "Untitled"
    let description = firstMatch(in: content, pattern: "//\\s*Description:\\s*(.+)") ?? ""
    let rawType = firstMatch(in: content, pattern: "//\\s*Type:\\s*(.+)")
    let rawDate = firstMatch(in: content, pattern: "Created by .+ on ([0-9/]+)")
    let featuredRaw = firstMatch(in: content, pattern: "//\\s*Featured:\\s*(.+)")
    let successRaw = firstMatch(in: content, pattern: "//\\s*Success:\\s*(.+)")

    let normalized = normalizedTitle(from: rawTitle, structName: structName)
    let dateString = normalizedDate(rawDate)

    return ParsedConcept(
        title: normalized.title,
        subtitle: subtitle,
        description: description,
        typeCase: typeCase(from: rawType),
        dateString: dateString,
        structName: structName,
        isFeatured: boolFlag(from: featuredRaw, default: false),
        success: boolFlag(from: successRaw, default: true),
        number: normalized.number,
        suffix: normalized.suffix
    )
}

func render(entries: [ParsedConcept]) -> String {
    var lines: [String] = []
    lines.append("// This file is auto-generated. Do not edit by hand.\n// Generated by Tools/generate_concepts.swift\n")
    lines.append("import SwiftUI\n")
    lines.append("struct ConceptRegistry {\n    static let allConcepts: [Concept] = [\n")

    for (index, entry) in entries.enumerated() {
        let prefix = "    "
        let descriptionLiteral = swiftStringLiteral(entry.description)
        let subtitleLiteral = swiftStringLiteral(entry.subtitle)
        lines.append("\(prefix)Concept(\n" +
                    "\(prefix)    title: \(swiftStringLiteral(entry.title)),\n" +
                    "\(prefix)    type: \(entry.typeCase),\n" +
                    "\(prefix)    date: Date(\"\(entry.dateString)\"),\n" +
                    "\(prefix)    isFeatured: \(entry.isFeatured),\n" +
                    "\(prefix)    subtitle: \(subtitleLiteral),\n" +
                    "\(prefix)    description: \(descriptionLiteral),\n" +
                    "\(prefix)    success: \(entry.success),\n" +
                    "\(prefix)    makeView: { AnyView(\(entry.structName)()) }\n" +
                    "\(prefix))\(index == entries.count - 1 ? "" : ",")\n")
    }

    lines.append("    ]\n\n    static let conceptsByTitle: [String: Concept] = {\n        Dictionary(uniqueKeysWithValues: allConcepts.map { ($0.title, $0) })\n    }()\n}\n")

    return lines.joined()
}

struct Arguments {
    var sourcePath = "SharedVisionsConcepts01/Concepts"
    var outputPath = "SharedVisionsConcepts01/App/Generated/ConceptRegistry.swift"
}

func parseArguments() -> Arguments {
    var arguments = Arguments()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--src", "--source":
            if let value = iterator.next() { arguments.sourcePath = value }
        case "--out", "--output":
            if let value = iterator.next() { arguments.outputPath = value }
        default:
            continue
        }
    }
    return arguments
}

let args = parseArguments()
let fm = FileManager.default
let srcURL = URL(fileURLWithPath: args.sourcePath)
let outURL = URL(fileURLWithPath: args.outputPath)

let files = (try? fm.contentsOfDirectory(at: srcURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
let swiftFiles = files.filter { $0.pathExtension == "swift" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

var parsedEntries: [ParsedConcept] = []

for file in swiftFiles {
    guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
    if let entry = parseConcept(from: content, fileName: file.lastPathComponent) {
        parsedEntries.append(entry)
    } else {
        fputs("Warning: Skipping \(file.lastPathComponent) (could not parse)\n", stderr)
    }
}

// Sort by concept number, then by variant suffix so Concept 012b precedes Concept 012c.
parsedEntries.sort { lhs, rhs in
    if let l = lhs.number, let r = rhs.number {
        if l != r { return l < r }
        return lhs.suffix < rhs.suffix
    }
    return lhs.title < rhs.title
}

let output = render(entries: parsedEntries)
try fm.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try output.write(to: outURL, atomically: true, encoding: .utf8)
if swiftFiles.isEmpty {
    fputs("Warning: No .swift files found at \(srcURL.path)\n", stderr)
}
print("Scanned \(swiftFiles.count) files; generated \(parsedEntries.count) concepts -> \(args.outputPath)")
