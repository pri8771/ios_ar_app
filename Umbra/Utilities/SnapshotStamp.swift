//
//  SnapshotStamp.swift
//  Umbra
//
//  Burns an honest, self-describing footer into an exported snapshot so a shared
//  "4pm shade" image stays truthful out of context: the date/time/location it
//  was computed for, the sun geometry, and a clear "Approximate — Umbra" mark.
//

import Foundation

#if canImport(UIKit)
import UIKit

enum SnapshotStamp {

    /// The metadata rendered into the footer.
    struct Info {
        /// Plan name.
        let title: String
        /// Human date + time, formatted in the plan's time zone.
        let dateTime: String
        /// Location label (manual name, or "lat, lon" for a live fix).
        let location: String
        /// Sun geometry summary, e.g. "Sun 42° up · 232° az" or "Below horizon".
        let sun: String
    }

    /// Returns `base` with the Umbra footer composited along the bottom edge.
    static func stamp(_ base: UIImage, info: Info) -> UIImage {
        let size = base.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext

            let w = size.width
            let barH = max(110, size.height * 0.155)
            let barRect = CGRect(x: 0, y: size.height - barH, width: w, height: barH)

            // Bottom scrim: transparent → deep indigo for legibility over any scene.
            let colors = [
                UIColor(red: 0.08, green: 0.07, blue: 0.20, alpha: 0.0).cgColor,
                UIColor(red: 0.05, green: 0.04, blue: 0.13, alpha: 0.92).cgColor,
            ] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
                cg.saveGState()
                cg.clip(to: barRect)
                cg.drawLinearGradient(grad,
                                      start: CGPoint(x: 0, y: barRect.minY),
                                      end: CGPoint(x: 0, y: barRect.maxY),
                                      options: [])
                cg.restoreGState()
            }

            let pad = w * 0.05
            let gold = UIColor(red: 1.0, green: 0.76, blue: 0.30, alpha: 1.0)
            let white = UIColor.white
            let dim = UIColor(white: 1.0, alpha: 0.74)

            let titleFont = UIFont.systemFont(ofSize: w * 0.044, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: w * 0.032, weight: .medium)
            let smallFont = UIFont.systemFont(ofSize: w * 0.027, weight: .regular)
            let markFont = UIFont.systemFont(ofSize: w * 0.030, weight: .heavy)

            // Left column: title, date/time, location + sun.
            var y = barRect.minY + barH * 0.16
            draw(info.title, font: titleFont, color: white, at: CGPoint(x: pad, y: y))
            y += titleFont.lineHeight * 1.05
            draw(info.dateTime, font: bodyFont, color: dim, at: CGPoint(x: pad, y: y))
            y += bodyFont.lineHeight * 1.05
            draw("\(info.location)   ·   \(info.sun)", font: smallFont, color: dim,
                 at: CGPoint(x: pad, y: y))

            // Brand mark, bottom-right: "☀ UMBRA · Approximate".
            let mark = "UMBRA"
            let markSize = (mark as NSString).size(withAttributes: [.font: markFont])
            let sub = "Approximate plan"
            let subSize = (sub as NSString).size(withAttributes: [.font: smallFont])
            let rightX = w - pad
            let markY = barRect.minY + barH * 0.30
            draw(mark, font: markFont, color: gold,
                 at: CGPoint(x: rightX - markSize.width, y: markY))
            draw(sub, font: smallFont, color: dim,
                 at: CGPoint(x: rightX - subSize.width, y: markY + markSize.height * 1.05))
        }
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, at point: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .shadow: {
                let s = NSShadow()
                s.shadowColor = UIColor(white: 0, alpha: 0.55)
                s.shadowBlurRadius = font.pointSize * 0.12
                s.shadowOffset = CGSize(width: 0, height: font.pointSize * 0.04)
                return s
            }(),
        ]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
