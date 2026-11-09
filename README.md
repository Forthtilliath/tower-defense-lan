# Tower Defense LAN

Tower defense jouable **à plusieurs en réseau local**, sur **PC Windows** et **Android**, sans serveur ni connexion Internet.
Un appareil héberge la partie (PC ou téléphone), les autres la rejoignent depuis le même Wi-Fi.

Projet né en 2021 chez *Les Étudiants du Web* (Forth, Saucedechoux, Atthis) sous forme de prototype JavaScript,
puis réécrit avec [Godot 4](https://godotengine.org). Le prototype d'origine est conservé sous le tag git `prototype-js`.
Sa carte vit encore dans le jeu : « Héritage (prototype 2021) ».

## Modes de jeu

| Mode | Principe |
|------|----------|
| **Coopération** | Une seule carte, vies communes. Chacun construit avec son propre or ; la prime d'un monstre va au propriétaire de la tourelle qui l'a tué. Chaque joueur supplémentaire ajoute 35 % de monstres (plus serrés) et 30 % de PV. |
| **Versus** | Chacun son plateau. Envoyer un monstre chez l'adversaire suivant coûte de l'or mais augmente le revenu versé à chaque vague. Après la dernière vague, la « mort subite » rend les vagues toujours plus dures. Le dernier en vie gagne. |

On peut jouer seul (coop solo) pour s'entraîner. Jusqu'à **4 joueurs**.
Entre deux vagues, « Prêt ! » lance la suivante en avance, avec un bonus d'or égal aux secondes restantes (quand tous les joueurs sont prêts).

### Contenu

- **7 cartes** de 12 à 20 vagues : Prairie, Carrefour, Héritage, Rivière, Trois portes (3 entrées), Spirale, Labyrinthe.
- **4 difficultés**, choisies par l'hôte : Facile, Normal, Difficile, Cauchemar (PV des monstres, vies, or de départ, primes).
- **8 tourelles à 5 niveaux** (revente à 70 %) : Arbalète (rapide, air et sol), Canon (zone au sol), Givre (ralentit),
  Baliste (longue portée), Tesla (arc qui rebondit), Venin (poison qui ignore l'armure), Mortier (grosse zone, très longue portée),
  Sentinelle (anti-aérien).
- **14 monstres** : Gobelin, Rat, Loup, Orc, Squelette (armure), Chauve-souris (volante), Gelée (se divise à sa mort),
  Chaman (soigne ses voisins), Spectre (volant, se régénère), Troll (se régénère), Golem (armure, insensible au ralentissement),
  Dragon (boss volant), Liche (boss final).
- **Cases spéciales** (cadre coloré) : Colline (+25 % de portée), Cristal (+30 % de dégâts), Rune (+25 % de cadence),
  Filon d'or (+15 or par vague au propriétaire de la tourelle).

Les volants vont en ligne droite du départ à l'arrivée (pointillés sur le plateau) : il faut de l'anti-aérien sur leur route.
L'armure retire des dégâts fixes à chaque coup (au moins 25 % passent toujours) : préférer les gros coups ou le poison.

## Jouer en réseau local

1. Tous les appareils sont sur **le même réseau Wi-Fi**.
2. Un joueur choisit **Héberger une partie**. Son adresse IP s'affiche dans le salon.
3. Les autres choisissent **Rejoindre une partie** : la partie apparaît d'elle-même. Sinon, saisir l'IP de l'hôte.
4. L'hôte choisit le mode et la carte, puis lance.

**Windows** : au premier lancement en tant qu'hôte, Windows demande d'autoriser le jeu dans le pare-feu. Accepter pour les **réseaux privés**.
Ports utilisés (UDP) : `47800` (partie) et `47801` (découverte des parties).

Certains réseaux (Wi-Fi public, invité, « isolation des clients ») bloquent la communication entre appareils : utiliser alors un réseau domestique ou le partage de connexion d'un téléphone.

## Installation

- **Windows** : lancer `TowerDefenseLAN-<version>.exe` (fichier unique, rien à installer).
- **Android** : installer `TowerDefenseLAN-<version>.apk` (autoriser l'installation depuis cette source).

## Développement

Prérequis : [Godot 4.7.2](https://godotengine.org/download) (version standard, pas .NET). Les scripts `tools/` cherchent
`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe`, ou le chemin indiqué dans la variable `GODOT_BIN`.

```powershell
.\tools\verify.ps1   # import, compilation des scripts, tests, test réseau hôte + client
.\tools\build.ps1    # build\TowerDefenseLAN-<version>.exe et .apk signé (release)
```

Le build Android nécessite les modèles d'export Godot 4.7.2, le SDK Android et la clé de signature release
(voir plus bas). Pour publier une nouvelle version : augmenter `config/version` dans `project.godot`,
ainsi que `version/name` **et** `version/code` dans `export_presets.cfg`.

### Organisation

```
data/game_data.json   Tourelles, monstres, vagues et cartes (modifiable sans toucher au code)
scripts/core/         Validation partagée (Check) et réglages du joueur
scripts/data/         Chargement et validation des données, cartes et chemins
scripts/sim/          Simulation (hôte) : plateau, monstres, tourelles, règles, commandes
scripts/net/          Réseau local : session ENet, RPC, découverte UDP, boucle de l'hôte
scripts/ui/           Écrans et dessin du plateau
tests/                Tests (headless) et tests automatisés réseau / captures
tools/                Scripts PowerShell : vérification et build
```

Les cartes s'écrivent en texte dans `data/game_data.json` : `.` herbe constructible, `=` route, `S` départ, `E` arrivée,
`#` rocher, `~` eau, `T` arbre, et les symboles des cases spéciales (`^` colline, `*` cristal, `!` rune, `$` filon d'or).
Les chemins sont calculés automatiquement de chaque départ vers l'arrivée la plus proche. `flyer_speed` (facultatif)
ralentit les volants sur une carte où leur ligne droite est un trop grand raccourci (Spirale, Labyrinthe).

Équilibrage : `tests/test_balance.gd` fait jouer un bot simple, qui doit gagner chaque carte en Normal ; après
une modification des données, relancer `tools/verify.ps1`.

### Architecture réseau

L'hôte **fait autorité** : il est le seul à simuler la partie (20 ticks/s) et diffuse l'état 10 fois par seconde.
Les autres appareils n'envoient que des **commandes** (construire, améliorer, vendre, envoyer un monstre, prêt)
et interpolent l'affichage entre deux états reçus.

### Sécurité

- Toute donnée externe est **validée en entier avant usage**, et rejetée à la première anomalie :
  fichier de données, réglages, annonces LAN, messages de salon, états de jeu reçus, commandes des joueurs (types, bornes, propriétaire, or).
- L'hôte limite les commandes à 20 par seconde et par joueur, exclut les connexions qui ne se présentent pas sous 5 s
  et refuse les versions différentes.
- Le décodage d'objets Godot à travers le réseau reste désactivé (réglage par défaut).
- APK : sauvegarde Android désactivée, 4 permissions réseau seulement, signé avec une **clé release dédiée**.
  Cette clé est stockée **hors du dépôt** (`%USERPROFILE%\.android-keys\`) et passée au build par variables d'environnement.
  **Sans elle, impossible de publier une mise à jour installable par-dessus** : la sauvegarder (gestionnaire de mots de passe).
- Limites connues : le trafic du jeu n'est pas chiffré (aucune donnée personnelle n'y circule à part les pseudos),
  et toute personne sur le même réseau peut rejoindre un salon ouvert.

## Licence

MIT, comme le projet d'origine.
