# Génère les vagues propres à chaque carte à partir de la courbe de référence (w1 à w20) :
# même or, mêmes PV et vague spéciale ; monstres de la famille de la carte, en nombre calculé pour
# garder la même « résistance » totale (PV pondérés par l'armure, la régénération, la vitesse…).
# Usage : .\tools\gen-waves.ps1 -Json data\game_data.json [-Write] (sans -Write : aperçu)
param([string]$Json, [switch]$Write)
$ErrorActionPreference = 'Stop'
$text = Get-Content $Json -Raw
$d = $text | ConvertFrom-Json
$mons = @{}
foreach ($m in $d.monsters) { $mons[$m.id] = $m }

function Num($o, $k) { if ($o.PSObject.Properties.Name -contains $k) { [double]$o.$k } else { 0.0 } }

function Weight($id) {
    $m = $mons[$id]
    $w = (Num $m 'hp') * (1 + 0.08 * (Num $m 'armor')) + 20 * (Num $m 'regen') + 30 * [math]::Min(1, (Num $m 'heal_radius'))
    if ((Num $m 'split_count') -gt 0) { $w += (Num $m 'split_count') * (Num $mons[$m.split_into] 'hp') }
    if ((Num $m 'brood_steps') -gt 0) { $w += ((Num $m 'brood_steps') - 1) * (Num $mons[$m.brood_into] 'hp') }
    if ((Num $m 'brood_interval') -gt 0) { $w += 4 * (Num $mons[$m.brood_into] 'hp') }
    if ((Num $m 'raise_interval') -gt 0) { $w += 2 * (Num $mons[$m.raise_into] 'hp') }
    if ((Num $m 'resist_physical') -ge 1) { $w *= 1.6 } elseif ((Num $m 'resist_pierce') -ge 1) { $w *= 1.2 }
    if ((Num $m 'burrow_interval') -gt 0) { $w *= 1.3 }
    if ((Num $m 'pack_count') -gt 0 -or (Num $m 'haste') -gt 0) { $w *= 1.15 }
    $w * [math]::Sqrt((Num $m 'speed') / 1.2)
}

