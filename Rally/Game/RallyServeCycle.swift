import Foundation

/// The serve and the live exchange never own the ball at the same time.
struct RallyServeCycle {
    enum Phase: Equatable { case ready, preparing, toss, rally, retry, stopped }
    private(set) var phase: Phase = .ready
    private(set) var startedAt: Double = 0
    static let duration: Double = 1.8
    static let contactWindow = 1.16...1.53

    mutating func begin(at time: Double) {
        guard time.isFinite, phase != .stopped else { return }
        startedAt = time
        phase = .preparing
    }
    func elapsed(at time: Double) -> Double { max(0, time - startedAt) }
    mutating func advance(at time: Double) {
        guard time.isFinite else { return }
        if phase == .preparing, elapsed(at: time) >= 0.5 { phase = .toss }
        if phase == .toss, elapsed(at: time) > Self.contactWindow.upperBound { phase = .retry; startedAt = time }
    }
    mutating func hit(at time: Double) -> Bool {
        guard time.isFinite, phase == .toss, Self.contactWindow.contains(elapsed(at: time)) else { return false }
        phase = .rally
        return true
    }
    mutating func enterRally() { if phase != .stopped { phase = .rally } }
    mutating func retry(at time: Double) { guard time.isFinite, phase != .stopped else { return }; phase = .retry; startedAt = time }
    mutating func stop() { phase = .stopped }
}

enum RallyPracticeTarget {
    static func center(at attempt: Int) -> Double { [0.34, 0.66, 0.5][max(0, attempt) % 3] }
    static func isHit(x: Double, width: Double, attempt: Int) -> Bool {
        guard x.isFinite, width.isFinite, width > 0 else { return false }
        return abs(x / width - center(at: attempt)) <= 0.10
    }
}
