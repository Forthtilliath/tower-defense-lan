# Construit les grilles des nouvelles cartes : routes tracées par leurs virages, eau (rectangles),
# cases spéciales sur les meilleurs emplacements (couverture de route, espacées), décor rasable
# jusqu'à la part voulue (surtout sur les cases faibles, un peu sur les bonnes : le Terrassier).
# Usage : .\tools\build-maps.ps1 [-Json data\game_data.json -Write] (sans -Write : aperçu)
param([string]$Json, [switch]$Write)
$ErrorActionPreference = 'Stop'

function New-Grid($w, $h) { $g = New-Object 'char[,]' $h, $w; for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $g[$y, $x] = '.' } }; ,$g }

function Draw-Line($g, $pts) {
    for ($i = 1; $i -lt $pts.Count; $i++) {
        $a = $pts[$i - 1]; $b = $pts[$i]
        $dx = [math]::Sign($b[0] - $a[0]); $dy = [math]::Sign($b[1] - $a[1])
        $x = $a[0]; $y = $a[1]
        while ($true) { if ($g[$y, $x] -eq '.') { $g[$y, $x] = '=' }; if ($x -eq $b[0] -and $y -eq $b[1]) { break }; $x += $dx; $y += $dy }
    }
}

function Cover($g, $w, $h, $cx, $cy) {
    $n = 0
    for ($dy = -3; $dy -le 3; $dy++) { for ($dx = -3; $dx -le 3; $dx++) {
        $x = $cx + $dx; $y = $cy + $dy
        if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h -or [math]::Sqrt($dx * $dx + $dy * $dy) -gt 2.5) { continue }
        if ('=', 'S', 'E', '1', '2', '3', '4' -contains [string]$g[$y, $x]) { $n++ }
    } }
    $n
}

function Build($m) {
    $w = $m.w; $h = $m.h
    $g = New-Grid $w $h
    foreach ($r in $m.water) { for ($y = $r[1]; $y -lt $r[1] + $r[3]; $y++) { for ($x = $r[0]; $x -lt $r[0] + $r[2]; $x++) { $g[$y, $x] = '~' } } }
    foreach ($line in $m.routes) { Draw-Line $g $line }
    foreach ($s in $m.starts) { $g[$s[2], $s[1]] = [char]$s[0] }
    foreach ($e in $m.ends) { $g[$e[1], $e[0]] = 'E' }
    # Cases spéciales : meilleurs emplacements, espacés d'au moins `gap` cases.
    $cells = @()
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { if ($g[$y, $x] -eq '.') { $cells += , @($x, $y, (Cover $g $w $h $x $y)) } } }
    $sorted = $cells | Sort-Object { - $_[2] }, { $_[1] }, { $_[0] }
    $picked = @()
    foreach ($c in $sorted) {
        if ($picked.Count -ge $m.specials.Length) { break }
        $far = $true
        foreach ($p in $picked) { if ([math]::Abs($p[0] - $c[0]) + [math]::Abs($p[1] - $c[1]) -lt $m.gap) { $far = $false } }
        if ($far) { $picked += , $c }
    }
    for ($i = 0; $i -lt $picked.Count; $i++) { $g[$picked[$i][1], $picked[$i][0]] = [char]$m.specials[$i] }
    # Décor : part voulue des cases hors route ; 30 % sur les bonnes cases, le reste sur les faibles.
    $free = $cells | Where-Object { $g[$_[1], $_[0]] -eq '.' }
    $target = [int][math]::Round($m.decor * $free.Count)
    $limit = ($sorted[[int]($sorted.Count * 0.25)])[2]
    $good = @($free | Where-Object { $_[2] -ge $limit }); $weak = @($free | Where-Object { $_[2] -lt $limit })
    $rng = New-Object Random $m.seed
    $goodCount = [math]::Min($good.Count, [int][math]::Round($target * 0.3))
    $chosen = @(($good | Sort-Object { $rng.Next() }) | Select-Object -First $goodCount) + @(($weak | Sort-Object { $rng.Next() }) | Select-Object -First ($target - $goodCount))
    foreach ($c in $chosen) { $g[$c[1], $c[0]] = if ($rng.NextDouble() -lt $m.trees) { 'T' } else { '#' } }
    $rows = @()
    for ($y = 0; $y -lt $h; $y++) { $s = ''; for ($x = 0; $x -lt $w; $x++) { $s += $g[$y, $x] }; $rows += $s }
    ,$rows
}

