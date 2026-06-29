//
//  ShadowGeometryServiceTests.swift
//  UmbraTests
//
//  Validates ground projection, convex hull, and the end-to-end shadow polygon
//  computation for known sun geometries.
//

import XCTest
import simd
@testable import Umbra

final class ShadowGeometryServiceTests: XCTestCase {

    private let service = ShadowGeometryService()

    private func box(at center: SIMD3<Double> = .zero,
                     size: SIMD3<Double>,
                     yaw: Double = 0,
                     kind: BlockerKind = .box) -> BlockerDescriptor {
        BlockerDescriptor(basePosition: center, size: size, yawRadians: yaw, kind: kind)
    }

    // MARK: Projection primitive

    func testProjectStraightDown() {
        // Light pointing straight down projects a point to directly below it.
        let p = SIMD3<Double>(2, 3, -1)
        let ground = Geometry.projectToGround(point: p, light: SIMD3<Double>(0, -1, 0), planeY: 0)
        XCTAssertNotNil(ground)
        XCTAssertEqual(ground!.x, 2, accuracy: 1e-9)
        XCTAssertEqual(ground!.z, -1, accuracy: 1e-9)
    }

    func testProjectAt45Degrees() {
        // Light traveling down-and-north at 45deg: a point at height h lands h
        // meters north (−z).
        let h = 4.0
        let light = simd_normalize(SIMD3<Double>(0, -1, -1))
        let ground = Geometry.projectToGround(point: SIMD3<Double>(0, h, 0), light: light, planeY: 0)
        XCTAssertNotNil(ground)
        XCTAssertEqual(ground!.x, 0, accuracy: 1e-9)
        XCTAssertEqual(ground!.z, -h, accuracy: 1e-9)
    }

    func testProjectParallelToPlaneReturnsNil() {
        let ground = Geometry.projectToGround(
            point: SIMD3<Double>(0, 2, 0), light: SIMD3<Double>(1, 0, 0), planeY: 0)
        XCTAssertNil(ground)
    }

    func testProjectUpwardLightReturnsNil() {
        // Light going up never reaches a plane below the point.
        let ground = Geometry.projectToGround(
            point: SIMD3<Double>(0, 2, 0), light: SIMD3<Double>(0, 1, 0), planeY: 0)
        XCTAssertNil(ground)
    }

    // MARK: Shadow polygon

    func testNoShadowWhenSunBelowHorizon() {
        let poly = service.shadow(for: box(size: SIMD3(1, 2, 1)),
                                  sunAzimuth: 90, sunElevation: -5)
        XCTAssertTrue(poly.isEmpty)
        XCTAssertEqual(poly.area, 0, accuracy: 1e-9)
    }

    func testOverheadSunCastsFootprintOnly() {
        // Sun straight up: the shadow equals the object's footprint.
        let size = SIMD3<Double>(0.5, 1.0, 0.5)
        let poly = service.shadow(for: box(size: size), sunAzimuth: 0, sunElevation: 90)
        XCTAssertFalse(poly.isEmpty)
        // Footprint area is 0.5 * 0.5 = 0.25 m^2.
        XCTAssertEqual(poly.area, 0.25, accuracy: 0.02)
        // All vertices remain within the footprint half-extents.
        for v in poly.vertices {
            XCTAssertLessThanOrEqual(abs(v.x), 0.26)
            XCTAssertLessThanOrEqual(abs(v.z), 0.26)
        }
    }

