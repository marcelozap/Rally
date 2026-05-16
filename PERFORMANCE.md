# Performance & Optimization Guide for Rally

## 🚀 Performance Targets

- **Cold start time:** < 2 seconds (target: 1.5s)
- **Tab transition:** < 300 ms
- **Game session load:** Instant (prewarmed)
- **Memory footprint:** < 150 MB (active session)
- **Battery drain:** < 5% per hour gameplay
- **Frame rate:** 60 FPS (game) / smooth (UI)

---

## 🎯 Implemented Optimizations

### Audio
- ✅ Pre-warmed `AudioManager` at app launch (eliminates first-tap latency)
- ✅ Programmatic synth via `AVAudioSourceNode` (no file I/O)
- ✅ Layered instruments crossfade (CPU-efficient mixing)

### Haptics
- ✅ Pre-warmed `HapticManager` with engine priming
- ✅ Transient-based patterns (low CPU + memory)

### Assets
- ✅ Lazy-loaded cosmetics catalog
- ✅ JSON-encoded catalog (smaller than bundles)
- ✅ SpriteKit texture atlasing (implicit)

### Data
- ✅ Query filtering by date (`@Query` predicate)
- ✅ Singleton patterns for progress + avatar config
- ✅ Batch saves post-game (atomic transactions)

### UI
- ✅ Hardware-accelerated animations
- ✅ Respects reduce motion preference
- ✅ Tab view recycling (SwiftUI standard)

---

## 📋 Checklist for Before Release

### Profiling (Use Xcode Instruments)
- [ ] Core Animation — Check for off-screen rendering, rasterization
- [ ] Memory Leaks — Verify no dangling references in GameEventBus
- [ ] Energy Impact — Profile game session + notifications
- [ ] Time Profiler — Identify hot paths in Rewards calculation

**Quick Commands:**
```bash
# Profile cold start
xcodebuild -scheme Rally -configuration Release -derivedDataPath build \
  -enableCodeCoverage NO | xcpretty

# Check memory (in Xcode: Debug > View Memory Graph)
```

### Build Optimization
- [ ] Enable optimizations: `-Osize` or `-Owholemodule` in Release build
- [ ] Strip debug symbols: `Strip Debug Symbols During Copy` = YES
- [ ] Module Stability: Enable for frameworks if distributed

### Testing
- [ ] A/B test notification timing (9 AM vs user preference)
- [ ] Verify daily challenge generation works after midnight
- [ ] Test achievement unlock notifications (no duplicates)
- [ ] Verify share sheet works on iOS 17+
- [ ] Test accessibility (VoiceOver, font sizing, color contrast)

---

## 🔍 Monitoring in Production

### Crashes
- Use Xcode Organizer or third-party service (Sentry, Crashlytics)
- Monitor:
  - `ModelContext.save()` exceptions
  - `UNUserNotificationCenter` errors
  - `GameScene` deallocation issues

### Engagement Metrics
- Track daily active users (DAU) + monthly (MAU)
- Monitor challenge completion rate (target: 60%+)
- Track achievement unlock rate (target: 2+ per player per week)
- Measure share button clicks (target: 5-10% of game overs)

### Notification Effectiveness
- Track open rate (target: 15-25%)
- Monitor opt-out rate (should stay < 5%)
- A/B test send times (9 AM vs personalized)

---

## 🎮 Game Session Performance Tips

### SpriteKit Optimization
```swift
// In GameScene
scene.physicsWorld.speed = 1.0  // Only if needed
scene.shouldEnableMotionBlur = false  // No motion blur
node.isHidden = true  // Better than removing (reuse pool)
```

### Memory Management
```swift
// Clear event bus listeners when game ends
GameEventBus.shared.removeAllSubscriptions()

// Batch process hits instead of per-frame updates
let hits = ballsInFrame.filter { $0.intersects(strikeZone) }
```

### Rendering
- Keep draw calls < 100 per frame
- Use texture atlases for cosmetics
- Batch particle emitters

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] `Rewards.swift` — Streak calculation, badge logic
- [ ] `DailyChallenge.swift` — Progress update logic
- [ ] `Achievement.swift` — Rarity classification
- [ ] Sync conflict resolution (max-wins for numerics)

### UI Tests
- [ ] Tab navigation (all 5 tabs accessible)
- [ ] Daily challenge display + progress
- [ ] Achievement gallery pagination
- [ ] Share button functionality
- [ ] Notification opt-in flow

### Integration Tests
- [ ] Full game session → reward → notification → home
- [ ] Multi-device sync (if applicable)
- [ ] Guest mode → sign-in transition

---

## 📦 Release Checklist

Before pushing to App Store / Play Store:

