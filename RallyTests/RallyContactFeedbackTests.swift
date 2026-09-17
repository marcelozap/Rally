import XCTest
@testable import Rally

/// Recipe checks never initialize AudioManager.shared or HapticManager.shared,
/// so validation does not enable sound or require a physical Taptic Engine.
final class RallyContactFeedbackTests: XCTestCase {
    func testContactAudioKeepsHeadroomAndFinishesBeforeNextFeed() throws {
        for quality in [HitQuality.perfect, .great, .good] {
            for power: CGFloat in [-100, 0.25, 1, 1.45, 100, .nan, .infinity] {
                let contact = try XCTUnwrap(AudioManager.contactSound(for: quality, combo: Int.max, power: power))
                XCTAssertLessThanOrEqual(contact.body.peak + contact.strings.peak, 0.65)
                for patch in [contact.body, contact.strings] {
                    XCTAssertTrue(patch.freqStartHz.isFinite)
                    XCTAssertTrue(patch.freqEndHz.isFinite)
                    XCTAssertGreaterThan(patch.freqEndHz, 0)
                    XCTAssertLessThanOrEqual(patch.durationMs, 110)
                    XCTAssertGreaterThan(patch.attackMs, 0)
                    XCTAssertLessThan(patch.attackMs + patch.releaseMs, patch.durationMs)
                    XCTAssertTrue((0...1).contains(patch.noiseMix))
                }
            }
        }
    }

    func testInvalidPowerFallsBackToNormalContact() throws {
        let normal = try XCTUnwrap(AudioManager.contactSound(for: .perfect, combo: 0, power: 1))
        for power: CGFloat in [.nan, .infinity, -.infinity] {
            let invalid = try XCTUnwrap(AudioManager.contactSound(for: .perfect, combo: 0, power: power))
            XCTAssertEqual(invalid.body.peak, normal.body.peak)
            XCTAssertEqual(invalid.strings.freqStartHz, normal.strings.freqStartHz)
        }
    }

    func testContactGradesDifferInAttackAndBodyRatherThanVolumeAlone() throws {
        let perfect = try XCTUnwrap(AudioManager.contactSound(for: .perfect, combo: 0, power: 1))
        let great = try XCTUnwrap(AudioManager.contactSound(for: .great, combo: 0, power: 1))
        let good = try XCTUnwrap(AudioManager.contactSound(for: .good, combo: 0, power: 1))
        XCTAssertGreaterThan(perfect.strings.freqStartHz, great.strings.freqStartHz)
        XCTAssertGreaterThan(great.strings.freqStartHz, good.strings.freqStartHz)
        XCTAssertLessThan(perfect.body.durationMs, great.body.durationMs)
        XCTAssertLessThan(great.body.durationMs, good.body.durationMs)
        XCTAssertGreaterThan(perfect.strings.noiseMix, good.strings.noiseMix)
    }

    func testStreakBrightnessDoesNotIncreaseLoudnessOrContactDuration() throws {
        let first = try XCTUnwrap(AudioManager.contactSound(for: .perfect, combo: 0, power: 1))
        let streak = try XCTUnwrap(AudioManager.contactSound(for: .perfect, combo: Int.max, power: 1))
        XCTAssertEqual(first.body.peak, streak.body.peak)
        XCTAssertEqual(first.strings.peak, streak.strings.peak)
        XCTAssertEqual(first.body.durationMs, streak.body.durationMs)
        XCTAssertGreaterThan(streak.strings.freqStartHz, first.strings.freqStartHz)
        XCTAssertLessThan(streak.strings.freqStartHz / first.strings.freqStartHz, 1.15)
    }

    func testHapticGradesRemainBriefAndSubtle() throws {
        let profiles = try [HitQuality.perfect, .great, .good].map {
            try XCTUnwrap(HapticManager.contactHaptics(for: $0))
        }
        for contact in profiles {
            XCTAssertLessThanOrEqual(contact.impactIntensity, 0.5)
            XCTAssertLessThanOrEqual(contact.bodyIntensity, 0.12)
            XCTAssertLessThanOrEqual(contact.echoIntensity, 0.15)
            XCTAssertLessThanOrEqual(contact.bodyDuration + 0.002, 0.040)
        }
        XCTAssertGreaterThan(profiles[0].sharpness, profiles[1].sharpness)
        XCTAssertGreaterThan(profiles[1].sharpness, profiles[2].sharpness)
        XCTAssertGreaterThan(profiles[0].echoIntensity, 0)
        XCTAssertEqual(profiles[1].echoIntensity, 0)
        XCTAssertEqual(profiles[2].echoIntensity, 0)
    }

    func testMissDoesNotProduceSuccessfulContactFeedback() {
        XCTAssertNil(AudioManager.contactSound(for: .miss, combo: 0, power: 1))
        XCTAssertNil(HapticManager.contactHaptics(for: .miss))
    }
}
