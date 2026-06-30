//
//  ModelTests.swift
//  UmbraTests
//
//  SwiftData model behavior: the settings singleton, the manual-location-default
//  detection that drives the "set your location" nudge, and cascade delete of a
//  project's blockers.
//

import XCTest
import SwiftData
import simd
@testable import Umbra

@MainActor
final class ModelTests: XCTestCase {

    /// Returns a container (NOT just its context) so the caller keeps it alive
    /// for the duration of the test — a context whose container has deallocated
    /// crashes on use.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ARProject.self, PlacedBlocker.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testAppSettingsSingletonReused() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let a = AppSettings.current(in: ctx)
        a.shadowOpacity = 0.42
        let b = AppSettings.current(in: ctx)
        XCTAssertEqual(b.shadowOpacity, 0.42, accuracy: 1e-9)
        let all = try ctx.fetch(FetchDescriptor<AppSettings>())
        XCTAssertEqual(all.count, 1)
    }

    func testManualLocationDefaultDetection() {
        let s = AppSettings()
        XCTAssertTrue(s.isManualLocationDefault)
        s.manualLatitude = 51.5074
        s.manualLongitude = -0.1278
        XCTAssertFalse(s.isManualLocationDefault)
    }

    func testCascadeDeleteRemovesBlockers() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let project = ARProject(name: "P", latitude: 0, longitude: 0)
        ctx.insert(project)
        let b = PlacedBlocker(kind: .box, position: .zero, size: SIMD3<Double>(1, 1, 1), project: project)
        project.blockers = [b]
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PlacedBlocker>()).count, 1)
        ctx.delete(project)
        try ctx.save()
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<PlacedBlocker>()).isEmpty)
    }

    func testBlockerKindRoundTripsThroughRawValue() {
        for kind in BlockerKind.allCases {
            let b = PlacedBlocker(kind: kind, position: .zero, size: kind.defaultSize)
            XCTAssertEqual(b.kind, kind)
            XCTAssertEqual(b.descriptor.kind, kind)
        }
    }
}
