//
//  SettingsView.swift
//  Shadow Lens
//
//  Local preferences: location source, manual location fallback, shadow
//  appearance, and a clear statement of the app's privacy posture. Handles
//  permission denial with a path to system Settings.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var locationService: LocationService
    @Query private var settingsRows: [AppSettings]

    private var settings: AppSettings {
        settingsRows.first ?? AppSettings.current(in: context)
    }

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                appearanceSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Location

    private var locationSection: some View {
        Section {
            Toggle("Use device location", isOn: Binding(
                get: { settings.useDeviceLocation },
                set: { newValue in
                    settings.useDeviceLocation = newValue
                    if newValue { locationService.requestAuthorization() }
                    try? context.save()
                }))

            locationStatusRow

            if !settings.useDeviceLocation || !locationService.state.isUsable {
                manualLocationControls
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Location is used only on this device to compute the sun's position. It is never uploaded.")
        }
    }

    @ViewBuilder private var locationStatusRow: some View {
        switch locationService.state {
        case .authorized:
            Label(locationService.placemarkName ?? "Using current location", systemImage: "location.fill")
                .foregroundStyle(.green)
        case .authorizedNoFix:
            Label("Acquiring location…", systemImage: "location")
                .foregroundStyle(.secondary)
        case .notDetermined:
            Button {
                locationService.requestAuthorization()
            } label: {
                Label("Grant location access", systemImage: "location")
            }
        case .denied, .restricted, .unavailable:
            VStack(alignment: .leading, spacing: 6) {
                Label("Location access is off", systemImage: "location.slash")
                    .foregroundStyle(.orange)
                #if canImport(UIKit)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                #endif
                Text("Using the manual location below instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualLocationControls: some View {
        Group {
            TextField("Location name", text: Binding(
                get: { settings.manualLocationName },
                set: { settings.manualLocationName = $0; try? context.save() }))

            HStack {
                Text("Latitude")
                Spacer()
                TextField("Latitude", value: Binding(
                    get: { settings.manualLatitude },
                    set: { settings.manualLatitude = min(90, max(-90, $0)); try? context.save() }),
                    format: .number.precision(.fractionLength(4)))
                .multilineTextAlignment(.trailing)
                .keyboardTypeDecimalIfAvailable()
                .frame(width: 120)
            }
            HStack {
                Text("Longitude")
                Spacer()
                TextField("Longitude", value: Binding(
                    get: { settings.manualLongitude },
                    set: { settings.manualLongitude = min(180, max(-180, $0)); try? context.save() }),
                    format: .number.precision(.fractionLength(4)))
                .multilineTextAlignment(.trailing)
                .keyboardTypeDecimalIfAvailable()
                .frame(width: 120)
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Shadow Appearance") {
            VStack(alignment: .leading) {
                Text("Shadow opacity: \(Int(settings.shadowOpacity * 100))%")
                    .font(.subheadline)
                Slider(value: Binding(
                    get: { settings.shadowOpacity },
                    set: { settings.shadowOpacity = $0; try? context.save() }),
                    in: 0.1...0.9)
                .accessibilityValue("\(Int(settings.shadowOpacity * 100)) percent")
            }
            Toggle("Show sun path overlay", isOn: Binding(
                get: { settings.showSunPath },
                set: { settings.showSunPath = $0; try? context.save() }))
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section("Privacy") {
            Label("No account, no cloud, no analytics", systemImage: "lock.shield")
            Label("All plans stored on this device", systemImage: "iphone")
            Label("No network requests", systemImage: "wifi.slash")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersionString).foregroundStyle(.secondary)
            }
            NavigationLink {
                ApproximationInfoView()
            } label: {
                Label("How accuracy works", systemImage: "info.circle")
            }
        } header: {
            Text("About")
        } footer: {
            Text("Shadow Lens is a local-first sun & shade planner. Results are approximate.")
        }
    }
}

private extension View {
    /// Applies the decimal keyboard on UIKit platforms; no-op elsewhere so the
    /// view still compiles for previews/macOS.
    @ViewBuilder func keyboardTypeDecimalIfAvailable() -> some View {
        #if os(iOS)
        self.keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }
}

extension Bundle {
    var appVersionString: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationService())
        .modelContainer(for: [ARProject.self, PlacedBlocker.self, AppSettings.self], inMemory: true)
}
