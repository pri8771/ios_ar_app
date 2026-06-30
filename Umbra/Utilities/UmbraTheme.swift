//
//  UmbraTheme.swift
//  Umbra
//
//  The brand design system: a single source of truth for Umbra's colors and
//  gradients, matching the app icon's twilight-indigo → warm-gold palette. Used
//  across onboarding, the project library, the lens, and settings so the app
//  reads as one cohesive, considered product.
//
//  "Umbra" is the darkest part of a shadow — the brand pairs cool twilight
//  indigos (shade) with a warm low sun (gold), exactly the two forces the app
//  reasons about.
//

import SwiftUI

extension Color {
    /// Initializes a color from a 24-bit hex value (e.g. `0x181440`).
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0)
    }
}

/// Brand palette + gradients. Pure values; no state.
enum UmbraTheme {

    // MARK: Core palette (mirrors scripts/make_icon.py)

    /// Deep zenith indigo — the darkest sky / deepest shade.
    static let indigoDeep = Color(hex: 0x141233)
    /// Twilight indigo.
    static let indigo = Color(hex: 0x201460)
    /// Dusk violet.
    static let violet = Color(hex: 0x2B2060)
    /// Mauve at the edge of dusk.
    static let mauve = Color(hex: 0x6E3A6E)
    /// Warm horizon band just below the sun.
    static let horizon = Color(hex: 0xD67947)
    /// Horizon glow.
    static let horizonGlow = Color(hex: 0xF7B85C)

    /// The sun: the single warm accent. Light/dark variants.
    static let sun = Color(hex: 0xFFC24D)
    static let sunCore = Color(hex: 0xFFF2C2)
    static let sunDeep = Color(hex: 0xF0A24A)

    // MARK: Gradients

    /// Full twilight sky → ground, top to bottom. The signature backdrop used
    /// behind onboarding and other immersive surfaces.
    static let twilightSky = LinearGradient(
        stops: [
            .init(color: indigoDeep, location: 0.00),
            .init(color: violet, location: 0.42),
            .init(color: mauve, location: 0.70),
            .init(color: horizon, location: 0.90),
            .init(color: horizonGlow, location: 1.00),
        ],
        startPoint: .top,
        endPoint: .bottom)

    /// A restrained dark twilight wash for content-heavy surfaces (no hot
    /// horizon), keeping text legible.
    static let duskWash = LinearGradient(
        colors: [indigoDeep, Color(hex: 0x1B1646), Color(hex: 0x2A1E55)],
        startPoint: .top,
        endPoint: .bottom)

    /// The warm sun gradient used for the brand mark and prominent accents.
    static let sunGradient = LinearGradient(
        colors: [sunCore, sun, sunDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
}

/// A reusable immersive twilight background with a soft radial sun glow in the
/// upper-trailing corner — the same composition as the app icon.
struct TwilightBackground: View {
    /// When false, omits the hot horizon for a calmer, more legible backdrop.
    var immersive: Bool = true

    var body: some View {
        ZStack {
            (immersive ? UmbraTheme.twilightSky : UmbraTheme.duskWash)
                .ignoresSafeArea()

            // Soft sun glow, echoing the icon.
            RadialGradient(
                colors: [UmbraTheme.sun.opacity(immersive ? 0.55 : 0.28), .clear],
                center: .init(x: 0.74, y: immersive ? 0.30 : 0.18),
                startRadius: 0,
                endRadius: 360)
            .ignoresSafeArea()
            .blendMode(.screen)
        }
    }
}

#Preview("Twilight") {
    TwilightBackground()
}

#Preview("Dusk") {
    TwilightBackground(immersive: false)
}
