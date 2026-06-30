//
//  ARSceneController.swift
//  Umbra
//
//  The RealityKit/ARKit coordinator. Owns the ARView, configures world
//  tracking with gravity-and-heading alignment, detects horizontal planes,
//  places proxy blockers via raycast, and renders approximate shadow meshes.
//
//  All AR types are compiled only where ARKit is available (i.e. not on the
//  simulator), so the project still builds and previews on the simulator using
//  the mock path elsewhere in the app.
//

import Foundation
import SwiftUI
import simd

#if canImport(ARKit) && !targetEnvironment(simulator)
import ARKit
import RealityKit
import Combine

/// Tracking quality surfaced to the UI for graceful messaging.
enum ARTrackingUIState: Equatable {
    case initializing
    case normal
    case limited(String)
    case interrupted
    case failed(String)
    case notAvailable
}

/// Coordinates a single AR session for the lens screen. This is a UIKit-free
/// controller object; the `UIViewRepresentable` lives in ARContainerView.swift.
final class ARSceneController: NSObject, ObservableObject {

    // MARK: Published UI state
    @Published var trackingState: ARTrackingUIState = .initializing
    @Published var hasPlaneAnchor: Bool = false
    @Published var planeHeight: Float = 0

    /// Called when the user taps to place; the owning view model decides what
    /// to drop. Returns the world position chosen, or nil if no surface hit.
    var onPlaneTap: ((SIMD3<Float>) -> Void)?

    let arView: ARView = ARView(frame: .zero)

    /// Root anchor representing the scene origin. Blocker positions are stored
    /// relative to this anchor so a project reopens consistently.
    private let originAnchor = AnchorEntity(world: .zero)
    private var planeAnchor: ARPlaneAnchor?
    private var blockerEntities: [UUID: ModelEntity] = [:]
    private var shadowEntities: [UUID: ModelEntity] = [:]
    private var sunPathEntity: ModelEntity?
    private var hasConfigured = false

    override init() {
        super.init()
        arView.session.delegate = self
        arView.scene.addAnchor(originAnchor)
        arView.environment.sceneUnderstanding.options = []
        arView.renderOptions.insert(.disablePersonOcclusion)
    }

