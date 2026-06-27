//
//  SunPositionServiceTests.swift
//  Shadow LensTests
//
//  Validates the local NOAA/Meeus solar math: Julian day anchors, declination,
//  elevation/azimuth behavior, refraction, and the world-direction vector.
//

import XCTest
import simd
@testable import ShadowLens

final class SunPositionServiceTests: XCTestCase {

    private let service = SunPositionService()
    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, _ s: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d
        comps.hour = h; comps.minute = mi; comps.second = s
        return utcCalendar.date(from: comps)!
    }

    // MARK: Julian day

    func testJulianDayAnchorJ2000() {
        // 2000-01-01 12:00:00 UTC is exactly JD 2451545.0.
        let jd = SunMath.julianDay(from: utcDate(2000, 1, 1, 12))
        XCTAssertEqual(jd, 2451545.0, accuracy: 1e-6)
    }

    func testJulianDayMeeusExample() {
        // Meeus, Astronomical Algorithms, example 7.b: 1987 June 19.5 -> JD 2446966.0
        let jd = SunMath.julianDay(from: utcDate(1987, 6, 19, 12))
        XCTAssertEqual(jd, 2446966.0, accuracy: 1e-6)
    }

    func testJulianDayHalfDayOffset() {
        // Midnight UTC is JD .5 less than noon of the same day.
        let noon = SunMath.julianDay(from: utcDate(2024, 3, 20, 12))
        let midnight = SunMath.julianDay(from: utcDate(2024, 3, 20, 0))
        XCTAssertEqual(noon - midnight, 0.5, accuracy: 1e-9)
    }

    // MARK: Elevation behavior

    func testEquatorEquinoxNoonNearZenith() {
        // Near the March equinox at the equator, the noon sun is almost overhead.
        // Find the daily maximum elevation by sampling.
        let maxPos = maxElevationSample(year: 2024, month: 3, day: 20, lat: 0, lon: 0)
        XCTAssertGreaterThan(maxPos.elevation, 88.0)
    }

    func testSunBelowHorizonAtMidnight() {
        // 40N, lon 0, local midnight (= 00:00 UTC) on the summer solstice: the
        // sun is below the horizon.
        let pos = service.position(date: utcDate(2024, 6, 21, 0), latitude: 40, longitude: 0)
        XCTAssertLessThan(pos.elevation, 0.0)
        XCTAssertFalse(pos.isUp)
    }

    func testSolsticeNoonHigherThanWinter() {
        let summer = maxElevationSample(year: 2024, month: 6, day: 21, lat: 40, lon: 0)
        let winter = maxElevationSample(year: 2024, month: 12, day: 21, lat: 40, lon: 0)
        XCTAssertGreaterThan(summer.elevation, winter.elevation + 30.0)
        // Sanity: 40N summer noon elevation ~ 73.4 deg; winter ~ 26.6 deg.
        XCTAssertEqual(summer.elevation, 73.4, accuracy: 2.0)
        XCTAssertEqual(winter.elevation, 26.6, accuracy: 2.0)
    }

    // MARK: Azimuth behavior

    func testNoonAzimuthIsSouthInNorthernMidLatitude() {
        // At 40N the noon sun is due south (azimuth ~180) year round.
        let noon = maxElevationSample(year: 2024, month: 6, day: 21, lat: 40, lon: 0)
        XCTAssertEqual(noon.position.azimuth, 180.0, accuracy: 3.0)
    }

    func testMorningSunIsEasterly() {
        // A few hours after sunrise the sun is in the eastern half (0..180).
        // 09:00 UTC at lon 0, 40N in June.
        let pos = service.position(date: utcDate(2024, 6, 21, 9), latitude: 40, longitude: 0)
        XCTAssertTrue(pos.azimuth > 60 && pos.azimuth < 180,
                      "Morning azimuth should be easterly, got \(pos.azimuth)")
    }

    // MARK: Refraction

    func testRefractionRaisesLowSun() {
        // Refraction is positive near the horizon, so the corrected elevation
        // exceeds the geometric one.
        let pos = service.position(date: utcDate(2024, 3, 20, 6), latitude: 40, longitude: 0)
        if abs(pos.elevationUnrefracted) < 5 {
            XCTAssertGreaterThan(pos.elevation, pos.elevationUnrefracted)
        }
    }

    func testRefractionZeroHighInSky() {
        XCTAssertEqual(SunMath.atmosphericRefraction(elevationDegrees: 89), 0.0, accuracy: 1e-9)
    }

    func testRefractionMagnitudeAtHorizon() {
        // At the geometric horizon refraction is roughly 0.5 degrees.
        let r = SunMath.atmosphericRefraction(elevationDegrees: 0)
        XCTAssertEqual(r, 0.48, accuracy: 0.1)
    }

    // MARK: World direction vector

    func testWorldDirectionOverhead() {
        let v = SunMath.worldDirection(azimuthDegrees: 123, elevationDegrees: 90)
        XCTAssertEqual(v.x, 0, accuracy: 1e-9)
        XCTAssertEqual(v.y, 1, accuracy: 1e-9)
        XCTAssertEqual(v.z, 0, accuracy: 1e-9)
    }

    func testWorldDirectionNorthHorizon() {
        // Azimuth 0 (north), elevation 0: points to -z (north) in ARKit frame.
        let v = SunMath.worldDirection(azimuthDegrees: 0, elevationDegrees: 0)
        XCTAssertEqual(v.x, 0, accuracy: 1e-9)
        XCTAssertEqual(v.y, 0, accuracy: 1e-9)
        XCTAssertEqual(v.z, -1, accuracy: 1e-9)
    }

    func testWorldDirectionEastHorizon() {
        // Azimuth 90 (east), elevation 0: points to +x (east).
        let v = SunMath.worldDirection(azimuthDegrees: 90, elevationDegrees: 0)
        XCTAssertEqual(v.x, 1, accuracy: 1e-9)
        XCTAssertEqual(v.y, 0, accuracy: 1e-9)
        XCTAssertEqual(v.z, 0, accuracy: 1e-9)
    }

    func testWorldDirectionIsUnitVector() {
        let v = SunMath.worldDirection(azimuthDegrees: 210, elevationDegrees: 35)
        XCTAssertEqual(simd_length(v), 1.0, accuracy: 1e-9)
    }

    // MARK: Helpers

    /// Samples a day at 5-minute resolution and returns the highest-elevation
    /// sample, decoupling these tests from SolarDayService.
    private func maxElevationSample(year: Int, month: Int, day: Int, lat: Double, lon: Double)
        -> (elevation: Double, position: SolarPosition) {
        var best = SolarPosition(azimuth: 0, elevation: -90, elevationUnrefracted: -90)
        for minute in stride(from: 0, through: 24 * 60, by: 5) {
            let date = utcDate(year, month, day, 0, 0, 0).addingTimeInterval(Double(minute) * 60)
            let pos = service.position(date: date, latitude: lat, longitude: lon)
            if pos.elevation > best.elevation { best = pos }
        }
        return (best.elevation, best)
    }
}
