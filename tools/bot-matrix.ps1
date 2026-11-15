# Bilan complet du bot d'équilibrage : chaque classe (toutes ses spécialisations) sur chaque carte,
# dans chaque difficulté, à deux niveaux de joueur par difficulté. Lance plusieurs Godot en
# parallèle (un essai = une classe, une difficulté, un niveau), puis affiche qui gagne ou bloque
# où, et écrit <OutDir>/BILAN.md (tableaux) et <OutDir>/bilan.csv (une ligne par partie, pour Excel).
#
# Usage :
#   .\tools\bot-matrix.ps1                                  # tout : 5 difficultés × 2 niveaux × 6 classes
#   .\tools\bot-matrix.ps1 -Difficulties 1,2 -Classes 0,3   # une partie seulement
#   .\tools\bot-matrix.ps1 -Levels @{ 1 = 5, 10 } -Difficulties 1
#   .\tools\bot-matrix.ps1 -Detail                          # une ligne par spécialisation à l'écran
#   .\tools\bot-matrix.ps1 -Resume                          # ne rejoue pas les essais déjà terminés
#   .\tools\bot-matrix.ps1 -ReportOnly                      # refait le bilan sans rien rejouer
param(
    [int[]]$Difficulties = @(0, 1, 2, 3, 4),
    [int[]]$Classes = @(),
    # Niveaux joués pour chaque difficulté (0 Facile, 1 Normal, 2 Difficile, 3 Cauchemar, 4 Infernal).
    [hashtable]$Levels = @{ 0 = @(1, 5, 10, 15, 20, 25, 30); 1 = @(1, 5, 10, 15, 20, 25, 30); 2 = @(1, 5, 10, 15, 20, 25, 30); 3 = @(1, 5, 10, 15, 20, 25, 30); 4 = @(1, 5, 10, 15, 20, 25, 30) },
    [int[]]$Maps = @(),
    [int]$Jobs = [Math]::Min(6, [Math]::Max(1, [int][Math]::Floor([Environment]::ProcessorCount / 2))),
    [int]$TimeoutSec = 1800,
    [string]$OutDir = "bot_results",
    [switch]$Resume,
    [switch]$ReportOnly,
    [switch]$Detail
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe" }
if (-not $ReportOnly -and -not (Test-Path $godot)) { Write-Error "Godot introuvable : $godot (définir GODOT_BIN)"; exit 2 }

# --- Données du jeu : noms des classes, spécialisations, cartes et difficultés ---
$gd = Get-Content (Join-Path $root 'data/game_data.json') -Raw -Encoding utf8 | ConvertFrom-Json
$mapList = @($gd.maps)
if ($Maps.Count) { $mapList = @($Maps | ForEach-Object { $gd.maps[$_] }) }
if ($Classes.Count -eq 0) { $Classes = @(0..($gd.builders.Count - 1)) }
$className = @{}; $specName = @{}; $mapName = @{}
foreach ($b in $gd.builders) {
    $className[$b.id] = $b.name
    foreach ($br in $b.branches) { if (-not $br.trunk) { $specName["$($b.id)/$($br.id)"] = $br.name } }
}
foreach ($m in $gd.maps) { $mapName[$m.id] = $m.name }

# --- Plan des essais ---
$runDir = "$OutDir/runs"
New-Item -ItemType Directory -Force (Join-Path $root $runDir) | Out-Null
$plan = @(foreach ($d in $Difficulties) {
        if (-not $Levels.ContainsKey($d)) { throw "Aucun niveau pour la difficulté $d (paramètre -Levels)" }
        foreach ($lv in $Levels[$d]) {
            foreach ($c in $Classes) {
                $tag = '{0}_lv{1:D2}_{2}' -f $gd.difficulties[$d].id, [int]$lv, $gd.builders[$c].id
                [pscustomobject]@{ D = $d; Level = [int]$lv; Class = $c; Tag = $tag
                    Log = Join-Path $root "$runDir/$tag.log"; Md = "./$runDir/$tag.md" -replace '\\', '/' }
            }
        }
    })
$combos = [System.Collections.Generic.List[object]]::new(); $seen = @{}
foreach ($r in $plan) {
    $k = "$($r.D)|$($r.Level)"
    if ($seen[$k]) { continue }
    $seen[$k] = $true
    $n = $gd.difficulties[$r.D].name
    $combos.Add([pscustomobject]@{ D = $r.D; Level = $r.Level; Name = $n; Short = ('{0}{1}' -f $n.Substring(0, 3), $r.Level) })
}

function Test-Done($r) { (Test-Path $r.Log) -and (Select-String -Path $r.Log -Pattern '^Total : ' -Quiet) }

function Get-Errors($r) {
    @($r.Log, "$($r.Log).err") | Where-Object { Test-Path $_ } |
        ForEach-Object { Select-String -Path $_ -Pattern 'SCRIPT ERROR|^ERROR:' -Encoding utf8 } | ForEach-Object { $_.Line }
}

# Start-Process exige un fichier pour stderr : on ne garde le .err que s'il contient quelque chose.
function Remove-EmptyErr([string[]]$paths) {
    foreach ($f in $paths) {
        if ((Test-Path $f) -and (Get-Item $f).Length -eq 0) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }
}
function Clear-EmptyErrs { Remove-EmptyErr @(Get-ChildItem (Join-Path $root $runDir) -Filter '*.err' | ForEach-Object FullName) }

function Start-Run($r) {
    $a = @('--headless', '--path', '.', '--script', 'res://tests/bot/bot_report.gd', '--',
        "--level=$($r.Level)", "--difficulty=$($r.D)", "--classes=$($r.Class)", "--out=$($r.Md)")
    if ($Maps.Count) { $a += "--maps=$($Maps -join ',')" }
    $line = ($a | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' '
    Start-Process -FilePath $godot -ArgumentList $line -WorkingDirectory $root -NoNewWindow -PassThru `
        -RedirectStandardOutput $r.Log -RedirectStandardError "$($r.Log).err"
}

# --- Lancement, plusieurs Godot à la fois ---
Clear-EmptyErrs  # restes des lancements précédents
if (-not $ReportOnly) {
    $todo = @($plan | Where-Object { -not ($Resume -and (Test-Done $_)) })
    Write-Host ("{0} essais à lancer ({1} déjà faits), {2} en parallèle, {3} s maximum chacun." -f `
            $todo.Count, ($plan.Count - $todo.Count), $Jobs, $TimeoutSec) -ForegroundColor Cyan
    $queue = [System.Collections.Generic.Queue[object]]::new()
    foreach ($r in $todo) { $queue.Enqueue($r) }
    $running = @{}; $finished = 0; $started = Get-Date
    try {
        while ($queue.Count -gt 0 -or $running.Count -gt 0) {
            while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
                $r = $queue.Dequeue()
                $p = Start-Run $r
                $running[$p.Id] = [pscustomobject]@{ Run = $r; Proc = $p; Start = Get-Date }
            }
            Start-Sleep -Milliseconds 500
            foreach ($id in @($running.Keys)) {
                $e = $running[$id]; $r = $e.Run
                $late = ((Get-Date) - $e.Start).TotalSeconds -gt $TimeoutSec
                if (-not $e.Proc.HasExited -and -not $late) { continue }
                if (-not $e.Proc.HasExited) { taskkill /PID $id /T /F 2>$null | Out-Null; $e.Proc.WaitForExit(5000) | Out-Null }
                $running.Remove($id); $finished++
                Remove-EmptyErr "$($r.Log).err"
                $secs = [int]((Get-Date) - $e.Start).TotalSeconds
                $head = '[{0}/{1}] {2,-30}' -f $finished, $todo.Count, $r.Tag
                $total = Select-String -Path $r.Log -Pattern '^Total : (\d+)/(\d+)' -Encoding utf8 | Select-Object -First 1
                if ($total) {
                    $g = $total.Matches[0].Groups
                    Write-Host ("$head {0}/{1} gagnées en {2} s" -f $g[1].Value, $g[2].Value, $secs)
                } elseif ($late) {
                    Write-Host "$head DÉLAI DÉPASSÉ ($TimeoutSec s) : processus tué" -ForegroundColor Red
                } else {
                    Write-Host "$head arrêté sans bilan (voir $($r.Log))" -ForegroundColor Red
                }
                Get-Errors $r | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            }
        }
    } finally {
        # Ctrl+C ou erreur : aucun Godot ne doit survivre au script.
        foreach ($e in $running.Values) {
            if (-not $e.Proc.HasExited) { taskkill /PID $e.Proc.Id /T /F 2>$null | Out-Null; $e.Proc.WaitForExit(5000) | Out-Null }
        }
        Clear-EmptyErrs
    }
    Write-Host ("Essais terminés en {0:N0} min." -f ((Get-Date) - $started).TotalMinutes) -ForegroundColor Cyan
}

