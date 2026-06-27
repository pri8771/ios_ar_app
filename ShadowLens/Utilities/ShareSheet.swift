//
//  ShareSheet.swift
//  Shadow Lens
//
//  Thin wrapper over UIActivityViewController for exporting a captured image.
//  Sharing is user-initiated and goes through the system share sheet only; the
//  app itself performs no uploads.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Utility for rendering a SwiftUI view to a UIImage for the mock-mode export
/// path (no AR frame to snapshot in the simulator).
@MainActor
enum SnapshotRenderer {
    static func image<V: View>(from view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
#endif
