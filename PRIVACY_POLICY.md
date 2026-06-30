# Umbra Privacy Policy

_Updated 2026-06-30 to match the shipped product and launch scope, including the decision to remove all network calls. See LAUNCH_READINESS.md._

**Effective Date:** June 2026
**Last Updated:** 2026-06-30

## Overview

Umbra is a local-first AR sun & shade planner. Your plans, object placements, and settings
are stored **only on your device**. Umbra has no account system, no analytics, no ads, and
no developer-operated backend, and we (the developer) never receive your data. Umbra makes
**no network requests of any kind** and works fully offline, even in airplane mode.

> **Correction note.** A previous version of this policy stated that location was "not
> collected or used." That was inaccurate: Umbra **does** use your device location
> (foreground only) to compute the sun's position **on-device**. This policy has been
> corrected to describe the app as it actually behaves. Note that your location is used
> purely for local solar math — it is never transmitted off the device.

## Data We Process

### Camera & AR data
- Camera access is required to show the live AR view where you place objects and preview shadows.
- Camera frames are processed **on-device only** by ARKit. They are **not** recorded, saved,
  or transmitted by Umbra.

### Location data (foreground only)
- With your permission, Umbra uses your device location **only while the app is open**
  ("When In Use") to compute the sun's position for your place and time.
- Your coordinates are used **on-device** for the solar math and are **never transmitted** —
  not to a developer server, not to Apple, not to anyone. There is no account to attach them
  to, and the app makes no network requests at all.
- The device's GPS fix is simply labelled "Current Location"; the app performs no online
  place-name lookup. If you enter a **manual location**, the name you provide is used.
- You can decline location entirely and enter a **manual location** instead; the app remains
  fully functional.

### Device motion data
- Used locally by ARKit for AR tracking and orientation. Processed on-device; not transmitted by Umbra.

### Your plans (user-created data)
- Projects, object placements, preview date/time, plane height, and an optional snapshot
  thumbnail are stored locally via SwiftData on your device.
- Nothing is synced to the cloud or shared with third parties by the app.

## Data Storage & Retention
- All data stays on your device. No account login, no cloud sync.
- Deleting a plan removes it (and its objects). Uninstalling Umbra removes all stored data.

## Sharing
- Sharing is **entirely user-initiated**: when you tap "Share Snapshot," iOS shows the system
  share sheet and you choose the destination. Umbra itself uploads nothing.

## Third-Party Services
Umbra does **not** use analytics (e.g. Google Analytics, Mixpanel), crash reporting (e.g.
Sentry, Firebase Crashlytics), advertising networks, social SDKs, or any developer-operated
cloud storage or sync. The only platform services used are Apple's **on-device**
ARKit/CoreLocation, which run entirely on your device. Umbra makes no network requests.

## Permissions
- **Camera** — to show the AR view and detect the ground plane. On-device only.
- **Location (When In Use)** — to compute the sun's position locally. Optional; a manual
  location can be used instead.

## Children's Privacy
Umbra does not knowingly collect personal information from children and has no account
system or developer backend.

## Changes to This Policy
We may update this policy. Continued use of Umbra constitutes acceptance of the updated policy.

## Questions?
For privacy questions, contact us via the GitHub repository:
https://github.com/pri8771/umbra-ios