    // MARK: - Session lifecycle

    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingState = .notAvailable
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none
        arView.session.run(config, options: hasConfigured ? [] : [.resetTracking, .removeExistingAnchors])
        hasConfigured = true
        installTapGesture()
    }

    func pauseSession() {
        arView.session.pause()
    }

    /// Releases the locked ground plane so the next detected horizontal surface
    /// re-locks. Non-destructive: the world map, tracking, and any placed
    /// objects are preserved (the first plane is otherwise kept for the session).
    func resetGround() {
        planeAnchor = nil
        hasPlaneAnchor = false
        planeHeight = 0
    }

    private func installTapGesture() {
        // Avoid stacking gesture recognizers across restarts.
        arView.gestureRecognizers?.forEach { arView.removeGestureRecognizer($0) }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: arView)
        // Prefer existing horizontal plane geometry; fall back to estimated.
        let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        let hit = results.first
            ?? arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first
        guard let hit else { return }
        let world = SIMD3<Float>(hit.worldTransform.columns.3.x,
                                 hit.worldTransform.columns.3.y,
                                 hit.worldTransform.columns.3.z)
        // Convert to coordinates relative to the origin anchor.
        let relative = world - originAnchor.position(relativeTo: nil)
        onPlaneTap?(relative)
    }

    // MARK: - Blockers

    /// Replaces all rendered blockers with the provided descriptors (keyed by
    /// id). Positions are relative to the scene origin anchor.
    func syncBlockers(_ blockers: [UUID: BlockerDescriptor]) {
        // Remove entities no longer present.
        for (id, entity) in blockerEntities where blockers[id] == nil {
            entity.removeFromParent()
            blockerEntities.removeValue(forKey: id)
        }
        for (id, desc) in blockers {
            let entity = blockerEntities[id] ?? makeBlockerEntity(for: desc)
            entity.transform.translation = SIMD3<Float>(
                Float(desc.basePosition.x),
                Float(desc.basePosition.y) + Float(desc.size.y) / 2.0,
                Float(desc.basePosition.z))
            entity.transform.rotation = simd_quatf(angle: Float(desc.yawRadians), axis: [0, 1, 0])
            if blockerEntities[id] == nil {
                originAnchor.addChild(entity)
                blockerEntities[id] = entity
            }
        }
    }

    private func makeBlockerEntity(for desc: BlockerDescriptor) -> ModelEntity {
        let mesh = MeshResource.generateBox(
            width: Float(desc.size.x),
            height: Float(desc.size.y),
            depth: Float(desc.size.z),
            cornerRadius: (desc.kind == .pole || desc.kind == .tree || desc.kind == .umbrella) ? Float(desc.size.x) / 2 : 0.01)
        var material = SimpleMaterial()
        material.color = .init(tint: BlockerStyle.color(for: desc.kind).withAlphaComponent(0.85))
        material.roughness = 0.8
        material.metallic = 0.0
        return ModelEntity(mesh: mesh, materials: [material])
    }

    // MARK: - Shadows

    /// Renders shadow polygons (keyed by blocker id). Empty polygons clear the
    /// corresponding shadow entity.
    func syncShadows(_ shadows: [UUID: ShadowPolygon], opacity: Double) {
        for (id, entity) in shadowEntities where shadows[id]?.isEmpty != false {
            entity.removeFromParent()
            shadowEntities.removeValue(forKey: id)
        }
        for (id, poly) in shadows where !poly.isEmpty {
            shadowEntities[id]?.removeFromParent()
            shadowEntities.removeValue(forKey: id)
            guard let mesh = ShadowMeshFactory.mesh(for: poly) else { continue }
            // Deep indigo rather than pure black: reads more clearly than a flat
            // black overlay against grass and concrete in bright outdoor light.
            var material = UnlitMaterial(color: UIColor(red: 0.05, green: 0.04, blue: 0.16, alpha: 1.0))
            material.blending = .transparent(opacity: .init(floatLiteral: Float(opacity)))
            let entity = ModelEntity(mesh: mesh, materials: [material])
            // Lift very slightly to avoid z-fighting with the plane.
            entity.position = SIMD3<Float>(0, Float(poly.planeY) + 0.002, 0)
            originAnchor.addChild(entity)
            shadowEntities[id] = entity
        }
    }

    // MARK: - Snapshot

    /// Captures a snapshot of the current AR frame for export/share.
    func snapshot(completion: @escaping (UIImage?) -> Void) {
        arView.snapshot(saveToHDR: false) { image in
            completion(image)
        }
    }
}

// MARK: - ARSessionDelegate

extension ARSceneController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let desired: ARTrackingUIState
        switch frame.camera.trackingState {
        case .normal: desired = .normal
        case .notAvailable: desired = .initializing
        case .limited(let reason): desired = .limited(Self.describe(reason))
        }
        // Only publish on change, and always on the main thread.
        DispatchQueue.main.async {
            if self.trackingState != desired {
                self.trackingState = desired
            }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal {
                if planeAnchor == nil {
                    planeAnchor = plane
                    DispatchQueue.main.async {
                        self.hasPlaneAnchor = true
                        self.planeHeight = plane.transform.columns.3.y
                    }
                }
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor, plane.identifier == planeAnchor?.identifier {
                DispatchQueue.main.async {
                    self.planeHeight = plane.transform.columns.3.y
                }
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.trackingState = .failed(error.localizedDescription)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { self.trackingState = .interrupted }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async { self.trackingState = .initializing }
        // Re-run to recover relocalization.
        startSession()
    }

    private static func describe(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing: return "Initializing — move your phone slowly."
        case .excessiveMotion: return "Too much motion — slow down."
        case .insufficientFeatures: return "Not enough detail — aim at a textured surface."
        case .relocalizing: return "Relocalizing — return to where you started."
        @unknown default: return "Limited tracking."
        }
    }
}

#endif
