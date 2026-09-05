import XCTest
@testable import Rally

final class RallyAvatarFootworkTests: XCTestCase {
    // With gameplay yaw near pi, anatomical R is on the screen's right.
    private let leftRest: Float = -0.22
    private let rightRest: Float = 0.22

    private func sample(_ gait: inout RallyAvatarFootwork, time: Double, position: Float) -> RallyAvatarFootwork.Pose {
        gait.sample(time: time, courtPosition: position, leftRestX: leftRest, rightRestX: rightRest)
    }

    func testStationaryPlayerDoesNotMarch() {
        var gait = RallyAvatarFootwork()
        for frame in 0...600 {
            let pose = sample(&gait, time: Double(frame) / 60, position: 0.43)
            XCTAssertFalse(pose.isStepping)
            XCTAssertEqual(pose.left.lift, 0)
            XCTAssertEqual(pose.right.lift, 0)
            XCTAssertEqual(pose.left.offset, 0, accuracy: 0.00001)
            XCTAssertEqual(pose.right.offset, 0, accuracy: 0.00001)
            XCTAssertEqual(pose.pelvisDrop, 0, accuracy: 0.00001)
        }
    }

    func testScreenRightChaseLiftsLeadFootThenTrailingFootAndPreservesSupportAnchor() {
        var gait = RallyAvatarFootwork()
        var previous = sample(&gait, time: 0, position: 0)
        var previousPosition: Float = 0
        var firstLift: String?
        var sawLeftLift = false
        var sawRightLift = false
        var peakLift: Float = 0
        for frame in 1...90 {
            let position = Float(frame) / 60 * 1.35
            let pose = sample(&gait, time: Double(frame) / 60, position: position)
            if firstLift == nil, pose.isStepping { firstLift = pose.left.isPlanted ? "R" : "L" }
            sawLeftLift = sawLeftLift || pose.left.lift > 0.02
            sawRightLift = sawRightLift || pose.right.lift > 0.02
            peakLift = max(peakLift, max(pose.left.lift, pose.right.lift))
            XCTAssertTrue(pose.left.isPlanted || pose.right.isPlanted)
            if previous.left.isPlanted && pose.left.isPlanted {
                XCTAssertEqual(previousPosition + leftRest + previous.left.offset,
                               position + leftRest + pose.left.offset, accuracy: 0.0001,
                               "Supporting left shoe must cancel the outer player translation")
            }
            if previous.right.isPlanted && pose.right.isPlanted {
                XCTAssertEqual(previousPosition + rightRest + previous.right.offset,
                               position + rightRest + pose.right.offset, accuracy: 0.0001,
                               "Supporting right shoe must cancel the outer player translation")
            }
            XCTAssertLessThan(abs(pose.left.offset), 0.231)
            XCTAssertLessThan(abs(pose.right.offset), 0.231)
            previous = pose
            previousPosition = position
        }
        XCTAssertEqual(firstLift, "R")
        XCTAssertTrue(sawLeftLift && sawRightLift)
        XCTAssertGreaterThan(peakLift, 0.04)
    }

    func testLeadFootFollowsProjectedStanceAndMovementDirection() {
        for (left, right) in [(Float(-0.22), Float(0.22)), (Float(0.22), Float(-0.22))] {
            for direction: Float in [-1, 1] {
                var gait = RallyAvatarFootwork()
                _ = gait.sample(time: 0, courtPosition: 0, leftRestX: left, rightRestX: right)
                var firstPose: RallyAvatarFootwork.Pose?
                for frame in 1...10 {
                    let pose = gait.sample(time: Double(frame) / 60, courtPosition: Float(frame) / 60 * direction,
                                           leftRestX: left, rightRestX: right)
                    if pose.isStepping { firstPose = pose; break }
                }
                XCTAssertNotNil(firstPose)
                let leftLeads = (left - right) * direction > 0
                XCTAssertEqual(firstPose?.left.isPlanted, !leftLeads)
                XCTAssertEqual(firstPose?.right.isPlanted, leftLeads)
            }
        }
    }

    func testStoppingCompletesRecoveryThenHoldsBothFeet() {
        var gait = RallyAvatarFootwork()
        for frame in 0...31 {
            _ = sample(&gait, time: Double(frame) / 60, position: Float(frame) / 60 * 0.8)
        }
        let finalPosition = Float(31) / 60 * 0.8
        for frame in 32...150 {
            _ = sample(&gait, time: Double(frame) / 60, position: finalPosition)
        }
        let resting = sample(&gait, time: 151.0 / 60, position: finalPosition)
        XCTAssertFalse(resting.isStepping)
        XCTAssertLessThanOrEqual(abs(resting.left.offset), 0.0251)
        XCTAssertLessThanOrEqual(abs(resting.right.offset), 0.0251)
        for frame in 152...270 {
            let pose = sample(&gait, time: Double(frame) / 60, position: finalPosition)
            XCTAssertFalse(pose.isStepping)
            XCTAssertEqual(pose.left, resting.left)
            XCTAssertEqual(pose.right, resting.right)
            XCTAssertLessThan(pose.pelvisDrop, 0.001)
        }
    }

