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
        let schema = Schema([ARProject.self, PlacedBlocker.self, AppSettings.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Defensive fallback: never block launch on a persistence error.
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
