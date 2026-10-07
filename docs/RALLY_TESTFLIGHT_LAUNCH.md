# Rally → Courtside Siblings launch

Prepared October 7, 2026. **Preparation only: no distribution archive, upload, TestFlight invite or App Store submission has been made.**

## Verified starting point

- Source: owner-authorized relocated checkout `/Users/a14/Desktop/_XIV Desktop System/99 Inbox - To Sort/Rally`, branch `codex/rally-gameplay-feel-sept17`. Starting app revision: `8664461`, including the latest thigh/shorts fit and approved backhand work.
- Preserve bundle identifier `com.marcelozap.rally` and existing team `832KFP5M8B`; verify the team against the enrolled account before distribution. Do not uninstall the existing apps or reset saved data on either phone.
- This Mac runs macOS 15.7.4, Xcode 16.4 and iOS SDK 18.5. Only development signing identities were found. Paid enrollment and App Store Connect access remain unverified.
- The September 17 development build expired September 24. It is not a downloadable App Store/TestFlight release.
- A fresh Release iOS Simulator build passed October 7 with the existing SDK. One existing actor-isolation warning remains in `RallyReferralLinkRouter.swift`; this is not proof of compatibility with the required newer SDK. No new physical-phone or gameplay acceptance test was performed.

## Owner action: enrollment

Open [Apple Developer enrollment](https://developer.apple.com/programs/enroll/) and sign in using the Apple Account used for Rally in Xcode. Complete identity checks, agreement and the membership purchase yourself. Apple lists the standard membership at $99 USD per year; confirm the amount and renewal terms at checkout. Use your actual individual or organization status. Do not share passwords, payment details or verification codes in chat.

After enrollment is active, verify the account in Xcode → Settings → Accounts and confirm access to App Store Connect. Membership includes distribution tools, but does not itself approve or publish an app. [Apple membership comparison](https://developer.apple.com/support/compare-memberships/)

## Toolchain prerequisite

Apple requires iOS SDK 26 or later for uploads starting April 28, 2026. Install a compatible production Xcode before making the distribution archive. Apple's compatibility table lists Xcode 26.3 as supporting macOS Sequoia 15.6 through Tahoe 26.x, so this Mac's OS meets that listed range. Check the selected download's requirements; do not assume the newest Xcode runs on this OS. Preserve Xcode 16.4 until the new setup works.

- [Upload SDK requirement](https://developer.apple.com/news/?id=ueeok6yw)
- [Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
- [Apple developer downloads](https://developer.apple.com/download/all/)

## Product work before inviting external testers

1. **Resolve the first-launch account flow.** `RallyAPIConfig` currently defaults to `http://127.0.0.1:8787`; `RootView` routes new users to `AuthView`, which offers login/create-account alongside Continue offline. An ordinary tester cannot use a developer's local server. Recommended initial beta: a clearly presented offline experience with account creation/cloud backup unavailable until a production service is ready. This is a recommendation, not an implemented change. An online launch instead needs a deployed HTTPS backend, working account lifecycle and verified data handling.
2. **Finish privacy/support setup.** No privacy manifest was found under `Rally/`, and no privacy-policy link or account-deletion implementation was found in the inspected Auth/services/backend paths. Inventory required-reason API use and actual data flows; add the applicable manifest declarations, host a truthful privacy policy and support page, and expose them in the app. If accounts remain available, finish the account lifecycle before release. Do not select “Data Not Collected” without checking the final build and backend.
3. **Check public-release assets.** `docs/SHOP_PHOTOGRAPHY.md` records third-party product-photo sources but does not establish distribution permission. Resolve usage rights or replace affected imagery before publication. Verify product destinations/prices, avoid partnership claims, and retain clear generic try-on labeling.
4. **Verify on both phones.** First launch, left/right hand selection, avatar/outfit persistence, full rally and retry, Shop links, World links, Coach import/cancellation, audio/haptics, background/reopen and saved-data retention. September simulator results do not replace this check.
5. **Prepare App Store Connect.** Confirm/create the Rally app record using its existing bundle ID. Supply beta description, review contact, feedback email, privacy/support URLs and accurate review instructions. Confirm encryption answers and any other required fields against the actual build. Store screenshots, pricing and final metadata are required for the subsequent App Store release.

These items are still open. The release script's toolchain check does not certify product readiness.

## Release commands after the prerequisites

From the source checkout:

```sh
./ship.sh --check
```

The default is also a read-only check. It now correctly fails on this Mac's iOS 18.5 SDK. It does not enroll an account, verify membership or alter signing settings.

Use an unused build number for the selected App Store version. `1` below is an example, not a verified available number:

```sh
BUILD_NUMBER=1 ./ship.sh --archive
BUILD_NUMBER=1 ./ship.sh --ipa
BUILD_NUMBER=1 ./ship.sh --upload
```

Each command creates a fresh archive in its own `build/release-*` directory; these are alternative modes, not three steps that must all be run. Archive-only stops before export. IPA mode exports locally. Only explicit `--upload` contacts App Store Connect for upload. Xcode automatic provisioning can update signing assets in all build modes. Existing archives, `Config/Local.xcconfig` and Xcode project registration are preserved. Full archive/export logs stay with each run. Archive failure prevents export, even if a partial archive directory exists.

Optional API authentication uses `ASC_KEY_PATH`, `ASC_KEY_ID`, `ASC_ISSUER_ID` together for both archive and export. Credentials are not stored in the repo. Failed or uncertain upload results must be checked in App Store Connect before retrying.

Release-script regression check: `python3 Tests/test_release_script.py`. Nine tests exercise a stub Xcode executable, including failed/incomplete archives, old SDK rejection, export/upload modes and preservation of prior outputs. These tests do not sign or upload anything.

## First shareable link

After a real upload finishes processing, verify the build with Marcelo and Isa, create an external tester group such as **Courtside Siblings**, provide beta review information and submit the first external build for TestFlight review. After approval, enable the group's public link, test it on a tester's phone, and then add that actual link to the TikTok profile where the account permits website links. No link exists in this launch packet.

[Apple's external-testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

## Copy ready for launch preparation

TikTok bio before an approved beta:

> Brother & sister. Tennis, rallies & friendly competition. Rally app coming soon 🎾

First video hook:

> We compete on the court. Now we're bringing that rivalry into Rally.

Film one real rally together, cut to the corresponding game action, and end with a score challenge. Use Marcelo's own music if he has the rights needed for that use. Keep the call to action “Follow for the beta” until the tested public link exists; then change it to “Try the Rally beta.” Confirm the exact TikTok handle before adding social links anywhere.

Draft TestFlight description, to verify against the final beta:

> Rally brings short tennis challenges, athlete customization and court discovery together on iPhone. Test the rally timing, left- and right-handed play, outfit selection and court links. Tell us where controls or movement feel unclear, and include your device model and iOS version when reporting a problem.
