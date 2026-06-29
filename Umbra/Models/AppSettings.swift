//
//  AppSettings.swift
//  Umbra
//
//  Lightweight user preferences persisted locally via SwiftData. A single row
//  is maintained for the whole app.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    /// There is only ever one settings row; this guards uniqueness.
    @Attribute(.unique) var singletonKey: String

    /// Whether onboarding has been completed.
    var hasCompletedOnboarding: Bool

    /// Use the device's live location for solar math when available.
    var useDeviceLocation: Bool

    /// Manual fallback location used when device location is unavailable or the
    /// user opts out. Defaults to a neutral mid-latitude location.
    var manualLatitude: Double
    var manualLongitude: Double
    var manualLocationName: String

    /// Visual style of the shadow overlay.
    var shadowOpacity: Double

    /// Whether to render the sun-path arc overlay in AR.
    var showSunPath: Bool

    init(
        singletonKey: String = "umbra.settings",
        hasCompletedOnboarding: Bool = false,
        useDeviceLocation: Bool = true,
        manualLatitude: Double = 37.7749,
        manualLongitude: Double = -122.4194,
        manualLocationName: String = "San Francisco, CA",
        shadowOpacity: Double = 0.5,
        showSunPath: Bool = true
    ) {
        self.singletonKey = singletonKey
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.useDeviceLocation = useDeviceLocation
        self.manualLatitude = manualLatitude
        self.manualLongitude = manualLongitude
        self.manualLocationName = manualLocationName
        self.shadowOpacity = shadowOpacity
        self.showSunPath = showSunPath
    }
}

extension AppSettings {
    /// Fetches the single settings row, creating it if needed.
    static func current(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        try? context.save()
        return created
    }
}
