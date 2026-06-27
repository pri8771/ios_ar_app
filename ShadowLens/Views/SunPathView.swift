//
//  SunPathView.swift
//  Shadow Lens
//
//  A compact sun-path chart: plots the sun's elevation vs. azimuth across the
//  day, with a marker for the current preview instant. Pure SwiftUI Canvas, no
//  Charts dependency required, works on simulator.
//

import SwiftUI

struct SunPathView: View {
    let samples: [SunPathSample]
    let current: SolarPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sun Path")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size)
                }
            }
            .frame(height: 90)
            .accessibilityElement()
            .accessibilityLabel("Sun path chart")
            .accessibilityValue(String(
                format: "Current elevation %.0f degrees, azimuth %.0f degrees",
                current.elevation, current.azimuth))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        // X axis: azimuth 0..360 mapped across width.
        // Y axis: elevation -10..90 mapped to height (90 at top).
        func point(az: Double, el: Double) -> CGPoint {
            let x = az / 360.0 * size.width
            let elClamped = min(90.0, max(-10.0, el))
            let y = size.height - (elClamped + 10.0) / 100.0 * size.height
            return CGPoint(x: x, y: y)
        }

        // Horizon line (elevation 0).
        var horizon = Path()
        let hy = point(az: 0, el: 0).y
        horizon.move(to: CGPoint(x: 0, y: hy))
        horizon.addLine(to: CGPoint(x: size.width, y: hy))
        ctx.stroke(horizon, with: .color(.white.opacity(0.25)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

        // Sun path curve (only daytime samples, above horizon).
        var path = Path()
        var started = false
        for s in samples {
            guard s.position.elevation > -2 else {
                started = false
                continue
            }
            let pt = point(az: s.position.azimuth, el: s.position.elevation)
            if !started {
                path.move(to: pt); started = true
            } else {
                path.addLine(to: pt)
            }
        }
        ctx.stroke(path, with: .color(.yellow.opacity(0.9)), lineWidth: 2)

        // Current marker.
        if current.elevation > -2 {
            let pt = point(az: current.azimuth, el: current.elevation)
            let r: CGFloat = 5
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                     with: .color(.orange))
        }

        // Cardinal labels.
        let labels: [(String, Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]
        for (label, az) in labels {
            let x = az / 360.0 * size.width
            ctx.draw(Text(label).font(.system(size: 9)).foregroundColor(.white.opacity(0.5)),
                     at: CGPoint(x: x + 8, y: size.height - 6))
        }
    }
}
