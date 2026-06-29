//
//  OnboardingView.swift
//  Umbra
//
//  Three-page onboarding that sets expectations (approximate planner), explains
//  permissions, and respects accessibility. No data leaves the device.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var locationService: LocationService
    var onFinish: () -> Void

    @State private var page = 0

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
             body: "Everything stays on your iPhone. No account, no cloud, no analytics, no network. Location is used only to compute the sun's position locally.")
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                    VStack(spacing: 20) {
                        Image(systemName: p.symbol)
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(p.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(p.body)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                    .tag(index)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(p.title). \(p.body)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                if page == pages.count - 1 {
                    Button {
                        locationService.requestAuthorization()
                    } label: {
                        Label("Allow Location (optional)", systemImage: "location")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Used only on-device to compute the sun's position. You can skip this.")

                    Button(action: onFinish) {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Skip", action: onFinish)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environmentObject(LocationService())
}