### Code
- [ ] All TODO comments addressed
- [ ] No print statements in production code
- [ ] Handle all edge cases (network errors, disk full, etc.)
- [ ] Validate all user input

### Assets
- [ ] All SF Symbols exist (verify on target iOS version)
- [ ] Color hex strings are valid
- [ ] Images optimized (WebP or HEIC when possible)

### Backend
- [ ] Sync endpoint tested for new models (Achievement, DailyChallenge)
- [ ] Migration path for existing users
- [ ] Error handling for failed syncs

### Marketing
- [ ] App Store description mentions daily challenges + achievements
- [ ] Screenshots updated to show new features
- [ ] Release notes include achievement system, challenges, notifications

### Privacy
- [ ] Notification permission properly explained
- [ ] Privacy Policy updated (if using analytics)
- [ ] No personally identifiable info in crash logs

---

## 🎯 Performance Targets by Screen

| Screen | Cold Load | Hot Load | Smooth Scroll |
|--------|-----------|----------|---------------|
| Home | 500ms | 50ms | 60 FPS |
| Play (before game) | 800ms | 50ms | 60 FPS |
| Game Session | < 16ms per frame | 60 FPS | 60 FPS |
| Logs | 200ms | 20ms | 60 FPS |
| Shop | 300ms | 50ms | 60 FPS |

---

## 🔧 Optimization Techniques (Reference)

### If Slow Startup:
1. Profile with Instruments → Core Animation
2. Check for synchronous I/O in `init`
3. Defer non-critical work to background
4. Use `async`/`await` for network calls

### If Slow Scrolling:
1. Profile Time Profiler → identify hot path
2. Reduce view hierarchy depth
3. Use `.drawsAsynchronously` sparingly
4. Pre-calculate dynamic sizes

### If High Memory:
1. Check for circular references in closures
2. Verify `@Published` not retaining view models
3. Profile with Memory Leaks instrument
4. Check GameEventBus listener cleanup

### If Battery Drain:
1. Disable motion sensors if not used
2. Reduce animation frame rate in `update(_:)`
3. Batch location updates
4. Verify notification background refresh off

---

## 📊 Analytics Events to Track

```swift
// Suggested events (implement via Firebase, Amplitude, etc.)
Analytics.logEvent("daily_challenge_completed", parameters: [
    "challenge_id": challengeId,
    "time_to_complete": timeInSeconds,
    "coins_earned": coinsEarned
])

Analytics.logEvent("achievement_unlocked", parameters: [
    "badge_id": badgeId,
    "rarity": rarity,
    "session_number": playerProgress.totalSessions
])

Analytics.logEvent("score_shared", parameters: [
    "score": finalScore,
    "new_personal_best": isNewBestScore
])

Analytics.logEvent("notification_opened", parameters: [
    "type": notificationType,
    "time_delay": minutesSinceNotification
])
```

---

## 🎬 Stress Test Scenarios

Before release, manually test:

1. **Rapid tab switching** — No crashes or memory leaks
2. **Kill app during sync** — Graceful recovery
3. **Fill storage** — Graceful degradation
4. **Disable notifications** — App continues working
5. **Play 10 games back-to-back** — No crashes, memory stable
6. **Unlock 5+ achievements in one game** — All notifications sent

---

## 📚 References

- [Apple Performance Best Practices](https://developer.apple.com/videos/)
- [Xcode Instruments Guide](https://developer.apple.com/documentation/xcode/using-instruments)
- [SwiftUI Performance](https://developer.apple.com/wwdc23/10160)
- [SpriteKit Optimization](https://developer.apple.com/documentation/spritekit)

---

## 🚨 Critical Bugs to Watch

1. **Notification duplicates** — Verify unique identifiers
2. **Streak reset without reason** — Check `Calendar` timezone handling
3. **Achievement not appearing** — Verify model context save
4. **Share sheet crash** — Test on iOS 17 + 18 (different ShareLink behavior)
5. **Challenge not progressing** — Verify `DailyChallengeMgr.updateChallenges` called post-game

---

## 💡 Quick Performance Wins

If running low on optimization time, prioritize:
1. ✅ Audio prewarm (already done)
2. ✅ Haptic prewarm (already done)
3. Asset lazy loading (add as needed)
4. Query filtering (implemented for challenges)
5. Reduce motion detection (implemented)

---

## 🎯 Success Metrics After Launch

Track these KPIs weekly:

- **DAU Growth** — Should jump 40-60% after challenges launch
- **Session Length** — Should increase 15-20%
- **Day 7 Retention** — Should improve 15-25%
- **Notification CTR** — Should be 15-25%
- **Challenge Completion** — Should be 50-70%
- **Share Rate** — Should be 5-15% of game overs

---

**Good luck with Rally! 🎾🚀**
