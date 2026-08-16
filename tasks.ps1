# Common tasks.  Usage:  .\tasks.ps1 test   |   .\tasks.ps1 lint   |   .\tasks.ps1 analyze clip.mp4
param([Parameter(Mandatory)][string]$Task, [string]$Arg)
Set-Location $PSScriptRoot
$py = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $py)) { Write-Error "No .venv — run .\setup.ps1 first"; exit 1 }

switch ($Task) {
    "test"    { & $py -m pytest tests -q }
    "unit"    { & $py -m pytest tests/unit -q }
    "int"     { & $py -m pytest tests/integration -q }
    "cov"     { & $py -m pytest tests --cov=rally_coach --cov-report=term-missing }
    "lint"    { & $py -m ruff check src tests; & $py -m mypy src }
    "fix"     { & $py -m ruff check src tests --fix }
    "fmt"     { & $py -m ruff format src tests }
    "check"   {
        # Everything that has to be green before a commit. Stops at the first
        # failure so you fix one thing at a time.
        Write-Host "== lint ==" -ForegroundColor Cyan
        & $py -m ruff check src tests
        if ($LASTEXITCODE -ne 0) { exit 1 }
        Write-Host "== types ==" -ForegroundColor Cyan
        & $py -m mypy src
        if ($LASTEXITCODE -ne 0) { exit 1 }
        Write-Host "== tests ==" -ForegroundColor Cyan
        & $py -m pytest tests -q
        if ($LASTEXITCODE -ne 0) { exit 1 }
        Write-Host "All green." -ForegroundColor Green
    }
    "analyze" {
        if (-not $Arg) { Write-Error "usage: .\tasks.ps1 analyze <clip.mp4>"; exit 1 }
        & $py -m rally_coach.cli analyze $Arg
    }
    default   { Write-Host "tasks: check | test | unit | int | cov | lint | fix | fmt | analyze <clip>" }
}