# --- Lecture des journaux : une ligne « classe/spé carte : résultat (vague, vies, or) » par partie ---
$rx = '^(?<cls>\S+)/(?<spec>\S+) (?<map>\S+) : (?<res>\S+) \(vague (?<wave>\d+), vies (?<lives>-?\d+), or (?<gold>-?\d+)\)'
$results = [System.Collections.Generic.List[object]]::new()
$byClass = @{}; $byMap = @{}
foreach ($r in $plan) {
    if (-not (Test-Path $r.Log)) { continue }
    foreach ($line in Get-Content $r.Log -Encoding utf8) {
        if ($line -notmatch $rx) { continue }
        $x = [pscustomobject]@{
            D = $r.D; Difficulte = $gd.difficulties[$r.D].name; Niveau = $r.Level
            ClasseId = $Matches.cls; Classe = $className[$Matches.cls]
            SpeId = $Matches.spec; Spe = $specName["$($Matches.cls)/$($Matches.spec)"]
            CarteId = $Matches.map; Carte = $mapName[$Matches.map]
            Gagne = $Matches.res -eq 'victory'; Vague = [int]$Matches.wave; Vies = [int]$Matches.lives; Or = [int]$Matches.gold
        }
        $results.Add($x)
        foreach ($pair in @(@($byClass, "$($r.D)|$($r.Level)|$($x.ClasseId)"), @($byMap, "$($r.D)|$($r.Level)|$($x.CarteId)"))) {
            if (-not $pair[0].ContainsKey($pair[1])) { $pair[0][$pair[1]] = [System.Collections.Generic.List[object]]::new() }
            $pair[0][$pair[1]].Add($x)
        }
    }
}
if ($results.Count -eq 0) { Write-Host "Aucun résultat dans $runDir." -ForegroundColor Red; exit 1 }

