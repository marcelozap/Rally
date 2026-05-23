# Rally iOS UI & Design System Overhaul Plan

**Status:** Planning document only — do not implement in this pass.  
**Target aesthetic:** XIV brand — modern, slick, dark, premium mobile sports. Not trashy neon; not photoreal UI chrome. Confident typography, restrained glow, tactile depth.  
**Brand north star:** Feels premium enough for partner shop integration (Wilson, Nike, etc.) and aligns visually with the [Avatar & Court Visual Overhaul Plan](./AVATAR_OVERHAUL_PLAN.md).  
**User feedback driving this:** Bottom tabs feel “2011 Android”; buttons and fonts need upgrading; colors are scattered and inconsistent.

---

## 1. Goals & Non-Goals

### Goals
- Establish a **single design system** (tokens + reusable components) so every screen reads as one XIV product, not a collection of one-offs.
- Replace ad-hoc `Color.cyan` / `Color.white.opacity(0.04)` / inline gradients with **semantic tokens** and shared button/card styles.
- Redesign **RallyNavBar** from labeled bottom tabs to a premium dock-style navigation that feels 2025 iOS-native, not legacy Android.
- Unify **typography hierarchy** — display, headline, body, caption, button label — with consistent weights and tracking.
- Preserve all existing flows: auth, locker → play, shop equip, logbook, courts atlas, game session, sync.

### Non-Goals (this overhaul)
- Replacing SpriteKit gameplay visuals (`GameScene`, particles, court backdrop) — UI chrome only; gameplay palette may be aligned in a follow-up pass.
- Rebuilding RealityKit avatar stage (covered by avatar plan).
- Adding light mode (dark-only is intentional for XIV brand).
- Custom icon font or full rebrand of app icon / marketing site.
- Changing SwiftData models, API sync payloads, or navigation structure (still 3 tabs + full-screen play).

---

## 2. Current State Audit (Phase 0)

### Shell & navigation

| Area | Location | Current state | Issues |
|------|----------|---------------|--------|
| App shell | `Rally/App/ContentView.swift` | `ZStack` + bottom `RallyNavBar`; `Color.black` background; 62 pt bottom padding | Hardcoded padding; no shared surface token |
| Bottom tabs | `Rally/App/RallyNavBar.swift` | 3 equal columns, icon + 10 pt label, cyan capsule selection | Reads as dated labeled tab bar; gradient hairline only polish |
| Root / loading | `Rally/App/RootView.swift` | Black + cyan `ProgressView` | Fine functionally; not on-brand typography |
| Auth gate | `Rally/Features/Auth/AuthView.swift` | Segmented login/register; flat cyan primary; stroked secondary | Duplicate button patterns; system segmented control styling |

### Feature screens

| Screen | Location | Typography | Colors / surfaces | Buttons |
|--------|----------|------------|-------------------|---------|
| **Locker** | `Rally/Features/Shop/LockerHubView.swift` | Mixed `.rounded` weights (heavy title3, caption) | Gradient bg `Color(red:0.03…)`; cards `white.opacity(0.04)` | Custom **Play Now** hero CTA (72 pt, cyan gradient); toolbar icon buttons |
| **Logbook** | `Rally/Features/Logs/LogbookView.swift` | System nav title; segmented picker default | `Color.black` flat | Journal compose icon only |
| **Courts** | `Rally/Features/Courts/CourtsMapView.swift` | caption2 helper text | Green radial map pins; system map chrome | Globe toolbar button |
| **Court detail** | `Rally/Features/Courts/CourtDetailView.swift` | `.rounded` titles; caption labels | Black bg; cyan/pink/green accents ad hoc | Unlock / check-in CTAs inline |
| **Game chrome** | `Rally/Features/Play/GameSessionView.swift` | `.subheadline.semibold` | `.ultraThinMaterial` capsules | Court picker `Menu`; exit `xmark` circle |
| **Game Over** | `Rally/Features/Play/GameOverView.swift` | 96 pt rounded score; heavy tracking on labels | Cyan radial backdrop; yellow/pink/cyan stat tints | Play Again gradient; stroked reflection; text exit |
| **Shop detail** | `Rally/Features/Shop/ShopItemDetailView.swift` | `.rounded` headlines | Cyan equip; stroked buy link | Equip / Equipped / Link trinity — third pattern |
| **Avatar setup** | `Rally/Features/Avatar/AvatarCustomizerView.swift` | Welcome hero largeTitle; section captions | Cyan selection rings | CTA mirrors Auth primary |
| **Training / Match / Journal** | `TrainingLogView`, `MatchLogView`, `JournalView`, editors | List + `.insetGrouped`; cyan `+` icons | Black bg; minimal card styling | System list rows; borderedProminent copy in shop |

