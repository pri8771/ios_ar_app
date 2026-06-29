//
//  ARSupport.swift
//  Umbra
//
//  Centralizes detection of AR capability so the UI can degrade gracefully to
//  the simulator / preview mock when world tracking is unavailable.
//

import Foundation

#if canImport(ARKit)
import ARKit
#endif

enum ARSupport {

    /// True when this device + OS supports `ARWorldTrackingConfiguration`.
    /// Returns false on the iOS simulator and on unsupported hardware, which
    /// drives the app into its mock/preview mode.
    static var isWorldTrackingSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #elseif canImport(ARKit)
        return ARWorldTrackingConfiguration.isSupported
        #else
        return false
        #endif
    }

    /// True when running on the iOS simulator (no camera / no AR).
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// A user-facing explanation used when AR is unavailable.
    static var unavailableReason: String {
        if isSimulator {
            return "AR requires a physical iPhone. You're viewing the preview mode, "
                + "which simulates a flat ground plane so you can explore the planner."
        }
        return "This device doesn't support world tracking AR. You can still use "
            + "the preview mode to plan with simulated ground."
    }
}