function Get-Color($won, $total) {
    if ($total -eq 0) { 'DarkGray' } elseif ($won -eq $total) { 'Green' } elseif ($won -eq 0) { 'Red' } else { 'Yellow' }
}
function Write-Cell([string]$text, [string]$color, [int]$width = 4) { Write-Host $text.PadLeft($width) -NoNewline -ForegroundColor $color }
function Get-Won($rows) { @($rows | Where-Object Gagne).Count }

# --- Écran : par difficulté et niveau, classes × cartes (nombre de spécialisations gagnantes) ---
$nameW = if ($Detail) { 26 } else { 14 }
$i = 0
Write-Host ("`nCartes : " + (($mapList | ForEach-Object { $i++; "$i $($_.name)" }) -join ' · '))
Write-Host "Case : spécialisations qui gagnent (vert = toutes, rouge = aucune) ; -Detail : V ou vague de la défaite."
foreach ($co in $combos) {
    Write-Host ("`n== {0} · niveau {1} ==" -f $co.Name, $co.Level) -ForegroundColor Cyan
    Write-Host ((' ' * $nameW) + (-join (1..$mapList.Count | ForEach-Object { "$_".PadLeft(4) })))
    foreach ($c in $Classes) {
        $cid = $gd.builders[$c].id
        $rows = $byClass["$($co.D)|$($co.Level)|$cid"]
        Write-Host $className[$cid].PadRight($nameW) -NoNewline
        if (-not $rows) { Write-Host '  pas de résultat' -ForegroundColor DarkGray; continue }
        foreach ($m in $mapList) {
            $g = @($rows | Where-Object CarteId -eq $m.id); $w = Get-Won $g
            Write-Cell $(if ($g.Count) { "$w" } else { '·' }) (Get-Color $w $g.Count)
        }
        $w = Get-Won $rows
        Write-Host ("  {0}/{1}" -f $w, $rows.Count) -ForegroundColor (Get-Color $w $rows.Count)
        if (-not $Detail) { continue }
        foreach ($s in @($rows | ForEach-Object SpeId | Select-Object -Unique)) {
            $label = "  · " + $specName["$cid/$s"]
            Write-Host $label.PadRight($nameW) -NoNewline
            foreach ($m in $mapList) {
                $x = $rows | Where-Object { $_.SpeId -eq $s -and $_.CarteId -eq $m.id } | Select-Object -First 1
                if (-not $x) { Write-Cell '·' DarkGray } elseif ($x.Gagne) { Write-Cell 'V' Green } else { Write-Cell "$($x.Vague)" Red }
            }
            Write-Host ''
        }
    }
}