### Shared / scattered primitives

| Primitive | Location | Notes |
|-----------|----------|-------|
| **Chip** | `AvatarCustomizerView.swift` (also used in Locker category filter) | Cyan fill selected / white 8% unselected — not tokenized |
| **SoundToggleButton** | `Rally/Managers/AudioPreferences.swift` | 36 pt circle, cyan when on — duplicated toolbar pattern |
| **PlayNowButtonStyle** | `LockerHubView.swift` (private) | Scale + brightness press — should be global |
| **Color(hex:)** | `AvatarCustomizerView`, `ShopCatalog`, cosmetics | Extension exists but UI does not centralize palette |
| **Theme / tokens** | *None* | **No `Theme.swift` or `DesignTokens`** — ~50+ hardcoded `Color.cyan` / `Color(red:)` across SwiftUI files |

### Typography audit summary

- **Dominant pattern:** `.font(.system(..., design: .rounded))` with inconsistent size/weight pairs.
- **System defaults** appear in: `AuthView` headline, `CourtDetailView` body, `CourtsMapView` captions, list content in logbook subviews.
- **No scale:** Title sizes vary (title2 vs title3 vs largeTitle) without documented roles.
- **Tracking / kerning:** Used decoratively in Game Over and welcome hero (`tracking(2–4)`) but not systematized.
- **Monospaced:** Score counters and promo codes only — good; extend to stats where appropriate.

### Color audit summary

| Usage | Approx. occurrences | Examples |
|-------|---------------------|----------|
| `Color.cyan` accent | 40+ across 20 files | Toolbar icons, chips, CTAs, toggles |
| `Color.black` background | Every major view | Flat or gradient to near-black |
| `Color.white.opacity(0.04–0.08)` surfaces | Cards, rows, inputs | No elevation ladder |
| `Color(red:green:blue:)` one-offs | Nav bar, locker bg, Play gradient | Not reusable |
| Semantic colors | Ad hoc | `.orange` guest banner, `.yellow` coins, `.pink` streak, `.green` map pins |

### Phase 0 checklist (execute before visual migration)
- [ ] Screenshot baseline: Locker, Logbook (3 segments), Courts map, Game Over, Auth, Avatar customizer, Shop detail.
- [ ] Grep inventory: `Color.cyan`, `Color(red:`, `.font(.system`, `RoundedRectangle(cornerRadius:` — attach counts to PR.
- [ ] Confirm iOS 17+ only (`@Observable`, SwiftData) — SF Pro variable weights available.
- [ ] Decide feature flag: `rally.uiOverhaulEnabled` for side-by-side QA (optional; tokens can ship without flag).
- [ ] Document bottom safe-area + nav height (currently ~62 pt content inset) for new dock spec.
- [ ] Cross-reference avatar plan accent cyan — UI tokens must match gameplay hit-quality cyan where they meet (locker → play → game over).

---

## 3. Design Direction — XIV Visual Language

