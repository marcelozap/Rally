# RALLY OVERHAUL DIRECTIVE
## Avatar Unification · Real-Merchandise Shop · World Referral Links

This is a structural overhaul, not a patch request. Do not return targeted fixes to individual symptoms. The symptoms below share root causes, and any change that does not eliminate the root cause is a failed response.

---

## SECTION 0 — AGENT BEHAVIOR RULES (NON-NEGOTIABLE)

1. Return every modified or created file IN FULL. No snippets, no "rest unchanged," no ellipses, no summaries in place of code.
2. Use the exact `// MARK: -` section headers specified per file below.
3. Before writing any code, output the complete list of files you will create, modify, and DELETE. Deletions are expected in this overhaul — duplicated avatar drawing code must be removed, not bypassed.
4. Do not declare any workstream complete until its audit gate (Section 5) passes. State each audit check and its pass/fail explicitly.
5. If you cannot complete a workstream in one response, say so up front and state exactly where you will stop. Do not silently truncate.
6. Do not invent a new avatar design. The canonical avatar already exists: the GameScene figure — young athletic male, warm light skin, jet-black Zuko-style hair, professional athletic build, confident asymmetric idle pose, per RallyAvatarRebuildDefaults. Every other avatar rendering in the app is wrong and must be replaced by the canonical one.

---

## SECTION 1 — ROOT CAUSE STATEMENT

The app currently has at least two independent avatar drawing implementations: the CGPath-based figure in GameScene (athleticLegPath, athleticShortsPath, etc.) and a separate drawing used by the Home/Loadout player screen. Because they are independent, they can never be made to match by adjustment — only by unification. Likewise, the Shop renders hardcoded placeholder visuals because no product/catalog model exists, and the World screen renders link-shaped buttons with no routing layer behind them. All three workstreams below replace missing architecture; none of them are styling tasks.

---

## SECTION 2 — WORKSTREAM A: SINGLE-SOURCE-OF-TRUTH AVATAR

### A1. RallyAvatarAppearance.swift (new)
A pure value model describing everything about the avatar's current look:
- Identity attributes: skin tone, hair style (zukoJetBlack), build (professionalAthletic), pose (confidentAsymmetricIdle) — sourced from RallyAvatarRebuildDefaults, never hardcoded elsewhere.
- Equipped gear by slot: `racket`, `top`, `shorts`, `shoes`, `socks`, `headband` — each slot holds an optional `RallyGearItem` reference (see Workstream B).
- Codable, Equatable. One shared instance owned by a `RallyAvatarAppearanceStore` (ObservableObject) injected at the app root. GameScene, Home, Loadout, Shop try-on, and World all read from this store. No surface may own its own copy.

Required MARK sections: `// MARK: - Identity Attributes`, `// MARK: - Gear Slots`, `// MARK: - Appearance Store`.

### A2. RallyAvatarGeometry.swift (new — extraction, not invention)
EXTRACT every avatar path function currently living inside GameScene (athleticLegPath, athleticShortsPath, athleticTorsoPath, head, hair, arms, racket grip — all of them) into one standalone geometry namespace, parameterized by `RallyAvatarAppearance` and a scale. GameScene must be refactored to call this shared geometry. The functions must be deleted from GameScene, not duplicated.

Required MARK sections: `// MARK: - Head & Hair`, `// MARK: - Torso`, `// MARK: - Arms & Racket Grip`, `// MARK: - Shorts`, `// MARK: - Legs & Feet`, `// MARK: - Composite Figure`.

### A3. RallyAvatarView.swift (new)
A SwiftUI view that renders the avatar from RallyAvatarGeometry via Canvas, taking `RallyAvatarAppearance` and a target height. This view becomes the ONLY way the avatar appears outside GameScene. Replace the Loadout screen avatar, the Home screen avatar, and any World/Shop avatar with RallyAvatarView. Equipped gear in the appearance store must visibly render (e.g., equipped shorts draw in the product colorway).

### A4. Deletions required
List and delete every pre-existing avatar drawing implementation outside RallyAvatarGeometry. If a screen previously used an image asset for the avatar, remove the asset reference.

---

## SECTION 3 — WORKSTREAM B: SHOP OVERHAUL TO REAL MERCHANDISE

The Shop becomes a high-fashion editorial storefront for REAL products with referral links. No placeholder icons anywhere.

### B1. RallyGearItem.swift (new)
Product model:
- `id`, `brand` (e.g., "Nike"), `name` (e.g., "Dri-FIT Slam Short — Black"), `slot` (racket/top/shorts/shoes/socks/headband), `colorwayName`, `priceDisplay` (display string, never computed math on price), `productImageURL`, `referralURL`, `accentColorHex`.
- `isOwnedForTryOn: Bool` — try-on is free; purchase happens externally via referral link.

### B2. RallyReferralCatalog.swift + RallyReferralCatalog.json (new)
- Catalog loads from a bundled JSON file so products can be revised without code changes. Include a starter catalog of at least 12 real items across all six slots (e.g., Nike Dri-FIT shorts in black, NikeCourt tops, Adidas Barricade shoes, Wilson/Babolat/Head rackets, Nike headbands and crew socks). Real product names, real product page URLs in `referralURL` with a `{REFERRAL_CODE}` placeholder token.
- `RallyReferralLinkRouter` (shared with Workstream C): single class responsible for substituting the referral code into `{REFERRAL_CODE}`, validating the URL, and presenting it in an in-app SFSafariViewController. EVERY outbound product/venue link in the entire app routes through this class. A nil or malformed URL must fail loudly in DEBUG (assertionFailure) and fall back to a disabled button state in release — never a dead tap.

