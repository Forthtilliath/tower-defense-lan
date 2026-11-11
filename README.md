# Tower Defense LAN

Tower defense jouable **à plusieurs en réseau local**, sur **PC Windows** et **Android**, sans serveur ni connexion Internet.
Un appareil héberge la partie (PC ou téléphone), les autres la rejoignent depuis le même Wi-Fi.

Projet né en 2021 chez *Les Étudiants du Web* (Forth, Saucedechoux, Atthis) sous forme de prototype JavaScript,
puis réécrit avec [Godot 4](https://godotengine.org). Le prototype d'origine est conservé sous le tag git `prototype-js`.

## Modes de jeu

| Mode | Principe |
|------|----------|
| **Coopération** | Une seule carte, vies communes. Chacun construit avec son propre or ; la prime d'un monstre est partagée entre les joueurs qui ont contribué à sa mort. Chaque joueur supplémentaire ajoute 35 % de monstres (plus serrés) et 15 % de PV. |
| **Versus** | Chacun son plateau. Envoyer un monstre chez l'adversaire suivant coûte de l'or mais augmente le revenu versé à chaque vague. Après la dernière vague, la « mort subite » rend les vagues toujours plus dures. Le dernier en vie gagne. |

On peut jouer seul (coop solo) pour s'entraîner. Jusqu'à **4 joueurs**. On ne construit jamais sur la route.

### Comptes

Au lancement : **Continuer** (liste des comptes de l'appareil, avec le pseudo et le niveau de chaque classe) ou
**Nouveau compte** (un pseudo, unique sur l'appareil). Chaque compte garde son pseudo, l'expérience et les talents de
chaque classe, dans `user://accounts/<id>.json`. Un fichier illisible n'est jamais effacé : il est mis de côté
(`<id>.invalid.json`) et signalé. Supprimer un compte demande confirmation.

**Historique et étoiles** : chaque partie terminée s'ajoute à l'historique du compte (100 dernières : date, carte,
difficulté, résultat, vies, classe et niveau, XP, coéquipiers et leur classe). « Historique des parties » (menu)
les liste avec des filtres (ta classe, coéquipier ou seul, classe d'un coéquipier, carte), le bilan des victoires
et un tableau des étoiles par carte et par difficulté. Une victoire en coopération rapporte des étoiles selon les
vies gardées : ★★★ à 90 % ou plus des vies de départ (18 sur 20 en Normal seul), ★★ à la moitié, ★ sinon ; le
record est gardé même quand la partie sort de l'historique. Dans le salon, chaque carte affiche les étoiles du compte
à la difficulté votée. L'historique fait partie du compte (envoyé avec lui d'un appareil à l'autre).

**Passer d'un appareil à l'autre** (ex. du PC au téléphone), sur le même Wi-Fi : sur l'appareil qui reçoit,
« Recevoir un compte » (accueil ou « Continuer ») affiche un code à 4 chiffres ; sur l'autre, « Continuer » →
« Envoyer » sur le compte, choisir l'appareil et taper le code. Le compte reçu est vérifié, montré (pseudo et niveaux),
puis enregistré seulement après confirmation ; un compte du même pseudo est remplacé. L'original reste sur l'appareil
qui l'a envoyé.

À la mise à jour, l'ancienne progression
unique (`progression.json`) devient automatiquement un compte au pseudo déjà utilisé (copie gardée en
`progression.migrated.json`).

### Dans le salon

Trois blocs : les **joueurs** (classe, niveau, vote) et la difficulté retenue à gauche ; la **partie** (options
réglées par l'hôte, aperçu de la carte) puis **tes choix** (classe, talents, vote) à droite. Le lancement est en bas.

- **Classe** (chaque joueur) : un bonus de classe, un tronc de talents et **4 spécialisations, dont une seule se choisit**.
  Tout le monde construit les 11 tourelles du tronc commun (Arbalète, Sentinelle, Fléchettes, Canon, Givre, Tesla,
  Brasier, Salamandre, Venin, Épines, Gong) ; chaque spécialisation renforce les siennes et en débloque 1 ou 2 au plus.
  - Artilleur (+10 % de dégâts des tirs physiques) : Brute (Broyeur), Tireur d'élite (Baliste), Artificier (Mortier), Mitrailleur.
  - Arcaniste (+10 % de dégâts du feu, de la foudre et de la glace) : Mage de feu (Lentille, Feu grégeois),
    de foudre (Pylône, Lance-foudre), de glace (Obélisque, Brise-glace), du vent (anti-aérien).
  - Fléau (+15 % de dégâts des effets continus) : Poison (Peste, Miasmes), Saignement (Faux), Gelure, Électrocution.
  - Support (+15 % de contrôles et d'auras) : Dompteur (Épouvantail, Flûte), Corrupteur (Alambic),
    Chef de guerre (Tambour, Étendard), Gardien (Totem) ; fait pour l'équipe.
  - Gobelin (+15 % sur ses parts de primes) : Chasseur de primes, Usurier (intérêts), Mécène (dons moins chers), Parieur.
  - Bâtisseur (+50 or de départ, tronc commun seulement) : Architecte (prix réduits), Ferrailleur (revente),
    Contremaître, Terrassier.

  Tourelles et mécaniques propres : Rafale (plusieurs cibles), Tourbillon (cloue les volants au sol), Stèle de gelure
  et Paratonnerre (imprègnent les tourelles voisines : gelure, monstres électrifiés qui subissent plus de dégâts),
  Phare (portée), Comptoir (prime des monstres tués à portée), Chantier (constructions moins chères autour, alliés
  compris), Alambic qui coupe les soins, primes d'équipe du Mécène, or des vagues lancées en avance ou sans fuite
  du Parieur, Terrassier qui rase arbres et rochers pour construire dessus et pose des cases bonus (Colline, Cristal,
  Rune, et avec ses talents Tableau de chasse, Butte et Fossé), avec un nombre de charges par partie selon ses talents.
- **Talents et progression** (bouton « Talents » du salon, un onglet par spécialisation) : chaque classe gagne de
  l'expérience à chaque partie (victoire : 10 XP par vague × difficulté — Difficile ×1,5, Cauchemar ×2 —, + 25 % ;
  défaite : chaque vague passée rapporte 10 %, 35 %, 60 % ou 85 % de ses 10 XP selon le quart de la partie atteint)
  et monte jusqu'au **niveau 30**, avec 1 point de talent par niveau. Le tronc (12 rangs) ne renforce que les
  tourelles de la classe ; une spécialisation compte 16 à 18 rangs (paliers à 3, 7, 11 et 15 points) : talents de
  mécanique (critiques, exécution, perforation, réactions entre éléments, contagion, auras, économie, étages…).
  Chaque spécialisation a un **talent ultime** (1 point, niveau 30) qui donne un **pouvoir actif** : un bouton en
  partie, rechargé en quelques vagues (ex. Météore à viser, Zéro absolu, Héroïsme, Ruée vers l'or, Coup de génie).
- **Héritage** : chaque classe montée au niveau 30 donne un bonus à toutes les autres, cumulable — Artilleur
  +20 % de dégâts des tirs physiques, Arcaniste +20 % des tourelles élémentaires, Fléau +20 % des effets continus,
  Support +25 % de contrôles et d'auras, Gobelin +100 or de départ et +15 % de primes, Bâtisseur −10 % sur les
  constructions et +10 % à la revente. Plus on a monté de classes, plus les suivantes sont faciles à monter. Les paliers 2, 3 et 4 d'une branche demandent 2, 4 et 5 points
  déjà placés dans cette branche. Placer un point dans une spécialisation ferme les trois autres ; on en change
  entre deux parties en retirant ses points.
  La progression appartient au **compte** choisi au lancement (voir *Comptes*), vérifiée à la relecture ; l'hôte revalide
  les talents de chacun (le niveau annoncé, lui, n'est pas vérifiable sans serveur).
- **Vote de difficulté** (chaque joueur) : Facile, Normal, Difficile ou Cauchemar. La plus votée l'emporte ; en cas d'égalité, la plus facile.
- **Rythme** (hôte, coopération) :
  - *Libre* : construire, améliorer et vendre à tout moment. « Vague suivante » appelle la prochaine vague, même pendant une vague
    (une seule vague d'avance), avec un bonus d'or égal aux secondes d'attente évitées.
  - *Entre les vagues* : une phase de construction de 20 s commence quand la carte est vide ; pendant une vague,
    impossible de construire, d'améliorer, de vendre ou d'appeler la vague suivante.
- **Lancement** (hôte, coopération) : *Vote de tous* (la vague part en avance quand tout le monde est prêt) ou *Hôte seul*.
- **Héritage** (hôte, coopération et versus) : *Activé* ou *Désactivé*. Désactivé, personne ne reçoit de bonus
  d'héritage : chacun joue avec sa classe et ses talents seulement, pour des parties plus équitables.

En partie, le bouton **Talents** de la barre du haut montre l'arbre joué, en lecture seule (la partie continue pendant
ce temps), avec la liste des bonus d'héritage du compte, marqués « désactivé » si l'hôte l'a coupé.

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
- **Support partout chez lui** : en coopération, le Support construit dans toutes les zones ouvertes, et ses alliés
  construisent dans la sienne.
- **Effets qui ne se cumulent pas** (poison, saignement sans charges en plus) : la tourelle vise d'abord un monstre qui
  ne les a pas encore, pour ne pas gaspiller ses coups.
- **Cartes à plusieurs couloirs séparés** (Quatre fiefs, Bastion) : un couloir s'ouvre par joueur, et la réserve de vies
  est multipliée par le nombre de couloirs ouverts. Les zones des couloirs fermés sont assombries : personne n'y construit
  (pas de pillage de leurs cases spéciales en petit comité).
- **Difficulté des cartes** : le salon les classe de la plus facile à la plus difficile. Sur les cartes à très longue route
  (Spirale, Labyrinthe, Quatre fiefs), les monstres ont plus de PV.

### Contenu

- **15 cartes** de 20 vagues, chacune avec ses propres monstres et ses propres cases spéciales :
  - décor Prairie : Prairie (bestiaire de base), Carrefour (peaux-vertes, 2 entrées), Rivière (créatures de l'eau),
    Trois portes (assaut armé, 3 entrées), Spirale (magie), Labyrinthe (coureurs), et trois grandes cartes pour 2 à 4 joueurs :
    Grande plaine (ciel ouvert), Quatre fiefs (horde, 4 zones, 4 couloirs), Bastion (siège, 4 zones autour d'un couloir commun) ;
  - cartes à thème, avec leur décor : Lac gelé (toundra, 2 entrées), Caldeira (volcan, spirale autour d'un cratère de lave),
    Tourbière (marais, 3 entrées), Cryptes (nécropole, 4 cryptes), Gorge du vautour (canyon, une très longue route),
    Sylve profonde (forêt dense, deux routes qui se frôlent).
- **Entrées par vague** : sur certaines cartes, les monstres arrivent par une entrée ou une autre selon la vague
  (ex. entrée 1, puis 2, puis les deux). La prochaine entrée est annoncée dans le panneau et clignote sur le plateau.
- **4 difficultés** : Facile, Normal, Difficile, Cauchemar (PV des monstres, vies, or de départ, primes).
- **36 tourelles à 5 niveaux** (revente à 70 %), présentées dans une fiche avant construction (stats, portée sur la case) :
  - tir : Fléchettes (courte, très rapide, faible), Arbalète (moyenne, équilibrée), Broyeur (courte, lente, très forte),
    Baliste (tireur d'élite), Canon et Mortier (zone au sol), Sentinelle (anti-aérien) ;
  - foudre : Tesla (rebondit), Pylône (onde autour de lui), Lance-foudre (traverse les monstres alignés, perce l'armure) ;
  - feu : Brasier (brûlure qui se cumule), Salamandre (souffle en cône), Feu grégeois (nappe de feu au sol),
    Lentille ardente (rayon continu qui chauffe sur la même cible) ;
  - glace : Givre (ralentit, gèle à partir du niveau 3), Obélisque (ralentit tout autour, sans dégâts),
    Brise-glace (frappe plus fort les monstres ralentis ou gelés) ;
  - poison : Venin, Alambic (ronge l'armure), Miasmes (nuage toxique au sol), Peste (poison contagieux) ;
  - saignement : Épines (en % des PV max), Faux (mêlée, coup critique un coup sur trois) ;
  - contrôles : Gong (étourdit en zone), Épouvantail (fait reculer), Flûte enchantée (charme : le monstre recule et frappe ses voisins) ;
  - soutien (ne tirent pas) : Tambour (cadence), Étendard (dégâts), Totem (contrôles), pour les tourelles à portée.
    La plus forte aura de chaque type s'applique.
- **Contrôles** : après un contrôle, un monstre en est protégé 1 s. Les gros monstres résistent (Troll, Golem, Dragon, Liche) ;
  boss et volants ne se laissent pas charmer.
- **23 monstres** : Gobelin, Rat, Loup (rapide), Orc, Squelette (armure), Chauve-souris (volante), Gelée (se divise à sa mort),
  Chaman (soigne ses voisins), Spectre (volant, se régénère), Troll (se régénère), Golem (armure, insensible au ralentissement),
  Dragon (boss volant), Liche (boss final), et des monstres à bonus :
  - Feu follet (lévite : les nappes au sol ne le touchent pas), Chariot (véhicule : insensible au poison, à la brûlure,
    au saignement, à la peur et au charme ; l'étourdissement et le ralentissement marchent) ;
  - résistances aux éléments (dégâts et effets de cet élément réduits) : Diablotin (feu), Yéti (glace : ralenti bien moins),
    Gargouille (foudre, volante), Sorcier (tous les éléments ; les tirs physiques restent entiers) ;
  - Ombre (bondit en avant toutes les 3 s), Porte-bouclier (ses voisins subissent 35 % de dégâts en moins),
    Saboteur (toutes les 5 s, brouille 2 s les tourelles proches, auras de soutien comprises) ;
  - monstres des thèmes : Mammouth (ses voisins avancent plus vite), Loup des neiges (plus rapide en meute),
    Braise vivante (se divise en étincelles), Hydre (une tête de plus à chaque tiers de PV perdu), Nécromancien
    (relève en squelette les morts voisins), Scorpion (armure, insensible au poison), Ver des sables (s'enfouit : ni visé
    ni touché), Vautour (volant qui ne dépasse pas les monstres au sol), Araignée (pond des petites), Sylvain
    (se régénère bien plus vite près des arbres).

  Le panneau de droite liste les monstres de la prochaine vague et leurs bonus. Une vague spéciale peut aussi donner
  lévitation, véhicule ou résistances à tous ses monstres (`wave_modifiers`).
- **Cases spéciales** (cadre coloré), 1 à 3 types par carte, toujours sur un bon emplacement (vérifié par un test) :
  Colline (+25 % de portée), Cristal (+30 % de dégâts), Rune (+25 % de cadence), Tableau de chasse (+1 or par monstre tué),
  Feu de camp / Coulée refroidie / Menhir (bonus des tourelles de feu / glace / foudre), Tourbière (effets plus longs),
  Belvédère (+50 % de portée, -15 % de cadence), Obsidienne (coups critiques), Nid de corbeaux (vise aussi les volants),
  Autel (dégâts doublés contre les gros), Cloche (auras plus larges), Pierre de sang (plus forte à chaque monstre tué),
  Filon instable (+60 % de dégâts, s'épuise après 6 vagues), Forge (améliorations moins chères), Îlot (pas de brouillage).

Les volants vont en ligne droite du départ à l'arrivée : il faut de l'anti-aérien sur leur route.
L'armure retire des dégâts fixes à chaque coup (au moins 25 % passent toujours) : préférer les gros coups ou le poison.

## Jouer en réseau local

1. Tous les appareils sont sur **le même réseau Wi-Fi**.
2. Un joueur choisit **Héberger une partie**. Son adresse IP s'affiche dans le salon.
3. Les autres choisissent **Rejoindre une partie** : la partie apparaît d'elle-même. Sinon, saisir l'IP de l'hôte.
4. Chacun choisit son bâtisseur et vote pour la difficulté ; l'hôte choisit le mode, la carte, le rythme, le lancement et l'héritage, puis lance.

**Windows** : au premier lancement en tant qu'hôte, Windows demande d'autoriser le jeu dans le pare-feu. Accepter pour les **réseaux privés**.
Ports utilisés (UDP) : `47800` (partie) et `47801` (découverte des parties) ; transfert de compte : `47802` (TCP)
et `47803` (UDP, découverte), ouverts seulement pendant « Recevoir un compte ».

Certains réseaux (Wi-Fi public, invité, « isolation des clients ») bloquent la communication entre appareils : utiliser alors un réseau domestique ou le partage de connexion d'un téléphone.

## Installation

- **Windows** : lancer `TowerDefenseLAN-<version>.exe` (fichier unique, rien à installer).
- **Android** : installer `TowerDefenseLAN-<version>.apk` (autoriser l'installation depuis cette source).

## Développement

Prérequis : [Godot 4.7.2](https://godotengine.org/download) (version standard, pas .NET). Les scripts `tools/` cherchent
`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe` (`Jouer.cmd` : la version sans console,
`Godot_v4.7.2-stable_win64.exe`), ou le chemin indiqué dans la variable `GODOT_BIN`.

```powershell
.\Jouer.cmd                  # lance le jeu depuis les sources (double-clic possible)
.\Jouer.cmd -Joueurs 2       # 2 à 4 fenêtres côte à côte pour tester la coop / le versus sur un seul PC
.\Jouer.cmd -Editeur         # ouvre le projet dans l'éditeur Godot
.\tools\verify.ps1   # import, compilation des scripts, tests, test réseau hôte + client
.\tools\build.ps1    # build\TowerDefenseLAN-<version>.exe et .apk signé (release)
```

Le build Android nécessite les modèles d'export Godot 4.7.2, le SDK Android et la clé de signature release
(voir plus bas). Pour publier une nouvelle version : augmenter `config/version` dans `project.godot`,
ainsi que `version/name` **et** `version/code` dans `export_presets.cfg`.

### Organisation

```
data/game_data.json      Tourelles, monstres, vagues et cartes (modifiable sans toucher au code)
scenes/main.tscn         Scène de départ
scripts/core/            Validation partagée (Check), réglages, comptes et progression
scripts/core/history/    Historique des parties et étoiles des cartes, validation à la relecture
scripts/data/            Chargement et validation des données, cartes et chemins
scripts/data/talents/    Talents : schéma, règles, validation des arbres, bonus d'un joueur
scripts/sim/match/       Simulation (hôte) : déroulé de la partie, commandes, or, pouvoirs
scripts/sim/board/       Plateau d'un joueur : combat, attaques, auras, talents, terrain
scripts/sim/units/       Monstres (capacités, effets, marques), tourelles, projectiles
scripts/net/             Réseau local : session ENet, RPC, découverte UDP, boucle de l'hôte
scripts/net/transfer/    Transfert d'un compte entre deux appareils
scripts/ui/main.gd       Racine de l'application : un écran à la fois
scripts/ui/screens/      Accueil, comptes, menu, rejoindre, envoyer / recevoir un compte
scripts/ui/screens/history/  Écran de l'historique : filtres, parties, étoiles par carte
scripts/ui/lobby/        Salon d'attente et arbre de talents
scripts/ui/game/         Écran de partie : barre du haut, panneaux, fin de partie, textes
scripts/ui/state/        État affiché, reconstruit à partir des instantanés de l'hôte
scripts/ui/board/        Dessin du plateau (décor, unités, effets) ; glyphs/ : silhouettes
scripts/ui/theme/        Thème, encre style manga, fond des menus
tests/                   run_tests.gd (tous les tests) et check_scripts (compilation)
tests/unit/              Tests headless, un fichier par thème
tests/bot/               Joueur automatique des tests d'équilibrage
tests/auto/              Test réseau de bout en bout et captures d'écran
tools/                   Scripts PowerShell : lancement, vérification et build
```

Les notes de conception (classes et talents, fiches des tourelles) sont dans `docs/`, non suivies par git.

Les cartes s'écrivent en texte dans `data/game_data.json` : `.` herbe constructible, `=` route, `S` départ, `E` arrivée,
`#` rocher, `~` eau, `T` arbre, `1` à `4` départs numérotés (entrées par vague, avec le motif `entries`, ex.
`["1", "2", "12"]`, répété en boucle), et les symboles des cases spéciales (`special_tiles`). `theme` choisit le décor
(prairie, tundra, volcano, swamp, necropolis, canyon, forest). Les nouvelles cartes et les vagues de chaque carte se
génèrent avec `tools/build-maps.ps1` et `tools/gen-waves.ps1`.
Les chemins sont calculés automatiquement de chaque départ vers l'arrivée la plus proche. `flyer_speed` (facultatif)
ralentit les volants sur une carte où leur ligne droite est un trop grand raccourci (Spirale, Labyrinthe).
Facultatifs aussi : `zones` (mêmes dimensions que la carte, `1` à `4` pour une zone de joueur, `.` pour une case commune),
`lanes` (nombre de couloirs défendus séparément, pour les vies et l'or en coopération), `tier` (difficulté affichée,
0 à 2, mesurée au bot), `hp` (PV des monstres sur cette carte, 1 par défaut), `min_players` / `max_players`
(nombre de joueurs conseillé, affiché dans le salon). Les bâtisseurs (`builders`) et les vagues spéciales
(`wave_modifiers`, appliquées par le champ `modifier` d'une vague) se règlent dans le même fichier.

Équilibrage : `tests/unit/test_balance.gd` fait jouer un bot simple (`tests/bot/balance_bot.gd`), qui doit gagner chaque carte en Normal ; après
une modification des données, relancer `tools/verify.ps1`.

### Architecture réseau

L'hôte **fait autorité** : il est le seul à simuler la partie (20 ticks/s) et diffuse l'état 10 fois par seconde.
Les autres appareils n'envoient que des **commandes** (construire, améliorer, vendre, envoyer un monstre, prêt)
et interpolent l'affichage entre deux états reçus.

### Sécurité

- Toute donnée externe est **validée en entier avant usage**, et rejetée à la première anomalie :
  fichier de données, réglages, comptes, annonces LAN, messages de salon, états de jeu reçus, commandes des joueurs (types, bornes, propriétaire, or).
- Transfert de compte : port ouvert seulement pendant l'attente, réseau local seulement, un message borné (128 Ko)
  par connexion et 8 s au plus, code à 4 chiffres tiré au hasard (5 essais, puis arrêt), compte revérifié en entier
  puis confirmé par le joueur avant d'être enregistré.
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
