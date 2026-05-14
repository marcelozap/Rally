/// The two swipe-target lanes. The entire input verb of the game maps onto
/// this enum: a swipe is either `.left` or `.right`.
enum Lane: String, CaseIterable {
    case left
    case right

    var opposite: Lane { self == .left ? .right : .left }
}
