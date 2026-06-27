//
//  SolarDayServiceTests.swift
//  Shadow LensTests
//
//  Validates daily solar events (sunrise/noon/sunset), day length, polar day /
//  night handling, and sun-path sampling.
//

import XCTest
@testable import ShadowLens

final class SolarDayServiceTests: XCTestCase {

    private let service = SolarDayService()
    private let utc = TimeZone(identifier: "UTC")!

    private func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
    }

    // MARK: Event ordering

    func testSunriseNoonSunsetOrdered() {
        let day = service.solarDay(for: utcDate(2024, 6, 21),
                                   latitude: 40, longitude: 0, timeZone: utc)
        XCTAssertFalse(day.isPolarDay)
        XCTAssertFalse(day.isPolarNight)
        let sunrise = try! XCTUnwrap(day.sunrise)
        let sunset = try! XCTUnwrap(day.sunset)
        XCTAssertLessThan(sunrise, day.solarNoon)
        XCTAssertLessThan(day.solarNoon, sunset)
    }

    func testMaxElevationPositiveInSummer() {
        let day = service.solarDay(for: utcDate(2024, 6, 21),
                                   latitude: 40, longitude: 0, timeZone: utc)
        XCTAssertEqual(day.maxElevation, 73.4, accuracy: 2.0)
    }

    // MARK: Day length

    func testEquatorDayLengthAboutTwelveHours() {
        let day = service.solarDay(for: utcDate(2024, 3, 20),
                                   latitude: 0, longitude: 0, timeZone: utc)
        let sunrise = try! XCTUnwrap(day.sunrise)
        let sunset = try! XCTUnwrap(day.sunset)
        let hours = sunset.timeIntervalSince(sunrise) / 3600.0
        XCTAssertEqual(hours, 12.0, accuracy: 0.5)
    }

    func testSummerDayLongerThanWinterInNorth() {
        let summer = service.solarDay(for: utcDate(2024, 6, 21),
                                      latitude: 51.5, longitude: 0, timeZone: utc)
        let winter = service.solarDay(for: utcDate(2024, 12, 21),
                                      latitude: 51.5, longitude: 0, timeZone: utc)
        let summerLen = summer.sunset!.timeIntervalSince(summer.sunrise!)
        let winterLen = winter.sunset!.timeIntervalSince(winter.sunrise!)
        XCTAssertGreaterThan(summerLen, winterLen)
        // London: ~16.6 h midsummer vs ~7.9 h midwinter.
        XCTAssertEqual(summerLen / 3600.0, 16.6, accuracy: 1.0)
        XCTAssertEqual(winterLen / 3600.0, 7.9, accuracy: 1.0)
    }

    // MARK: Polar conditions

    func testPolarDayInArcticSummer() {
        let day = service.solarDay(for: utcDate(2024, 6, 21),
                                   latitude: 80, longitude: 0, timeZone: utc)
        XCTAssertTrue(day.isPolarDay)
        XCTAssertNil(day.sunrise)
        XCTAssertNil(day.sunset)
        XCTAssertGreaterThan(day.maxElevation, 0)
    }

    func testPolarNightInArcticWinter() {
        let day = service.solarDay(for: utcDate(2024, 12, 21),
                                   latitude: 80, longitude: 0, timeZone: utc)
        XCTAssertTrue(day.isPolarNight)
        XCTAssertNil(day.sunrise)
        XCTAssertNil(day.sunset)
        XCTAssertLessThan(day.maxElevation, 0)
    }

    // MARK: Sun path sampling

    func testSunPathSampleCount() {
        let path = service.sunPath(for: utcDate(2024, 6, 21),
                                   latitude: 40, longitude: 0, timeZone: utc, stepMinutes: 30)
        // 24h / 30min inclusive of both endpoints = 49 samples.
        XCTAssertEqual(path.count, 49)
    }

    func testSunPathPeakNearSolarNoon() {
        let date = utcDate(2024, 6, 21)
        let day = service.solarDay(for: date, latitude: 40, longitude: 0, timeZone: utc)
        let path = service.sunPath(for: date, latitude: 40, longitude: 0, timeZone: utc, stepMinutes: 5)
        let peak = path.max { $0.position.elevation < $1.position.elevation }!
        let delta = abs(peak.date.timeIntervalSince(day.solarNoon))
        // The highest sampled point should sit within ~10 minutes of solar noon.
        XCTAssertLessThan(delta, 600)
    }

    func testSolarNoonElevationMatchesMaxElevation() {
        let day = service.solarDay(for: utcDate(2024, 6, 21),
                                   latitude: 40, longitude: 0, timeZone: utc)
        let path = service.sunPath(for: utcDate(2024, 6, 21),
                                   latitude: 40, longitude: 0, timeZone: utc, stepMinutes: 2)
        let peak = path.map(\.position.elevation).max()!
        XCTAssertEqual(day.maxElevation, peak, accuracy: 0.5)
    }
}
