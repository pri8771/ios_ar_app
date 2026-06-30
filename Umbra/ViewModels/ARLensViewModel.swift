//
//  ARLensViewModel.swift
//  Umbra
//
//  Drives the AR lens screen: holds the working project state, computes the
//  sun position and shadow polygons, and feeds both the real AR renderer and
//  the simulator mock. Views stay thin; this is where the logic lives.
//

import Foundation
import SwiftUI
import SwiftData
import simd

@MainActor
final class ARLensViewModel: ObservableObject {

    // MARK: Dependencies
    private let sunService = SunPositionService()
    private let shadowService = ShadowGeometryService()
    private let solarDayService = SolarDayService()

    // MARK: Working state
    /// Blockers currently in the scene, keyed by stable id.
    @Published private(set) var blockers: [UUID: BlockerDescriptor] = [:]
    /// The instant being previewed.
    @Published var previewDate: Date
    /// Selected kind to place on next tap.
    @Published var selectedKind: BlockerKind = .pole
    /// The y height of the ground plane (relative to scene origin anchor).
    @Published var planeHeight: Double = 0
    /// Latest computed sun position.
    @Published private(set) var sunPosition: SolarPosition = SolarPosition(azimuth: 0, elevation: 0, elevationUnrefracted: 0)
    /// Computed shadow polygons keyed by blocker id.
    @Published private(set) var shadows: [UUID: ShadowPolygon] = [:]
    /// Solar day summary for the current date/location.
    @Published private(set) var solarDay: SolarDay?
    /// Sampled sun path for visualization.
    @Published private(set) var sunPath: [SunPathSample] = []
    /// Currently selected blocker for editing/removal.
    @Published var selectedBlockerID: UUID?

    // MARK: Location context
    private(set) var latitude: Double
    private(set) var longitude: Double
    private(set) var timeZone: TimeZone

    init(
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current,
        previewDate: Date = .now
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.previewDate = previewDate
        recompute()
    }

    // MARK: - Location updates

    func updateLocation(latitude: Double, longitude: Double, timeZone: TimeZone) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        recompute()
    }

    // MARK: - Blocker management

    /// Adds a blocker of the currently selected kind at a ground position
    /// (relative to the scene origin anchor).
    @discardableResult
    func addBlocker(at groundPosition: SIMD3<Double>) -> UUID {
        let id = UUID()
        let kind = selectedKind
        var pos = groundPosition
        pos.y = planeHeight
        let desc = BlockerDescriptor(
            basePosition: pos,
            size: kind.defaultSize,
            yawRadians: 0,
            kind: kind)
        blockers[id] = desc
        selectedBlockerID = id
        recomputeShadows()
        return id
    }

    func removeBlocker(_ id: UUID) {
        blockers.removeValue(forKey: id)
        shadows.removeValue(forKey: id)
        if selectedBlockerID == id { selectedBlockerID = nil }
    }

    func removeAll() {
        blockers.removeAll()
        shadows.removeAll()
        selectedBlockerID = nil
    }

    func rotateSelected(by radians: Double) {
        guard let id = selectedBlockerID, var d = blockers[id] else { return }
        d.yawRadians += radians
        blockers[id] = d
        recomputeShadows()
    }

    func setHeightForSelected(_ height: Double) {
        guard let id = selectedBlockerID, var d = blockers[id] else { return }
        d.size.y = max(0.1, height)
        blockers[id] = d
        recomputeShadows()
    }

    /// Loads blockers from persisted project data.
    func load(blockers placed: [PlacedBlocker], planeHeight: Double) {
        self.planeHeight = planeHeight
        var map: [UUID: BlockerDescriptor] = [:]
        for b in placed {
            map[b.id] = b.descriptor
        }
        blockers = map
        recomputeShadows()
    }

    // MARK: - Time

    func setPreviewDate(_ date: Date) {
        previewDate = date
        recompute()
    }

    /// Sets the time-of-day (hours, fractional) keeping the current calendar day.
    func setTimeOfDay(hours: Double) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: previewDate)
        previewDate = startOfDay.addingTimeInterval(hours * 3600.0)
        recompute()
    }

    /// Hours-of-day (0..<24) of the current preview date in the project tz.
    var previewHours: Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: previewDate)
        return previewDate.timeIntervalSince(startOfDay) / 3600.0
    }

    // MARK: - Recompute

    func recompute() {
        sunPosition = sunService.position(date: previewDate, latitude: latitude, longitude: longitude)
        solarDay = solarDayService.solarDay(
            for: previewDate, latitude: latitude, longitude: longitude, timeZone: timeZone)
        sunPath = solarDayService.sunPath(
            for: previewDate, latitude: latitude, longitude: longitude, timeZone: timeZone, stepMinutes: 15)
        recomputeShadows()
    }

    private func recomputeShadows() {
        var result: [UUID: ShadowPolygon] = [:]
        for (id, desc) in blockers {
            result[id] = shadowService.shadow(
                for: desc,
                sunAzimuth: sunPosition.azimuth,
                sunElevation: sunPosition.elevation)
        }
        shadows = result
    }

    // MARK: - Persistence bridge

    /// Writes the current working state into a SwiftData project.
    func persist(into project: ARProject, context: ModelContext) {
        project.previewDate = previewDate
        project.planeHeight = planeHeight
        project.latitude = latitude
        project.longitude = longitude
        project.timeZoneIdentifier = timeZone.identifier
        project.updatedAt = .now

        // Replace blockers.
        for existing in project.blockers {
            context.delete(existing)
        }
        project.blockers = blockers.map { (id, d) in
            PlacedBlocker(
                id: id,
                kind: d.kind,
                position: d.basePosition,
                size: d.size,
                yaw: d.yawRadians,
                project: project)
        }
        try? context.save()
    }

    // MARK: - Derived UI helpers

    var sunStatusText: String {
        if let day = solarDay, day.isPolarNight {
            return "Polar night — sun stays below the horizon."
        }
        if sunPosition.elevation <= 0 {
            return "Sun is below the horizon — no cast shadow at this time."
        }
        return String(format: "Sun: %.0f° elevation, %.0f° azimuth",
                      sunPosition.elevation, sunPosition.azimuth)
    }

    /// Height (meters) of the currently selected blocker, if any.
    var selectedHeight: Double? {
        guard let id = selectedBlockerID else { return nil }
        return blockers[id]?.size.y
    }

    // MARK: - Export stamp strings

    /// Preview date + time formatted in the plan's time zone.
    var previewDateTimeString: String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f.string(from: previewDate)
    }

    /// Self-contained "lat, lon" label (no online place-name lookup).
    var locationCoordString: String {
        String(format: "%.3f, %.3f", latitude, longitude)
    }

    /// Compact sun-geometry summary for the export footer.
    var sunSummaryString: String {
        if let day = solarDay, day.isPolarNight { return "Polar night" }
        if sunPosition.elevation <= 0 { return "Sun below horizon" }
        return String(format: "Sun %.0f° up · %.0f° az",
                      sunPosition.elevation, sunPosition.azimuth)
    }
}
