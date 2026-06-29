//
//  ARLensView.swift
//  Umbra
//
//  The main planning screen. On a real device it shows the live AR camera with
//  placed objects and projected shadows; on the simulator it shows the top-down
//  mock. Either way the time scrubber, palette, sun-path, and export work.
//

import SwiftUI
import SwiftData
import simd

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ARKit) && !targetEnvironment(simulator)
import ARKit
#endif

struct ARLensView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var locationService: LocationService
    @Query private var settingsRows: [AppSettings]

    let project: ARProject

    @StateObject private var viewModel: ARLensViewModel
    @State private var showShare = false
    @State private var shareImage: UIImage?
    @State private var showInfo = false
    @State private var didLoad = false

    #if canImport(ARKit) && !targetEnvironment(simulator)
    @StateObject private var arController = ARSceneController()
    #endif

    private var settings: AppSettings { settingsRows.first ?? AppSettings() }

    init(project: ARProject) {
        self.project = project
        _viewModel = StateObject(wrappedValue: ARLensViewModel(
            latitude: project.latitude,
            longitude: project.longitude,
            timeZone: project.resolvedTimeZone,
            previewDate: project.previewDate))
    }

    var body: some View {
        ZStack {
            sceneLayer
                .ignoresSafeArea()

            VStack {
                topBar
                approximateBanner
                Spacer()
                bottomControls
            }
            .padding()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear(perform: onAppear)
        .onDisappear(perform: save)
        .sheet(isPresented: $showShare) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showInfo) {
            ApproximationInfoView()
        }
        #if canImport(ARKit) && !targetEnvironment(simulator)
        .onReceive(arController.$planeHeight) { h in
            viewModel.planeHeight = Double(h)
        }
        .onChange(of: viewModel.blockers) { _, new in
            arController.syncBlockers(new)
        }
        .onChange(of: viewModel.shadows) { _, new in
            arController.syncShadows(new, opacity: settings.shadowOpacity)
        }
        #endif
    }

    // MARK: - Scene

    @ViewBuilder private var sceneLayer: some View {
        #if canImport(ARKit) && !targetEnvironment(simulator)
        if ARSupport.isWorldTrackingSupported {
            ARContainerView(controller: arController)
                .overlay(alignment: .center) { trackingOverlay }
        } else {
            MockSceneView(viewModel: viewModel)
        }
        #else
        MockSceneView(viewModel: viewModel)
            .overlay(alignment: .top) { simulatorBadge }
        #endif
    }

    #if canImport(ARKit) && !targetEnvironment(simulator)
    @ViewBuilder private var trackingOverlay: some View {
        switch arController.trackingState {
        case .normal:
            if !arController.hasPlaneAnchor {
                guidanceCard("Move your phone slowly to detect the ground.", systemImage: "viewfinder")
            }
        case .initializing:
            guidanceCard("Starting AR…", systemImage: "arkit")
        case .limited(let reason):
            guidanceCard(reason, systemImage: "exclamationmark.triangle")
        case .interrupted:
            guidanceCard("AR paused. Return to the scene to continue.", systemImage: "pause.circle")
        case .failed(let message):
            guidanceCard("AR error: \(message)", systemImage: "xmark.octagon")
        case .notAvailable:
            MockSceneView(viewModel: viewModel)
        }
    }
    #endif

    private var simulatorBadge: some View {
        Text("Preview mode — AR runs on a physical iPhone")
            .font(.caption2)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 60)
    }

    private func guidanceCard(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                save()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Back to plans")

            Spacer()

            VStack(spacing: 2) {
                Text(project.name).font(.subheadline.bold()).lineLimit(1)
                Text(viewModel.sunStatusText).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Menu {
                Button {
                    exportSnapshot()
                } label: {
                    Label("Share Snapshot", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    viewModel.removeAll()
                } label: {
                    Label("Clear Objects", systemImage: "trash")
                }
                Button {
                    showInfo = true
                } label: {
                    Label("About Accuracy", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("More actions")
        }
    }

    private var approximateBanner: some View {
        Button {
            showInfo = true
        } label: {
            Label("Approximate — projected from your placed objects", systemImage: "info.circle")
                .font(.caption2)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.yellow.opacity(0.25), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityHint("Explains how shadows are estimated")
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if settings.showSunPath {
                SunPathView(samples: viewModel.sunPath, current: viewModel.sunPosition)
            }

            if let id = viewModel.selectedBlockerID, viewModel.blockers[id] != nil {
                selectedObjectControls(id: id)
            }

            ObjectPaletteView(selectedKind: $viewModel.selectedKind)

            TimeScrubberView(viewModel: viewModel)
        }
    }

    private func selectedObjectControls(id: UUID) -> some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.blockers[id]?.kind.systemImage ?? "cube")
            Text(viewModel.blockers[id]?.kind.displayName ?? "Object")
                .font(.subheadline.bold())
            Spacer()
            Button {
                viewModel.rotateSelected(by: .pi / 8)
            } label: {
                Image(systemName: "rotate.right")
            }
            .accessibilityLabel("Rotate object")
            Button(role: .destructive) {
                viewModel.removeBlocker(id)
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Remove object")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Lifecycle / actions

    private func onAppear() {
        guard !didLoad else { return }
        didLoad = true
        viewModel.load(blockers: project.blockers, planeHeight: project.planeHeight)
        refreshLocation()

        #if canImport(ARKit) && !targetEnvironment(simulator)
        arController.onPlaneTap = { relative in
            viewModel.addBlocker(at: SIMD3<Double>(Double(relative.x), Double(relative.y), Double(relative.z)))
        }
        #endif
    }

    private func refreshLocation() {
        if settings.useDeviceLocation, case let .authorized(loc) = locationService.state {
            viewModel.updateLocation(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                timeZone: .current)
        }
    }

    private func save() {
        viewModel.persist(into: project, context: context)
    }

    private func exportSnapshot() {
        #if canImport(ARKit) && !targetEnvironment(simulator)
        if ARSupport.isWorldTrackingSupported {
            arController.snapshot { image in
                guard let image else { return }
                self.shareImage = image
                self.persistThumbnail(image)
                self.showShare = true
            }
            return
        }
        #endif
        // Mock-mode export: render the top-down plan.
        let snapshotView = MockSceneView(viewModel: viewModel)
        if let image = SnapshotRenderer.image(from: snapshotView, size: CGSize(width: 1080, height: 1080)) {
            shareImage = image
            persistThumbnail(image)
            showShare = true
        }
    }

    private func persistThumbnail(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.6) {
            project.thumbnailData = data
            try? context.save()
        }
    }
}

/// Explains the approximation model to the user — a first-class limitation, not
/// a vague disclaimer.
struct ApproximationInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("How shadows are estimated", systemImage: "sun.max")
                        .font(.title3.bold())

                    Text("Umbra computes the sun's real position for your date, time, and location using local astronomy math (no internet needed).")

                    Text("It then projects the simple objects you place — pole, box, wall, person, tree — onto the detected ground plane to show where their shade falls.")

                    Divider()

                    Text("What it does **not** do:")
                        .font(.headline)
                    bullet("Reconstruct real buildings, terrain, or existing objects in your space.")
                    bullet("Model soft shadow edges, reflected light, or partial cloud cover.")
                    bullet("Account for elevation changes in the ground beyond the flat detected plane.")

                    Text("Treat the result as a practical planning approximation, accurate to within the simplifications above.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Accuracy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 6)
            Text(text)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ARProject.self, PlacedBlocker.self, AppSettings.self, configurations: config)
    let project = ARProject(name: "Backyard", latitude: 37.77, longitude: -122.41)
    container.mainContext.insert(project)
    return ARLensView(project: project)
        .environmentObject(LocationService())
        .modelContainer(container)
}
