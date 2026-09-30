//
//  WaterSphereEffect.swift
//  SharedVisionsConcepts01
//
//  Created by Kiro on 9/24/26.
//
//  A small, reusable RealityKit effect: a sphere whose surface can be
//  disturbed at a point, sending a ring-shaped ripple traveling across the
//  surface and fading out — like a drop of water settling on the surface of
//  a sphere rather than a flat pond. Intended as a stand-in for a proper
//  glass/water look until a real Reality Composer Pro shader graph material
//  is authored; the ripple simulation itself is plain math and works
//  regardless of the material applied on top.

import RealityKit
import simd
import UIKit

/// A single disturbance on a `WaterSphereMesh`'s surface, expanding outward
/// from `originDirection` (a unit vector in the sphere's local space) as a
/// traveling ring wave that fades over time.
struct WaterRipple {
    let originDirection: SIMD3<Float>
    let startTime: Float
}

/// Builds and regenerates a displaced UV-sphere `MeshResource` to visualize
/// one or more active `WaterRipple`s. Callers own the ripple list and drive
/// regeneration once per frame only while ripples are active; once every
/// ripple has aged past `rippleLifetime`, the mesh has already settled back
/// to its resting (flat) shape and no further regeneration is needed until a
/// new ripple starts.
struct WaterSphereMesh {
    let radius: Float
    let latSegments: Int
    let longSegments: Int

    /// How far outward (in meters) a ripple's crest pushes the surface.
    var amplitude: Float = 0.006
    /// Angular speed (radians/second) the ripple's wavefront travels across
    /// the sphere's surface.
    var waveSpeed: Float = 3.4
    /// Angular width (radians) of the traveling ring; smaller reads as a
    /// sharper pulse, larger as a broader swell.
    var ringWidth: Float = 0.5
    /// Exponential decay time constant (seconds) for a ripple's amplitude.
    var decayTau: Float = 0.55
    /// Ripples older than this are effectively invisible and safe to drop.
    var rippleLifetime: Float = 2.2

    init(radius: Float, latSegments: Int = 22, longSegments: Int = 30) {
        self.radius = radius
        self.latSegments = latSegments
        self.longSegments = longSegments
    }

    /// Generates the sphere's mesh with each vertex displaced along its own
    /// outward direction by the sum of all active ripples' contributions at
    /// `elapsedTime`. Passing an empty `ripples` array yields a plain sphere.
    func generate(ripples: [WaterRipple], elapsedTime: Float) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity((latSegments + 1) * longSegments)

        for latIndex in 0...latSegments {
            let theta = Float(latIndex) / Float(latSegments) * Float.pi
            let y = cos(theta)
            let ringRadius = sin(theta)

            for lonIndex in 0..<longSegments {
                let phi = Float(lonIndex) / Float(longSegments) * 2 * Float.pi
                let direction = SIMD3<Float>(ringRadius * cos(phi), y, ringRadius * sin(phi))
                let displacement = surfaceDisplacement(at: direction, ripples: ripples, elapsedTime: elapsedTime)
                positions.append(direction * (radius + displacement))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(latSegments * longSegments * 6)

        func vertexIndex(_ lat: Int, _ lon: Int) -> UInt32 {
            UInt32(lat * longSegments + (lon % longSegments))
        }

        for latIndex in 0..<latSegments {
            for lonIndex in 0..<longSegments {
                let a = vertexIndex(latIndex, lonIndex)
                let b = vertexIndex(latIndex, lonIndex + 1)
                let c = vertexIndex(latIndex + 1, lonIndex + 1)
                let d = vertexIndex(latIndex + 1, lonIndex)
                // Degenerate at the exact poles (all vertices in that row
                // coincide), which just produces a few harmless zero-area
                // triangles rather than requiring special-cased fans.
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        var descriptor = MeshDescriptor(name: "WaterSphere")
        descriptor.positions = .init(positions)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    private func surfaceDisplacement(at direction: SIMD3<Float>, ripples: [WaterRipple], elapsedTime: Float) -> Float {
        var total: Float = 0
        for ripple in ripples {
            let age = elapsedTime - ripple.startTime
            guard age >= 0, age <= rippleLifetime else { continue }

            let angularDistance = acos(simd_clamp(simd_dot(direction, ripple.originDirection), -1, 1))
            let waveFront = waveSpeed * age
            let diff = angularDistance - waveFront
            let ring = exp(-(diff * diff) / (2 * ringWidth * ringWidth))
            let fade = exp(-age / decayTau)
            total += amplitude * ring * fade
        }
        return total
    }
}

/// Shared "water" look for `WaterSphereMesh` instances: high clearcoat and
/// low roughness so the surface reads as wet/reflective, with enough
/// transparency to hint at depth. Plain `PhysicallyBasedMaterial` rather than
/// a shader graph, so it works without a Reality Composer Pro asset.
enum WaterSphereMaterial {
    static func make(tint: UIColor = UIColor(red: 0.05, green: 0.55, blue: 0.68, alpha: 1.0)) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: tint)
        material.roughness = 0.04
        material.metallic = 0.0
        material.clearcoat = 1.0
        material.clearcoatRoughness = 0.02
        material.emissiveColor = .init(color: tint)
        material.emissiveIntensity = 0.12
        material.blending = .transparent(opacity: .init(floatLiteral: 0.68))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }
}
