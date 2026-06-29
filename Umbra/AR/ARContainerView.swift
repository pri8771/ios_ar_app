//
//  ARContainerView.swift
//  Umbra
//
//  SwiftUI bridge to the RealityKit ARView via UIViewRepresentable. Only used
//  on real devices; the simulator/preview path uses MockSceneView instead.
//

import SwiftUI

#if canImport(ARKit) && !targetEnvironment(simulator)
import ARKit
import RealityKit

struct ARContainerView: UIViewRepresentable {
    @ObservedObject var controller: ARSceneController

    func makeUIView(context: Context) -> ARView {
        controller.startSession()
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // The controller owns all mutation; nothing imperative needed here.
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
#endif
