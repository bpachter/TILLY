$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Running TILLY data validation..." -ForegroundColor Cyan
python tools/validation/validate_data.py
