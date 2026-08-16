# notebooks/

Exploration lives here: threshold distributions, metric histograms, eyeballing a
clip frame by frame. Anything that earns its place moves into `src/`.

Two rules, both from `CLAUDE.md`:

- `notebooks/` may import from `src/`. `src/` may **never** import from
  `notebooks/`. If pipeline code needs something that lives here, move it.
- Outputs are stripped on commit (`nbstripout`, wired in
  `.pre-commit-config.yaml`). Frame dumps and rendered overlays are exactly what
  "never commit" means.

For the threshold calibration work described in `docs/TUNING.md`, this is where
the good-vs-bad distributions belong.
