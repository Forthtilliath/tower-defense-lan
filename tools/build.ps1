# Construit les versions release : build\TowerDefenseLAN-<version>.exe et .apk
# La clé de signature Android n'est jamais écrite dans le projet : elle est lue hors du dépôt
# et passée à Godot par variables d'environnement, le temps du build seulement.
#
# Usage : .\tools\build.ps1 [-Only windows|android]
param([ValidateSet('all', 'windows', 'android')][string]$Only = 'all')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $run = Join-Path $PSScriptRoot 'run-godot.ps1'
    $version = (Select-String -Path project.godot -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
    $code = (Select-String -Path export_presets.cfg -Pattern '^version/code=(\d+)').Matches[0].Groups[1].Value
    $apkVersion = (Select-String -Path export_presets.cfg -Pattern '^version/name="(.+)"').Matches[0].Groups[1].Value
    if ($apkVersion -ne $version) { throw "Version incohérente : project.godot $version / export_presets.cfg $apkVersion" }
    Write-Host "Version $version (code Android $code)"
    New-Item -ItemType Directory -Force build | Out-Null

    if ($Only -in 'all', 'windows') {
        $exe = "build\TowerDefenseLAN-$version.exe"
        & $run -TimeoutSec 300 -- --headless --path . --export-release "Windows Desktop" $exe | Select-String 'ERROR|error'
        if (-not (Test-Path $exe)) { throw "Export Windows échoué" }
        Write-Host "OK : $exe"
    }

    if ($Only -in 'all', 'android') {
        $keyDir = Join-Path $env:USERPROFILE '.android-keys'
        $keystore = Join-Path $keyDir 'tower-defense-lan-release.jks'
        $passFile = Join-Path $keyDir 'tower-defense-lan-release.password.txt'
        if (-not (Test-Path $keystore) -or -not (Test-Path $passFile)) { throw "Clé de signature release introuvable dans $keyDir" }
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystore
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'towerdefenselan'
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = (Get-Content $passFile -Raw).Trim()
        try {
            $apk = "build\TowerDefenseLAN-$version.apk"
            & $run -TimeoutSec 600 -- --headless --path . --export-release "Android" $apk | Select-String 'ERROR|error'
            if (-not (Test-Path $apk)) { throw "Export Android échoué" }
        }
        finally {
            Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH, Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER, Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
        }
        # Contrôle : l'APK doit être signé par la clé release, jamais par une clé de debug
        $buildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" | Sort-Object Name -Descending | Select-Object -First 1
        $certs = & "$($buildTools.FullName)\apksigner.bat" verify --print-certs $apk 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Signature APK invalide :`n$certs" }
        if ($certs -match 'Android Debug') { throw "APK signé avec une clé de DEBUG : refusé" }
        $certs | Select-String 'Signer #1 certificate DN|SHA-256'
        Write-Host "OK : $apk"
    }
}
finally {
    Pop-Location
}
