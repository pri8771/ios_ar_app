//
//  SunPositionService.swift
//  Umbra
//
//  Local NOAA / Meeus-style solar position math. No network, no external
//  dependencies. All calculations are pure functions so they can be unit
//  tested without an AR session or a device.
//
//  Conventions used throughout this file:
//   - Azimuth is measured in degrees CLOCKWISE FROM TRUE NORTH
//     (0 = north, 90 = east, 180 = south, 270 = west).
//   - Elevation (altitude) is degrees above the horizon. Negative means the
//     sun is below the horizon.
//   - Latitude is positive north, longitude is positive EAST.
//   - Dates are interpreted in UTC for the astronomy; the caller supplies a
//     `Date`, which is an absolute instant and therefore timezone independent.
//

import Foundation

/// A computed position of the sun in the local horizontal coordinate system.
struct SolarPosition: Equatable, Hashable {
    /// Azimuth in degrees clockwise from true north (0..<360).
    let azimuth: Double
    /// Elevation in degrees above the horizon, including atmospheric
    /// refraction correction. Negative when the sun is below the horizon.
    let elevation: Double
    /// Geometric elevation in degrees, WITHOUT refraction correction. Useful
    /// for tests and for understanding the raw geometry.
    let elevationUnrefracted: Double

    /// True when the (refracted) sun is at or above the horizon.
    var isUp: Bool { elevation > 0 }
}

/// Stateless service that computes solar position for an instant and location.
struct SunPositionService {

    // MARK: - Public API

    /// Computes the solar position for a given instant and geographic location.
    /// - Parameters:
    ///   - date: The absolute instant in time.
    ///   - latitude: Latitude in degrees, positive north (-90...90).
    ///   - longitude: Longitude in degrees, positive east (-180...180).
    /// - Returns: The solar azimuth/elevation in the local horizontal frame.
    func position(date: Date, latitude: Double, longitude: Double) -> SolarPosition {
        let jd = SunMath.julianDay(from: date)
        return SunMath.position(julianDay: jd, latitude: latitude, longitude: longitude)
    }

    /// Computes a sun direction unit vector in an East-Up-North (right handed
    /// when expressed as x=east, y=up, z=south) world frame matching ARKit's
    /// `gravityAndHeading` alignment.
    ///
    /// The returned vector points FROM the observer TOWARD the sun.
    /// ARKit `gravityAndHeading`: +x = east, +y = up, +z = south (north = -z).
    func sunWorldDirection(date: Date, latitude: Double, longitude: Double) -> SIMD3<Double> {
        let p = position(date: date, latitude: latitude, longitude: longitude)
        return SunMath.worldDirection(azimuthDegrees: p.azimuth, elevationDegrees: p.elevation)
    }
}

/// Pure math used by `SunPositionService`. Exposed (internal) so unit tests can
/// validate the building blocks (Julian day, equation of time, refraction).
enum SunMath {

    // MARK: Trig helpers (degrees)

    @inline(__always) static func rad(_ deg: Double) -> Double { deg * .pi / 180.0 }
    @inline(__always) static func deg(_ rad: Double) -> Double { rad * 180.0 / .pi }

    /// Normalizes an angle in degrees to the range [0, 360).
    @inline(__always) static func normalize360(_ deg: Double) -> Double {
        let m = deg.truncatingRemainder(dividingBy: 360.0)
        return m < 0 ? m + 360.0 : m
    }

    // MARK: Julian day

    /// Computes the Julian Day (including fractional day) from a `Date`.
    /// Verified anchor: 2000-01-01 12:00:00 UTC == JD 2451545.0.
    static func julianDay(from date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)

        var year = c.year ?? 2000
        var month = c.month ?? 1
        let day = c.day ?? 1
        let hour = Double(c.hour ?? 0)
        let minute = Double(c.minute ?? 0)
        let second = Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1_000_000_000.0

        if month <= 2 {
            year -= 1
            month += 12
        }
        let a = (Double(year) / 100.0).rounded(.down)
        let b = 2 - a + (a / 4.0).rounded(.down)
        let dayFraction = (hour + minute / 60.0 + second / 3600.0) / 24.0

