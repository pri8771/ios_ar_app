//
//  Geometry.swift
//  Shadow Lens
//
//  Small, dependency-free computational geometry helpers used by the shadow
//  projection math. Kept pure so they are trivially unit-testable.
//

import Foundation
import simd

/// A 2D point on the ground plane (x = east, z = south in world space).
struct Point2D: Equatable, Hashable {
    var x: Double
    var z: Double

    init(_ x: Double, _ z: Double) {
        self.x = x
        self.z = z
    }
}

enum Geometry {

    /// Computes the convex hull of a set of 2D points using Andrew's monotone
    /// chain algorithm. Returns the hull vertices in counter-clockwise order.
    /// Degenerate inputs (0, 1, 2 unique points) are returned as-is.
    static func convexHull(_ points: [Point2D]) -> [Point2D] {
        // De-duplicate and sort lexicographically by (x, z).
        let unique = Array(Set(points)).sorted {
            $0.x != $1.x ? $0.x < $1.x : $0.z < $1.z
        }
        guard unique.count >= 3 else { return unique }

        func cross(_ o: Point2D, _ a: Point2D, _ b: Point2D) -> Double {
            (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
        }

        var lower: [Point2D] = []
        for p in unique {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [Point2D] = []
        for p in unique.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    /// Computes the area of a simple polygon via the shoelace formula. Always
    /// returns a non-negative value.
    static func polygonArea(_ points: [Point2D]) -> Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for i in 0..<points.count {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            sum += (a.x * b.z - b.x * a.z)
        }
        return abs(sum) / 2.0
    }

    /// Projects a 3D point onto a horizontal plane (constant y = `planeY`)
    /// along light direction `light` (the direction light travels, pointing
    /// generally downward). Returns nil when the light is parallel to the plane
    /// or points away from it (sun at/below horizon relative to the point).
    static func projectToGround(
        point: SIMD3<Double>,
        light: SIMD3<Double>,
        planeY: Double
    ) -> Point2D? {
        // Solve point.y + t * light.y == planeY for t > 0.
        guard abs(light.y) > 1e-9 else { return nil }
        let t = (planeY - point.y) / light.y
        guard t > 0 else { return nil }
        let ground = point + light * t
        return Point2D(ground.x, ground.z)
    }
}
