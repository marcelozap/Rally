# Movement check — the free, in-browser version

One HTML file. Pose estimation runs in the visitor's browser via MediaPipe Tasks
(WASM + GPU). **No video is uploaded and there is no server**, which is what makes
it free to run at any scale and honest about privacy at the same time.

## Host it

Drop `index.html` anywhere static — GitHub Pages, Netlify, Cloudflare Pages. All
free tiers, zero per-user cost.

```bash
git subtree push --prefix web origin gh-pages     # or just drag it into Netlify
```

Needs HTTPS (or localhost) for camera access. Every static host gives you that.

## Adding a goal

Every goal is one entry in `PROFILES` inside `index.html`. The pipeline underneath
never changes:

```js
mygoal: {
  name: "Running gait", blurb: "…",
  calibrate: true,            // learn their baseline for 5s first
  observationsOnly: false,    // true = describe the body, never advise on pain
  tiles: ["hipTilt", "kne", "lean"],
  cues(m, b, s) { return [["watch", "…"]] },   // ok | watch | off
}
```

`observationsOnly` is the important flag. Technique goals get coaching cues —
telling someone their elbow drops is ordinary coaching. The pain goal gets
observations about what the body did and nothing about what to do for the pain.

## Why this exists

The Python pipeline is for you — batch analysis, session history, the progress
report. This page is for everyone else, because a person with hip pain does not
have Python installed.

It measures. It does not diagnose, and it says so on the page.