        let jd = (365.25 * (Double(year) + 4716)).rounded(.down)
            + (30.6001 * (Double(month) + 1)).rounded(.down)
            + Double(day) + b - 1524.5 + dayFraction
        return jd
    }

    // MARK: Core NOAA algorithm

    /// The intermediate solar quantities derived from the Julian century. Kept
    /// as a struct so tests can inspect declination and the equation of time.
    struct SolarIntermediate {
        let julianCentury: Double
        let geomMeanLongSun: Double   // degrees
        let geomMeanAnomSun: Double   // degrees
        let eccentricity: Double
        let sunEqOfCenter: Double     // degrees
        let sunTrueLong: Double       // degrees
        let sunAppLong: Double        // degrees
        let meanObliqEcliptic: Double // degrees
        let obliqCorrection: Double   // degrees
        let declination: Double       // degrees
        let equationOfTime: Double    // minutes
    }

    static func intermediate(julianDay jd: Double) -> SolarIntermediate {
        let t = (jd - 2451545.0) / 36525.0

        let l0 = normalize360(280.46646 + t * (36000.76983 + t * 0.0003032))
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let mRad = rad(m)
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289

        let trueLong = l0 + c
        let appLong = trueLong - 0.00569 - 0.00478 * sin(rad(125.04 - 1934.136 * t))

        let meanObliq = 23.0 + (26.0 + ((21.448 - t * (46.815 + t * (0.00059 - t * 0.001813)))) / 60.0) / 60.0
        let obliqCorr = meanObliq + 0.00256 * cos(rad(125.04 - 1934.136 * t))

        let declination = deg(asin(sin(rad(obliqCorr)) * sin(rad(appLong))))

        // Equation of time (minutes).
        let y = pow(tan(rad(obliqCorr / 2.0)), 2)
        let eot = 4.0 * deg(
            y * sin(2 * rad(l0))
            - 2 * e * sin(mRad)
            + 4 * e * y * sin(mRad) * cos(2 * rad(l0))
            - 0.5 * y * y * sin(4 * rad(l0))
            - 1.25 * e * e * sin(2 * mRad))

        return SolarIntermediate(
            julianCentury: t,
            geomMeanLongSun: l0,
            geomMeanAnomSun: m,
            eccentricity: e,
            sunEqOfCenter: c,
            sunTrueLong: trueLong,
            sunAppLong: appLong,
            meanObliqEcliptic: meanObliq,
            obliqCorrection: obliqCorr,
            declination: declination,
            equationOfTime: eot)
    }

    static func position(julianDay jd: Double, latitude: Double, longitude: Double) -> SolarPosition {
        let inter = intermediate(julianDay: jd)

        // Minutes past UTC midnight for this instant.
        let utcMinutes = (jd + 0.5 - (jd + 0.5).rounded(.down)) * 1440.0

        // True solar time in minutes (longitude positive east).
        var trueSolarTime = (utcMinutes + inter.equationOfTime + 4.0 * longitude)
            .truncatingRemainder(dividingBy: 1440.0)
        if trueSolarTime < 0 { trueSolarTime += 1440.0 }

        // Hour angle in degrees.
        var hourAngle = trueSolarTime / 4.0 - 180.0
        if hourAngle < -180 { hourAngle += 360 }

        let latRad = rad(latitude)
        let decRad = rad(inter.declination)
        let haRad = rad(hourAngle)

        let cosZenith = sin(latRad) * sin(decRad)
            + cos(latRad) * cos(decRad) * cos(haRad)
        let zenith = acos(min(1.0, max(-1.0, cosZenith)))
        let elevation = 90.0 - deg(zenith)

        // Azimuth (clockwise from north).
        let azimuth: Double
        let sinZenith = sin(zenith)
        if abs(sinZenith) < 1e-9 {
            // Sun directly overhead/underfoot; azimuth is undefined. Use 180.
            azimuth = 180.0
        } else {
            let cosAz = (sin(latRad) * cos(zenith) - sin(decRad)) / (cos(latRad) * sinZenith)
            let azAcos = deg(acos(min(1.0, max(-1.0, cosAz))))
            if hourAngle > 0 {
                azimuth = normalize360(azAcos + 180.0)
            } else {
                azimuth = normalize360(540.0 - azAcos)
            }
        }

        let refraction = atmosphericRefraction(elevationDegrees: elevation)
        return SolarPosition(
            azimuth: azimuth,
            elevation: elevation + refraction,
            elevationUnrefracted: elevation)
    }

    // MARK: Atmospheric refraction

    /// Returns the atmospheric refraction correction in degrees to add to the
    /// geometric elevation. Standard NOAA piecewise approximation.
    static func atmosphericRefraction(elevationDegrees e: Double) -> Double {
        if e > 85.0 { return 0.0 }
        let te = tan(rad(e))
        let arcseconds: Double
        if e > 5.0 {
            arcseconds = 58.1 / te - 0.07 / pow(te, 3) + 0.000086 / pow(te, 5)
        } else if e > -0.575 {
            arcseconds = 1735.0 + e * (-518.2 + e * (103.4 + e * (-12.79 + e * 0.711)))
        } else {
            arcseconds = -20.774 / te
        }
        return arcseconds / 3600.0
    }

    // MARK: World direction vector

    /// Converts azimuth (clockwise from north) and elevation into a unit
    /// direction vector in ARKit `gravityAndHeading` world coordinates:
    /// x = east, y = up, z = south (north = -z). Vector points toward the sun.
    static func worldDirection(azimuthDegrees az: Double, elevationDegrees el: Double) -> SIMD3<Double> {
        let azRad = rad(az)
        let elRad = rad(el)
        let cosEl = cos(elRad)
        let east = cosEl * sin(azRad)
        let up = sin(elRad)
        let north = cosEl * cos(azRad)
        // z points south, so south component = -north.
        return SIMD3<Double>(east, up, -north)
    }
}
