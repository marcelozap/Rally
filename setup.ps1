# rally-coach — one-shot environment setup.
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "== checking python ==" -ForegroundColor Cyan
$v = (python --version 2>&1)
Write-Host "  $v"
if ($v -match "3\.(1[3-9]|[2-9]\d)") {
    Write-Warning "MediaPipe has no wheels for Python 3.13+. Install 3.12 and re-run."
    Write-Warning "  winget install Python.Python.3.12"
    exit 1
}

if (-not (Test-Path ".venv")) {
    Write-Host "== creating .venv ==" -ForegroundColor Cyan
    python -m venv .venv
}

Write-Host "== installing ==" -ForegroundColor Cyan
& .\.venv\Scripts\python.exe -m pip install --upgrade pip --quiet
& .\.venv\Scripts\python.exe -m pip install -e ".[dev]"

Write-Host "== running tests ==" -ForegroundColor Cyan
& .\.venv\Scripts\python.exe -m pytest tests -q

Write-Host ""
Write-Host "Ready. Activate with:  .\.venv\Scripts\activate" -ForegroundColor Green
Write-Host "Then:                  rally-coach analyze <clip.mp4>" -ForegroundColor Green
