//
//  MockSceneView.swift
//  Umbra
//
//  Simulator / no-AR fallback. Renders a top-down 2D plan of the same scene the
//  AR renderer would show: a ground grid, placed blocker footprints, and their
//  projected shadow polygons — all from the identical shadow math. Tapping the
//  ground places an object, so the planner is fully usable without a device.
//

import SwiftUI
import simd

struct MockSceneView: View {
    @ObservedObject var viewModel: ARLensViewModel

    /// Meters shown across the full width of the view.
    private let metersAcross: Double = 12.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = Double(min(size.width, size.height)) / metersAcross
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            ZStack {
                background

                Canvas { ctx, _ in
                    drawGrid(ctx: ctx, size: size, scale: scale, center: center)
                    drawShadows(ctx: ctx, scale: scale, center: center)
                    drawBlockers(ctx: ctx, scale: scale, center: center)
                    drawSunIndicator(ctx: ctx, size: size, center: center)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    place(at: location, scale: scale, center: center)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Top-down plan preview")
            .accessibilityValue("\(viewModel.blockers.count) objects placed. \(viewModel.sunStatusText)")
            .accessibilityHint("Double tap to add an object near the center.")
            .accessibilityAction(named: "Add object at center") {
                viewModel.addBlocker(at: SIMD3<Double>(0, viewModel.planeHeight, 0))
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(white: 0.20), Color(white: 0.10)],
            startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }

    // MARK: Drawing

    /// Maps world XZ (meters, relative to origin anchor) to view coordinates.
    /// North (-z) is up; East (+x) is right.
    private func project(_ x: Double, _ z: Double, scale: Double, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + x * scale, y: center.y + z * scale)
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize, scale: Double, center: CGPoint) {
        var path = Path()
        let meters = Int(metersAcross / 2) + 1
        for m in -meters...meters {
            let p = Double(m)
            let start = project(p, -Double(meters), scale: scale, center: center)
            let end = project(p, Double(meters), scale: scale, center: center)
            path.move(to: start); path.addLine(to: end)
            let s2 = project(-Double(meters), p, scale: scale, center: center)
            let e2 = project(Double(meters), p, scale: scale, center: center)
            path.move(to: s2); path.addLine(to: e2)
        }
        ctx.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)

        // North label at the top edge (north = up).
        ctx.draw(Text("N").font(.caption2.bold()).foregroundColor(.white.opacity(0.6)),
                 at: CGPoint(x: center.x, y: 14))
    }

    private func drawShadows(ctx: GraphicsContext, scale: Double, center: CGPoint) {
        for (_, poly) in viewModel.shadows where !poly.isEmpty {
            var path = Path()
            for (i, v) in poly.vertices.enumerated() {
                let pt = project(v.x, v.z, scale: scale, center: center)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(.black.opacity(0.45)))
            ctx.stroke(path, with: .color(.black.opacity(0.6)), lineWidth: 1)
        }
    }

    private func drawBlockers(ctx: GraphicsContext, scale: Double, center: CGPoint) {
        let service = ShadowGeometryService()
        for (id, desc) in viewModel.blockers {
            let corners = service.boundingBoxCorners(for: desc)
                .filter { abs($0.y - desc.basePosition.y) < 1e-6 } // base footprint
            var path = Path()
            for (i, c) in corners.enumerated() {
                let pt = project(c.x, c.z, scale: scale, center: center)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            let color = BlockerStyle.swiftUIColor(for: desc.kind)
            ctx.fill(path, with: .color(color.opacity(0.9)))
            let isSelected = id == viewModel.selectedBlockerID
            ctx.stroke(path,
                       with: .color(isSelected ? .white : color.opacity(0.5)),
                       lineWidth: isSelected ? 2.5 : 1)
        }
    }

    private func drawSunIndicator(ctx: GraphicsContext, size: CGSize, center: CGPoint) {
        guard viewModel.sunPosition.elevation > 0 else { return }
        // Place a small sun marker in the azimuth direction near the edge.
        let az = SunMath.rad(viewModel.sunPosition.azimuth)
        let radius = Double(min(size.width, size.height)) * 0.42
        // North = up = -z; East = +x. Screen y grows downward.
        let dx = sin(az) * radius
        let dy = -cos(az) * radius
        let pt = CGPoint(x: center.x + dx, y: center.y + dy)
        let rect = CGRect(x: pt.x - 10, y: pt.y - 10, width: 20, height: 20)
        ctx.fill(Path(ellipseIn: rect), with: .color(.yellow))
        ctx.draw(Text("☀")
            .font(.caption), at: pt)
    }

    // MARK: Interaction

    private func place(at location: CGPoint, scale: Double, center: CGPoint) {
        let x = (Double(location.x) - Double(center.x)) / scale
        let z = (Double(location.y) - Double(center.y)) / scale
        viewModel.addBlocker(at: SIMD3<Double>(x, viewModel.planeHeight, z))
    }
}

#Preview {
    let vm = ARLensViewModel(latitude: 37.77, longitude: -122.41)
    vm.addBlocker(at: SIMD3<Double>(0, 0, 0))
    vm.setTimeOfDay(hours: 9)
    return MockSceneView(viewModel: vm)
}