    func testLowSunInSouthCastsShadowNorth() {
        // Sun in the south (az 180) at 45deg elevation: a 2.5 m pole casts its
        // shadow to the north (−z), roughly its own height long.
        let pole = box(size: SIMD3(0.08, 2.5, 0.08), kind: .pole)
        let poly = service.shadow(for: pole, sunAzimuth: 180, sunElevation: 45)
        XCTAssertFalse(poly.isEmpty)

        let minZ = poly.vertices.map(\.z).min()!
        let maxX = poly.vertices.map { abs($0.x) }.max()!
        // Shadow tip is ~2.5 m north of the base (tan 45 = 1).
        XCTAssertEqual(minZ, -2.5, accuracy: 0.1)
        // Negligible east-west spread for a thin pole.
        XCTAssertLessThan(maxX, 0.2)
        // The shadow lies on the north side (all z <= small positive).
        XCTAssertLessThan(poly.vertices.map(\.z).max()!, 0.1)
    }

    func testLowerSunCastsLongerShadow() {
        let pole = box(size: SIMD3(0.1, 2.0, 0.1), kind: .pole)
        let high = service.shadow(for: pole, sunAzimuth: 180, sunElevation: 60)
        let low = service.shadow(for: pole, sunAzimuth: 180, sunElevation: 20)
        let highLen = abs(high.vertices.map(\.z).min()!)
        let lowLen = abs(low.vertices.map(\.z).min()!)
        XCTAssertGreaterThan(lowLen, highLen)
    }

    func testShadowDirectionFollowsAzimuth() {
        // Sun in the east (az 90) casts the shadow to the west (−x).
        let pole = box(size: SIMD3(0.1, 2.0, 0.1), kind: .pole)
        let poly = service.shadow(for: pole, sunAzimuth: 90, sunElevation: 30)
        let minX = poly.vertices.map(\.x).min()!
        XCTAssertLessThan(minX, -1.0)  // extends west
    }

    func testConvenienceOverloadComputesSun() {
        // The date-based overload should produce a non-empty shadow at midday.
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        let noon = c.date(from: DateComponents(year: 2024, month: 6, day: 21, hour: 12))!
        let poly = service.shadow(for: box(size: SIMD3(1, 2, 1)),
                                  date: noon, latitude: 40, longitude: 0)
        XCTAssertFalse(poly.isEmpty)
    }

    // MARK: Convex hull & area

    func testConvexHullOfSquare() {
        let pts = [Point2D(0, 0), Point2D(1, 0), Point2D(1, 1), Point2D(0, 1),
                   Point2D(0.5, 0.5)] // interior point should be discarded
        let hull = Geometry.convexHull(pts)
        XCTAssertEqual(hull.count, 4)
        XCTAssertEqual(Geometry.polygonArea(hull), 1.0, accuracy: 1e-9)
    }

    func testConvexHullCollinearAndDuplicates() {
        let pts = [Point2D(0, 0), Point2D(1, 0), Point2D(2, 0), Point2D(2, 0),
                   Point2D(2, 2), Point2D(0, 2)]
        let hull = Geometry.convexHull(pts)
        // Collinear midpoint (1,0) should not be a hull vertex.
        XCTAssertFalse(hull.contains(Point2D(1, 0)))
        XCTAssertEqual(Geometry.polygonArea(hull), 4.0, accuracy: 1e-9)
    }

    func testPolygonAreaDegenerate() {
        XCTAssertEqual(Geometry.polygonArea([Point2D(0, 0), Point2D(1, 1)]), 0)
        XCTAssertEqual(Geometry.polygonArea([]), 0)
    }

    func testConvexHullTriangleArea() {
        let hull = Geometry.convexHull([Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)])
        XCTAssertEqual(Geometry.polygonArea(hull), 6.0, accuracy: 1e-9)
    }

    // MARK: Bounding box corners

    func testBoundingBoxCornerCount() {
        let corners = service.boundingBoxCorners(for: box(size: SIMD3(1, 2, 1)))
        XCTAssertEqual(corners.count, 8)
        let tops = corners.filter { abs($0.y - 2.0) < 1e-6 }
        let bases = corners.filter { abs($0.y) < 1e-6 }
        XCTAssertEqual(tops.count, 4)
        XCTAssertEqual(bases.count, 4)
    }
}
