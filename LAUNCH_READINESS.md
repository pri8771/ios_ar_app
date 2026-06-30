# Umbra — Launch Readiness (v1)

> Umbra is a **local-first iOS AR sun & shade planner**. You point your iPhone at a
> space, the app detects a horizontal ground plane, you drop simple **proxy objects**
> (pole / box / wall / person / tree), then scrub the **date and time** to preview where
> their shadows fall throughout the day — driven by on-device NOAA/Meeus solar math.
> It is **honest by design**: Umbra does **not** reconstruct real-world geometry; it
> projects physically plausible shadows from the proxies *you* place and labels every
> result **approximate**. Primary user: homeowners and outdoor-space planners deciding
> "where will the shade be at 4pm?" for patios, gardens, and solar/planting decisions.
>
> **Implementation maturity: working SwiftUI app + unit tests (near launch; one hardware gate remains).**
> The repo contains a real Xcode project (~30 Swift source files) with a complete MVVM
> architecture, ARKit/RealityKit device path, a fully-functional simulator/preview ("mock")
> path, SwiftData persistence, foreground CoreLocation, share/export, and 5 XCTest suites
> (solar math, shadow geometry, the lens view model, and SwiftData persistence). The core
> loop runs end-to-end **in the preview path today**; the on-device AR path is implemented
> but **unverified on hardware**, which is now the single dominant launch risk.
>
> **Update (2026-06-30 iteration).** All submission and truth-debt blockers are cleared:
> a designed app icon is in place (BLK-2), a `PrivacyInfo.xcprivacy` manifest declares no
> tracking / no collection (BLK-5), the app is now **truly offline** — reverse-geocoding was
> removed so there are no network calls of any kind (BLK-3) — and the privacy policy, terms,
> README, and marketing copy were reconciled to the shipped app, dropping "accurate"/Premium
> claims (BLK-4, BLK-6). The lens gained an honest stamped export, a height slider, a
> "re-detect ground" affordance, a first-use location nudge, haptics, and a cohesive brand
> design system; shadow legibility was tuned for outdoor light. CI (GitHub Actions) builds and
> tests on every push. **The only remaining launch gate is BLK-1: on-device AR validation on
> real hardware**, which cannot be done from source alone.

---

## 1. PRD / Launch Scope

### Problem & insight
People constantly make outdoor decisions that hinge on shade — where to put a patio
table, a vegetable bed, a sun lounger, a solar panel — and get it wrong because shadows
move through the day and across seasons. Existing tools are either professional CAD/solar
software (overkill, expensive, requires a site model) or generic AR toys that don't
answer the question. The insight: you don't need a millimetre-accurate 3D reconstruction
to plan shade. A correct sun position (which is pure math) plus a few **user-placed proxy
shapes** projected onto a detected ground plane is enough to answer "is this spot in shade
at 4pm in July?" — provided the app is honest that it's an approximation.

### Target user
- **Primary:** Homeowners / renters (≈30–65) planning gardens, patios, decks, furniture,
  awnings, or panel placement. They want a quick, private, on-the-spot answer, not a survey.
- **Secondary:** Landscape designers / contractors using it for fast on-site client
  illustration ("here's roughly where afternoon shade lands"), and AR-curious users.

### Value proposition
*See where the shade will be — at any date and time, anywhere — without uploading
anything, in under a minute.*

### Positioning / category & pitch
Utility / Lifestyle (with AR/Photography keywords). One-sentence pitch:
**"Umbra is a private, on-device AR planner that shows where shadows will fall throughout
the day, using real solar math and the simple objects you place."**

