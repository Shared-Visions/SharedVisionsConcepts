//
//  Helpers.swift
//  SharedVisionsConcepts01
//
//  Created by Joseph Simpson on 2/1/26.
//

import SwiftUI

extension Date {
    init(_ dateString: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        self = dateFormatter.date(from: dateString) ?? Date()
    }
}

/// Numbers (into `Headshot01`...`Headshot16` in Assets.xcassets) of the
/// bundled stock headshots that depict adults. Headshots 2, 15, and 16 are
/// children and are excluded so mock "community member" / "interviewee" data
/// never surfaces a child's photo standing in for an adult role.
let adultHeadshotNumbers: [Int] = [1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

/// Maps an arbitrary index to one of the adult-only headshot asset names,
/// cycling through `adultHeadshotNumbers` rather than through all 16 images.
func adultHeadshotName(for index: Int) -> String {
    let number = adultHeadshotNumbers[index % adultHeadshotNumbers.count]
    return "Headshot\(String(format: "%02d", number))"
}



/// See WWDC 2025 Session: Meet SwiftUI spatial layout
/// https://developer.apple.com/videos/play/wwdc2025/273
extension View {
    func debugBorder3D(_ color: Color) -> some View {
        spatialOverlay {
            ZStack {
                Color.clear.border(color, width: 4)
                ZStack {
                    Color.clear.border(color, width: 4)
                    Spacer()
                    Color.clear.border(color, width: 4)
                }
                .rotation3DLayout(.degrees(90), axis: .y)
                Color.clear.border(color, width: 4)
            }
        }
    }
}

// As a view instead of a modifier
func debugBorder3DView(_ color: Color) -> some View {
    ZStack {
        Color.clear.border(color, width: 4)
        ZStack {
            Color.clear.border(color, width: 4)
            Spacer()
            Color.clear.border(color, width: 4)
        }
        .rotation3DLayout(.degrees(90), axis: .y)
        Color.clear.border(color, width: 4)
    }
}
