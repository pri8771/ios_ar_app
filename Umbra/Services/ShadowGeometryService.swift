//
//  ShadowGeometryService.swift
//  Umbra
//
//  Projects user-placed proxy "blocker" objects onto a horizontal AR plane to
//  produce an approximate shadow polygon, then turns that polygon into a
//  RealityKit mesh for rendering.
//
//  IMPORTANT product truth: Umbra does NOT reconstruct real-world
//  geometry. It projects physically plausible shadows from simple proxy shapes
//  and clearly labels the result as approximate.
//

import Foundation
import simd

/// The kinds of proxy blockers a user can place. Each maps to a simple
/// axis-aligned box footprint described by width/depth/height in meters.
enum BlockerKind: String, CaseIterable, Codable, Identifiable {
    case pole
    case box
    case wall
    case person
    case tree

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pole: return "Pole"
        case .box: return "Box"
        case .wall: return "Wall"
        case .person: return "Person"
        case .tree: return "Tree"
        }
    }

    var systemImage: String {
        switch self {
        case .pole: return "lineweight"
        case .box: return "cube"
        case .wall: return "rectangle.portrait"
        case .person: return "figure.stand"
        case .tree: return "tree"
        }
    }

    /// Default size in meters: (width along x, height along y, depth along z).
    var defaultSize: SIMD3<Double> {
        switch self {
        case .pole: return SIMD3(0.08, 2.5, 0.08)
        case .box: return SIMD3(0.5, 0.5, 0.5)
        case .wall: return SIMD3(2.0, 1.8, 0.15)
        case .person: return SIMD3(0.45, 1.75, 0.30)
        case .tree: return SIMD3(1.6, 3.0, 1.6)
        }
    }
}

/// A description of a blocker positioned in the AR scene (relative to the scene
/// origin anchor), independent of RealityKit so the math is testable.
struct BlockerDescriptor: Equatable {
    /// Center of the footprint on the ground plane (x, planeY, z), in meters.
    var basePosition: SIMD3<Double>
    /// Size in meters (width x, height y, depth z).
    var size: SIMD3<Double>
    /// Rotation about the vertical (y) axis in radians.
    var yawRadians: Double
    /// The kind of object (used to pick a silhouette model).
    var kind: BlockerKind
}

/// Result of a shadow computation.
struct ShadowPolygon: Equatable {
    /// Ground-plane vertices of the shadow, in CCW order. Empty when the sun is
    /// at/below the horizon (no cast shadow).
    let vertices: [Point2D]
    /// The y height of the ground plane the shadow lies on.
    let planeY: Double
    /// Approximate area of the shadow in square meters.
    var area: Double { Geometry.polygonArea(vertices) }
    /// True when there is no shadow to draw.
    var isEmpty: Bool { vertices.count < 3 }
}

struct ShadowGeometryService {

    private let sun = SunPositionService()

    // MARK: - Shadow polygon

    /// Computes the approximate shadow polygon cast by a blocker for a given
    /// sun position.
    /// - Parameters:
    ///   - blocker: The blocker descriptor (position/size/yaw on the plane).
    ///   - sunAzimuth: Azimuth degrees clockwise from north.
    ///   - sunElevation: Elevation degrees above horizon (refracted).
    /// - Returns: A `ShadowPolygon`. Empty when the sun is below the horizon.
    func shadow(
        for blocker: BlockerDescriptor,
        sunAzimuth: Double,
        sunElevation: Double
    ) -> ShadowPolygon {
        let planeY = blocker.basePosition.y
        guard sunElevation > 0 else {
            return ShadowPolygon(vertices: [], planeY: planeY)
        }

        let toSun = SunMath.worldDirection(azimuthDegrees: sunAzimuth, elevationDegrees: sunElevation)
        let light = -toSun // direction the light travels (downward)

        // Build the 8 corners of the blocker's bounding box in world space.
        let corners = boundingBoxCorners(for: blocker)

        var groundPoints: [Point2D] = []
        // Always include the base footprint corners so the hull encloses the
        // object's own footprint even with a very high sun.
        for c in corners where abs(c.y - planeY) < 1e-6 {
            groundPoints.append(Point2D(c.x, c.z))
        }
        // Project every corner (top corners produce the cast extent).
        for c in corners {
            if let g = Geometry.projectToGround(point: c, light: light, planeY: planeY) {
                groundPoints.append(g)
            }
        }

        let hull = Geometry.convexHull(groundPoints)
        return ShadowPolygon(vertices: hull, planeY: planeY)
    }

    /// Convenience overload that computes the sun position internally.
    func shadow(
        for blocker: BlockerDescriptor,
        date: Date,
        latitude: Double,
        longitude: Double
    ) -> ShadowPolygon {
        let p = sun.position(date: date, latitude: latitude, longitude: longitude)
        return shadow(for: blocker, sunAzimuth: p.azimuth, sunElevation: p.elevation)
    }

    // MARK: - Bounding box corners

    /// Returns the 8 corners of the blocker bounding box in world space,
    /// honoring yaw about the vertical axis. The footprint is centered on
    /// `basePosition` and the box rises by `size.y` above the plane.
    func boundingBoxCorners(for blocker: BlockerDescriptor) -> [SIMD3<Double>] {
        let hw = blocker.size.x / 2.0
        let hd = blocker.size.z / 2.0
        let h = blocker.size.y
        let planeY = blocker.basePosition.y

        let local: [SIMD2<Double>] = [
            SIMD2(-hw, -hd), SIMD2(hw, -hd), SIMD2(hw, hd), SIMD2(-hw, hd)
        ]
        let cosY = cos(blocker.yawRadians)
        let sinY = sin(blocker.yawRadians)

        var corners: [SIMD3<Double>] = []
        for p in local {
            let rx = p.x * cosY - p.y * sinY
            let rz = p.x * sinY + p.y * cosY
            let baseX = blocker.basePosition.x + rx
            let baseZ = blocker.basePosition.z + rz
            corners.append(SIMD3(baseX, planeY, baseZ))      // base corner
            corners.append(SIMD3(baseX, planeY + h, baseZ))  // top corner
        }
        return corners
    }
}
