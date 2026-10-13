# Vela Tennis — App Review corrections, October 13, 2026

## Implemented

- Owner chose the fastest bare-bones release after discussing the missing live database. Release builds now start directly in on-device mode without login/registration. Cloud bootstrap, sync and remote tunables are disabled even when credentials or old preferences exist. The account/deletion implementation remains available in development for future hosted accounts; it is not presented as a public account feature. Match logs, player setup, wardrobe and journals still use persistent local SwiftData storage. Reinstallation/device changes do not provide cloud recovery.

- Shop uses two columns at normal text sizes, a centered tablet content width and bottom navigation across phone/tablet layouts. A card tap immediately equips and saves clothing/headbands, with an explicit Equipped state and save-error feedback. Accessories are Headbands with a persistent optional headband slot, visible sweatband geometry and a No headband action. Original tops always use the fitted tee mesh, avoiding the inherited tank/polo cut selected by historical retailer IDs. The fitting view always shows the selected racket; leaving a detail screen clears temporary previews. The persistence test covers racket → pants → shirt preview → shirt equip → headband, keeping each prior slot intact.
- Home has a visible Player entry and an Account and locker entry. Player setup and editing have explicit Male/Female controls and three models per selection. The selection retains the corresponding model index and persists with the existing Done/Step onto the court action.
- Signed-in users can open Home → Account and locker → Account → Delete account. A confirmation sheet explains permanent deletion and requires the current password. Cancel is available; repeated submissions are disabled while deletion runs.
- DELETE /api/me authenticates the token and current password, removes the user, and cascades to the cloud snapshot. All authenticated routes now reject tokens whose user has been deleted. The client keeps data when deletion is refused or unreachable; after server success it clears credentials, sync revision, court check-ins, Coach reports, and its SwiftData player/progress/history, then seeds a fresh player.
- The shop contains 43 free original Vela digital gear entries. Historical item identifiers remain internal compatibility keys for saved outfits. Product photos, retailer referral data, branded garment reference metadata, third-party vendor listings, promo codes, purchase CTAs and merchant links are removed from the active storefront. The 32 bundled retailer photograph image sets have been deleted. Colors, categories and original generic garment silhouettes remain available for try-on/equip.

## Evidence

- Debug simulator build succeeds on Xcode 26.3.
- 8 backend tests pass under Node 22.20.0, including an isolated temporary-database deletion test covering password refusal, cascade removal, old-token invalidation, another user's continued access, and re-registering without resurrecting deleted data.
- 35 focused native tests pass (including a disk-backed database reopen check for match/journal entries, player selection, clothing equip and headband removal): merchandise resolver, garment manifest, court unlocks and saved player/defaults. An unrelated pre-existing Swift type-check timeout at CoachVideoAnalyzerTests.swift:194 prevented the first test build; that file was excluded only in the focused test command. This is not a claim that the full test suite passes.
- iPad simulator interaction verifies the new Male/Female controls, model selection, setup completion, Home account access, and Vela shop labels/items. Simulator evidence does not satisfy Apple's requested physical-device recording.

## Asset documentation

The existing asset manifest records source hashes and CC0-1.0 licensing for the MakeHuman base meshes, textures, hair and generic garments:

- https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
- https://static.makehumancommunity.org/assets/assetpacks/shirts01.html
- Rally/Resources/Avatar3D/asset-manifest.json

These sources explicitly list the relevant included assets as CC0. Original Vela catalog illustrations use app-authored vector drawing code. Do not describe the release as having retailer sponsorship or retailer-photo permission. This documentation covers the identified character/gear sources, not an assurance about every possible right in all app content.

## Required before resubmission

1. First release uses on-device storage without accounts. Account deletion has been implemented/tested for the development server only. Before a future account-enabled release, deploy the account service over HTTPS, configure a production URL, retest registration/login/deletion and update privacy disclosures.
2. Upload a replacement build; these changes do not alter the build Apple already reviewed.
3. Test that exact replacement build on supported physical devices. Include first launch, both model selections, gameplay, try-on/equip, persistence, journaling and account lifecycle if accounts are enabled.
4. Capture Apple's requested recording on a physical device running the latest iOS, starting with launch. Demonstrate registration, login and deletion if the release supports accounts; otherwise accurately explain that it is an offline release without accounts.
5. Update store screenshots, privacy disclosures, App Review Notes and the review reply to describe the replacement build. Include accessible video link, device/iOS and exact build number. Do not assert testing or deployment that has not happened.
