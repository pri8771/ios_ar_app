//
//  ShadowMeshFactory.swift
//  Umbra
//
//  Converts a 2D ground-plane shadow polygon into a flat RealityKit mesh lying
//  in the y = 0 plane (the caller positions the entity at the plane height).
//
//  Compiled only where RealityKit is available (device builds).
//

import Foundation

#if canImport(RealityKit) && !targetEnvironment(simulator)
import RealityKit
import simd

enum ShadowMeshFactory {

    /// Builds a triangulated mesh from a convex shadow polygon using a simple
    /// fan triangulation (valid because the polygon is convex). Vertices are
    /// placed in the XZ plane at y = 0.
    static func mesh(for polygon: ShadowPolygon) -> MeshResource? {
        let verts = polygon.vertices
        guard verts.count >= 3 else { return nil }

        var positions: [SIMD3<Float>] = verts.map {
            SIMD3<Float>(Float($0.x), 0, Float($0.z))
        }
        var indices: [UInt32] = []
        for i in 1..<(verts.count - 1) {
            indices.append(0)
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
        }

        // Upward normals so the unlit shadow renders consistently.
        let normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 1, 0), count: positions.count)

        var descriptor = MeshDescriptor(name: "shadow")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)

        positions.removeAll(keepingCapacity: false)
        return try? MeshResource.generate(from: [descriptor])
    }
}
#endif
