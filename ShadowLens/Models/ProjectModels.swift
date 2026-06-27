//
//  ProjectModels.swift
//  Shadow Lens
//
//  SwiftData models. ALL persistence is local to the device; there is no cloud
//  sync, no account, and no network access anywhere in this app.
//

import Foundation
import SwiftData

/// A saved planning project: a location, a chosen instant, and a set of
/// placed proxy blockers relative to the scene origin anchor.
@Model
final class ARProject {
    /// Stable identifier.
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    /// Captured geographic location used for the solar math.
    var latitude: Double
    var longitude: Double
    /// Identifier of the timezone used when this project was created, so the
    /// time scrubber reproduces the same local times on reopening.
    var timeZoneIdentifier: String

    /// The instant currently being previewed (date + time of day).
    var previewDate: Date

    /// The y height (in meters) of the detected ground plane relative to the
    /// scene origin anchor, so blockers re-seat correctly on reopen.
    var planeHeight: Double

    /// Optional thumbnail (PNG data) captured on export/save. Stored on device.
    @Attribute(.externalStorage) var thumbnailData: Data?

    /// Placed blockers. Cascade delete so removing a project removes its parts.
    @Relationship(deleteRule: .cascade, inverse: \PlacedBlocker.project)
    var blockers: [PlacedBlocker]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        latitude: Double,
        longitude: Double,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        previewDate: Date = .now,
        planeHeight: Double = 0,
        thumbnailData: Data? = nil,
        blockers: [PlacedBlocker] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.previewDate = previewDate
        self.planeHeight = planeHeight
        self.thumbnailData = thumbnailData
        self.blockers = blockers
    }

    var resolvedTimeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}

/// A single placed proxy blocker. Positions are stored relative to the scene
/// origin anchor so a project can be reopened and the layout reproduced.
@Model
final class PlacedBlocker {
    @Attribute(.unique) var id: UUID
    /// Raw value of `BlockerKind`.
    var kindRaw: String

    // Position relative to scene origin anchor, in meters.
    var positionX: Double
    var positionY: Double
    var positionZ: Double

    // Size in meters.
    var sizeX: Double
    var sizeY: Double
    var sizeZ: Double

    /// Yaw about the vertical axis, in radians.
    var yaw: Double

    var project: ARProject?

    init(
        id: UUID = UUID(),
        kind: BlockerKind,
        position: SIMD3<Double>,
        size: SIMD3<Double>,
        yaw: Double = 0,
        project: ARProject? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.positionX = position.x
        self.positionY = position.y
        self.positionZ = position.z
        self.sizeX = size.x
        self.sizeY = size.y
        self.sizeZ = size.z
        self.yaw = yaw
        self.project = project
    }

    var kind: BlockerKind {
        get { BlockerKind(rawValue: kindRaw) ?? .box }
        set { kindRaw = newValue.rawValue }
    }

    var position: SIMD3<Double> {
        get { SIMD3(positionX, positionY, positionZ) }
        set { positionX = newValue.x; positionY = newValue.y; positionZ = newValue.z }
    }

    var size: SIMD3<Double> {
        get { SIMD3(sizeX, sizeY, sizeZ) }
        set { sizeX = newValue.x; sizeY = newValue.y; sizeZ = newValue.z }
    }

    /// Bridges to the math-layer descriptor used by `ShadowGeometryService`.
    var descriptor: BlockerDescriptor {
        BlockerDescriptor(basePosition: position, size: size, yawRadians: yaw, kind: kind)
    }
}
