# Récap lisible du bilan du bot : lit <OutDir>/bilan.csv (écrit par tools/bot-matrix.ps1) et écrit
# <OutDir>/RECAP.md. Vue d'ensemble : pour chaque spécialisation, son taux de réussite par niveau et
# par difficulté. Détail : pour chaque classe et chaque difficulté, une ligne par niveau et par
# spécialisation, avec le taux de réussite, les cartes gagnées et les cartes perdues (vague de la défaite).
#
# Usage :
#   .\tools\bot-recap.ps1                      # tout le bilan
#   .\tools\bot-recap.ps1 -Classes Gobelin     # une ou plusieurs classes (noms affichés)
#   .\tools\bot-recap.ps1 -Difficulties Normal,Difficile
param(
    [string]$OutDir = "bot_results",
    [string[]]$Classes = @(),
    [string[]]$Difficulties = @()
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root "$OutDir/bilan.csv"
if (-not (Test-Path $csvPath)) { Write-Error "Bilan introuvable : $csvPath (lancer d'abord tools/bot-matrix.ps1)"; exit 1 }
$rows = @(Import-Csv $csvPath -Delimiter ';' -Encoding utf8)
if ($Classes.Count) { $rows = @($rows | Where-Object { $_.Classe -in $Classes }) }
if ($Difficulties.Count) { $rows = @($rows | Where-Object { $_.Difficulte -in $Difficulties }) }
if ($rows.Count -eq 0) { Write-Error "Aucune partie ne correspond aux filtres."; exit 1 }

# Ordre d'apparition dans le bilan (celui des données du jeu), niveaux triés numériquement
function Get-Order($items) { $seen = [ordered]@{}; foreach ($i in $items) { $seen[$i] = $true }; @($seen.Keys) }
$classOrder = Get-Order ($rows | ForEach-Object Classe)
$diffOrder = Get-Order ($rows | ForEach-Object Difficulte)
$levelOrder = @($rows | ForEach-Object { [int]$_.Niveau } | Sort-Object -Unique)
$mapOrder = Get-Order ($rows | ForEach-Object Carte)

## Taux de réussite ; « ⚠ incomplet » quand l'essai n'a pas joué toutes ses parties (délai dépassé, arrêt).
function Get-Rate($group, [int]$expected = 0) {
    $won = @($group | Where-Object Gagne -eq 'oui').Count
    $n = @($group).Count
    if ($n -eq 0) { return '·' }
    $text = '{0} % ({1}/{2})' -f [math]::Round(100 * $won / $n), $won, $n
    if ($expected -gt 0 -and $n -lt $expected) { $text += ' ⚠ incomplet' }
    $text
}

$index = @{}  # "classe|difficulté|niveau|spé" -> parties
foreach ($r in $rows) {
    $k = "$($r.Classe)|$($r.Difficulte)|$($r.Niveau)|$($r.Spe)"
    if (-not $index.ContainsKey($k)) { $index[$k] = [System.Collections.Generic.List[object]]::new() }
    $index[$k].Add($r)
}

$md = [System.Collections.Generic.List[string]]::new()
$md.Add("# Récap du bot")
$md.Add("")
$md.Add("Source : ``$OutDir/bilan.csv`` du $((Get-Item $csvPath).LastWriteTime.ToString('yyyy-MM-dd HH:mm')), $($rows.Count) parties. Récap généré le $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
$md.Add("Cartes perdues : vague de la défaite entre parenthèses. « ⚠ incomplet » : essai interrompu avant la fin, à relancer (``bot-matrix.ps1 -Resume``).")

# --- Vue d'ensemble : taux de réussite de chaque spécialisation, niveau par niveau et difficulté par difficulté ---
$md.Add("")
$md.Add("## Vue d'ensemble par spécialisation")
foreach ($c in $classOrder) {
    $md.Add("")
    $md.Add("### $c")
    foreach ($s in (Get-Order ($rows | Where-Object Classe -eq $c | ForEach-Object Spe))) {
        $md.Add("")
        $md.Add("**$c · $s**")
        $md.Add("")
        $md.Add("| Niveau | " + ($diffOrder -join ' | ') + " |")
        $md.Add("|---|" + ('---|' * $diffOrder.Count))
        foreach ($lv in $levelOrder) {
            $cells = foreach ($d in $diffOrder) { Get-Rate $index["$c|$d|$lv|$s"] $mapOrder.Count }
            $md.Add("| $lv | " + ($cells -join ' | ') + " |")
        }
    }
}

# --- Détail : classe > difficulté > niveau × spécialisation ---
foreach ($c in $classOrder) {
    $md.Add("")
    $md.Add("## Détail · $c")
    $specs =Get-Order ($rows | Where-Object Classe -eq $c | ForEach-Object Spe)
    foreach ($d in $diffOrder) {
        $md.Add("")
        $md.Add("### $c · $d")
        $md.Add("")
        $md.Add("| Niveau | Spécialisation | Réussite | Gagnées | Perdues |")
        $md.Add("|---|---|---|---|---|")
        foreach ($lv in $levelOrder) {
            foreach ($s in $specs) {
                $g = $index["$c|$d|$lv|$s"]
                if (-not $g) { continue }
                $sorted = @($g | Sort-Object { [array]::IndexOf($mapOrder, $_.Carte) })
                $won = @($sorted | Where-Object Gagne -eq 'oui' | ForEach-Object Carte)
                $lost = @($sorted | Where-Object Gagne -ne 'oui' | ForEach-Object { "$($_.Carte) ($($_.Vague))" })
                $wonText = if ($won.Count -eq $sorted.Count) { 'toutes' } elseif ($won.Count) { $won -join ', ' } else { '–' }
                $lostText = if ($lost.Count) { $lost -join ', ' } else { '–' }
                $md.Add("| $lv | $s | $(Get-Rate $sorted $mapOrder.Count) | $wonText | $lostText |")
            }
        }
    }
}

$out = Join-Path $root "$OutDir/RECAP.md"
Set-Content -Path $out -Value $md -Encoding utf8
Write-Host "Récap écrit : $out ($($rows.Count) parties)" -ForegroundColor Cyan
