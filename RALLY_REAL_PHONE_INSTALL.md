# Rally Real Phone Install

Use this guide to put the current `rally/dev` build on a real iPhone before running `RALLY_REAL_PHONE_TEST.md`.

The goal is not to fix bugs during install. The goal is to get one honest device run, write results into `RALLY_REAL_PHONE_RESULTS.md`, then patch only the highest-impact issues.

## 1. Confirm The Repo

Run this from Terminal:

```bash
cd /Users/a14/Desktop/Rally
pwd
git status --short --branch
git pull --ff-only origin rally/dev
git log --oneline -1
```

Expected:

- Path is `/Users/a14/Desktop/Rally`.
- Branch is `rally/dev`.
- The only known dirty file may be `agents/handoff.md`; do not stage it unless you are intentionally resolving that handoff.

## 2. Open In Xcode

```bash
open /Users/a14/Desktop/Rally/Rally.xcodeproj
```

In Xcode:

- Select the `Rally` scheme.
- Connect the iPhone with USB.
- Trust the computer on the iPhone if prompted.
- Enable Developer Mode on the iPhone if prompted.
- Select the physical iPhone as the run destination.
- If Xcode asks for signing, choose your Apple account/team for the Rally app target.
- Press Run.

## 3. First Launch Checks

Before testing gameplay, verify:

- The app launches without crashing.
- Sound is off by default.
- No autoplay or background audio starts by itself.
- Home/Loadout appears.
- The PLAY button is visible and tappable.

If any of those fail, stop and write the failure into `RALLY_REAL_PHONE_RESULTS.md`.

## 4. Run The Real Phone Checklist

Open `RALLY_REAL_PHONE_TEST.md` and go top to bottom:

- Launch and quiet defaults
- Avatar identity
- Outfit and gear
- Gameplay feed
- Tennis feel
- Audio
- Shop, Journal, World
- Final score
- Top three bugs

Do not fix during the run. Rally needs one clean read of what the phone actually feels like.

## 5. Record Results

After the run, fill in `RALLY_REAL_PHONE_RESULTS.md`.

Use short blunt notes:

- what you tapped
- what you expected
- what happened
- screenshot or video path when available
- severity

The next code pass should fix only the top three bugs in score-impact order.

## 6. If Build Or Install Fails

If Xcode build fails:

- Copy the first Swift error and the file/line.
- Do not paste the entire build log unless asked.
- Do not run destructive cleanup commands.

If install succeeds but launch fails:

- Check iPhone Developer Mode.
- Check Trust This Computer.
- Check signing/team settings.
- Re-run once from Xcode and capture the first runtime error.

## 7. Quiet Audio Rule

Rally is intentionally quiet by default right now.

Only turn sound on manually during Pass 6 of `RALLY_REAL_PHONE_TEST.md`, then turn it back off before ending the run.
