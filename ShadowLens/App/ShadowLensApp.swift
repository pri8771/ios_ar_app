//
//  ShadowLensApp.swift
//  Shadow Lens
//
//  App entry point. SwiftUI lifecycle + SwiftData container. Fully local: the
//  model container is an on-device store with no CloudKit, no sync.
//

import SwiftUI
import SwiftData

@main
struct ShadowLensApp: App {

    /// Local-only SwiftData container. If the store fails to open (e.g. a
    /// migration problem), fall back to an in-memory store so the app still
    /// launches rather than crashing on the user.
    let container: ModelContainer

    init() {
        // Build from the versioned schema so future model changes migrate
        // cleanly instead of failing to open the on-device store.
        let schema = Schema(versionedSchema: CurrentSchema.self)
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(
                for: schema,
                migrationPlan: ShadowLensMigrationPlan.self,
                configurations: [config])
        } catch {
            // Defensive fallback: never block launch on a persistence error.
            // An in-memory store keeps the app usable for the session even if
            // the on-disk store is corrupt or a migration cannot complete.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            container = try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
