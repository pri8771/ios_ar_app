//
//  BlockerStyle.swift
//  Umbra
//
//  Shared visual styling for blocker kinds, usable by both the AR renderer and
//  the SwiftUI mock/preview views.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum BlockerStyle {

    /// SwiftUI color used in lists, palette, and the mock 2D preview.
    static func swiftUIColor(for kind: BlockerKind) -> Color {
        switch kind {
        case .pole: return Color(red: 0.55, green: 0.55, blue: 0.60)
        case .umbrella: return Color(red: 0.88, green: 0.38, blue: 0.36)
        case .box: return Color(red: 0.85, green: 0.65, blue: 0.30)
        case .wall: return Color(red: 0.70, green: 0.45, blue: 0.40)
        case .person: return Color(red: 0.35, green: 0.55, blue: 0.85)
        case .tree: return Color(red: 0.30, green: 0.60, blue: 0.40)
        }
    }

    #if canImport(UIKit)
    /// UIColor used by RealityKit materials on device.
    static func color(for kind: BlockerKind) -> UIColor {
        UIColor(swiftUIColor(for: kind))
    }
    #endif
}
