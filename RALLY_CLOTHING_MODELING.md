# Rally clothing modeling intake

September 5, 2026. Character customization is now limited to selecting a generic base model and changing skin or hair color. All three men share one clothing fit; all three women share another. The next production work is garment construction and materials.

## Exact products selected

These are official product references, not completed branded 3D assets. Five verified-price items are in the shop; UNIQLO is held in the source catalog until its US price is verified. Prices are observations on the date above, not a live inventory or pricing feed.

| Company / item | Style and color | Observed USD | App state |
| --- | --- | ---: | --- |
| [Nike — NikeCourt Advantage Men’s Dri-FIT Tennis Top](https://www.nike.com/t/nikecourt-advantage-mens-dri-fit-tennis-top-TcVn1mOS/FZ6910-010) | FZ6910-010 · Black/White | $75.00 | Photo reference + style preview |
| [Nike — NikeCourt Advantage Men’s Dri-FIT 6-inch Tennis Shorts](https://www.nike.com/t/nikecourt-advantage-mens-dri-fit-6-tennis-shorts-cCYH6Bt5/FZ6913-010) | FZ6913-010 · Black/White | $75.00 | Photo reference + style preview |
| [adidas — Tennis Climacool Ergo Shorts Pro](https://www.adidas.com/us/tennis-climacool-ergo-shorts-pro/KV4294.html) | KV4294 · White | $65.00 | Photo reference + style preview |
| [UNIQLO — DRY-EX Quarter-Zip Polo Shirt](https://www.uniqlo.com/us/en/products/E482306-000/00?colorDisplayCode=00) | 482306 · 00 WHITE | Unverified | Source only |
| [New Balance — Tournament Tank](https://www.newbalance.com/pd/tournament-tank/WT61K74K-WT.html) | WT61K74KWT · WHITE with GREY MATTER | $59.99 | Photo reference + style preview |
| [New Balance — Tournament Skort](https://www.newbalance.com/pd/tournament-skort/WB61S4JJ-WT.html) | WB61S4JJWT · WHITE with GREY MATTER | $59.99 | Photo reference + style preview |

## First garment pair

Start with the New Balance Tournament Tank WT61K74KWT and Tournament Skort WB61S4JJWT. They form one outfit, include official product-gallery references, and use the same stated knit composition. The tank needs its bonded neckline and armholes; the skort needs distinct outer-skirt, waistband, inner-short and pocket geometry. Then author the Nike Advantage top and six-inch shorts as the men’s first pair.

The photo URLs are associated with their selected products by the official pages. Image pixels and front/back/side angles could not be inspected during this pass. Shared UNIQLO detail photos may show another color; only the selected white hero enters the app manifest. The full source intake records construction, materials, listed sizes, source URLs, and verification limits:

- `docs/garments/2026-09-05-source-intake.json` — source evidence and exact item IDs.
- `Rally/Resources/RallyGarmentCatalog.json` — app manifest, exact colorways and future per-body mesh slots.

## Asset handoff

No exact-product GLB, USDZ, CAD pattern or downloadable 3D garment was linked on the six inspected public pages. To author accurate garments, the next useful input is front/back/side reference photography plus finished-garment measurements or a pattern/tech pack; alternatively use a supplied brand asset. Body size charts are not garment patterns. Supplier assets and artwork should include their permitted app/distribution use; no brands have been contacted or partnerships claimed.

Fit each garment against the existing male and female bind poses, in meters, Y-up and +Z-forward, retaining the 163-bone rig. Preserve authored hems and panels. Validate shoulders, underarms, waist, seated skirt/inner-short layers, and racket-hand clearance through ready stance, forehand and backhand. Apparel must remain opaque where required during loading and motion.

Each record has `meshes.male` and `meshes.female`, containing full Avatar3D resource basenames without extension. Keep `representation: referenceOnly` until authored geometry is bundled and reviewed. Use `skuAuthored` for an authored product model or `brandSupplied` for a supplied one. A missing mesh retains the generic style preview. Exact garment material/UV texture slots must be added alongside the first authored asset before describing it as product-accurate; the current generic fabric material is not that asset pipeline.

## Changes in this pass

- Removed personal names; added color-only controls and compatible local/sync persistence.
- Added strict product-ID and gear-slot lookup. Shop, details and Locker cannot borrow another product’s photo.
- Corrected the New Balance tank URL, price and erroneous `mt61k74k` photo reference to the selected `wt61k74kwt` gallery.
- Added four distinct shop IDs for the new exact products. Old IDs remain readable for existing equipped items; none are silently relabeled as another SKU.
- Added actual style code, colorway, fabric and construction to garment detail pages.
- Replaced garment-name substring guesses with an explicit typed registry. New garment meshes can be mapped independently for the two fixed bodies.
- Kept a visible style-preview label while current avatar garments remain generic.
