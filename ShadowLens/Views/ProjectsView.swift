//
//  ProjectsView.swift
//  Shadow Lens
//
//  Local project library. Create, open, and delete saved plans. All data is
//  stored on-device via SwiftData.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var locationService: LocationService
    @Query(sort: \ARProject.updatedAt, order: .reverse) private var projects: [ARProject]
    @Query private var settingsRows: [AppSettings]

    @State private var openedProject: ARProject?
    @State private var showingSettings = false
    @State private var newProjectActive = false

    private var settings: AppSettings { settingsRows.first ?? AppSettings() }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Shadow Lens")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createAndOpen()
                    } label: {
                        Label("New Plan", systemImage: "plus")
                    }
                    .accessibilityLabel("New plan")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(locationService)
            }
            .fullScreenCover(item: $openedProject) { project in
                ARLensView(project: project)
                    .environmentObject(locationService)
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(projects) { project in
                    Button {
                        openedProject = project
                    } label: {
                        ProjectRow(project: project)
                    }
                    .accessibilityHint("Opens this plan in the lens")
                }
                .onDelete(perform: delete)
            } footer: {
                Text("Plans are stored only on this device.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Plans Yet", systemImage: "sun.haze")
        } description: {
            Text("Create a plan, point your camera at the ground, drop an object, and scrub the time to preview shade.")
        } actions: {
            Button {
                createAndOpen()
            } label: {
                Text("Create First Plan")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func createAndOpen() {
        let resolved = currentResolvedLocation()
        let project = ARProject(
            name: defaultName(),
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            timeZoneIdentifier: TimeZone.current.identifier,
            previewDate: .now)
        context.insert(project)
        try? context.save()
        openedProject = project
    }

    private func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Plan \(formatter.string(from: .now))"
    }

    private func currentResolvedLocation() -> ResolvedLocation {
        if settings.useDeviceLocation, case let .authorized(loc) = locationService.state {
            return ResolvedLocation(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                name: locationService.placemarkName ?? "Current Location",
                isLive: true)
        }
        return ResolvedLocation(
            latitude: settings.manualLatitude,
            longitude: settings.manualLongitude,
            name: settings.manualLocationName,
            isLive: false)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(projects[index])
        }
        try? context.save()
    }
}

private struct ProjectRow: View {
    let project: ARProject

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(project.blockers.count) object\(project.blockers.count == 1 ? "" : "s") · Updated \(project.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var thumbnail: some View {
        #if canImport(UIKit)
        if let data = project.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.tint.opacity(0.15))
            .frame(width: 56, height: 56)
            .overlay(Image(systemName: "sun.max").foregroundStyle(.tint))
            .accessibilityHidden(true)
    }
}

#Preview {
    ProjectsView()
        .environmentObject(LocationService())
        .modelContainer(for: [ARProject.self, PlacedBlocker.self, AppSettings.self], inMemory: true)
}
