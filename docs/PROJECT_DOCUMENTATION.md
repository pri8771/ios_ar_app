# Umbra — Project Documentation

_Updated 2026-06-30 to match the shipped product and launch scope. See LAUNCH_READINESS.md._

GitHub is the source of truth for this project documentation. Notion indexes this file in
the Priyansh App Factory Command Center.

> **Correction note.** Earlier versions of this document described Umbra as a generic
> "visual camera app" with a "signature effect," capture/gallery, and effect packs. That
> was a stale template and did **not** describe this repo. Umbra is an **AR sun & shade
> planner**. This document has been rewritten to match the actual code; the canonical,
> reviewer-grade scope lives in [`LAUNCH_READINESS.md`](../LAUNCH_READINESS.md).

## 00. Executive Summary
Umbra is a **local-first iOS AR sun & shade planner**. The user points the iPhone at a
space, the app detects a horizontal ground plane, the user drops simple **proxy objects**
(pole / box / wall / person / tree), then scrubs the **date and time** to preview where
shadows fall — using on-device NOAA/Meeus solar math. It is **honest by design**: it does
not reconstruct real-world geometry; it projects physically plausible shadows from the
proxies the user places and labels every result **approximate**. Built with SwiftUI,
ARKit/RealityKit, SwiftData, and foreground CoreLocation, with a simulator/preview ("mock")
top-down mode so the planner is fully usable without a device. The end product includes
onboarding, a local project library, the AR/preview lens, the time scrubber, a sun-path
chart, snapshot share/export, and settings — all on-device, no backend, no accounts.

## 01. Product
**MVP scope:** onboarding (incl. the "approximate" expectation), local project library,
AR plane detection + proxy placement (device) / top-down preview (simulator & non-AR),
proxy palette, local solar math, shadow projection, time/date scrubber, sun-path chart,
persistent "approximate" trust copy, foreground location with manual fallback, snapshot
share, and settings. **Acceptance:** the app launches, onboarding sets expectations clearly,
and a user can create a plan and preview shade for a chosen time in under 60 seconds (full
loop verified in the preview path; on-device AR pending hardware validation). See
`LAUNCH_READINESS.md` §2 for per-feature acceptance criteria and Built/Partial/Not-built status.

## 02. Design
Practical, trustworthy, native-feeling. Dark lens UI with glass (`.ultraThinMaterial`)
controls; a persistent yellow **"Approximate — projected from your placed objects"** banner;
clear first-run onboarding. Screens: Onboarding, Projects library, AR/Preview Lens (with
time scrubber, object palette, sun-path overlay), About Accuracy, Settings. Honesty is a
design primitive: the approximation is stated at the point of decision, not buried.

## 03. Frontend Technical
**SwiftUI + MVVM + stateless services.** Views are thin; logic lives in `ARLensViewModel`
and pure services. `RootView` gates onboarding vs library. The AR path
(`ARSceneController` / `ARContainerView` via `UIViewRepresentable`) compiles only off
simulator; `MockSceneView` provides the identical planning loop everywhere else using the
same `ShadowGeometryService`. Navigation: Onboarding → Projects → Lens (full-screen) →
Settings (sheet). Persistence is local SwiftData (`ARProject`, `PlacedBlocker`, `AppSettings`).

## 04. Backend Technical
**No backend.** No accounts, no cloud sync, no analytics, no ads, no third-party packages.
The only outbound network touch today is `CLGeocoder` reverse-geocoding to display a place
name; this must be reconciled with the app's "no network" messaging before launch (see
`LAUNCH_READINESS.md` §7 BLK-3). Future *optional* services are explicitly out of v1 scope.

## 05. Business
**Free, fully-functional v1.** There is **no StoreKit / IAP / paywall** in the code. A
hypothetical "Premium" tier appears only in `MARKETING_PLAN.md` and is **not built**; it
must not be implied in store metadata for v1. Operating cost ≈ Apple developer fee.

## 06. Marketing
Positioning: a private, on-device AR planner that shows where shade lands throughout the
day. Lead with the **approximate, honest** framing and the local-first privacy posture.
Drop any "accurate"/"precise" language and any Premium implication from store-facing copy
(see `LAUNCH_READINESS.md` §7 BLK-6). Channels: home-improvement / iOS / AR communities,
short on-device demo clips, "Best New Apps" pitches.

## 07. User Acquisition
Beta with 25–50 homeowners / outdoor planners and AR-curious testers. Because the app
collects **no telemetry**, measure success out-of-band: onboarding→plan→place→scrub→export
activation, the field-trust check (projected vs real shadow at current time), second-day
return to a saved plan, and App Store rating/crash-free guardrails.

## 08. Execution
Plan: (1) reconcile docs to reality [this update]; (2) run the on-device AR validation
matrix (patio/balcony first); (3) clear submission blockers (app icon, privacy manifest);
(4) fix copy (network/privacy, "accurate", Premium); (5) add export stamp + first-use
location nudge; (6) QA + TestFlight. See `LAUNCH_READINESS.md` §8 for the ordered checklist.

## 09. QA
Unit tests cover the math core (solar position, solar day, shadow geometry). Not yet
covered: SwiftUI views, the view model, SwiftData round-trips, `LocationService`, the AR
controller, and the snapshot pipeline; **no CI** is configured. Manual QA must include
device sizes, Dynamic Type, VoiceOver, dark mode, permission-denied path, polar-latitude
edge cases, app relaunch/persistence, and — critically — **on-device AR** reliability and
shadow legibility in bright sun.

## 10. Legal / Compliance
Camera and **foreground (when-in-use) location** are used; both have usage strings in
`Info.plist`. Location is used on-device to compute the sun's position. `PRIVACY_POLICY.md`
and `TERMS_OF_SERVICE.md` exist but currently contain inaccuracies (a privacy policy that
says location is *not* used; a "completely offline" claim despite geocoding; a stale
`ios_ar_app` repo URL; malformed Terms markdown) — these are flagged as launch blockers /
fast-follows in `LAUNCH_READINESS.md` §7. A `PrivacyInfo.xcprivacy` manifest must be added
(no tracking, no data collection).

## 11. Operations
Release process: internal device build → small beta (TestFlight) → launch decision.
The Xcode project is generated from source via `scripts/generate_project.py` (re-run after
adding/removing files). Post-launch: device-AR polish, export stamping, optional height
controls; **no** server to operate.
