"""rally-coach CLI.

    rally-coach analyze clip.mp4 --out artifacts/runs/session1.json
    rally-coach analyze clip.mp4 --overlay artifacts/overlays/session1.mp4
    rally-coach show artifacts/runs/session1.json
"""
from __future__ import annotations

from pathlib import Path

import typer
from rich.console import Console
from rich.table import Table

from rally_coach.export.writer import read, write
from rally_coach.pipeline import analyze as run_analysis
from rally_coach.pipeline import load_config

app = typer.Typer(add_completion=False, help="Tennis movement analysis and coaching advice.")
console = Console()


@app.command()
def analyze(
    clip: Path = typer.Argument(..., exists=True, help="Video file to analyse."),
    out: Path = typer.Option(None, "--out", "-o", help="Where to write analysis.v1 JSON."),
    config: Path = typer.Option(None, "--config", "-c", help="pipeline.yaml override."),
) -> None:
    """Run the full pipeline over a clip."""
    cfg = load_config(config)
    with console.status(f"[cyan]analysing[/] {clip.name} ..."):
        result = run_analysis(clip, cfg)

    destination = out or Path("artifacts/runs") / f"{clip.stem}.json"
    write(result, destination)
    console.print(f"[green]wrote[/] {destination}")
    _render(result)


@app.command()
def show(analysis_json: Path = typer.Argument(..., exists=True)) -> None:
    """Pretty-print a saved analysis."""
    _render(read(analysis_json))


def _render(result) -> None:
    console.print(
        f"\n[bold]{Path(result.clip).name}[/]  "
        f"{result.duration_s:.1f}s @ {result.fps:.0f}fps  "
        f"hand=[cyan]{result.handedness.value}[/]  "
        f"swings=[cyan]{len(result.swings)}[/]"
    )

    if result.swings:
        t = Table(title="Swings", header_style="cyan")
        for col in ("#", "type", "contact", "peak speed", "conf"):
            t.add_column(col)
        for s in result.swings:
            t.add_row(
                str(s.id), s.type.value, f"{s.contact_t:.2f}s",
                f"{s.peak_wrist_speed:.2f}", f"{s.confidence:.2f}",
            )
        console.print(t)

    if result.metrics:
        m = Table(title="Metrics", header_style="cyan")
        m.add_column("metric")
        m.add_column("value", justify="right")
        for k, v in result.metrics.items():
            m.add_row(k, f"{v:g}")
        console.print(m)

    if result.notes:
        console.print("\n[bold]Coaching notes[/]")
        tone = {"fix": "magenta", "suggest": "cyan", "info": "white"}
        for n in result.notes:
            console.print(f"  [{tone.get(n.severity,'white')}]{n.severity.upper()}[/] {n.title}")
            console.print(f"    {n.detail}\n")
    else:
        console.print("\n[dim]No coaching notes crossed the confidence threshold.[/]")


if __name__ == "__main__":
    app()
