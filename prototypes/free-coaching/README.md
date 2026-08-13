# Free Coaching Prototype

This folder holds local computer-vision experiments for Rally's free coaching track.

## First Test

Install dependencies:

```powershell
python -m pip install -r prototypes/free-coaching/requirements.txt
```

Put a phone video in:

```text
data/raw-videos/
```

Run pose overlay:

```powershell
python prototypes/free-coaching/pose_overlay.py --input data/raw-videos/serve-side-01.mp4
```

Outputs are written to:

```text
data/processed-videos/
```

The raw and processed videos are intentionally ignored by Git.
