# Rally Shop — Art Direction for Desire

## The Problem With the Current Model

The shop hero is 176px of gradient with three SF Symbol icons. No avatar. No product. No emotion. The player has no reason to want anything because there's nothing to want — just labels on dark cards. Desire requires a subject to project onto, and right now there's no subject.

The fix is one clear idea: **the avatar is the model, the court is the stage, and every item is a piece of identity.**

---

## The Visual Model: "Locker Room Before the Match"

The feeling to design toward: you are standing in front of a mirror in the locker room at Wimbledon, dressed and ready. The racket is in your hand. The match is in 10 minutes. You look exactly like someone who belongs on that court.

That's the emotional state the shop should produce.

---

## Hero Stage — Replace the 176px Block

**Current:** 176px gradient container with shoe/shirt/racket icons. Avatar not present.

**Target:** Full-height avatar stage (420–480px). The avatar stands center frame, fully dressed in the currently equipped outfit, on a court-floor horizon. The background accent shifts with the active court (clay = warm terracotta glow, grass = cool green rim light, hard = electric blue floor reflection).

Specific changes to `PremiumAvatarStageContainer` / `AvatarShopStageView`:
- Increase stage height to 420–480px in the shop context
- Add a court-surface floor plane at the avatar's feet (a subtle perspective rectangle in the surface color — clay, grass, or hard)
- Add a split key/fill lighting effect: one light from top-left (white, editorial), one rim light from behind (surface accent color)
- Avatar pose: shift from neutral stand to a slightly open "ready position" — weight forward, racket raised slightly. This reads as athletic, not mannequin.
- When a new item is equipped, run a 0.3s "flash-on" animation: the item appears with a brief brightness flare and a scale pulse (1.0 → 1.04 → 1.0). Makes equipping feel like an event.

---

## Item Cards — Replace Icon Silhouettes With Product Identity

**Current:** White icon silhouette on a dark pill. Category label. No brand, no color, no texture.

**Target:** Two-zone card. Top 65%: real product photo (or a high-fidelity colored illustration matching the real product's colorway and brand logo placement). Bottom 35%: item name, brand name, price.

Card design:
- Background: not black — use the product's dominant color at 8% opacity behind the photo. A cyan Nike polo card has a faint cyan field. A red Babolat cap card has a faint red field. This creates a collection feel.
- Brand logo: small, top-left corner of the card, white or brand-color
- "New" badge: cyan dot, top-right
- "Equipped" state: cyan outline stroke on the card, checkmark chip replacing the price
- "Try On" affordance: on card tap, the avatar in the hero stage above immediately wears the item before the player commits. The card gets a pulsing cyan border while try-on is active.

Card size: two columns, taller than wide (roughly 3:4 ratio). Not square — square reads like an app icon, not a product.

---

## The Try-On Flow — The Core Desire Loop

The moment a player taps a card and sees their avatar wearing the item is the moment they want it. This is the entire business model of fashion retail.

Current state: unknown whether try-on actually updates the live stage hero.

Target flow:
1. Player scrolls product grid
2. Taps any card
3. Hero stage avatar instantly updates to wear the item (no navigation, no modal — happens in place, above the grid)
4. Card gets active treatment (border, glow)
5. Item detail sheet slides up with: product photo, brand story (2 sentences), performance claim ("clay court grip pattern", "moisture-wicking match day fabric"), EQUIP button + SHOP IRL button
6. EQUIP saves to appearance store. SHOP IRL opens `RallyReferralLinkRouter` to the real product page.

The stage stays live throughout — player can scroll, try more items, and watch themselves change without leaving the screen.

---

## Performance Copy — Make Gear Feel Functional

Every item needs one performance line. Not marketing copy. Functional copy that connects gear to gameplay.

Examples:
- Wilson Clash 100 → "Flexible frame absorbs mistimed contact — forgiving on off-center hits"
- Nike Court Air Zoom Vapor → "Herringbone sole grips hard and clay — lateral pivot support"
- Adidas Ubersonic → "Reinforced toe cap for drag-foot servers — durability where it matters"
- Nike Dri-FIT Advantage Polo → "Sweat-wicking fabric stays dry through a three-set match"

This copy makes the player feel like the gear helps them play better. That's the strongest purchase motivation in sports: performance identity.

---

## Drop Culture — Create Scarcity and Urgency

Items that are always available feel low-value. Items that appear for a limited time feel like opportunities.

Add three states to the catalog:
- **Standard**: always available, no badge
- **New Drop**: appeared in the last 14 days → cyan "New" badge
- **Limited**: time-boxed → countdown chip ("Gone in 2d 14h") in rose/gold

Tie limited drops to real tennis calendar:
- Roland Garros window (May–June): clay court colorways, red and orange accents
- Wimbledon window (June–July): all-white items, grass-green accents
- US Open window (August–September): night session items, electric blue

This gives the player a reason to check the shop even when they're not buying.

---

## Outfit Bundles — Increase Intent and AOV

A player looking at individual items may feel uncertain. A player seeing a complete look — shirt, shorts, shoes, racket, bag — as one card feels inspiration.

Add a "Featured Look" section above the category grid:
- Full-width card showing the avatar in a complete outfit
- "Complete the look" label
- One-tap "Equip All" button
- Total coin cost shown

Bundle cards rotate weekly (or per-court: Wimbledon look, Roland Garros look, US Open night look).

---

## Surface Color System for the Stage Background

The avatar stage background should react to the selected court. This ties gear to place, reinforcing the locker-room-before-the-match feeling.

| Court surface | Stage accent color | Rim light |
|---|---|---|
| Hard (Australia, US Open) | Electric blue `#0066CC` at 18% | Cyan |
| Clay (Roland Garros, Barcelona) | Terracotta `#C2581A` at 15% | Warm gold |
| Grass (Wimbledon) | Deep green `#2D6B3C` at 12% | Soft white |
| Indoor hard | Cool grey `#3A3F52` at 20% | Purple-white |

---

## What to Build First (Ordered by Impact)

1. **Increase stage height and add avatar** — biggest single visual change. Currently no avatar in the shop hero. Adding it transforms the screen.
2. **Try-on live update** — wire item card tap to immediately update the hero avatar. This is the desire loop.
3. **Product colorway cards** — replace white icon silhouettes with colored product illustrations or photos. Even flat colored shapes beat white-on-dark.
4. **Performance copy** — one line per item in the catalog JSON.
5. **Surface-reactive background** — tie stage accent color to selected court.
6. **Limited drops + New badges** — add to catalog model and render on cards.
7. **Featured Look bundle card** — weekly editorial push.
