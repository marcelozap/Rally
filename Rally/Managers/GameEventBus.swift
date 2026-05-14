import Foundation

/// Single-publisher, multi-subscriber event hub. Gameplay (`GameScene`)
/// publishes; the three feedback managers subscribe.
///
/// Why a custom bus instead of `Combine` or `NotificationCenter`?
/// - We want **strong typing** on the payload (`GameEvent` is a sum type).
/// - We want **zero allocation** on the hot path. Combine pipelines allocate
///   per emission; we don't want any GC pressure during a 60–120 Hz scene.
/// - Subscribers are owned by long-lived singletons, so identity-based
///   weak storage is fine and simpler than `AnyCancellable`s.
///
/// All access is on the main thread (SpriteKit's thread). If a manager needs
/// to do work off the main thread (e.g. audio buffer scheduling) it should
/// hop to its own queue inside its handler.
final class GameEventBus {
    static let shared = GameEventBus()
    private init() {}

    private struct Subscription {
        weak var owner: AnyObject?
        let handler: (GameEvent) -> Void
    }

    private var subscriptions: [Subscription] = []

    func subscribe(_ owner: AnyObject, _ handler: @escaping (GameEvent) -> Void) {
        subscriptions.append(Subscription(owner: owner, handler: handler))
    }

    func publish(_ event: GameEvent) {
        var compacted: [Subscription] = []
        compacted.reserveCapacity(subscriptions.count)
        for sub in subscriptions {
            guard sub.owner != nil else { continue }
            sub.handler(event)
            compacted.append(sub)
        }
        subscriptions = compacted
    }
}
