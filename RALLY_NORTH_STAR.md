# RALLY NORTH STAR

## Purpose

Rally is a premium tennis iOS game built around one tight loop:

Choose a fixed athlete, dress them in desirable real tennis gear, play a 20-second rally against your own double that teaches timing and rhythm, then carry that identity into training logs, gear discovery, and court culture.

The game must feel professional, stylish, athletic, kid-safe, and alive. It cannot feel like a prototype, a puppet show, a dashboard, or a generic mobile skin shop.

This file is the repo's tiebreaker. If an old prompt, comment, branch, agent note, or design document conflicts with this file, this file wins.

## Product Shape

Rally has six connected pillars:

1. Gameplay: a 20-second Mirror Rally with readable depth, timing, contact, recovery, and body mechanics.
2. Avatar: one canonical player identity shared by Home, Locker, Shop try-on, World, and GameScene.
3. Loadout: a Fortnite-style pregame surface where the player sees court, outfit, racket, handedness, and PLAY.
4. Shop: real tennis gear, real product imagery, try-on first, referral commerce second.
5. Locker: wardrobe mode for owned or try-on gear, not store mode; no prices in Locker.
6. Journal: training history and real-life tennis memory, inspired by Garmin Connect but built for Rally.

## Architecture Laws

1. There is one avatar identity source.
2. GameScene may simplify rendering, but it must consume the same avatar appearance data as Home and Shop.
3. No screen may draw its own duplicate avatar from scratch.
4. Gear selection writes to the shared appearance store.
5. Shop creates desire; Locker resolves ownership and outfit selection.
6. Promotional copy is noise; functional copy is infrastructure.
7. Gameplay owns the ball through explicit lifecycle states; no double-driving position, scale, or shadow.
8. Every outbound commerce or venue link goes through `RallyReferralLinkRouter`.
9. Every task ends with a build unless it is documentation-only.
10. Screenshots beat claims. If the screenshot looks wrong, it is wrong.

## Canonical Avatar

The canonical Rally player is:

- young
- athletic
- friendly
- stylish
- grounded
- expressive
- safe for kids
- premium enough for a paid tennis game

The avatar must never read as:

- bald unless explicitly selected
- old
- scary
- devilish
- hostile
- deformed
- floating
- humpbacked
- diaper-shaped
- stick-legged
- disconnected at hips, knees, shoulders, wrists, or ankles
- a different person between Home and gameplay

Current ground truth:

- Production character geometry is the CC0 anatomical mesh in `Rally/Resources/Avatar3D/`; `RallyAvatarRig.swift` owns its shared skeleton, garment materials, and articulated poses.
- The roster is six fixed adult tennis athletes: three men and three women, each with White/European, Asian and Black representation. Models have generic labels, with simple skin-tone and hair-color swatches. Body dimensions, facial geometry and hairstyles stay fixed for consistent garment fit; clothing is the focus.
- `scripts/prepare_avatar_assets.py` reproducibly fits garments to two lean athletic bodies (one per sex), with distinct authored faces and textures for the six presets. Source hashes and licensing are recorded beside the assets.
- Defaults live in `Rally/Features/Avatar/RallyAvatarRebuildDefaults.swift`.
- SwiftUI surfaces render through `RallyAvatarView`.
- Gameplay embeds the same `RallyAvatarRig` with `SK3DNode` for player and opponent. It uses the projected racket for contact placement; character shape does not change input timing grades.
- Home presents a grounded, rhythmic tennis-ready stance. Shop/Locker support rotation and zoom for garment inspection.
- Generic silhouettes are labeled style previews. RallyGarmentCatalog maps exact brand/style/colorway references to separate male/female garment assets; reference photos alone never imply a completed digital garment. See RALLY_CLOTHING_MODELING.md for the first six verified product references.

Quality target:

- face visible and friendly at iPhone size
- jet-black styled hair with clear silhouette
- neck connects head to torso
- shoulders and hips read anatomically
- arms connect to shoulders, hands connect to wrists
- thighs, knees, calves, ankles, and shoes read clearly
- feet plant on the court plane
- ready stance has rhythm, not mannequin stillness

## Gameplay Feel Contract

The current build target is a 20-second Mirror Rally that feels satisfying enough to immediately play again. The far player uses your same athlete and outfit, automatically answering each successful shot. Swipe upward anywhere to time contact; horizontal flick direction aims the outgoing ball. Both players must step toward their next contact, plant, and recover.

