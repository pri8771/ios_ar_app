//
//  ARLensViewModelTests.swift
//  UmbraTests
//
//  Exercises the lens view model's working state: placement, selection,
//  rotation, height editing, time scrubbing, loading from persisted blockers,
//  and a SwiftData persist → reload round-trip.
//

import XCTest
import SwiftData
import simd
@testable import Umbra

@MainActor
final class ARLensViewModelTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    private func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
    }

    /// 40°N, lon 0, summer-solstice noon (sun well above the horizon).
    private func makeVM() -> ARLensViewModel {
        ARLensViewModel(latitude: 40, longitude: 0, timeZone: utc, previewDate: utcDate(2024, 6, 21, 12))
    }

    func testInitComputesSunDayAndPath() {
        let vm = makeVM()
        XCTAssertGreaterThan(vm.sunPosition.elevation, 0)
        XCTAssertNotNil(vm.solarDay)
        XCTAssertFalse(vm.sunPath.isEmpty)
    }

    func testAddBlockerSelectsAndCastsShadow() {
        let vm = makeVM()
        let id = vm.addBlocker(at: SIMD3<Double>(0, 0, 0))
        XCTAssertEqual(vm.selectedBlockerID, id)
        XCTAssertEqual(vm.blockers.count, 1)
        XCTAssertNotNil(vm.shadows[id])
        XCTAssertFalse(vm.shadows[id]!.isEmpty)  // midday sun is up
    }

    func testSelectedKindDrivesPlacement() {
        let vm = makeVM()
        vm.selectedKind = .wall
        let id = vm.addBlocker(at: .zero)
        XCTAssertEqual(vm.blockers[id]?.kind, .wall)
        XCTAssertEqual(vm.blockers[id]?.size, BlockerKind.wall.defaultSize)
    }

    func testPlacementSeatsOnPlaneHeight() {
        let vm = makeVM()
        vm.planeHeight = 0.75
        let id = vm.addBlocker(at: SIMD3<Double>(1, 999, 2))  // y should be overridden
        XCTAssertEqual(vm.blockers[id]!.basePosition.y, 0.75, accuracy: 1e-9)
    }

    func testRemoveBlockerClearsShadowAndSelection() {
        let vm = makeVM()
        let id = vm.addBlocker(at: .zero)
        vm.removeBlocker(id)
        XCTAssertTrue(vm.blockers.isEmpty)
        XCTAssertNil(vm.shadows[id])
        XCTAssertNil(vm.selectedBlockerID)
    }

    func testRemoveAll() {
        let vm = makeVM()
        _ = vm.addBlocker(at: .zero)
        _ = vm.addBlocker(at: SIMD3<Double>(1, 0, 1))
        vm.removeAll()
        XCTAssertTrue(vm.blockers.isEmpty)
        XCTAssertTrue(vm.shadows.isEmpty)
        XCTAssertNil(vm.selectedBlockerID)
    }

    func testSetHeightClampsAndUpdatesShadow() {
        let vm = makeVM()
        let id = vm.addBlocker(at: .zero)
        vm.setHeightForSelected(3.0)
        XCTAssertEqual(vm.blockers[id]!.size.y, 3.0, accuracy: 1e-9)
        XCTAssertEqual(vm.selectedHeight!, 3.0, accuracy: 1e-9)
        // Negative/zero heights clamp to a small positive minimum.
        vm.setHeightForSelected(-5)
        XCTAssertEqual(vm.blockers[id]!.size.y, 0.1, accuracy: 1e-9)
    }

    func testRotateSelectedChangesYaw() {
        let vm = makeVM()
        let id = vm.addBlocker(at: .zero)
        let before = vm.blockers[id]!.yawRadians
        vm.rotateSelected(by: .pi / 4)
        XCTAssertEqual(vm.blockers[id]!.yawRadians, before + .pi / 4, accuracy: 1e-9)
    }

    func testSetTimeOfDayUpdatesPreviewHours() {
        let vm = makeVM()
        vm.setTimeOfDay(hours: 6)
        XCTAssertEqual(vm.previewHours, 6, accuracy: 1e-6)
    }

    func testNightProducesNoShadow() {
        let vm = makeVM()
        let id = vm.addBlocker(at: .zero)
        vm.setTimeOfDay(hours: 0)  // local midnight: sun below horizon
        XCTAssertLessThanOrEqual(vm.sunPosition.elevation, 0)
        XCTAssertTrue(vm.shadows[id]?.isEmpty ?? true)
    }

    func testLoadFromPlacedBlockers() {
        let vm = makeVM()
        let pb = PlacedBlocker(kind: .pole, position: SIMD3<Double>(1, 0.5, 2),
                               size: SIMD3<Double>(0.1, 2, 0.1), yaw: 0.3)
        vm.load(blockers: [pb], planeHeight: 0.5)
        XCTAssertEqual(vm.planeHeight, 0.5, accuracy: 1e-9)
        XCTAssertEqual(vm.blockers.count, 1)
        XCTAssertEqual(vm.blockers[pb.id]?.kind, .pole)
    }

    func testExportStringsAreSensible() {
        let vm = makeVM()
        XCTAssertTrue(vm.locationCoordString.contains(","))
        XCTAssertTrue(vm.sunSummaryString.lowercased().contains("sun"))
        XCTAssertFalse(vm.previewDateTimeString.isEmpty)
    }

    func testPersistRoundTrip() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ARProject.self, PlacedBlocker.self, AppSettings.self, configurations: config)
        let ctx = container.mainContext

        let project = ARProject(name: "Test", latitude: 40, longitude: 0,
                                timeZoneIdentifier: "UTC", previewDate: utcDate(2024, 6, 21, 12))
        ctx.insert(project)

        let vm = makeVM()
        vm.selectedKind = .box
        _ = vm.addBlocker(at: SIMD3<Double>(1, 0, 1))
        vm.selectedKind = .tree
        _ = vm.addBlocker(at: SIMD3<Double>(-2, 0, 0))
        vm.persist(into: project, context: ctx)

        XCTAssertEqual(project.blockers.count, 2)

        // Reload into a fresh view model and confirm the layout reproduces.
        let vm2 = ARLensViewModel(latitude: 40, longitude: 0, timeZone: utc,
                                  previewDate: project.previewDate)
        vm2.load(blockers: project.blockers, planeHeight: project.planeHeight)
        XCTAssertEqual(vm2.blockers.count, 2)
        XCTAssertEqual(Set(vm2.blockers.values.map(\.kind)), Set([.box, .tree]))
    }
}
