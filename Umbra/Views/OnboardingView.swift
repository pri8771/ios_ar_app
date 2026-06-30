//
//  OnboardingView.swift
//  Umbra
//
//  Three-page onboarding that sets expectations (approximate planner), explains
//  permissions, and respects accessibility. No data leaves the device. Dressed
//  in the brand twilight palette so the first run feels considered.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var locationService: LocationService
    var onFinish: () -> Void

    @State private var page = 0
    @State private var requestedLocation = false

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(symbol: "camera.viewfinder",
             title: "Point & Plan",
             body: "Point your camera at the ground, drop a simple object, scrub the time, and see where shade will land."),
        Page(symbol: "sun.max",
             title: "Approximate by design",
             body: "Umbra projects physically plausible shadows from the proxy objects you place. It does not reconstruct the real world — results are an approximation to help you plan."),
        Page(symbol: "lock.shield",
             title: "Private & on‑device",
             body: "Everything stays on your iPhone. No account, no cloud, no analytics, and no network — Umbra even works in airplane mode. Location is used only to compute the sun's position locally.")
    ]

    var body: some View {
        ZStack {
            TwilightBackground()

            VStack(spacing: 20) {
                brandMark
                    .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                        pageView(p)
                            .tag(index)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(p.title). \(p.body)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                controls
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Brand mark

    private var brandMark: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.haze.fill")
                .font(.headline)
                .foregroundStyle(UmbraTheme.sunGradient)
            Text("UMBRA")
                .font(.headline.weight(.bold))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.92))
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Page

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(UmbraTheme.sunGradient)
                    .frame(width: 132, height: 132)
                    .shadow(color: UmbraTheme.sun.opacity(0.5), radius: 28, y: 6)
                Image(systemName: p.symbol)
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(UmbraTheme.indigoDeep)
                    .accessibilityHidden(true)
            }
            Text(p.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(p.body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
        .padding()
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        VStack(spacing: 12) {
            if page == pages.count - 1 {
                Button {
                    requestedLocation = true
                    locationService.requestAuthorization()
                } label: {
                    Label(requestedLocation ? "Location requested" : "Allow Location (optional)",
                          systemImage: requestedLocation ? "checkmark.circle.fill" : "location")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.18)))
                }
                .foregroundStyle(.white)
                .disabled(requestedLocation)
                .accessibilityHint("Used only on-device to compute the sun's position. You can skip this.")

                Button(action: onFinish) {
                    Text("Get Started")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(SunButtonStyle())
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Next")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(SunButtonStyle())

                Button("Skip", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

/// The brand's primary call-to-action: a warm sun-gradient pill with dark text.
struct SunButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(UmbraTheme.indigoDeep)
            .background(UmbraTheme.sunGradient, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: UmbraTheme.sun.opacity(0.45), radius: 14, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environmentObject(LocationService())
}