    func testStoppingAtDifferentSwingPhasesDoesNotSnapTheShoeOrPelvis() {
        // Stop throughout the shuffle, especially just before touchdown where
        // abruptly removing landing prediction used to jump the shoe backward.
        for stopFrame in 12...80 {
            var gait = RallyAvatarFootwork()
            var previous = RallyAvatarFootwork.Pose()
            for frame in 0...stopFrame {
                previous = sample(&gait, time: Double(frame) / 60, position: Float(frame) / 60 * 1.35)
            }
            let position = Float(stopFrame) / 60 * 1.35
            for frame in (stopFrame + 1)...(stopFrame + 40) {
                let pose = sample(&gait, time: Double(frame) / 60, position: position)
                XCTAssertLessThan(abs(pose.left.offset - previous.left.offset), 0.05,
                                  "Left shoe snapped after stopping at frame \(stopFrame)")
                XCTAssertLessThan(abs(pose.right.offset - previous.right.offset), 0.05,
                                  "Right shoe snapped after stopping at frame \(stopFrame)")
                XCTAssertLessThan(abs(pose.pelvisOffset - previous.pelvisOffset), 0.015)
                previous = pose
            }
            XCTAssertFalse(previous.isStepping)
        }
    }

    func testWideReversalKeepsShoesOrderedAndContinuous() {
        var gait = RallyAvatarFootwork()
        var previousLeft = leftRest
        var previousRight = rightRest
        var previousPose = RallyAvatarFootwork.Pose()
        for frame in 0...240 {
            let time = Double(frame) / 60
            let position: Float
            if time < 0.52 { position = Float(time) * 1.35 }
            else if time < 1.56 { position = 0.702 - Float(time - 0.52) * 1.35 }
            else if time < 2.08 { position = -0.702 + Float(time - 1.56) * 1.35 }
            else { position = 0 }
            let pose = sample(&gait, time: time, position: position)
            let left = position + leftRest + pose.left.offset
            let right = position + rightRest + pose.right.offset
            XCTAssertTrue(left.isFinite && right.isFinite && pose.pelvisDrop.isFinite)
            XCTAssertLessThan(left, right)
            XCTAssertLessThan(abs(left - previousLeft), 0.11)
            XCTAssertLessThan(abs(right - previousRight), 0.11)
            XCTAssertTrue(pose.left.isPlanted || pose.right.isPlanted)
            if previousPose.left.isPlanted && pose.left.isPlanted {
                XCTAssertEqual(left, previousLeft, accuracy: 0.0001)
            }
            if previousPose.right.isPlanted && pose.right.isPlanted {
                XCTAssertEqual(right, previousRight, accuracy: 0.0001)
            }
            previousLeft = left
            previousRight = right
            previousPose = pose
        }
    }

    func testRewindsTeleportsAndResumingAfterPauseResetSafely() {
        for discontinuity in [(Double(0.1), Float(0.2)), (0.51, 4), (3, 0.4)] {
            var gait = RallyAvatarFootwork()
            for frame in 0...30 {
                _ = sample(&gait, time: Double(frame) / 60, position: Float(frame) / 60 * 0.8)
            }
            let pose = sample(&gait, time: discontinuity.0, position: discontinuity.1)
            XCTAssertEqual(pose, RallyAvatarFootwork.Pose())
        }
        var gait = RallyAvatarFootwork()
        let invalid = sample(&gait, time: .infinity, position: .nan)
        XCTAssertEqual(invalid, RallyAvatarFootwork.Pose())
        XCTAssertEqual(sample(&gait, time: 0, position: 0), RallyAvatarFootwork.Pose())
    }

    func testIdenticalSamplesAreDeterministicAndRepeatedTimestampDoesNotAdvance() {
        var first = RallyAvatarFootwork()
        var second = RallyAvatarFootwork()
        for frame in 0...180 {
            let time = Double(frame) / 60
            let position = Float(sin(time * 1.3)) * 0.6
            let expected = sample(&first, time: time, position: position)
            XCTAssertEqual(sample(&second, time: time, position: position), expected)
            XCTAssertEqual(sample(&first, time: time, position: position), expected)
        }
    }

    func testSubpixelPositionJitterDoesNotTriggerSteps() {
        var gait = RallyAvatarFootwork()
        for frame in 0...180 {
            let time = Double(frame) / 60
            let pose = sample(&gait, time: time, position: Float(sin(time * 10)) * 0.001)
            XCTAssertFalse(pose.isStepping)
            XCTAssertEqual(pose.left.lift, 0)
            XCTAssertEqual(pose.right.lift, 0)
        }
    }
}