# Familles : 20 vagues, monstres de chaque vague séparés par des virgules.
$families = [ordered]@{
    prairie = @('goblin', 'goblin,rat', 'goblin,wolf', 'orc', 'bat', 'wolf,goblin', 'rat,wolf', 'orc,shaman', 'troll,goblin', 'dragon,bat',
        'orc,wolf,shaman', 'bat,wolf', 'troll,orc', 'troll,goblin', 'dragon,orc', 'troll,shaman,wolf', 'troll,orc', 'dragon,wolf,bat', 'golem,troll,dragon', 'lich,golem,troll')
    carrefour = @('goblin', 'goblin,wolf', 'goblin,orc', 'orc', 'wolf', 'goblin,shaman', 'orc,saboteur', 'orc,goblin', 'troll,shaman,saboteur', 'troll,bat',
        'orc,shaman,saboteur', 'goblin,wolf,bat', 'troll,orc', 'orc,shaman,saboteur', 'bat,troll', 'troll,shaman', 'orc,troll,bat', 'goblin,orc,saboteur', 'troll,shaman,saboteur,bat', 'troll,orc,shaman,saboteur')
    riviere = @('wisp', 'slime', 'wisp,slime', 'slime', 'bat', 'slime,wisp', 'slime,wisp', 'turtle', 'hydra,wisp', 'hydra,spectre',
        'slime,turtle', 'wisp,spectre', 'turtle,slime', 'hydra,slime', 'spectre,wisp', 'hydra,turtle', 'spectre,slime,bat', 'hydra,wisp,spectre', 'turtle,hydra,spectre', 'hydra,turtle,lich')
    trois_portes = @('goblin', 'skeleton,goblin', 'orc', 'orc,skeleton', 'bat', 'skeleton,herald', 'chariot,orc', 'herald,skeleton', 'golem,orc', 'gargoyle,golem',
        'chariot,herald,skeleton', 'orc,saboteur', 'golem,herald', 'chariot,orc', 'gargoyle,chariot', 'golem,herald,skeleton', 'gargoyle,golem', 'chariot,herald,saboteur', 'golem,chariot,gargoyle', 'lich,golem,herald')
    spirale = @('wisp', 'imp', 'wisp,shade', 'warlock', 'spectre', 'imp,wisp', 'shade,wisp', 'warlock,imp', 'shaman,warlock,shade', 'spectre,warlock',
        'ghost,imp', 'shade,spectre', 'warlock,shaman', 'imp,shade,ghost', 'spectre,warlock', 'warlock,ghost,shaman', 'shade,spectre,imp', 'ghost,spectre', 'warlock,shade,spectre,ghost', 'lich,warlock,spectre')
    labyrinthe = @('rat', 'rat,goblin', 'wolf', 'wolf,rat', 'bat', 'shade,rat', 'wolf,snow_wolf', 'shade,wolf', 'snow_wolf,bat', 'bat,wolf',
        'shade,snow_wolf', 'bat,rat', 'wolf,shade', 'snow_wolf,shade,bat', 'bat,wolf', 'shade,snow_wolf', 'bat,wolf,rat', 'shade,bat', 'snow_wolf,shade,bat', 'dragon,wolf,shade,snow_wolf')
    grande_plaine = @('goblin', 'goblin,bat', 'bat', 'orc,bat', 'bat', 'vulture,goblin', 'bat,gargoyle', 'orc,vulture', 'gargoyle,spectre', 'dragon,bat',
        'vulture,orc,bat', 'spectre,gargoyle', 'orc,vulture', 'gargoyle,spectre,bat', 'dragon,spectre', 'vulture,troll', 'gargoyle,bat,dragon', 'spectre,vulture', 'dragon,gargoyle,troll', 'dragon,spectre,gargoyle,golem')
    quatre_fiefs = @('goblin', 'goblin,wolf', 'orc', 'orc,goblin', 'bat', 'orc,shaman', 'yeti,goblin', 'orc,wolf', 'orc,shaman,wolf', 'mammoth,bat',
        'yeti,orc', 'troll,wolf', 'mammoth,orc', 'yeti,shaman,orc', 'troll,bat', 'mammoth,yeti', 'troll,orc,shaman', 'yeti,wolf,bat', 'mammoth,troll,yeti', 'mammoth,troll,yeti,shaman')
    bastion = @('goblin', 'orc', 'orc,goblin', 'chariot', 'bat', 'saboteur,orc', 'chariot,orc', 'herald,orc', 'golem,saboteur', 'turtle,gargoyle',
        'chariot,herald', 'golem,saboteur', 'turtle,herald', 'chariot,golem', 'gargoyle,chariot', 'golem,turtle', 'herald,golem,saboteur', 'turtle,chariot', 'golem,turtle,chariot', 'lich,golem,turtle')
    lac_gele = @('wolf', 'snow_wolf', 'wolf,snow_wolf', 'yeti', 'bat', 'snow_wolf,wolf', 'yeti,wolf', 'mammoth', 'yeti,snow_wolf', 'mammoth,bat',
        'yeti,wolf,snow_wolf', 'bat,snow_wolf', 'mammoth,yeti', 'snow_wolf,yeti', 'bat,mammoth', 'mammoth,snow_wolf', 'yeti,mammoth,bat', 'snow_wolf,wolf,yeti', 'mammoth,yeti,bat', 'mammoth,yeti,snow_wolf')
    caldeira = @('imp', 'ember', 'imp,ember', 'warlock', 'gargoyle', 'ember,imp', 'imp,warlock', 'golem', 'ember,warlock,imp', 'dragon,gargoyle',
        'golem,imp', 'gargoyle,ember', 'golem,warlock', 'ember,imp,gargoyle', 'dragon,ember', 'golem,warlock,imp', 'gargoyle,golem', 'ember,dragon', 'golem,warlock,dragon', 'dragon,golem,ember')
    tourbiere = @('wisp', 'slime', 'wisp,slime', 'shaman,wisp', 'bat', 'slime,shaman', 'wisp,slime', 'hydra', 'slime,shaman,wisp', 'hydra,spectre',
        'ghost,wisp', 'spectre,slime', 'hydra,shaman', 'slime,shaman,wisp', 'spectre,hydra', 'hydra,shaman,slime', 'spectre,ghost,bat', 'wisp,hydra,spectre', 'hydra,ghost,spectre', 'hydra,shaman,spectre')
    cryptes = @('shade', 'skeleton', 'shade,skeleton', 'necromancer,shade', 'bat', 'skeleton,shade', 'necromancer,shade', 'shade,bat', 'skeleton,shade,bat', 'spectre,necromancer',
        'skeleton,shade', 'spectre,shade', 'necromancer,ghost', 'skeleton,shade,spectre', 'spectre,ghost', 'necromancer,skeleton,spectre', 'spectre,shade,bat', 'ghost,spectre', 'necromancer,ghost,spectre', 'lich,necromancer,spectre')
    gorge_vautour = @('rat', 'rat,scorpion', 'scorpion', 'chariot', 'vulture', 'scorpion,rat', 'sandworm', 'chariot,scorpion', 'sandworm,saboteur', 'vulture,chariot',
        'scorpion,sandworm', 'vulture,rat', 'chariot,saboteur', 'sandworm,scorpion,vulture', 'vulture,chariot', 'sandworm,chariot', 'vulture,scorpion,saboteur', 'sandworm,rat,vulture', 'chariot,sandworm,vulture', 'sandworm,chariot,scorpion,vulture')
    sylve = @('goblin', 'wolf', 'goblin,wolf', 'spider', 'bat', 'wolf,shade', 'spider,goblin', 'shade,wolf', 'spider,wolf', 'spider,bat,wolf',
        'wolf,spider,shade', 'bat,shade', 'sylvan,wolf', 'spider,shade,bat', 'sylvan,bat', 'spider,sylvan', 'shade,bat,wolf', 'spider,shade', 'sylvan,spider,bat', 'sylvan,spider,shade,bat')
}

