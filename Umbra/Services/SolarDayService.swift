//
//  SolarDayService.swift
//  Umbra
//
//  Computes daily solar events (sunrise, solar noon, sunset) and samples the
//  sun's path across a day for visualization. Pure, local, testable.
//

import Foundation

/// Summary of the solar day for a location, used to drive the sun-path UI and
/// the time scrubber's bounds.
struct SolarDay: Equatable {
    /// Local-civil start of the day this summary describes (00:00 local).
    let startOfDay: Date
    /// Sunrise instant, or nil if the sun never rises (polar night) for the day.
    let sunrise: Date?
    /// Solar noon (sun crosses the meridian) instant.
    let solarNoon: Date
    /// Sunset instant, or nil if the sun never sets (polar day) for the day.
    let sunset: Date?
    /// Maximum solar elevation reached during the day, in degrees.
    let maxElevation: Double
    /// True when the sun stays above the horizon the entire day.
    let isPolarDay: Bool
    /// True when the sun stays below the horizon the entire day.
    let isPolarNight: Bool
}

/// A single sampled point on the sun's path.
struct SunPathSample: Identifiable, Equatable {
    let id: Int
    let date: Date
    let position: SolarPosition
}

struct SolarDayService {

    private let sun = SunPositionService()

    // MARK: - Daily events

    /// Computes sunrise / solar noon / sunset for the civil day containing
    /// `date` at the given location and timezone.
    func solarDay(
        for date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> SolarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: date)

        // Use local noon of the civil day as the reference for the NOAA daily
        // formulas (declination/EoT vary slowly, so noon is a good anchor).
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var localNoonComps = comps
        localNoonComps.hour = 12
        let localNoon = calendar.date(from: localNoonComps) ?? date

        let jd = SunMath.julianDay(from: localNoon)
        let inter = SunMath.intermediate(julianDay: jd)
        let decRad = SunMath.rad(inter.declination)
        let latRad = SunMath.rad(latitude)

        // Hour angle for sunrise/sunset using 90.833° zenith (refraction + disk).
        let zenith = SunMath.rad(90.833)
        let cosH = (cos(zenith) - sin(latRad) * sin(decRad)) / (cos(latRad) * cos(decRad))

        // Solar noon (UTC minutes past midnight), longitude positive east.
        let solarNoonUTCMin = 720.0 - 4.0 * longitude - inter.equationOfTime
        let solarNoonDate = utcDate(utcMinutes: solarNoonUTCMin, civilDay: startOfDay, calendar: calendar)
        let noonPos = sun.position(date: solarNoonDate, latitude: latitude, longitude: longitude)

        var isPolarDay = false
        var isPolarNight = false
        var sunrise: Date? = nil
        var sunset: Date? = nil

        if cosH > 1.0 {
            // Sun never rises.
            isPolarNight = true
        } else if cosH < -1.0 {
            // Sun never sets.
            isPolarDay = true
        } else {
            let ha = SunMath.deg(acos(min(1.0, max(-1.0, cosH))))
            let sunriseUTCMin = 720.0 - 4.0 * (longitude + ha) - inter.equationOfTime
            let sunsetUTCMin = 720.0 - 4.0 * (longitude - ha) - inter.equationOfTime
            sunrise = utcDate(utcMinutes: sunriseUTCMin, civilDay: startOfDay, calendar: calendar)
            sunset = utcDate(utcMinutes: sunsetUTCMin, civilDay: startOfDay, calendar: calendar)
        }

        return SolarDay(
            startOfDay: startOfDay,
            sunrise: sunrise,
            solarNoon: solarNoonDate,
            sunset: sunset,
            maxElevation: noonPos.elevation,
            isPolarDay: isPolarDay,
            isPolarNight: isPolarNight)
    }

    // MARK: - Path sampling

    /// Samples the sun's path across the civil day at a fixed interval.
    /// - Parameter stepMinutes: Sampling interval. Defaults to 10 minutes.
    func sunPath(
        for date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        stepMinutes: Int = 10
    ) -> [SunPathSample] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: date)

        var samples: [SunPathSample] = []
        let totalSteps = (24 * 60) / max(1, stepMinutes)
        for i in 0...totalSteps {
            guard let t = calendar.date(byAdding: .minute, value: i * stepMinutes, to: startOfDay) else { continue }
            let pos = sun.position(date: t, latitude: latitude, longitude: longitude)
            samples.append(SunPathSample(id: i, date: t, position: pos))
        }
        return samples
    }

    // MARK: - Helpers

    /// Builds a concrete `Date` from "minutes past UTC midnight of the civil
    /// day". Handles wrap-around past midnight by anchoring on the civil day's
    /// UTC midnight.
    private func utcDate(utcMinutes: Double, civilDay: Date, calendar: Calendar) -> Date {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        // Determine UTC midnight of the civil day (using the civil day's date
        // components in the location timezone, then mapped to that UTC date).
        let comps = calendar.dateComponents([.year, .month, .day], from: civilDay)
        var midnightComps = comps
        midnightComps.hour = 0
        midnightComps.minute = 0
        midnightComps.second = 0
        let utcMidnight = utcCal.date(from: midnightComps) ?? civilDay
        return utcMidnight.addingTimeInterval(utcMinutes * 60.0)
    }
}