### Platform & tech baseline (verified against the repo)
- **iOS 17.0+** (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`), Swift 5, portrait iPhone (also
  builds for iPad family `1,2`). Bundle id `com.localfirst.umbra`, version 1.0 (1).
- **SwiftUI** app lifecycle (`UmbraApp.swift`), **SwiftData** local store (`ARProject`,
  `PlacedBlocker`, `AppSettings`), **ARKit + RealityKit** device path
  (`ARWorldTrackingConfiguration`, `.gravityAndHeading`, horizontal plane detection),
  **CoreLocation** foreground-only wrapper, **Swift Charts-free** custom Canvas charts.
- **No third-party packages**; project generated from source via
  `scripts/generate_project.py` (objectVersion 56, Xcode 15).
- AR types compiled only off-simulator (`#if canImport(ARKit) && !targetEnvironment(simulator)`);
  a top-down 2D **mock scene** (`MockSceneView`) provides the same planning loop on
  simulator / non-AR devices using the identical shadow math.

### Business model (only what the repo supports)
- **Free, fully-functional** v1. There is **no StoreKit, no IAP, no paywall** in the
  codebase. `MARKETING_PLAN.md` describes a hypothetical future "Premium ($4.99/mo)" tier
  — that is aspirational copy, **not built**, and must not be implied at launch.
- No backend, accounts, ads, analytics, or subscriptions. Operating cost ≈ Apple developer
  program fee only.

### North-star / success signals (privacy-respecting, beta-observable)
The app collects **no telemetry by design**, so success must be measured out-of-band:
- **Activation:** % of beta testers who complete onboarding → create a plan → place ≥1
  object → scrub time → export, in one session (self-reported / TestFlight feedback).
- **Field-trust signal (the key one):** with the device at a real outdoor scene at the
  current time, does the projected shadow visually match the real one? (manual go/no-go).
- **Retention proxy:** testers who return to a saved plan on a second day.
- App Store rating ≥ 4.5 and crash-free sessions ≥ 99% as guardrails.

---

## 2. MVP Feature List (with acceptance criteria)

> Status legend — **Built**: implemented and exercised in code (and/or tests).
> **Partial**: implemented but with a real gap or unverified on hardware.
> **Not built**: described somewhere but absent from the code.

### F1. Onboarding that sets the "approximate" expectation — **Built**
Three-page onboarding (`OnboardingView.swift`): Point & Plan, "Approximate by design",
"Private & on-device", with an optional Location request and Skip/Get Started.
- **Given** a fresh install, **when** the app launches, **then** `RootView` shows
  `OnboardingView` (because `AppSettings.hasCompletedOnboarding == false`).
- Page 2 explicitly states Umbra "does not reconstruct the real world — results are an
  approximation." (verifiable string in `OnboardingView.pages`).
- The final page exposes **Allow Location (optional)** calling
  `locationService.requestAuthorization()` and a **Get Started** button that calls
  `onFinish`, which sets `hasCompletedOnboarding = true` and persists it.
- **Skip** is available on non-final pages and also finishes onboarding.
- Onboarding does not reappear on next launch (persisted flag).
- Accessibility: each page combines title+body into one VoiceOver element.

### F2. Local project library (create / open / delete) — **Built**
`ProjectsView.swift` lists `ARProject`s sorted by `updatedAt` desc, with empty-state,
thumbnails, swipe-to-delete, and a footer stating data is on-device.
- **Given** no projects, **then** an empty state with "Create First Plan" is shown.
- **When** the user taps **New Plan / +**, **then** a project is created seeded with the
  current resolved location (device fix if authorized + enabled, else manual fallback) and
  opened full-screen in the lens.
- **When** the user swipes a row and deletes, **then** the project (and via cascade its
  blockers) is removed and persisted.
- Each row shows name, object count, and relative "Updated …" time.

### F3. AR ground-plane detection & object placement (device) — **Partial**
`ARSceneController.swift` runs `ARWorldTrackingConfiguration` (`.gravityAndHeading`,
horizontal plane detection); tap raycasts to existing/estimated plane geometry and places
the selected proxy relative to a scene-origin anchor.
- **Given** a supported device, **when** AR starts, **then** a `gravityAndHeading` session
  runs and the first horizontal `ARPlaneAnchor` sets `hasPlaneAnchor = true` and publishes
  `planeHeight`.
- **When** the user taps a detected surface, **then** a raycast hit converts to
  origin-relative coordinates and `onPlaneTap` adds a blocker of `selectedKind`.
- Tracking states (initializing / limited+reason / interrupted / failed / normal) surface
  on-screen guidance (`trackingOverlay`); interruption end re-runs the session.
- **Gap (why Partial):** none of this is verified on real hardware in this repo — no
  device test evidence, no captured screenshots. Plane reliability, drift, and shadow
  legibility in bright sun are unproven. This is the #1 launch risk (see §7 BLK-1).

### F4. Top-down preview / mock planner (simulator & non-AR devices) — **Built**
`MockSceneView.swift` renders a 2D top-down plan (grid, north label, blocker footprints,
projected shadow polygons, sun-azimuth marker) using the **same** `ShadowGeometryService`,
and supports tap-to-place. `ARLensView` routes to it whenever world tracking is
unavailable.
- **Given** the simulator or a non-AR device, **then** the lens shows the mock scene with a
  "Preview mode" badge.
- **When** the user taps the canvas, **then** an object is placed at the mapped world XZ.
- Shadows, sun marker, and selection highlight update live as time/objects change.
- A VoiceOver "Add object at center" action exists for the canvas.

### F5. Proxy object palette (pole / box / wall / person / tree) — **Built**
`BlockerKind` enum + `ObjectPaletteView.swift`; each kind has a default real-world size and
SF Symbol; selection drives the next placement.
- All five kinds are selectable with clear selected state and accessibility labels.
- Selecting a kind sets `viewModel.selectedKind`; the next placement uses
  `kind.defaultSize` (e.g. pole 0.08×2.5×0.08 m, wall 2.0×1.8×0.15 m).
- A selected object can be **rotated** (`rotate.right`, +π/8) and **removed**; height edit
  API exists (`setHeightForSelected`) though no slider is wired in the lens UI yet.

### F6. Local solar position math (NOAA/Meeus) — **Built (well-tested)**
`SunPositionService` / `SunMath` computes azimuth (CW from true north) + elevation (with
atmospheric refraction) from date/lat/lon; `SolarDayService` derives sunrise / solar noon /
sunset, day length, polar day/night, and samples the sun path.
- **Given** 2000-01-01 12:00 UTC, **then** Julian Day == 2451545.0 (tested).
- 40°N summer-solstice noon elevation ≈ 73.4° and winter ≈ 26.6° (tested ±2°).
- Noon azimuth ≈ 180° (due south) at 40°N (tested ±3°); morning sun is easterly.
- Refraction is positive near the horizon and ≈ 0.48° at the geometric horizon (tested).
- Polar day/night handled: arctic summer → no sunrise/sunset, max elevation > 0; arctic
  winter → max elevation < 0 (tested).
- World-direction vector is unit length and matches ARKit's east/up/south frame (tested).

### F7. Shadow projection geometry — **Built (well-tested)**
`ShadowGeometryService` projects a blocker's 8 bounding-box corners along the light
direction onto the plane, then takes the **convex hull** (`Geometry.convexHull`, monotone
chain) to form a flat shadow polygon; area via shoelace.
- **When** the sun is below the horizon, **then** the shadow is empty (tested).
- Overhead sun → shadow ≈ footprint (0.25 m² for a 0.5 m box, tested).
- South sun at 45° → a 2.5 m pole casts a ~2.5 m shadow to the north (tested ±0.1 m).
- Lower sun → longer shadow; east sun → shadow extends west (tested).
- Convex hull discards interior/collinear/duplicate points; area is correct (tested).

### F8. Time & date scrubber with live recompute — **Built**
`TimeScrubberView.swift` + `ARLensViewModel`: a date picker and a 0–24h slider (5-minute
steps) re-run the full solar + shadow recompute; sunrise/sunset (or polar) markers shown.
- **When** the slider moves, **then** `setTimeOfDay(hours:)` updates `previewDate` and
  `recompute()` refreshes sun position, solar day, sun path, and all shadows.
- Times are formatted in the project's stored time zone.
- Sun status text reports elevation/azimuth or "below the horizon / polar night".

### F9. Sun-path overlay chart — **Built**
`SunPathView.swift` draws elevation-vs-azimuth across the day on a SwiftUI `Canvas` with a
horizon line, cardinal labels, the day curve, and a current-instant marker. Toggleable via
Settings (`showSunPath`).
- Daytime samples (elevation > −2°) form the curve; the current marker tracks the scrubber.
- Has a VoiceOver label/value reporting current elevation & azimuth.

### F10. Persistent "approximate" trust copy (onboarding + results) — **Built**
Beyond onboarding (F1), the lens shows a persistent yellow **"Approximate — projected from
your placed objects"** banner (`approximateBanner`) and an **About Accuracy**
(`ApproximationInfoView`) sheet enumerating what the app does **not** do; reachable from the
lens menu and Settings.
- The banner is visible on the results screen at all times and opens the accuracy sheet.
- The accuracy sheet lists: no real-geometry reconstruction, no soft edges/reflected
  light/clouds, no terrain elevation beyond the flat plane.

### F11. Foreground location with manual fallback — **Partial**
`LocationService.swift` is a foreground-only (`requestWhenInUseAuthorization`) CoreLocation
wrapper; `SettingsView` exposes a "Use device location" toggle, live status, an Open-Settings
deep link on denial, and editable manual lat/lon/name (clamped).
- **Given** authorization, **then** the resolved location feeds the solar math; **given**
  denial/opt-out, **then** the manual fallback (default San Francisco) is used.
- **Gap (why Partial):** the service also calls `CLGeocoder.reverseGeocodeLocation` to show a
  place name — that **is a network request** to Apple's geocoding service. This contradicts
  the app's "no network requests anywhere" claim in README/Settings/Privacy Policy. Must be
  reconciled (disclose, or gate/remove) before launch — see §7 BLK-3.

### F12. Snapshot share / export — **Built**
`ARLensView.exportSnapshot()` captures the AR frame on device (`arView.snapshot`) or renders
the mock scene via `SnapshotRenderer` (`ImageRenderer`) in preview mode, presents the system
`ShareSheet` (`UIActivityViewController`), and persists a JPEG thumbnail on the project.
- **When** "Share Snapshot" is tapped, **then** an image is produced and the system share
  sheet appears; the app performs no upload itself.
- The captured image is stored as the project thumbnail (`thumbnailData`, external storage).
- **Note:** the shared image does **not** currently burn in the "approximate" label or the
  date/time/location stamp the conversation called for — see §7 NB-2.

### F13. Settings & privacy posture surface — **Built**
`SettingsView.swift`: location source + manual fallback, shadow opacity, sun-path toggle,
a Privacy section ("no account/cloud/analytics", "stored on device", "no network requests"),
version, and a link to the accuracy explainer.
- Toggles persist immediately to the single `AppSettings` row.
- **Note:** the "No network requests" claim is currently inaccurate due to F11 geocoding.

### F14. Resilient local persistence — **Built**
`UmbraApp` opens an on-device SwiftData store and **falls back to in-memory** if the store
fails to open, so launch never crashes on a migration/store error.
- **Given** a store-open failure, **then** the app still launches (in-memory) rather than
  crashing.
- All models are local; no CloudKit/sync configured.

### F15. Monetization / Premium tier — **Not built**
Described in `MARKETING_PLAN.md` only. No StoreKit configuration, products, or paywall in
the repo. v1 ships free; see §3.

---

## 3. Out of Scope (v1 non-goals)

1. **Real-world geometry reconstruction** — no scene mesh, LiDAR depth, building/terrain
   capture, or occlusion by real objects. This is the core honesty guarantee, not a TODO.
2. **Surveying / engineering-grade accuracy** — explicitly disclaimed; not for critical
   construction or solar-array sizing decisions (`TERMS_OF_SERVICE` §4).
3. **Soft shadows / penumbra, reflected light, cloud cover, atmospheric haze** — shadows are
   hard-edged convex polygons.
4. **Sloped/uneven terrain** — a single flat detected plane only.
5. **Accounts, cloud sync, sharing back-end, multi-device** — local-first; nothing leaves
   the device except a user-initiated share-sheet image and (currently) reverse-geocoding.
6. **Analytics / crash reporting / ads / third-party SDKs** — none.
7. **Background location / Always authorization** — foreground "when in use" only.
8. **In-app purchases / subscriptions / "Premium"** — not built; marketing copy is aspirational.
9. **Android / web / macOS** — iPhone-first (iPad layout allowed but not a v1 target).
10. **Object height slider / freeform resize / drag-to-move in the lens** — rotation + remove
    are wired; height-edit API exists but is not surfaced; drag-move is not implemented.
11. **Multiple ground planes / wall (vertical) surfaces** — horizontal plane only.

---

## 4. User Flows

### 4.1 First run / onboarding
1. Launch → `RootView` sees `hasCompletedOnboarding == false` → shows `OnboardingView`.
2. Page 1 **Point & Plan** → Next.
3. Page 2 **Approximate by design** (sets expectations) → Next.
4. Page 3 **Private & on-device** → tap **Allow Location (optional)** (triggers the system
   when-in-use prompt) or skip it → tap **Get Started**.
5. `onFinish` persists `hasCompletedOnboarding = true`; app shows `ProjectsView`.

### 4.2 Core loop (plan shade)
1. In `ProjectsView`, tap **+ New Plan** (or "Create First Plan") → an `ARProject` is created
   with the resolved location and opened full-screen in `ARLensView`.
2. **Scene layer** appears: on a supported device, the live `ARContainerView`; otherwise the
   `MockSceneView` top-down preview with a "Preview mode" badge.
3. (Device) Move the phone slowly until the ground plane is detected; guidance overlays coach
   tracking. (Preview) the simulated ground is immediately ready.
4. Pick an object in the **palette** (F5), then **tap** the surface/canvas to place it.
5. Drag the **time slider** / change the **date** → sun position and all shadows recompute
   live; the **sun-path** chart and sunrise/sunset markers update.
6. Optionally select an object to **rotate** or **remove**; the persistent **Approximate**
   banner and **About Accuracy** sheet are available throughout.
7. Leaving the screen (`onDisappear` / back) **persists** blockers, plane height, location,
   time zone, and preview date into the `ARProject`.

### 4.3 Settings / privacy
1. `ProjectsView` toolbar gear → `SettingsView` sheet.
2. Toggle **Use device location**; on denial, an **Open Settings** deep link and a manual
   lat/lon/name editor appear.
3. Adjust **shadow opacity** and **sun-path** visibility (persist immediately).
4. Privacy section states the local-first posture; **How accuracy works** opens the explainer.

### 4.4 Share / export
1. In the lens, **⋯ → Share Snapshot**.
2. Device: the AR frame is snapshotted; Preview: the top-down plan is rendered to an image.
3. The system **share sheet** appears; the image is also saved as the project thumbnail.

---

## 5. Acceptance Criteria Summary

| ID | Feature | Status | Launch pass/fail gate |
|----|---------|--------|-----------------------|
| F1 | Onboarding + approximate expectation | Built | Onboarding shows once, sets flag, includes "approximate" + privacy pages |
| F2 | Local project library | Built | Create/open/delete persists; empty state present |
| F3 | AR plane detect + placement (device) | Partial | **Must verify on hardware**: plane detect, tap-place, tracking guidance, drift acceptable |
| F4 | Mock/preview planner | Built | Full loop usable on simulator & non-AR devices |
| F5 | Proxy palette | Built | 5 kinds selectable; place/rotate/remove work |
| F6 | Solar math | Built | All `SunPositionServiceTests`/`SolarDayServiceTests` green |
| F7 | Shadow geometry | Built | All `ShadowGeometryServiceTests` green |
| F8 | Time/date scrubber | Built | Scrub re-runs math live; tz-correct times |
| F9 | Sun-path chart | Built | Curve + current marker + a11y value render |
| F10 | Persistent trust copy | Built | Banner on results + accuracy sheet reachable |
| F11 | Foreground location + manual fallback | Partial | **Reconcile geocoding vs "no network" claim**; fallback works |
| F12 | Snapshot share/export | Built | Image produced (device + mock), share sheet shows |
| F13 | Settings/privacy surface | Built | Toggles persist; copy accurate after F11 fix |
| F14 | Resilient persistence | Built | Store-open failure → in-memory, no crash |
| F15 | Monetization/Premium | Not built | Out of scope for v1; remove from store-facing copy |

**Launch gate:** all **Built** rows green + F3 verified on ≥2 real devices + F11 network/privacy
reconciliation + the §9 store/privacy/content items. F15 is intentionally not a gate.

---

## 6. Known Limitations

- **Approximate by design.** Shadows come from user-placed proxies, not the real scene; the
  result is a "plausible projection, not a survey." Surfaced in onboarding, a persistent
  banner, and the About-Accuracy sheet.
- **AR reliability is device- and environment-dependent.** Plane detection needs texture and
  light; bright direct sun (the app's prime use case) can wash out feature tracking and make
  a dark shadow overlay hard to read. Unproven in this repo.
- **Flat ground plane only.** No slopes, steps, or multiple planes; the first horizontal
  plane wins (`planeAnchor` is set once and not user-reselectable).
- **Hard-edged shadows.** No penumbra, ambient/reflected light, or cloud cover.
- **Object model is coarse.** Boxes/cylinders with default sizes; height-edit API exists but
  isn't surfaced; no free move/resize/drag in the lens (rotate + delete only).
- **Reverse geocoding touches the network.** `CLGeocoder` resolves a place name online,
  contradicting the "no network" copy until reconciled.
- **Manual-location default is San Francisco** — if a user denies location and never edits it,
  shadows are computed for SF, which can be silently wrong. Needs a clearer prompt.
- **Single shared time zone per project.** Reopening uses the stored tz; changing device tz
  doesn't migrate existing projects.
- **No haptics, no export label burn-in, no localization** (English only; `SWIFT_EMIT_LOC_STRINGS`
  is on but no `.strings`).
- **App icon is a placeholder** (1024 slot defined, no image) and there is **no privacy
  manifest** — both block App Store submission.

---

## 7. Bug & Risk Triage

### Launch-blocking (must fix before TestFlight / App Store)

- **BLK-1 — On-device AR is unverified (reliability + legibility).**
  Where: `Umbra/AR/ARSceneController.swift`, `ARContainerView.swift`, `ARLensView.swift`.
  Why blocking: the entire device value prop (F3) has zero hardware evidence in the repo.
  Plane detection, tracking drift moving the shadow, and a black shadow overlay being
  illegible in bright outdoor sun are exactly the failure modes that break user trust.
  Must run the patio/balcony field matrix (lighting × surface × time) with the
  **projected-vs-real-shadow-at-current-time** go/no-go check before beta.

- **BLK-2 — Missing app icon image.**
  Where: `Umbra/Assets.xcassets/AppIcon.appiconset/Contents.json` declares a 1024×1024
  universal slot but **no PNG is present**. App Store / TestFlight upload will be rejected
  (and the icon column is empty). Add the icon asset before any submission.

- **BLK-3 — "No network requests" claim is false (privacy accuracy).**
  Where: `Umbra/Services/LocationService.swift` calls `CLGeocoder.reverseGeocodeLocation`
  (a network call) while `README.md`, `SettingsView` ("No network requests"), and
  `PRIVACY_POLICY.md` assert no network usage. App Review and users can catch this.
  Fix: either (a) remove/disable reverse geocoding and use coordinates/manual name only, or
  (b) keep it and accurately disclose the one online lookup everywhere. Pick one; align all copy.

- **BLK-4 — Privacy Policy contradicts the actual app.**
  Where: `PRIVACY_POLICY.md` states "Location — **NOT collected or used**" and "Sun
  calculations use your manual date/time input, not location services" and "runs completely
  offline." The app **does** use foreground CoreLocation and (currently) online geocoding,
  and computes from location. A materially wrong privacy policy is an App Store and legal
  risk. Rewrite to match reality (foreground location used on-device for solar math; geocoding
  per BLK-3 decision). Also fix the stale repo URL `github.com/pri8771/ios_ar_app`.

- **BLK-5 — Missing `PrivacyInfo.xcprivacy` privacy manifest.**
  Where: repo root / app target (absent). Apple requires a privacy manifest declaring data
  use and any "required-reason" APIs. The app should declare **no tracking, no data
  collection**, and any required-reason API usage (e.g. file timestamp / UserDefaults if
  used by frameworks). Add before submission.

- **BLK-6 — Store-facing copy implies precision/Premium the app doesn't deliver.**
  Where: `MARKETING_PLAN.md` ("Real physics: **Accurate** sun position", "Premium $4.99/mo",
  ASO subtitle) and the App Store description draft. v1 has no IAP and is explicitly
  *approximate*. Ship copy must drop "accurate," drop Premium, and lead with the honest
  approximate framing to avoid 2.3.x (accurate-metadata) review issues and 1-star "it's not
  precise" reviews.

### Non-blocking (ship-with, fix in a fast-follow)

- **NB-1 — Default manual location is silently San Francisco.**
  `AppSettings.manualLatitude/Longitude`. If location is denied and never edited, results are
  wrong without warning. Add a first-use "set your location" nudge when no fix and default
  is unchanged. Defer because the planner still functions.

- **NB-2 — Exported snapshot lacks the "approximate" + date/time/location stamp.**
  `ARLensView.exportSnapshot()`. The conversation called for a stamped, labelled export so a
  shared "4pm shade" image stays honest out of context. Add an overlay before sharing.

- **NB-3 — `TERMS_OF_SERVICE.md` is malformed and has the stale URL.**
  Sections 3–10 render as a broken nested bullet list; contact URL is `ios_ar_app`.
  Cosmetic/legibility, not a launch gate, but should be cleaned up.

- **NB-4 — Height-edit API is dead UI.**
  `ARLensViewModel.setHeightForSelected(_:)` exists but no control invokes it. Either surface
  a height slider or remove the unused path.

- **NB-5 — Plane anchor is chosen once and not reselectable.**
  `ARSceneController.didAdd` locks the first horizontal plane. If the user wants a different
  surface, there's no reset. Add a "re-detect ground" affordance later.

- **NB-6 — No `UIRequiredDeviceCapabilities`/explicit AR gating in Info.plist.**
  Intentional (graceful degradation to preview), but document it so reviewers/users
  understand the app works on non-AR devices in preview mode; consider an App Store note.

- **NB-7 — `manualLocation` text fields use `.numbersAndPunctuation` keyboard.**
  `SettingsView.keyboardTypeDecimalIfAvailable()` isn't a true decimal pad; minor UX polish.

---

## 8. Production-Readiness Assessment

### Current estimated readiness: **~85%**
Justification: the architecture is complete and clean, the math is correct and **unit-tested**
(56 tests across 5 suites, now including the lens view model and SwiftData persistence), and the
**planning loop runs end-to-end today in the preview path** (place → scrub → see shadows →
stamped export → persist). As of the 2026-06-30 iteration, every submission blocker and all
truth/copy debt is resolved: app icon (BLK-2), privacy manifest (BLK-5), a genuinely
**offline** app with no network calls (BLK-3), and privacy/terms/README/marketing reconciled to
the shipped app (BLK-4, BLK-6). Fast-follow polish landed too: stamped export (NB-2), height
slider (NB-4), re-detect ground (NB-5), location nudge (NB-1), haptics, a brand design system,
outdoor shadow-legibility tuning, and CI. The remaining ~15% is essentially **one gate**: the
on-device AR path (BLK-1) is implemented but **unverified on real hardware** — plane reliability,
tracking drift, and shadow legibility in bright sun must be confirmed on ≥2 devices before
TestFlight. That verification (not more code) is what stands between this and ~95% launch-ready.

### Ordered checklist to reach 80–90% production-ready
1. **Run the on-device AR validation matrix (BLK-1).** Patio/balcony first; lighting
   (bright/overcast/golden) × surface (textured/plain/grass) × time. Gate on
   projected-vs-real-shadow agreement at the current time. Capture screenshots/video.
2. **Improve shadow legibility in bright sun** if BLK-1 fails: outline/contrast/opacity-by-elevation
   tuning so the overlay reads outdoors.
3. **Reconcile network/privacy (BLK-3, BLK-4):** decide on geocoding; rewrite `PRIVACY_POLICY.md`
   to match the app; fix the `ios_ar_app` URLs; align `SettingsView` "no network" copy.
4. **Add the app icon** (BLK-2) and **`PrivacyInfo.xcprivacy`** (BLK-5: no tracking, no
   collection, required-reason APIs as applicable).
5. **Fix store-facing copy (BLK-6):** drop "accurate," drop Premium, lead with "approximate";
   align `MARKETING_PLAN.md` and the App Store description/keywords.
6. **Stamp exports (NB-2)** with date/time/location + "Approximate — Umbra" label.
7. **First-use location nudge (NB-1)** when no fix and default is unchanged.
8. **Clean up `TERMS_OF_SERVICE.md` (NB-3)**; decide on height slider vs removing the dead API (NB-4).
9. **Add UI/integration tests** for onboarding→library→lens→place→scrub→export and a
   persistence round-trip; smoke-build for device + simulator destinations in CI.
10. **Manual QA pass:** device sizes, Dynamic Type, VoiceOver, dark mode, permission-denied
    path, polar-latitude edge cases, store reopen.

### Test coverage summary
- **Covered (unit, XCTest):** the math core — `SunPositionServiceTests` (Julian-day anchors
  incl. Meeus 7.b, elevation/azimuth across seasons, refraction, world-direction vector),
  `SolarDayServiceTests` (sunrise/noon/sunset ordering, day length, polar day/night, sun-path
  sampling), `ShadowGeometryServiceTests` (ground projection, convex hull/area, end-to-end
  shadow polygons for known geometries). This is the riskiest logic and it's solid.
- **Not covered:** all UI/SwiftUI views, `ARLensViewModel` state transitions, SwiftData
  persistence round-trips, `LocationService` authorization/geocoding behavior, the AR
  controller (raycast, tracking states, mesh sync), and the share/snapshot pipeline. **No CI
  workflow** is present. No on-device test evidence.

---

## 9. Launch Checklist (Umbra-specific)

**App Store / build**
- [x] **BLK-2** 1024×1024 **AppIcon** added (`Umbra/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`,
      generated reproducibly by `scripts/make_icon.py`).
- [x] `Umbra.xcodeproj` builds & **56 tests pass** on the iOS 17+ simulator; project re-generated
      via `scripts/generate_project.py`. (Real-device destination still to be run as part of BLK-1.)
- [ ] App Store Connect record: name "Umbra", subtitle (no "accurate"), category Utilities
      (secondary Lifestyle/Photography), 5 screenshots + the 30s preview from real device AR. *(off-repo)*
- [ ] **Age rating 4+**; no UGC, no objectionable content. *(off-repo, set in App Store Connect)*

**Privacy**
- [x] **BLK-5** `PrivacyInfo.xcprivacy` added: `NSPrivacyTracking=false`, empty tracking domains,
      **no collected data types**, no required-reason APIs used. Bundled in the app target.
- [x] **BLK-4** `PRIVACY_POLICY.md` rewritten to match the app (foreground location used on-device
      for solar math; no network); `ios_ar_app` URL fixed.
- [ ] App Privacy "nutrition label" in App Store Connect: **Data Not Collected** (now fully accurate —
      no geocoding, no network). *(off-repo)*
- [x] `NSCameraUsageDescription` and `NSLocationWhenInUseUsageDescription` strings read accurately.

**Safety / content / accuracy**
- [x] **BLK-6** Marketing/description: removed "accurate," removed "Premium," lead with the
      **approximate** framing; metadata matches the shipped (free) app.
- [x] In-app **"approximate"** banner + About-Accuracy copy present (F10); `TERMS_OF_SERVICE` §4
      disclaimer intact and well-formed (NB-3 resolved).
- [x] **BLK-3** Resolved: reverse-geocoding removed; the app makes **no network requests** and all
      "no network / works offline" copy is now true.

**Functional gate**
- [ ] **BLK-1** On-device AR validation matrix on ≥2 devices; shadow legible in bright sun;
      projected ≈ real shadow at current time. *(the one remaining gate — needs hardware; shadow
      overlay already tuned toward a deep-indigo tint + warm rim for outdoor legibility.)*
- [x] Permission-denied path implemented (manual location + Open-Settings deep link + first-use
      nudge); verified in the preview path. *(re-confirm on device under BLK-1.)*
- [x] Persistence round-trip **unit-tested** (`ARLensViewModelTests.testPersistRoundTrip`).

**Nice-to-have before 1.0 (non-gating)**
- [x] NB-1 location nudge · NB-2 stamped export · NB-4 height slider · NB-5 re-detect ground ·
      haptics · brand design system · CI smoke build — all landed.
