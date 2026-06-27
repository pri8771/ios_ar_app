//
//  RootView.swift
//  Shadow Lens
//
//  Top-level navigation. Shows onboarding until completed, then the project
//  library. Honors dark mode and Dynamic Type via standard SwiftUI.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]

    @StateObject private var locationService = LocationService()

    private var settings: AppSettings? { settingsRows.first }

    var body: some View {
        Group {
            if let settings, settings.hasCompletedOnboarding {
                ProjectsView()
                    .environmentObject(locationService)
            } else {
                OnboardingView(onFinish: completeOnboarding)
                    .environmentObject(locationService)
            }
        }
        .onAppear(perform: ensureSettings)
    }

    private func ensureSettings() {
        if settingsRows.isEmpty {
            _ = AppSettings.current(in: context)
        }
    }

    private func completeOnboarding() {
        let s = AppSettings.current(in: context)
        s.hasCompletedOnboarding = true
        try? context.save()
    }
}

#Preview {
    RootView()
        .modelContainer(for: [ARProject.self, PlacedBlocker.self, AppSettings.self], inMemory: true)
}