The implementation remains a prototype until a person validates its timing, legibility, and replay appeal on a phone. See `RALLY_MIRROR_RALLY.md` for the current build and verification status.

The player must read:

- ball traveling away to the player’s double
- the double’s racket meeting and returning the ball
- ball accelerating back toward the player
- the avatar preparing before contact
- forehand and two-handed backhand as distinct mechanics
- racket meeting the ball at the contact frame
- weight transfer through feet, hips, torso, shoulder, wrist, and racket

Gameplay priorities:

1. Readable depth: ball scale, shadow, court perspective, wall plane.
2. Contact payoff: hit-stop, flash, sparks, sound, haptic, timing text.
3. Body mechanics: feet plant, hips lead, torso uncoils, wrist snaps, recovery resolves.
4. Alternation: rallies should force forehands and true two-handed backhands.
5. Miss clarity: early, late, side, move, and miss states must be obvious without HUD bloat.

Top chrome in gameplay:

- simple score
- simple exit
- no heavy card covering play
- no exit button on top of score
- no decorative UI fighting the court

## Home And Loadout

Home is the pregame hub. It should feel like a premium loadout screen, not a settings form.

Must stay:

- centered avatar stage
- selected court
- handedness
- racket/top/shorts/shoes/socks/headband/bag slots as the model supports them
- clear PLAY dock
- optional quiet Journal/This Week strip

Must not return:

- dashboard copy
- game mode clutter
- cheap default SwiftUI controls
- mismatched avatar identity
- rainbow tile chaos
- cramped bottom controls

The dressed avatar is the communication.

## Shop And Locker

Shop:

- desirable product browsing
- real product names
- real product imagery
- prices visible
- Try On and Shop CTAs
- referral link through router
- no generic product placeholder as final state

Locker:

- wardrobe and fitting floor
- no prices
- Wear or Equip language
- owned and try-on feeling
- current outfit clearly visible

The Shop bottleneck is product/stage quality, not extra copy.

## Journal

Journal makes Rally more than a game. It records tennis life.

Minimum product shape:

- auto-log in-app rally sessions
- calendar-style weekly/monthly history
- manual training notes
- venue/court association
- gear worn in session
- simple performance metrics

Garmin integration should be architected behind a source protocol:

- manual entries
- in-app rally entries
- future Garmin imports

Build now with stubs; plug real Garmin API after approval.

## Monetization

Rally can monetize through:

- paid app or subscription
- referral commerce for physical tennis gear
- premium cosmetic/identity packs if they are digital goods and use Apple IAP
- partnerships with tennis venues, coaches, and camps later

Physical goods purchased through external links are allowed to leave the app through Safari-style flows. Referral links need clear disclosure near product surfaces.

## Current Priority Order

1. Fix gameplay player credibility: face, hair, joints, feet, knees, racket grip, and two-handed backhand.
2. Fix gameplay camera/physics feel: depth, wall, return acceleration, hit feedback, top chrome.
3. Make Home/Loadout feel like a designed premium loadout surface.
4. Make outfit selection reliable and seamless across top, shorts, shoes, racket, and future slots.
5. Improve Shop with real products and strong visual hierarchy.
6. Add Journal polish and Garmin-ready architecture.
7. Improve World/Courts links, safe area, and marker clarity.

Do not chase broad new features before priority 1 and 2 feel credible.

## Agent Rules

1. Start every session by confirming path, commit, branch, status.
2. Read this file before making changes.
3. Keep changes scoped to the active task.
4. Do not edit another agent's lane unless asked.
5. Do not stage screenshots, derived data, videos, or generated artifacts unless explicitly requested.
6. Build after code changes.
7. If a simulator screenshot contradicts the claim, patch again.
8. Prefer one strong visual change over five weak ones.
9. Use named constants for tunables.
10. Leave the repo better organized than you found it.

## Exit Tests

Avatar:

- Home and gameplay look like the same person.
- Feet are planted.
- Face is friendly.
- Hair is visible.
- Joints connect.
- Racket is held.

Gameplay:

- Forehand and two-handed backhand are visibly different.
- Ball depth is readable.
- Wall contact is readable.
- Return acceleration feels urgent.
- Contact feels punchy.
- Top chrome is only score and exit.

Home:

- PLAY is obvious.
- Loadout slots are usable.
- Outfit changes are visible.
- Buttons and chips look designed, not default.

Shop:

- Product cards use real merchandise imagery.
- Try On changes the avatar.
- Shop opens in-app Safari through the router.

Journal:

- A played session creates a useful entry.
- This Week strip is readable and quiet.