Required MARK sections in the router: `// MARK: - Referral Code Injection`, `// MARK: - URL Validation`, `// MARK: - Presentation`.

### B3. Shop UI rebuild
- Editorial product cards: large product imagery (AsyncImage from `productImageURL` with a branded placeholder while loading — never a generic SF Symbol as the final state), brand lockup, product name, colorway, price, and two CTAs: **Try On** and **Shop**.
- **Try On** writes the item into the shared `RallyAvatarAppearanceStore` slot and presents the avatar (RallyAvatarView) wearing it immediately.
- **Shop** opens the referral URL through RallyReferralLinkRouter.
- Category chips (All / Tops / Bottoms / Shoes / Rackets / Bags / Headbands / Socks) filter the catalog.
- The aesthetic target is premium fashion commerce (SSENSE / Nike SNKRS energy), consistent with the existing dark Shop theme.

---

## SECTION 4 — WORKSTREAM C: WORLD SCREEN FIXES

### C1. Safe area defect
The search bar / header is clipped under the Dynamic Island. Only the map background may use `.ignoresSafeArea()`. All interactive content (search field, filter chips All/Venues/Camps/World) must be laid out inside the safe area via `.safeAreaInset(edge: .top)` or equivalent. Verify on iPhone 16 Pro simulator: no element occluded at the top.

### C2. Dead links
Every link-shaped control on venue cards (Official links, Site, Booking, Open official destination) must resolve to a real destination URL on the venue model and route through RallyReferralLinkRouter (same referral-code injection as the Shop). Venue model gains `officialSiteURL`, `bookingURL` — populate with the real URLs for the existing venues (Arthur Ashe Stadium / USTA, Centre Court / Wimbledon AELTC, Philippe-Chatrier / Roland-Garros, Rafa Nadal Tennis Centre Costa Mujeres). No control may render as a link unless its URL is non-nil.

---

## SECTION 5 — AUDIT GATES

Following the existing Rally audit pattern (RallyAvatarRebuildAudit style), create three audit types. Each is a set of static checks returning pass/fail with a reason. ALL must pass before the workstream is reported complete.

### RallyAvatarUnificationAudit
- A-1: Zero avatar path functions remain in GameScene (geometry fully extracted).
- A-2: Exactly one appearance store instance exists at app root; Home, Loadout, GameScene, Shop try-on all reference it.
- A-3: RallyAvatarView and GameScene render from the same RallyAvatarGeometry functions (no per-surface geometry).
- A-4: Equipping an item in any slot changes the avatar on ALL surfaces.
- A-5: No image-asset or alternate-drawing avatar remains anywhere in the project.

### RallyShopCatalogAudit
- S-1: Catalog loads ≥12 items from JSON; every item has non-empty brand, name, slot, priceDisplay, productImageURL, referralURL.
- S-2: Every referralURL contains the `{REFERRAL_CODE}` token and validates as a URL after substitution.
- S-3: No SF Symbol or placeholder icon is the terminal visual state of any product card.
- S-4: Try On mutates the shared appearance store and the avatar visibly updates.
- S-5: Every Shop CTA routes through RallyReferralLinkRouter; no raw `openURL` calls in Shop code.

### RallyWorldLinkAudit
- W-1: No interactive element is occluded by the Dynamic Island / status bar on iPhone 16 Pro.
- W-2: Every venue has non-nil officialSiteURL and bookingURL.
- W-3: Every link-shaped control either routes through RallyReferralLinkRouter or does not render.
- W-4: Referral code injection applies to World links identically to Shop links.

---

## SECTION 6 — DELIVERY FORMAT

Respond in this order:
1. File plan: created / modified / deleted, one line each.
2. Full source of every file, in dependency order, with the exact MARK sections specified above.
3. Audit results: every check ID with PASS/FAIL and one-line evidence.
4. Simulator verification checklist: the exact taps to confirm (equip black shorts in Shop → see them on Loadout avatar → see them on GameScene avatar → tap Shop CTA → SFSafariViewController opens product page → World search bar fully visible → venue Official link opens).

Do not include anything else. No summaries of what you did — the file plan and audit results are the report.

---

## ADDENDA — AMBIGUITY RESOLUTIONS

1. World surface: wherever the directive describes the "World screen," the actual files are CourtsMapView.swift and CourtDetailView.swift. All Workstream C requirements apply to those files. Do not create WorldView.swift or GlobeView.swift.
2. RallyAvatarRebuildDefaults does not exist in the repo. The canonical avatar is defined by what GameScene currently RENDERS — the CGPath figure with jet-black Zuko-style hair, warm light skin, athletic build, asymmetric idle pose. During Workstream A, consolidate the identity values currently in AvatarIdentity / AvatarVisualSpec (Avatar3DModels.swift) and GameScene into the new RallyAvatarAppearance, then create RallyAvatarRebuildDefaults.swift as the single home for those default values. GameScene's rendered output is the visual ground truth: nothing about its look may change.
3. ShopItemCard.swift does not exist; product card code lives inside ShopView.swift. Workstream B applies there.