### Brand pillars
1. **Dark depth, not flat black** — layered surfaces (base → surface → elevated → overlay) with subtle cool undertone (#0A0C12 family), not pure `#000`.
2. **Electric accent, used sparingly** — cyan/teal is the Rally/XIV signature; pair with ice-white text and muted blue-gray secondary text.
3. **Premium tactility** — continuous corner radii, hairline borders with gradient opacity, soft shadow on hero CTAs only (not every card).
4. **Typography with authority** — SF Pro Display weight for hero numbers; SF Pro Text/Rounded for UI labels; tight hierarchy, generous line-height on body.
5. **Motion with purpose** — spring on tab selection, stagger on Game Over (keep); respect Reduce Motion.

### What “not 2011 Android” means for nav
- **Avoid:** equal-width columns, small all-caps labels under icons, heavy capsule selection pills spanning full tab width.
- **Prefer:** floating dock bar with blur/material, **icon-first** with optional micro-label on selection only, center-weighted Locker tab or elevated Play affordance, 1 pt luminous top edge (keep but refine gradient stops from tokens).

### Spacing grid
- Base unit: **4 pt**; standard increments: 8, 12, 16, 20, 24, 32, 40.
- Screen horizontal padding: **20 pt** (Locker/Auth already close; standardize).
- Section vertical rhythm: **16 pt** between groups, **24 pt** before major CTAs.
- Nav dock height: target **56–60 pt** content + safe area; content inset must match.

### Corner radii
| Token | Value | Use |
|-------|-------|-----|
| `radiusSM` | 10 | Inputs, small chips |
| `radiusMD` | 14 | Cards, secondary buttons |
| `radiusLG` | 20 | Hero Play CTA, dock |
| `radiusPill` | 999 | Pills, tab indicators |

### Motion
| Interaction | Spec |
|-------------|------|
| Button press | scale 0.97, brightness −4%, 120 ms ease-out (existing PlayNow pattern) |
| Tab switch | cross-fade content 200 ms; icon scale 1.0 → 1.08 selected |
| Game Over entrance | keep existing stagger; wire durations to tokens |
| Reduce Motion | disable scale; opacity-only transitions |

---

## 4. Typography System

### Font strategy (iOS 17+)
- **Primary UI:** SF Pro (default design) for body, labels, navigation — better readability at small sizes.
- **Display / marketing moments:** SF Pro **Rounded** for scores, welcome hero, Game Over headline — sporty but native.
- **Optional bundled display font:** Only if brand team supplies a licensed face (e.g. custom XIV wordmark font). **Default recommendation: no bundled font** — reduces bundle size and maintains iOS-native feel. Use `.system(..., design: .rounded)` + weight discipline instead.

### Type scale (semantic roles)

| Token | Font | Weight | Size | Tracking | Use |
|-------|------|--------|------|----------|-----|
| `displayXL` | Rounded | Heavy | 96 | −1 | Game Over score |
| `displayLG` | Rounded | Heavy | 34 | 0 | Welcome hero |
| `title1` | Rounded | Bold | 28 | 0 | Screen titles (custom nav) |
| `title2` | Rounded | Bold | 22 | 0 | Section headers, shop item name |
| `title3` | Rounded | Semibold | 20 | 0 | Play CTA title |
| `headline` | Default | Semibold | 17 | 0 | Button labels, row titles |
| `body` | Default | Regular | 17 | 0 | Paragraphs, court detail |
| `callout` | Default | Medium | 16 | 0 | Secondary actions |
| `subheadline` | Default | Medium | 15 | 0 | Subtitles under CTAs |
| `caption` | Default | Medium | 12 | +0.2 | Meta, helper text |
| `caption2` | Default | Semibold | 11 | +0.5 | Uppercase labels, tab micro-copy |
| `overline` | Rounded | Bold | 11 | +2.0 | “NEW BEST”, section kicker |

### Minimum tap targets
- All interactive controls: **44 × 44 pt** minimum (HIG).
- Toolbar icon buttons: 36 pt visual in 44 pt hit area (SoundToggle already close).
- Dock tabs: full column width but minHeight 44.

### Implementation
```swift
// Rally/Design/Typography.swift (proposed)
enum RallyFont {
    static func displayXL() -> Font { .system(size: 96, weight: .heavy, design: .rounded) }
    static func headline() -> Font { .system(.headline, design: .default).weight(.semibold) }
    // …
}
```
Prefer `View.rallyFont(_:)` modifier wrapping `Environment(\.rallyTypography)` for testability.

---

## 5. Color System — Semantic Tokens

### Core palette (dark XIV)

| Token | Hex / value | Role |
|-------|-------------|------|
| `backgroundBase` | `#050608` | Root scaffold (`ContentView`, `RootView`) |
| `backgroundElevated` | `#0A0C12` | Nav dock gradient top |
| `surfacePrimary` | `#12151C` @ 100% | Cards, sheets |
| `surfaceSecondary` | `#FFFFFF` @ 6% | Legacy card fill — migrate to surfacePrimary |
| `surfaceOverlay` | `#FFFFFF` @ 4% | Subtle rows |
| `borderSubtle` | `#FFFFFF` @ 10% | Card strokes |
| `borderAccent` | accent @ 35% | Selected tiles |
| `textPrimary` | `#F4F7FA` | Headlines, body |
| `textSecondary` | `#FFFFFF` @ 55% | Captions, hints |
| `textTertiary` | `#FFFFFF` @ 35% | Disabled, legal copy |
| `accentPrimary` | `#00E5FF` (cyan tuned) | Links, selected nav, toggles |
| `accentSecondary` | `#00B8D4` | Gradient start |
| `accentGlow` | accent @ 45% | Hero CTA shadow |
| `success` | `#34D399` | Unlock collected, positive states |
| `warning` | `#FBBF24` | Guest offline banner (replace orange) |
| `error` | `#F87171` | Auth errors |
| `rewardGold` | `#FCD34D` | Coins |
| `rewardXP` | accentPrimary | XP bolts |
| `streak` | `#F472B6` | Streak chip (refined pink) |

### Gradients (named, not inline)

| Token | Stops | Use |
|-------|-------|-----|
| `gradientPlayCTA` | accentSecondary → accentPrimary → `#8EF6FF` | Play Now, Play Again |
| `gradientBackground` | `#080A10` → backgroundBase | Locker, scroll screens |
| `gradientNavHairline` | accent @ 35% → white @ 8% | Dock top edge |
| `gradientXPBar` | accent → streak | Player level strip |

### Swift structure (proposed)
```swift
// Rally/Design/RallyTheme.swift
enum RallyTheme {
    enum ColorToken {
        static let backgroundBase = Color(hex: 0x050608)
        static let accentPrimary = Color(hex: 0x00E5FF)
        // …
    }
    enum GradientToken {
        static var playCTA: LinearGradient { … }
    }
}
```

Provide `Color` hex initializer once in `Color+Rally.swift`; **ban** new raw `Color(red:green:blue:)` in feature views after Phase 1.

---

## 6. Component Catalog

All new components live under `Rally/Design/Components/`.

### Buttons

| Component | Variants | Replaces |
|-----------|----------|----------|
| **RallyPrimaryButton** | default, loading, disabled | Auth submit, Avatar save, Equip, Play Again, Game Over primary |
| **RallySecondaryButton** | stroked accent | Continue offline, Log reflection, Buy at brand |
| **RallyGhostButton** | text only | Back to Locker, tertiary links |
| **RallyDestructiveButton** | red subtle fill | Sign out (in menu — optional) |
| **RallyIconButton** | 36/44 pt, material bg | Toolbar icons, sound toggle, close game |
| **RallyPlayNowButton** | large hero, icon + subtitle + arrow | Locker floating CTA — extends Primary with fixed layout |

**Shared behavior:** `RallyButtonStyle` — press scale, haptic light impact on primary only.

### Navigation

| Component | Spec |
|-----------|------|
| **RallyTabBar** (rename/refactor `RallyNavBar`) | Floating dock, material background, icon-first, accent dot or underline indicator (not full-width capsule), optional haptic on selection |
| **RallyNavigationBar** | Inline title styling token; trailing icon cluster spacing 12 pt |

### Filters & inputs

| Component | Spec |
|-----------|------|
| **RallyChip** | Refactor `Chip` — uses surface + accent border when selected; typography `callout` |
| **RallySegmentedControl** | Custom or styled wrapper replacing raw `.segmented` in Logbook/Auth/Courts — surface track, accent thumb |
| **RallyTextField** | Auth + Avatar name field — unified padding, focus ring accent |

### Cards & lists

| Component | Spec |
|-----------|------|
| **RallyCard** | surfacePrimary, radiusMD, borderSubtle, optional glow flag |
| **RallyListRow** | Shop row, training row — thumbnail slot, title, subtitle, trailing chevron |
| **RallyStatTile** | Game Over stats, player strip stats — consistent padding 18 vertical |
| **RallyRewardChip** | Coins / XP strip |
| **RallyBanner** | Guest offline, errors — warning/error tokens |

### Misc

| Component | Spec |
|-----------|------|
| **RallySoundToggle** | Rename/refactor `SoundToggleButton`; uses `RallyIconButton` |
| **RallyProgressBar** | XP bar, segment accuracy — height 4/8 pt variants |
| **RallyEmptyState** | Icon + title + subtitle pattern for empty logs |

---

## 7. Screen-by-Screen Migration

### 7.1 ContentView & shell
- Apply `backgroundBase` + `gradientBackground` at root.
- Replace hardcoded `padding(.bottom, 62)` with `RallyMetrics.tabBarContentInset`.
- Inject `@Environment(\.rallyTheme)` (optional) for child consistency.

### 7.2 RallyNavBar → RallyTabBar
- Redesign dock: blur material, rounded top corners radiusLG, inset horizontal 12 pt.
- Selected state: accent icon + 9 pt label fade-in (not always-on labels).
- Unselected: secondary text @ 50% opacity.
- Keep three destinations; do not add tabs.

### 7.3 LockerHubView
- Swap `playNowButton` → `RallyPlayNowButton`.
- `playerStrip` → `RallyCard` + `RallyProgressBar` + stat pills using reward tokens.
- `shopRow` → `RallyListRow`; EQUIPPED badge → accent capsule token.
- `guestOfflineBanner` → `RallyBanner` warning variant.
- Toolbar: `RallyIconButton` cluster.
- Category filter: `RallyChip` horizontal scroll.

### 7.4 LogbookView + subviews
- Replace segmented picker with `RallySegmentedControl`.
- `TrainingLogView` / `MatchLogView` / `JournalView`: unify list row styling via `RallyListRow`; empty states via `RallyEmptyState`.
- Journal compose: `RallyIconButton`.
- Consider pinned segment header on scroll (optional polish).

### 7.5 CourtsMapView + CourtDetailView
- Map pins: use accent/success tokens instead of raw green; add subtle pulse on selected (respect Reduce Motion).
- Layer picker → `RallySegmentedControl` floating panel with `RallyCard` background (readable over map).
- Court detail: typographic hierarchy from tokens; unlock CTA → `RallyPrimaryButton`; referral links → `RallySecondaryButton`.

### 7.6 GameSessionView (chrome only)
- Court picker pill → `RallyChip` or compact `Menu` styled with surface + border.
- Exit button → `RallyIconButton` destructive tint optional.
- Do not obstruct playfield hit targets (keep top bar only).

### 7.7 GameOverView
- Wire all fonts to typography tokens.
- Stat tiles / reward chips → shared components.
- Action stack → Primary / Secondary / Ghost buttons.
- Backdrop radial uses `accentGlow` token.

### 7.8 AuthView
- Header icon treatment: accent ring or subtle gradient orb.
- Form fields → `RallyTextField`.
- Primary / offline → Primary / Secondary buttons.
- Segmented mode → `RallySegmentedControl`.
- Error text → `error` token.

### 7.9 AvatarCustomizerView
- Welcome hero → displayLG + overline kicker tokens.
- CTA → `RallyPrimaryButton`.
- Chips → `RallyChip`.
- Selection rings → `borderAccent`.

### 7.10 ShopItemDetailView + ShopView
- Equip / buy / equipped states → button catalog.
- Vendor card → `RallyCard`.
- Remove `.borderedProminent` system button on copy — use `RallySecondaryButton` small variant.

### 7.11 RootView loading
- Branded splash: wordmark or tennis mark + `RallyFont.headline` “Loading…”

---

## 8. Implementation Phases

### Phase 0 — Audit & scaffolding (no visual change)
- [ ] Complete Phase 0 checklist (§2).
- [ ] Add `Rally/Design/` folder structure.
- [ ] Add grep-based lint note in PR template: no new hardcoded `Color.cyan`.

### Phase 1 — Tokens in Swift (`Theme.swift` / `DesignTokens`)
- [ ] `Color+Rally.swift` — hex initializer (consolidate existing).
- [ ] `RallyTheme.swift` — ColorToken, GradientToken.
- [ ] `Typography.swift` — RallyFont + view modifier.
- [ ] `RallyMetrics.swift` — spacing, radii, tab bar inset.
- [ ] `RallyThemeEnvironment.swift` — `EnvironmentValues.rallyTheme`.
- [ ] Unit test: token contrast pairs documented (see Phase 4).

**Files created (expected):**
- `Rally/Design/RallyTheme.swift`
- `Rally/Design/Typography.swift`
- `Rally/Design/RallyMetrics.swift`
- `Rally/Design/Color+Rally.swift`
- `Rally/Design/RallyThemeEnvironment.swift`

### Phase 2 — Nav + buttons
- [ ] `RallyPrimaryButton`, `RallySecondaryButton`, `RallyGhostButton`, `RallyIconButton`.
- [ ] `RallyPlayNowButton`.
- [ ] Refactor `RallyNavBar` → `RallyTabBar`.
- [ ] Refactor `SoundToggleButton` → `RallySoundToggle`.
- [ ] Migrate Auth + Avatar CTA + Game Over actions.

### Phase 3 — Screens
- [ ] LockerHubView full migration.
- [ ] Logbook stack (segment + lists + empty states).
- [ ] Courts map + detail.
- [ ] Game session chrome.
- [ ] Shop detail + shared shop row component.
- [ ] Root loading state.

### Phase 4 — Polish & motion
- [ ] `RallyButtonStyle` haptics alignment with `HapticManager`.
- [ ] Tab switch animations.
- [ ] Hero CTA shadow from `accentGlow` token only.
- [ ] **Accessibility contrast audit:** all text/background pairs ≥ WCAG AA (4.5:1 body, 3:1 large type); document exceptions (decorative map overlays).
- [ ] VoiceOver labels on new components.
- [ ] Reduce Motion QA pass.

### Phase 5 — Cleanup
- [ ] Remove duplicate `Chip` / inline button code.
- [ ] Grep verification: zero `Color.cyan` in Features/ (except Theme).
- [ ] Update SwiftUI previews with `RallyThemePreview` wrapper.
- [ ] Screenshot diff vs Phase 0 baseline.

---

## 9. Technical Approach

### SwiftUI Theme enum
```swift
struct RallyTheme: Equatable {
    var colors: RallyColors
    var typography: RallyTypography
    var metrics: RallyMetrics
}

private struct RallyThemeKey: EnvironmentKey {
    static let defaultValue = RallyTheme.standard
}

extension EnvironmentValues {
    var rallyTheme: RallyTheme {
        get { self[RallyThemeKey.self] }
        set { self[RallyThemeKey.self] = newValue }
    }
}
```

Apply once in `RallyApp` or `RootView`:
```swift
.environment(\.rallyTheme, .standard)
.preferredColorScheme(.dark)
```

### Migration rules for executing agent
1. **No new hardcoded colors** in feature views after Phase 1 merges.
2. **Replace, don’t wrap forever** — migrate call sites when touching a file; avoid double styling.
3. **SpriteKit colors** (`GameScene`, `CourtSurface`) — optional alignment pass; use shared hex constants exported to UIKit if syncing brand cyan.
4. **Previews:** every component gets `#Preview { … }` on dark background.
5. **XcodeGen:** add `Rally/Design/**` to `project.yml` sources if not auto-included.

### Avoid
- Scattered `Color(hex:)` in views — only in `RallyTheme.swift`.
- Copy-pasting `LinearGradient(colors: [Color.cyan, …])` — use `GradientToken.playCTA`.
- Mixing `.rounded` on every label — use scale (§4).

---

## 10. Brand & Marketing Alignment

- **Partner shop integration:** Locker and Shop detail must feel like a premium storefront — consistent card elevation, brand names in `textSecondary`, prices in `accentPrimary`, vendor links as Secondary buttons. Visual parity with avatar plan’s “recognizable at thumbnail size” standard.
- **XIV premium dark:** Same cool undertone as future RealityKit locker IBL — UI surfaces should not clash with avatar stage lighting (avoid warm gray cards).
- **Share/marketing:** When avatar plan adds “Share look” snapshot, UI chrome around share sheet should already be tokenized (Phase 2+).
- **Cross-doc dependency:** Execute UI Phase 1–2 before or in parallel with Avatar Phase 1 so Locker stage + nav feel cohesive in screenshots.

---

## 11. Do Not Break

| System | Constraint |
|--------|------------|
| Gameplay | No changes to touch handling, scene layout, or `GameSessionView` full-screen cover lifecycle |
| Sync | Auth, equip, game-over save, journal edits — no API or SwiftData schema changes |
| Navigation | Still 3 tabs; Play remains full-screen cover from Locker |
| Court unlock / check-in | Business logic in `CourtUnlocks`, `CourtCheckIn` untouched |
| Audio / haptics | `AudioPreferences`, `HapticManager` behavior unchanged — UI only reskins toggle |
| Guest mode | Offline banner must remain visible and readable |
| Accessibility | Do not reduce contrast vs today on primary actions; Phase 4 must pass AA |
| Tests | Existing XCTest must pass; add snapshot/token tests only if low-cost |

---

## 12. Module & File Map (post-overhaul target)

```
Rally/
  Design/
    RallyTheme.swift
    RallyThemeEnvironment.swift
    Typography.swift
    RallyMetrics.swift
    Color+Rally.swift
    Components/
      RallyPrimaryButton.swift
      RallySecondaryButton.swift
      RallyGhostButton.swift
      RallyIconButton.swift
      RallyPlayNowButton.swift
      RallyTabBar.swift          # replaces RallyNavBar.swift
      RallyChip.swift
      RallySegmentedControl.swift
      RallyTextField.swift
      RallyCard.swift
      RallyListRow.swift
      RallyStatTile.swift
      RallyBanner.swift
      RallySoundToggle.swift
      RallyEmptyState.swift
  App/
    ContentView.swift            # uses tokens + inset metrics
    RallyNavBar.swift            # DELETE after RallyTabBar ships
  Features/                      # migrated to components — no local button structs
```

---

## 13. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tab bar redesign disorients existing users | Confusion | Keep same three icons/order; beta screenshot review |
| Token migration half-done | Visual inconsistency | Phase gate: no screen PR without component adoption checklist |
| Custom segmented control bugs | Logbook regressions | Wrap UIKit `UISegmentedControl` appearance if SwiftUI custom proves fragile |
| Over-glow “trash neon” | Off-brand | Limit glow to Play CTA + Game Over; cards stay matte |
| Map readability | Pins invisible | Test hybrid/satellite modes; pin contrast independent of UI tokens |
| Contrast failures on caption text | A11y rejection | Phase 4 audit with Accessibility Inspector |

---

## 14. Milestone Checklist (scope, not dates)

- [ ] **M0:** Phase 0 audit + screenshot baseline.
- [ ] **M1:** Design tokens merged; no user-visible change required.
- [ ] **M2:** Button catalog + RallyTabBar live; Auth + Game Over migrated.
- [ ] **M3:** Locker + Shop detail on new system.
- [ ] **M4:** Logbook + Courts complete.
- [ ] **M5:** Zero hardcoded `Color.cyan` in Features/.
- [ ] **M6:** Accessibility contrast audit signed off.
- [ ] **M7:** Old `RallyNavBar` / duplicate Chip removed.

---

## 15. Acceptance Criteria (definition of done)

- Bottom navigation reads **premium iOS 2025**, not labeled Android tabs — validated by stakeholder review against “2011 Android” feedback.
- **One primary button style** across Auth, Avatar, Shop equip, Game Over, Play Again.
- All feature screens use **semantic color tokens** exclusively.
- Typography follows documented scale; no arbitrary `.font(.system(size:))` in migrated files.
- WCAG AA contrast on primary text and CTAs.
- No regression to gameplay, sync, auth, or shop equip persistence.
- Locker → Play → Game Over loop feels visually continuous (shared accent gradient on CTAs).

---

## 16. Suggested Agent Execution Order

1. Phase 0 grep + screenshots.
2. Create `Rally/Design/` tokens (Phase 1).
3. Build button components + previews (Phase 2).
4. Ship `RallyTabBar`; swap in `ContentView`.
5. Migrate Auth + Game Over (high-visibility CTAs).
6. Migrate LockerHubView (hero CTA + shop rows).
7. Logbook segmented + lists.
8. Courts map overlay + detail.
9. Game session chrome + Shop detail.
10. Phase 4 accessibility + Reduce Motion.
11. Delete legacy nav + grep cleanup.

---

## 17. Agent Handoff Prompt

A copy-paste prompt for another AI agent lives in **[`CODEX_PROMPT_UI.md`](./CODEX_PROMPT_UI.md)**.

---

*Document owner: Rally iOS team. Execute phases in order; do not skip Phase 0 audit. Coordinate with [AVATAR_OVERHAUL_PLAN.md](./AVATAR_OVERHAUL_PLAN.md) for Locker stage cohesion.*
