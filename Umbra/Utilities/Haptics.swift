//
//  Haptics.swift
//  Umbra
//
//  Tiny wrapper around UIKit feedback generators so the lens can confirm
//  placement and selection with a light tap. No-ops where UIKit is unavailable.
//

import Foundation

#if canImport(UIKit)
import UIKit

enum Haptics {
    /// A light tap, e.g. when an object is placed.
    static func place() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }

    /// A soft selection tick.
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A success notification, e.g. after an export is prepared.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
#else
enum Haptics {
    static func place() {}
    static func select() {}
    static func success() {}
}
#endif