$maps = [ordered]@{
    lac_gele = @{ name = 'Lac gelé'; theme = 'tundra'; tier = 1; players = 3; hp = 0.8; flyer = 0.7; w = 20; h = 10; seed = 11; gap = 4; decor = 0.13; trees = 0.6
        water = @(, @(1, 3, 14, 4)); starts = @(@('1', 0, 1), @('2', 0, 8)); ends = @(, @(19, 5))
        routes = @(@(@(0, 1), @(16, 1), @(16, 5), @(19, 5)), @(@(0, 8), @(16, 8), @(16, 5)))
        specials = 'ff^f^'; entries = @('1', '2', '12') }
    caldeira = @{ name = 'Caldeira'; theme = 'volcano'; tier = 2; players = 3; hp = 1.0; flyer = 0.5; w = 19; h = 13; seed = 23; gap = 4; decor = 0.13; trees = 0.4
        water = @(@(7, 4, 5, 5), @(9, 2, 1, 2), @(9, 10, 1, 1)); starts = @(, @('S', 0, 1)); ends = @(, @(12, 6))
        routes = @(, @(@(0, 1), @(17, 1), @(17, 11), @(1, 11), @(1, 3), @(5, 3), @(5, 9), @(13, 9), @(13, 6), @(12, 6)))
        specials = 'cococ'; entries = @() }
    tourbiere = @{ name = 'Tourbière'; theme = 'swamp'; tier = 1; players = 3; hp = 0.9; flyer = 0.8; w = 21; h = 13; seed = 37; gap = 4; decor = 0.15; trees = 0.85
        water = @(@(1, 3, 3, 2), @(1, 8, 3, 2), @(11, 1, 2, 2), @(11, 8, 2, 3)); starts = @(@('1', 0, 1), @('2', 0, 6), @('3', 0, 11)); ends = @(, @(20, 9))
        routes = @(@(@(0, 1), @(6, 1), @(6, 3), @(9, 3), @(9, 6)), @(@(0, 6), @(14, 6), @(14, 3), @(17, 3), @(17, 9), @(20, 9)), @(@(0, 11), @(6, 11), @(6, 9), @(9, 9), @(9, 6)))
        specials = 'bibib'; entries = @('2', '13', '1', '3', '12', '23', '123') }
    cryptes = @{ name = 'Cryptes'; theme = 'necropolis'; tier = 2; players = 3; hp = 0.85; flyer = 0.7; w = 21; h = 13; seed = 41; gap = 4; decor = 0.13; trees = 0.35
        water = @(); starts = @(@('1', 4, 2), @('2', 4, 10), @('3', 10, 2), @('4', 10, 10)); ends = @(, @(20, 10))
        routes = @(@(@(4, 2), @(4, 10)), @(@(10, 2), @(10, 10)), @(@(4, 6), @(13, 6), @(13, 2), @(17, 2), @(17, 10), @(20, 10)))
        specials = 'alal$'; entries = @('1', '2', '3', '4', '13', '24', '1234') }
    gorge_vautour = @{ name = 'Gorge du vautour'; theme = 'canyon'; tier = 1; players = 3; hp = 1.0; flyer = 0.6; w = 22; h = 12; seed = 53; gap = 5; decor = 0.15; trees = 0.25
        water = @(); starts = @(, @('S', 0, 2)); ends = @(, @(21, 1))
        routes = @(, @(@(0, 2), @(5, 2), @(5, 10), @(9, 10), @(9, 4), @(13, 4), @(13, 8), @(17, 8), @(17, 1), @(21, 1)))
        specials = 'vvv'; entries = @() }
    sylve = @{ name = 'Sylve profonde'; theme = 'forest'; tier = 1; players = 4; hp = 1.0; flyer = 0.6; w = 21; h = 13; seed = 67; gap = 4; decor = 0.2; trees = 0.85
        water = @(, @(2, 5, 3, 3)); starts = @(@('1', 0, 2), @('2', 0, 10)); ends = @(, @(20, 6))
        routes = @(@(@(0, 2), @(8, 2), @(8, 6), @(12, 6), @(12, 2), @(16, 2), @(16, 10), @(18, 10), @(18, 6), @(20, 6)), @(@(0, 10), @(8, 10), @(8, 6)))
        specials = 'npnpn'; entries = @('12', '1', '2') }
}

$blocks = @()
foreach ($id in $maps.Keys) {
    $m = $maps[$id]
    $rows = Build $m
    Write-Host "== $id"
    $rows | ForEach-Object { Write-Host "   $_" }
    $waves = (1..20 | ForEach-Object { '"' + $id + '_' + $_ + '"' }) -join ', '
    $head = '"id": "' + $id + '", "name": "' + $m.name + '", "theme": "' + $m.theme + '", "tier": ' + $m.tier
    if ($m.hp -ne 1.0) { $head += ', "hp": ' + $m.hp.ToString([cultureinfo]::InvariantCulture) }
    $head += ', "flyer_speed": ' + $m.flyer.ToString([cultureinfo]::InvariantCulture) + ', "max_players": ' + $m.players
    $b = "`t`t{`r`n`t`t`t" + $head + ",`r`n`t`t`t" + '"waves": [' + $waves + "],`r`n`t`t`t" + '"rows": [' + "`r`n"
    $b += (($rows | ForEach-Object { "`t`t`t`t`"$_`"" }) -join ",`r`n") + "`r`n`t`t`t]"
    if ($m.entries.Count -gt 0) { $b += ",`r`n`t`t`t" + '"entries": [' + (($m.entries | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']' }
    $b += "`r`n`t`t}"
    $blocks += $b
}
if (-not $Write) { return }
$text = [IO.File]::ReadAllText($Json)
foreach ($id in $maps.Keys) {  # carte déjà là : retirée avant d'être réécrite
    $text = [regex]::Replace($text, ',\r\n\t\t\{\r\n\t\t\t"id": "' + $id + '"[\s\S]*?\r\n\t\t\}(?=,|\r\n\t\])', '')
}
$close = $text.LastIndexOf("`r`n`t]`r`n}")
$text = $text.Substring(0, $close) + ",`r`n" + ($blocks -join ",`r`n") + $text.Substring($close)
[IO.File]::WriteAllText($Json, $text, (New-Object Text.UTF8Encoding $false))
"Écrit : $($blocks.Count) cartes"





