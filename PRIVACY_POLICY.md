# Umbra Privacy Policy

_Updated 2026-06-30 to match the shipped product and launch scope. See LAUNCH_READINESS.md._

**Effective Date:** June 2026
**Last Updated:** 2026-06-30

## Overview

Umbra is a local-first AR sun & shade planner. Your plans, object placements, and settings
are stored **only on your device**. Umbra has no account system, no analytics, no ads, and
no developer-operated backend, and we (the developer) never receive your data.

> **Correction note.** A previous version of this policy stated that location was "not
> collected or used" and that the app "runs completely offline." That was inaccurate. Umbra
> **does** use your device location (foreground only) to compute the sun's position, and it
> uses Apple's geocoding service to display a place name. This policy has been corrected to
> describe the app as it actually behaves.

## Data We Process

### Camera & AR data
- Camera access is required to show the live AR view where you place objects and preview shadows.
- Camera frames are processed **on-device only** by ARKit. They are **not** recorded, saved,
  or transmitted by Umbra.

### Location data (foreground only)
- With your permission, Umbra uses your device location **only while the app is open**
  ("When In Use") to compute the sun's position for your place and time.
- Your coordinates are used **on-device** for the solar math. Umbra does **not** upload your
  location to any developer server, and there is no account to attach it to.
- **Geocoding:** to show a friendly place name (e.g. "San Francisco, CA"), Umbra asks
  Apple's CoreLocation geocoding service to convert coordinates to a name. This request is
  handled by Apple under Apple's privacy terms; Umbra does not store or transmit it elsewhere.
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
cloud storage or sync. The only platform services used are Apple's on-device ARKit/CoreLocation
and Apple's geocoding lookup described above.

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