# --- Écran : par carte, spécialisations gagnantes (toutes classes) dans chaque difficulté ---
$mapW = 18
Write-Host "`n== Par carte : spécialisations gagnantes, toutes classes ==" -ForegroundColor Cyan
Write-Host ((' ' * $mapW) + (-join ($combos | ForEach-Object { $_.Short.PadLeft(7) })))
foreach ($m in $mapList) {
    Write-Host $m.name.PadRight($mapW) -NoNewline
    foreach ($co in $combos) {
        $g = $byMap["$($co.D)|$($co.Level)|$($m.id)"]; $n = if ($g) { $g.Count } else { 0 }; $w = Get-Won $g
        Write-Cell $(if ($n) { "$w/$n" } else { '·' }) (Get-Color $w $n) 7
    }
    Write-Host ''
}

# --- Fichiers : BILAN.md et bilan.csv ---
$md = [System.Collections.Generic.List[string]]::new()
$md.Add("# Bilan du bot"); $md.Add("")
$md.Add("Généré le $(Get-Date -Format 'yyyy-MM-dd HH:mm'), $($results.Count) parties. Case : spécialisations qui gagnent sur la carte.")
$md.Add(""); $md.Add("## Par carte (toutes classes)"); $md.Add("")
$md.Add("| Carte | " + (($combos | ForEach-Object { "$($_.Name) $($_.Level)" }) -join ' | ') + " |")
$md.Add("|---|" + ('---|' * $combos.Count))
foreach ($m in $mapList) {
    $cells = foreach ($co in $combos) { $g = $byMap["$($co.D)|$($co.Level)|$($m.id)"]; if ($g) { "$(Get-Won $g)/$($g.Count)" } else { '·' } }
    $md.Add("| $($m.name) | " + ($cells -join ' | ') + " |")
}
$mapHeader = ($mapList | ForEach-Object { $_.name }) -join ' | '
foreach ($co in $combos) {
    $md.Add(""); $md.Add("## $($co.Name) · niveau $($co.Level)"); $md.Add("")
    $md.Add("| Classe | $mapHeader | Gagnées |"); $md.Add("|---|" + ('---|' * ($mapList.Count + 1)))
    $specLines = [System.Collections.Generic.List[string]]::new()
    foreach ($c in $Classes) {
        $cid = $gd.builders[$c].id
        $rows = $byClass["$($co.D)|$($co.Level)|$cid"]
        if (-not $rows) { continue }
        $cells = foreach ($m in $mapList) { $g = @($rows | Where-Object CarteId -eq $m.id); if ($g.Count) { "$(Get-Won $g)/$($g.Count)" } else { '·' } }
        $md.Add("| $($className[$cid]) | " + ($cells -join ' | ') + " | $(Get-Won $rows)/$($rows.Count) |")
        foreach ($s in @($rows | ForEach-Object SpeId | Select-Object -Unique)) {
            $cells = foreach ($m in $mapList) {
                $x = $rows | Where-Object { $_.SpeId -eq $s -and $_.CarteId -eq $m.id } | Select-Object -First 1
                if (-not $x) { '·' } elseif ($x.Gagne) { "V $($x.Vies)" } else { "✗ $($x.Vague)" }
            }
            $specLines.Add("| $($className[$cid]) · $($specName["$cid/$s"]) | " + ($cells -join ' | ') + " |")
        }
    }
    $md.Add(""); $md.Add("| Spécialisation | $mapHeader |"); $md.Add("|---|" + ('---|' * $mapList.Count))
    $specLines | ForEach-Object { $md.Add($_) }
}
$mdPath = Join-Path $root "$OutDir/BILAN.md"
$csvPath = Join-Path $root "$OutDir/bilan.csv"
Set-Content -Path $mdPath -Value $md -Encoding utf8
$results | Select-Object Difficulte, Niveau, Classe, Spe, Carte, @{ n = 'Gagne'; e = { if ($_.Gagne) { 'oui' } else { 'non' } } }, Vague, Vies, Or |
    Export-Csv -Path $csvPath -Delimiter ';' -Encoding utf8BOM
Write-Host "`nBilan écrit : $mdPath et $csvPath" -ForegroundColor Cyan
