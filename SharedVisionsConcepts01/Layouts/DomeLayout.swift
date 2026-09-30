//
//  DomeLayout.swift
//  SharedVisionsConcepts01
//
//  Created by Kiro on 9/23/26.
//

import simd

/// Distributes points across the inside of a dome/sphere so 3D content can surround
/// the user rather than sitting on a flat grid. Unlike `RadialLayout`/`HoneycombLayout`
/// (which are SwiftUI `Layout` conformances operating on a 2D plane), this is a plain
/// math helper that returns real `SIMD3<Float>` world positions for use inside a
/// `RealityView`, since points on a sphere can't be expressed as 2D `CGPoint`s.
///
/// Uses a Fibonacci/golden-angle lattice (evenly distributed, non-repeating spacing)
/// restricted to a comfortable viewing arc in front of the user, rather than a full
/// sphere, so nothing lands directly overhead, underfoot, or behind the viewer.
struct DomeLayout {

    /// Standing eye height used to center dome content on the viewer's head
    /// rather than the world origin (which is typically floor level). Content
    /// built around `(0, 0, 0)` with no offset reads as "mostly toward the
    /// floor" once the user is standing at a realistic eye height above that
    /// origin — this default corrects for that.
    static let defaultEyeLevel: Float = 1.5

    /// Returns `count` positions on the inside of a sphere of the given `radius`,
    /// centered directly in front of the user (facing -Z) at `center` (eye height
    /// by default), restricted to `verticalArcDegrees` of elevation and
    /// `horizontalArcDegrees` of azimuth.
    ///
    /// - Parameters:
    ///   - count: Number of points to generate.
    ///   - radius: Distance from `center` to each point, in meters.
    ///   - verticalArcDegrees: Total elevation coverage, centered on the horizon.
    ///     Kept narrow by default so content stays within a comfortable
    ///     head-turn range instead of wrapping toward the floor or ceiling.
    ///   - horizontalArcDegrees: Total azimuth coverage, centered in front of
    ///     the user. Kept narrow by default so neighboring points don't read
    ///     as "spread too far apart" at typical dome radii.
    ///   - center: World-space point the dome is built around. Defaults to
    ///     `defaultEyeLevel` above the origin so content lands at eye level
    ///     for a standing viewer instead of at floor level.
    static func positions(
        count: Int,
        radius: Float,
        verticalArcDegrees: Float = 70,
        horizontalArcDegrees: Float = 150,
        center: SIMD3<Float> = SIMD3<Float>(0, defaultEyeLevel, 0)
    ) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }

        let goldenAngle: Float = .pi * (3 - sqrt(5)) // ~2.39996 radians
        let verticalArc = verticalArcDegrees * .pi / 180
        let horizontalArc = horizontalArcDegrees * .pi / 180

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(count)

        for i in 0..<count {
            // Even fractional spread across the vertical arc (low index = lower elevation).
            let t = (Float(i) + 0.5) / Float(count)
            let elevation = (t - 0.5) * verticalArc

            // Golden-angle spin gives an even, non-aligned azimuthal spread; wrap into 0...1
            // then map into the horizontal arc, centered in front of the user.
            let rawAzimuth = Float(i) * goldenAngle
            let azimuthFraction = (rawAzimuth / (2 * .pi)).truncatingRemainder(dividingBy: 1)
            let azimuth = (azimuthFraction - 0.5) * horizontalArc

            let x = radius * cos(elevation) * sin(azimuth)
            let y = radius * sin(elevation)
            let z = -radius * cos(elevation) * cos(azimuth)

            points.append(center + SIMD3<Float>(x, y, z))
        }

        return points
    }
}
