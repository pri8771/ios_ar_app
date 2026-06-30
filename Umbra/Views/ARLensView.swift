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

            if !settings.hasSeenLensCoach {
                lensCoachOverlay
            }
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
                #if canImport(ARKit) && !targetEnvironment(simulator)
                if ARSupport.isWorldTrackingSupported {
                    Button {
                        arController.resetGround()
                        viewModel.planeHeight = 0
                    } label: {
                        Label("Re-detect Ground", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                #endif
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

    // MARK: - First-run trust moment

    /// The "now-shadow matches" coach: the first-minute moment that teaches the
    /// proxy model and earns trust before the user scrubs to other times.
    private var lensCoachOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { dismissCoach() }

            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(UmbraTheme.sunGradient).frame(width: 64, height: 64)
                    Image(systemName: "sun.max.fill")
                        .font(.title)
                        .foregroundStyle(UmbraTheme.indigoDeep)
                }
                Text("See it line up first")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Place an object next to something real outside — a post, a wall, a chair — then tap **Now**. If the projected shadow lines up with the real one, you can trust where the shade falls at any time you scrub to.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    dismissCoach()
                } label: {
                    Text("Got it")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(SunButtonStyle())
                .padding(.top, 4)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.12)))
            .padding(32)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("See it line up first. Place an object next to something real, then tap Now. If the projected shadow matches the real one, you can trust the shade at any time.")
        }
        .transition(.opacity)
    }

    private func dismissCoach() {
        let s = settingsRows.first ?? AppSettings.current(in: context)
        s.hasSeenLensCoach = true
        try? context.save()
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
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.blockers[id]?.kind.systemImage ?? "cube")
                Text(viewModel.blockers[id]?.kind.displayName ?? "Object")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    viewModel.rotateSelected(by: .pi / 8)
                    Haptics.select()
                } label: {
                    Image(systemName: "rotate.right")
                }
                .accessibilityLabel("Rotate object")
                Button(role: .destructive) {
                    viewModel.removeBlocker(id)
                    Haptics.select()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Remove object")
            }

            HStack(spacing: 10) {
                Image(systemName: "arrow.up.and.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { viewModel.selectedHeight ?? 1.0 },
                    set: { viewModel.setHeightForSelected($0) }),
                    in: 0.3...6.0)
                Text(String(format: "%.1f m", viewModel.selectedHeight ?? 0))
                    .font(.caption.monospacedDigit())
                    .frame(width: 50, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Object height")
            .accessibilityValue(String(format: "%.1f meters", viewModel.selectedHeight ?? 0))
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
            Haptics.place()
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
                let stamped = self.stamped(image)
                self.shareImage = stamped
                self.persistThumbnail(stamped)
                self.showShare = true
                Haptics.success()
            }
            return
        }
        #endif
        // Mock-mode export: render the top-down plan.
        let snapshotView = MockSceneView(viewModel: viewModel)
        if let image = SnapshotRenderer.image(from: snapshotView, size: CGSize(width: 1080, height: 1080)) {
            let stampedImage = stamped(image)
            shareImage = stampedImage
            persistThumbnail(stampedImage)
            showShare = true
            Haptics.success()
        }
    }

    /// Burns the honest date/time/location/sun + "Approximate — Umbra" footer
    /// into an exported image so a shared snapshot stays truthful out of context.
    private func stamped(_ image: UIImage) -> UIImage {
        SnapshotStamp.stamp(image, info: SnapshotStamp.Info(
            title: project.name,
            dateTime: viewModel.previewDateTimeString,
            location: viewModel.locationCoordString,
            sun: viewModel.sunSummaryString))
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
