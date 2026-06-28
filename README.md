# Shadow Lens

[![CI](https://github.com/pri8771/ios_ar_app/actions/workflows/ci.yml/badge.svg)](https://github.com/pri8771/ios_ar_app/actions/workflows/ci.yml)

**Point your camera, drop a simple object, scrub the time, and see where shade will land.**

Shadow Lens is a **local-first** iOS AR sun & shade planner. Point your iPhone at
an outdoor or indoor space, detect a ground plane, place simple proxy objects
(pole / box / wall / person / tree), then scrub the date and time to preview
where shadows fall throughout the day.

> **Honest by design.** Shadow Lens does **not** reconstruct real-world
> geometry. It projects physically plausible shadows from the proxy objects
> *you* place onto a detected horizontal plane, and clearly labels every result
> as **approximate**.

## Privacy & local-first guarantees

- ✅ Fully on-device. **No backend, no accounts, no analytics, no cloud sync.**
- ✅ **No third-party packages** and **no network calls** anywhere.
- ✅ All projects are stored locally via **SwiftData**.
- ✅ Location is used **only in the foreground**, **only on-device**, to compute
  the sun's position. It is never stored off-device or transmitted.

## Requirements

- iOS **17.0+**
- Xcode **15+**
- AR features require a physical iPhone with ARKit world tracking.
  The app builds and runs in the **Simulator** using a top-down **preview
  (mock) mode** so the planner can be inspected without a device.

## Build & run

```bash
# Open in Xcode
open ShadowLens.xcodeproj

# Or build / test from the command line (simulator)
xcodebuild -scheme ShadowLens -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -scheme ShadowLens -destination 'platform=iOS Simulator,name=iPhone 15' test
```

The Xcode project is generated from the source tree by
[`scripts/generate_project.py`](scripts/generate_project.py). Re-run it after
adding or removing source files:

```bash
python3 scripts/generate_project.py
```

## Architecture

**MVVM + services.** SwiftUI views are thin; logic lives in view models and
stateless services. ARKit + RealityKit power the on-device AR experience.

```
ShadowLens/
├── App/                 ShadowLensApp – SwiftUI lifecycle + SwiftData container
├── Models/              SwiftData models (ARProject, PlacedBlocker, AppSettings)
├── Services/
│   ├── SunPositionService     NOAA/Meeus solar azimuth + elevation (+ refraction)
│   ├── SolarDayService        Sunrise / solar noon / sunset + sun-path sampling
│   ├── ShadowGeometryService  Projects blockers to a ground-plane shadow polygon
│   ├── LocationService        Foreground-only CoreLocation wrapper
│   └── ARSupport              AR capability detection / graceful fallback
├── AR/
│   ├── ARSceneController      ARView coordinator: tracking, raycast, rendering
│   ├── ARContainerView        UIViewRepresentable bridge (device only)
│   └── ShadowMeshFactory      Polygon → RealityKit mesh (device only)
├── ViewModels/          ARLensViewModel – working scene state + recompute
├── Views/               Onboarding, Projects library, AR lens, scrubber,
│                        sun-path, palette, settings, mock preview
└── Utilities/           Geometry (convex hull), styling, share sheet
```

### Solar math

`SunPositionService` implements the NOAA/Meeus algorithm locally with full
Julian-day calculations:

- Azimuth is measured **clockwise from true north** (0 = N, 90 = E, 180 = S).
- Elevation in degrees above the horizon, **including atmospheric refraction
  correction**.
- Verified anchor: `2000-01-01 12:00 UTC` → Julian Day `2451545.0`.

### Shadow geometry

`ShadowGeometryService` projects a blocker's bounding-box corners onto the
horizontal plane along the sun's light direction, then takes the **convex hull**
of the projected points to form a flat shadow polygon. On device this polygon is
triangulated into a RealityKit mesh; in the Simulator it is drawn top-down.

ARKit uses `ARWorldTrackingConfiguration` with **gravity-and-heading**
alignment (x = east, y = up, z = south). Blocker positions are stored relative
to a scene-origin anchor so projects reopen consistently.

## Graceful degradation

| Situation                         | Behavior                                                        |
|-----------------------------------|----------------------------------------------------------------|
| Running on Simulator              | Top-down **preview mode** with full planning + export          |
| Device without world tracking     | Falls back to preview mode with an explanation                 |
| Location permission denied        | Uses a manual location from Settings; offers a Settings deep-link |
| AR tracking limited / interrupted | On-screen guidance; auto-recovers on interruption end          |
| Persistence store fails to open   | Falls back to an in-memory store so launch never fails         |

## Accessibility

Dynamic Type throughout, VoiceOver labels/hints on interactive elements and the
charts, and full dark-mode support.

## Tests

Core math is covered by XCTest unit tests:

- `SunPositionServiceTests` – Julian day anchors, declination/elevation/azimuth,
  refraction, world-direction vector.
- `ShadowGeometryServiceTests` – ground projection, convex hull, end-to-end
  shadow polygons for known sun geometries.
- `SolarDayServiceTests` – sunrise/noon/sunset ordering, day length, polar
  day/night, sun-path sampling.

## Production readiness

- **App icon**: opaque 1024×1024 icon generated by
  [`scripts/generate_icon.py`](scripts/generate_icon.py) (no alpha — App Store
  compliant).
- **Launch screen**: branded background color (`LaunchBackground` color set).
- **Privacy manifest**: `PrivacyInfo.xcprivacy` declares no tracking and no data
  collection.
- **Export compliance**: `ITSAppUsesNonExemptEncryption = false` (no encryption
  beyond OS defaults), so App Store Connect won't prompt on every upload.
- **Permissions**: camera, when-in-use location, and photo-library-add usage
  descriptions are all present and explain the on-device-only use.
- **SwiftData migrations**: a `VersionedSchema` (`ShadowLensSchemaV1`) and
  `SchemaMigrationPlan` (`ShadowLensMigrationPlan`) are in place so the first
  schema change ships without wiping users' local projects.
- **Device family**: iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait.
- **CI**: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) builds and runs
  the unit tests on an iOS Simulator on `macos-latest` for every push/PR to
  `main`.

### Before submitting to the App Store

These require Apple developer account access and a Mac, so they are intentionally
left to the human submitter:

- Set the development team / signing certificate and a provisioning profile.
- Replace the generated placeholder icon with final brand artwork if desired.
- Capture App Store screenshots and write the store listing.
- Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` per release.

## Out of v1 scope (explicit limitations, not TODOs)

These are intentional simplifications, surfaced to the user in-app under
**About Accuracy**:

- No reconstruction of real buildings, terrain, or existing objects.
- Flat ground plane only (no modeling of sloped terrain beyond the detected plane).
- Hard-edged shadows; no penumbra, reflected light, or cloud cover.
