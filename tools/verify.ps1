# Vérification complète en local : import, compilation des scripts, tests, test réseau hôte + client.
# Usage : .\tools\verify.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $run = Join-Path $PSScriptRoot 'run-godot.ps1'
    $failed = $false

    Write-Host '== Import du projet'
    & $run -TimeoutSec 180 -- --headless --path . --import | Out-Null

    Write-Host '== Compilation des scripts'
    & $run -TimeoutSec 120 -- --headless --path . res://tests/check_scripts.tscn | Select-String 'ERREUR|ERROR|vérifiés'
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    Write-Host '== Tests unitaires'
    & $run -TimeoutSec 600 -- --headless --path . --script res://tests/run_tests.gd | Select-String 'TOTAL|ÉCHEC|ERROR'
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    Write-Host '== Test réseau (hôte + client en local)'
    $godot = $env:GODOT_BIN
    if (-not $godot) { $godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe" }
    $hostOut = New-TemporaryFile
    $hostErr = New-TemporaryFile
    $hostProc = Start-Process -FilePath $godot -ArgumentList '--headless --path . -- --autotest=host' `
        -NoNewWindow -PassThru -RedirectStandardOutput $hostOut.FullName -RedirectStandardError $hostErr.FullName
    Start-Sleep -Milliseconds 1500
    & $run -TimeoutSec 40 -- --headless --path . -- --autotest=client | Select-String 'AUTOTEST|SCRIPT ERROR'
    if ($LASTEXITCODE -ne 0) { $failed = $true }
    if (-not $hostProc.WaitForExit(10000)) { taskkill /PID $hostProc.Id /T /F | Out-Null; $failed = $true }
    Get-Content $hostOut.FullName, $hostErr.FullName | Select-String 'AUTOTEST|SCRIPT ERROR'
    if ($hostProc.ExitCode -ne 0) { $failed = $true }
    Remove-Item $hostOut.FullName, $hostErr.FullName

    if ($failed) { Write-Host 'ÉCHEC de la vérification' -ForegroundColor Red; exit 1 }
    Write-Host 'Tout est vert' -ForegroundColor Green
}
finally {
    Pop-Location
}
