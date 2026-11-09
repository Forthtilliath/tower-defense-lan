# Lance Godot en mode console avec un délai maximum, puis tue le processus s'il ne s'est pas arrêté.
# Usage : .\tools\run-godot.ps1 -TimeoutSec 120 -- --headless --path . --script res://tests/run_tests.gd
param(
    [int]$TimeoutSec = 120,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs
)

$godot = $env:GODOT_BIN
if (-not $godot) { $godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $godot)) { Write-Error "Godot introuvable : $godot (définir GODOT_BIN)"; exit 2 }

$out = New-TemporaryFile
$err = New-TemporaryFile
# Seul le premier « -- » (séparateur pour PowerShell) est retiré : les suivants vont à Godot.
if ($GodotArgs.Count -gt 0 -and $GodotArgs[0] -eq '--') { $GodotArgs = $GodotArgs[1..($GodotArgs.Count - 1)] }
$argLine = ($GodotArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' '
$p = Start-Process -FilePath $godot -ArgumentList $argLine -NoNewWindow -PassThru `
    -RedirectStandardOutput $out.FullName -RedirectStandardError $err.FullName
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    taskkill /PID $p.Id /T /F | Out-Null
    Get-Content $out.FullName
    Get-Content $err.FullName
    Write-Host "DÉLAI DÉPASSÉ ($TimeoutSec s) : processus tué"
    Remove-Item $out.FullName, $err.FullName
    exit 124
}
Get-Content $out.FullName
Get-Content $err.FullName
$code = $p.ExitCode
Remove-Item $out.FullName, $err.FullName
exit $code
