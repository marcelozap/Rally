# Common tasks.  Usage:  .\tasks.ps1 test   |   .\tasks.ps1 lint   |   .\tasks.ps1 analyze clip.mp4
param([Parameter(Mandatory)][string]$Task, [string]$Arg)
Set-Location $PSScriptRoot
$py = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $py)) { Write-Error "No .venv — run .\setup.ps1 first"; exit 1 }

switch ($Task) {
    "test"    { & $py -m pytest tests -q }
    "cov"     { & $py -m pytest tests --cov=rally_coach --cov-report=term-missing }
    "lint"    { & $py -m ruff check src tests; & $py -m mypy src }
    "fmt"     { & $py -m ruff format src tests }
    "analyze" {
        if (-not $Arg) { Write-Error "usage: .\tasks.ps1 analyze <clip.mp4>"; exit 1 }
        & $py -m rally_coach.cli analyze $Arg
    }
    default   { Write-Host "tasks: test | cov | lint | fmt | analyze <clip>" }
}
