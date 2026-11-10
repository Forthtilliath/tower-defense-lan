# Lance le jeu depuis les sources (sans export), en une ou plusieurs fenêtres.
# Plusieurs fenêtres = plusieurs joueurs sur ce PC, pour tester la coop ou le versus en local :
# l'une héberge, les autres rejoignent (la partie apparaît dans « Rejoindre », sinon IP 127.0.0.1).
#
# Usage : .\tools\play.ps1 [-Joueurs 1..4] [-Editeur]
#   -Joueurs 2   deux fenêtres côte à côte
#   -Editeur     ouvre le projet dans l'éditeur Godot au lieu de lancer le jeu
param(
    [ValidateRange(1, 4)][int]$Joueurs = 1,
    [switch]$Editeur
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# Exécutable sans console (pas de fenêtre noire), sinon celui désigné par GODOT_BIN.
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe" }
if (-not (Test-Path $godot)) { Write-Error "Godot introuvable : $godot (définir GODOT_BIN)"; exit 2 }

if ($Editeur) {
    Start-Process -FilePath $godot -ArgumentList "--path `"$root`" --editor"
    exit 0
}

# Premier lancement (ou cache effacé) : importer les ressources avant de jouer.
if (-not (Test-Path (Join-Path $root '.godot\imported'))) {
    Write-Host 'Premier lancement : import du projet...'
    & (Join-Path $PSScriptRoot 'run-godot.ps1') -TimeoutSec 180 -- --headless --path $root --import | Out-Null
}

if ($Joueurs -eq 1) {
    Start-Process -FilePath $godot -ArgumentList "--path `"$root`""
    exit 0
}

# Plusieurs fenêtres : réparties en grille sur l'écran principal.
Add-Type -AssemblyName System.Windows.Forms
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$cols = 2
$rows = [math]::Ceiling($Joueurs / $cols)
$w = [math]::Floor($area.Width / $cols)
$h = [math]::Min([math]::Floor($area.Height / $rows) - 40, [math]::Floor($w * 9 / 16))
for ($i = 0; $i -lt $Joueurs; $i++) {
    $x = $area.X + ($i % $cols) * $w
    $y = $area.Y + [math]::Floor($i / $cols) * ($h + 40) + 30
    Start-Process -FilePath $godot -ArgumentList "--path `"$root`" --resolution ${w}x$h --position $x,$y"
    Start-Sleep -Milliseconds 300
}
Write-Host "$Joueurs fenêtres lancées : héberger dans l'une, rejoindre depuis les autres."
