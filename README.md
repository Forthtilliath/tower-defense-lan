# Tower Defense LAN

Tower defense jouable **à plusieurs en réseau local**, sur **PC Windows** et **Android**, sans serveur ni connexion Internet.
Un appareil héberge la partie (PC ou téléphone), les autres la rejoignent depuis le même Wi-Fi.

Projet né en 2021 chez *Les Étudiants du Web* (Forth, Saucedechoux, Atthis) sous forme de prototype JavaScript,
puis réécrit avec [Godot 4](https://godotengine.org). Le prototype d'origine est conservé sous le tag git `prototype-js`.
Sa carte vit encore dans le jeu : « Héritage (prototype 2021) ».

## Modes de jeu

| Mode | Principe |
|------|----------|
| **Coopération** | Une seule carte, vies communes. Chacun construit avec son propre or ; la prime d'un monstre est partagée entre les joueurs qui ont contribué à sa mort. Chaque joueur supplémentaire ajoute 35 % de monstres (plus serrés) et 15 % de PV. |
| **Versus** | Chacun son plateau. Envoyer un monstre chez l'adversaire suivant coûte de l'or mais augmente le revenu versé à chaque vague. Après la dernière vague, la « mort subite » rend les vagues toujours plus dures. Le dernier en vie gagne. |

On peut jouer seul (coop solo) pour s'entraîner. Jusqu'à **4 joueurs**. On ne construit jamais sur la route.

### Dans le salon

- **Classe** (chaque joueur) : 3 tourelles de base, un bonus de classe, et un arbre de talents à 3 branches.
  - Touche-à-tout : sans bonus ; branches Artillerie, Éléments, Contrôle.
  - Artilleur : +15 % de dégâts ; Siège, Précision, Commandement (auras).
  - Arcaniste : +25 % de cadence, +15 % de dégâts ; Foudre, Alchimie (poison, feu), Hiver.
  - Éclaireur : +15 % de portée ; Tireur d'élite, Pièges (saignement, poison), Embuscade.
  - Gobelin : +25 % sur ses parts de primes, +2 % d'intérêts (plafond +20), tourelles 10 % moins fortes ; Usure, Bricolage, Coups bas.
  - Enchanteur : contrôles +30 % ; Envoûtement (charme), Terreur (peur), Choc (étourdissement) ; classe de soutien, faite pour l'équipe.
- **Talents et progression** (bouton « Talents » du salon) : chaque classe gagne de l'expérience à chaque partie
  (victoire : 10 XP par vague × difficulté ; défaite : 40 % de cette somme au prorata des vagues passées) et monte
  jusqu'au niveau 15, avec 1 point de talent par niveau. Les paliers 2, 3 et 4 d'une branche demandent 2, 4 et 5 points
  déjà placés dans cette branche ; les tourelles avancées se débloquent ainsi. Une branche complète coûte 7 points :
  au niveau 15, on en maîtrise deux sur trois, et deux joueurs de la même classe peuvent jouer très différemment.
  La progression est enregistrée sur chaque appareil (`progression.json`) et vérifiée à la relecture ; l'hôte revalide
  les talents de chacun (le niveau annoncé, lui, n'est pas vérifiable sans serveur).
- **Vote de difficulté** (chaque joueur) : Facile, Normal, Difficile ou Cauchemar. La plus votée l'emporte ; en cas d'égalité, la plus facile.
- **Rythme** (hôte, coopération) :
  - *Libre* : construire, améliorer et vendre à tout moment. « Vague suivante » appelle la prochaine vague, même pendant une vague
    (une seule vague d'avance), avec un bonus d'or égal aux secondes d'attente évitées.
  - *Entre les vagues* : une phase de construction de 20 s commence quand la carte est vide ; pendant une vague,
    impossible de construire, d'améliorer, de vendre ou d'appeler la vague suivante.
- **Lancement** (hôte, coopération) : *Vote de tous* (la vague part en avance quand tout le monde est prêt) ou *Hôte seul*.

Dans tous les cas, **la première vague ne part jamais seule** : on se prépare aussi longtemps qu'on veut, puis on la lance
(« Prêt ! » de tous les joueurs, ou l'hôte seul selon le lancement choisi).

### En coopération

- **Primes partagées selon la contribution** : la prime d'un monstre se répartit entre les joueurs selon les dégâts infligés,
  la part apportée par leurs auras et les secondes de contrôle. Un joueur de soutien gagne donc sa part sans tuer.
- **Intérêts** : à chaque vague, 4 % de l'or gardé (30 or au plus).
- **Don d'or** à un allié (panneau de droite) : le don coûte cher, l'allié ne reçoit que la moitié du montant.
- **Vagues spéciales** toutes les 5 vagues, annoncées à l'avance : Ruée (monstres plus rapides), Colosses (moitié moins de monstres,
  bien plus résistants et plus riches), Cuirassés (+2 d'armure). La vague 20 est celle du boss final.
- **Cartes partagées, en zones ou mixtes** : sur une carte en zones, chacun ne construit que dans la sienne (teintée de sa couleur) ;
  une carte mixte ajoute des cases communes. Avec moins de joueurs que de zones, chacun en tient plusieurs ;
  la zone d'un joueur qui quitte la partie devient commune.
- **Cartes à plusieurs couloirs séparés** (Quatre fiefs, Bastion) : la réserve de vies est multipliée par le nombre de couloirs,
  et si vous êtes moins nombreux que les couloirs, l'or de départ et des vagues l'est par le nombre de couloirs tenus.

### Contenu

- **10 cartes** de 12 à 20 vagues : Prairie, Carrefour, Héritage, Rivière, Trois portes (3 entrées), Spirale, Labyrinthe,
  et trois grandes cartes pour 2 à 4 joueurs : Grande plaine (partagée, un très long serpentin), Quatre fiefs (4 zones, 4 couloirs),
  Bastion (4 zones autour d'un couloir central commun).
- **4 difficultés** : Facile, Normal, Difficile, Cauchemar (PV des monstres, vies, or de départ, primes).
- **18 tourelles à 5 niveaux** (revente à 70 %), présentées dans une fiche avant construction (stats, portée sur la case) :
  - tir : Fléchettes (courte, très rapide, faible), Arbalète (moyenne, équilibrée), Broyeur (courte, lente, très forte),
    Baliste (tireur d'élite), Canon et Mortier (zone au sol), Sentinelle (anti-aérien) ;
  - éléments : Givre (ralentit, gèle à partir du niveau 3), Brasier (brûlure qui se cumule), Venin (poison),
    Épines (saignement en % des PV max), Tesla (foudre qui rebondit) ;
  - contrôles : Gong (étourdit en zone), Épouvantail (fait reculer), Flûte enchantée (charme : le monstre recule et frappe ses voisins) ;
  - soutien (ne tirent pas) : Tambour (cadence), Étendard (dégâts), Totem (contrôles), pour les tourelles à portée.
    La plus forte aura de chaque type s'applique.
- **Contrôles** : après un contrôle, un monstre en est protégé 1 s. Les gros monstres résistent (Troll, Golem, Dragon, Liche) ;
  boss et volants ne se laissent pas charmer.
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
4. Chacun choisit son bâtisseur et vote pour la difficulté ; l'hôte choisit le mode, la carte, le rythme et le lancement, puis lance.

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
Facultatifs aussi : `zones` (mêmes dimensions que la carte, `1` à `4` pour une zone de joueur, `.` pour une case commune),
`lanes` (nombre de couloirs défendus séparément, pour les vies et l'or en coopération), `min_players` / `max_players`
(nombre de joueurs conseillé, affiché dans le salon). Les bâtisseurs (`builders`) et les vagues spéciales
(`wave_modifiers`, appliquées par le champ `modifier` d'une vague) se règlent dans le même fichier.

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
