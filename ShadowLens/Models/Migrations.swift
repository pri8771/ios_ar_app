//
//  Migrations.swift
//  Shadow Lens
//
//  SwiftData schema versioning + migration scaffold. v1 is the initial shipping
//  schema. When a model changes in a future release, add a `SchemaV2` (and so
//  on) and a corresponding `MigrationStage` in `ShadowLensMigrationPlan` so
//  existing on-device stores upgrade cleanly instead of failing to open.
//
//  Keeping this in place from v1 means the first schema change won't force a
//  destructive reset of users' locally stored projects.
//

import Foundation
import SwiftData

/// The initial (v1.0.0) schema for Shadow Lens.
enum ShadowLensSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ARProject.self, PlacedBlocker.self, AppSettings.self]
    }
}

/// The current schema the app builds its container from. Update this alias when
/// introducing a newer versioned schema.
typealias CurrentSchema = ShadowLensSchemaV1

/// Migration plan describing how to move between schema versions.
///
/// For v1 there is nothing to migrate, so `stages` is intentionally empty. When
/// `ShadowLensSchemaV2` is introduced, append it to `schemas` and add a
/// `.lightweight(...)` or `.custom(...)` stage here.
enum ShadowLensMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ShadowLensSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