$base = @{}
foreach ($w in $d.waves) { $base[$w.id] = $w }
$lines = @()
$ids = [ordered]@{}
foreach ($map in $families.Keys) {
    $list = $families[$map]
    if ($list.Count -ne 20) { throw "$map : $($list.Count) vagues" }
    $ids[$map] = @()
    for ($n = 1; $n -le 20; $n++) {
        $ref = $base["w$n"]
        $budget = 0.0; $duration = 0.0
        foreach ($g in $ref.groups) { $budget += $g.count * (Weight $g.monster); $duration += $g.count * $g.interval }
        $kinds = $list[$n - 1].Split(',')
        $groups = @()
        foreach ($k in $kinds) {
            if (-not $mons.ContainsKey($k)) { throw "$map vague $n : monstre $k inconnu" }
            $count = [math]::Max(1, [int][math]::Round($budget / $kinds.Count / (Weight $k)))
            $interval = [math]::Round([math]::Min(8.0, [math]::Max(0.25, $duration / $kinds.Count / $count)) * 20) / 20
            $groups += '{ "monster": "' + $k + '", "count": ' + $count + ', "interval": ' + $interval.ToString([cultureinfo]::InvariantCulture) + ' }'
        }
        $id = "${map}_$n"
        $ids[$map] += $id
        $head = '{ "id": "' + $id + '", "gold": ' + $ref.gold
        if ($ref.PSObject.Properties.Name -contains 'hp') { $head += ', "hp": ' + ([double]$ref.hp).ToString([cultureinfo]::InvariantCulture) }
        if ($ref.PSObject.Properties.Name -contains 'modifier') { $head += ', "modifier": "' + $ref.modifier + '"' }
        $lines += "`t`t" + $head + ', "groups": [' + ($groups -join ', ') + '] }'
    }
}
if (-not $Write) { $lines | Select-Object -First 25; return }
# Ajoute les vagues après la dernière vague de référence, remplace la liste de vagues des cartes.
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$marker = '"id": "w20"'
$at = $text.IndexOf($marker)
$end = $text.IndexOf($nl, $at)
$close = $text.IndexOf($nl + "`t],", $end)  # vagues déjà générées : remplacées
$text = $text.Substring(0, $end).TrimEnd(',') + $text.Substring($close)
$end = $text.IndexOf($nl, $text.IndexOf($marker))
$text = $text.Substring(0, $end) + ',' + $nl + ($lines -join (',' + $nl)) + $text.Substring($end)
foreach ($map in $ids.Keys) {
    $pattern = '("id": "' + $map + '"[^\r\n]*\r?\n\s*"waves": )\[[^\]]*\]'
    $quoted = ($ids[$map] | ForEach-Object { '"' + $_ + '"' }) -join ', '
    if (-not [regex]::IsMatch($text, $pattern)) { throw "carte $map : liste de vagues introuvable" }
    $text = [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + '[' + $quoted + ']' })
}
[IO.File]::WriteAllText($Json, $text, (New-Object Text.UTF8Encoding $false))
"Écrit : $($lines.Count) vagues"




