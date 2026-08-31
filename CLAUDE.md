# Tiny Kingdoms

Jeu mobile Android : **Tactical RPG de gestion et d'exploration**. Le
joueur construit son royaume, développe ses héros, explore un monde
dangereux et mène lui-même ses compagnons dans des combats au tour par
tour fondés sur les **PA**, les **PM** et le positionnement.

Moteur **Godot 4.6**, GDScript. Orientation **paysage verrouillée**.

**La vision fondatrice est dans `docs/vision.md`. Elle prime sur tout.**
Lis-la avant toute tâche de gameplay.
**L'état du chantier et le plan de migration : `docs/etat-des-lieux.md`.**
**Pour installer le projet et exporter sur le téléphone : `docs/installation.md`.**

> `docs/conception.md` est la conception précédente (« Reconquête »).
> Elle est **caduque**, sauf son **annexe § 16 — l'inventaire vérifié des
> assets**, qui reste la référence. Ce qui en survit est listé dans
> `docs/etat-des-lieux.md`.

---

## La boucle, en une ligne

```
🏰 ROYAUME → 🗺️ EXPLORER → ⚔️ COMBAT → 💎 LOOT → 👤 HÉROS → 🏰 ROYAUME
```

Toute feature se juge à une seule question (§ 55) : **est-ce que ça
améliore cette boucle ?** Si non, elle va dans `plus-tard.md`.

Ordre de priorité absolu (§ 54), dans cet ordre et pas un autre :
**1. combat tactique amusant · 2. progression RPG · 3. exploration ·
4. royaume · 5. interconnexion · 6. contenu.**

---

## Commandes

```bash
godot --path .                                    # lancer le jeu
godot --headless --path . --import                # (re)importer les assets
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit  # lancer les tests
godot --headless --path . --export-debug "Android" build/reconquete.apk
```

**Version du moteur : Godot 4.6-stable.** GUT 9.5.0 est versionné dans
`addons/gut/` — rien à installer.

**Les assets Tiny Swords ne sont pas dans le dépôt** (la licence interdit
leur redistribution). Copier le pack à la main dans `assets/tiny_swords/free/`
et `assets/tiny_swords/enemy/` sur chaque poste ; ces deux dossiers sont
dans le `.gitignore`. Le code ne doit jamais planter parce qu'un asset
manque : `AssetTable` renvoie une erreur explicite, pas un crash.

---

## Arborescence

```
res://
├── data/       # .tres et .json — TOUTES les valeurs chiffrées vivent ici
├── engine/     # logique pure — AUCUNE dépendance à un nœud Godot
│   ├── assets/     AssetTable — le seul endroit qui résout un chemin
│   ├── combat/     CombatEngine, TurnOrder, Grid, Unit, Ability, IA
│   ├── heroes/     classes, statistiques, XP, compétences, équipement
│   ├── kingdom/    ressources, bâtiments, population, production
│   └── world/      régions, expéditions, rencontres, événements
├── scenes/     # combat/ kingdom/ world/ expedition/ ui/
├── autoload/   # GameState, SaveManager, AudioManager, EventBus
├── assets/     # tiny_swords/ audio/ fonts/ icons/
├── shaders/
├── tests/
├── tools/      # scripts hors jeu : import de sprites, vérification d'assets
└── docs/       # vision.md, etat-des-lieux.md, installation.md
```

---

## Les six règles dures

1. **Aucune valeur chiffrée dans le code.** PV, PA, PM, dégâts, portées, coûts, seuils, probabilités : tout dans `data/`. Si tu écris un nombre dans un `.gd` autre qu'un index ou une constante technique, c'est une erreur. Le § 46 en fait un principe : « dégâts, PA, PM, portée, PV, coûts, XP modifiables sans réécrire la logique ».
2. **`engine/` ne connaît pas Godot.** Pas de `Node`, pas de `Sprite2D`, pas de `get_tree()`. Uniquement des classes GDScript pures. C'est ce qui rend la logique testable en headless.
3. **Tout ce qui est dans `engine/` a des tests.** Une tâche de logique n'est pas finie sans son test dans `tests/`.
4. **Aléatoire à graine.** Toujours passer par `GameState.rng`. Jamais `randi()` en direct. Chaque combat stocke sa graine pour pouvoir rejouer un bug à l'identique. Le roguelite en dépend.
5. **Sauvegarde après chaque action significative.** Sur mobile, l'app peut être tuée à tout moment.
6. **Zéro texte en dur dans l'UI.** Tout passe par les clés de traduction, même si le jeu ne sort qu'en français.

**Règle d'architecture (§ 46) :** construire modulaire, pas monumental.
Chaque système évolue indépendamment. On n'écrit pas l'architecture des
régions avant que le combat soit fun.

---

## Conventions

- **Code, identifiants, noms de fichiers, clés de données : en anglais.** `hero_warrior.tres`, `CombatEngine.gd`, `push_target()`.
- **Commentaires et messages de commit : en français.**
- **Textes joueur : en français**, dans `data/i18n/fr.csv`, jamais dans le code.
- Fichiers en `snake_case`, classes en `PascalCase`, signaux au passé (`unit_died`).
- Communication entre systèmes par `EventBus`, pas par références directes entre scènes.

---

## Décisions verrouillées — ne pas rouvrir

### Cadre

- **Projet personnel.** Le jeu ne sera ni vendu ni publié publiquement.
  Aucune licence d'asset n'est donc bloquante tant que ce cadre tient.
  Si ce cadre change un jour, `CREDITS.md` garde la liste de ce qu'il
  faudrait alors établir.
- **Pas de free-to-play** : pas d'énergie, pas de timer, pas de monnaie
  premium, pas de publicité.
- **Pas de mort définitive dans le MVP** (§ 25). Le héros principal ne
  meurt jamais définitivement. On construit d'abord un système amusant.

### Combat

- **PA / PM.** Chaque personnage dispose de Points d'Action et de Points
  de Mouvement, remis à neuf au début de son activation. 1 case = 1 PM.
  Les compétences coûtent des PA. C'est le cœur du jeu (§ 13).
- **Timeline d'initiative entremêlée** (§ 16). Un seul personnage agit à la
  fois, alliés et ennemis mélangés selon leur initiative. Le joueur voit
  toujours qui joue maintenant et qui joue ensuite.
- **Grille 12 × 9.** Justifié dans `etat-des-lieux.md` § 4.2 : avec un arc
  qui porte à 4–7 et 4 à 5 PM, une grille plus petite fait disparaître le
  positionnement.
- **Adjacence orthogonale** : 4 voisins, distance de Manhattan. Une case
  en diagonale est donc à distance 2. Les 8 directions dessinées servent à
  l'orientation de l'attaque, pas au déplacement. 1 case = 1 PM n'a de sens
  que si toutes les cases voisines coûtent pareil.
- **Le télégraphe** : les ennemis annoncent leur attaque avant de la
  porter, avec les dégâts chiffrés. Information parfaite, toujours. Le § 39
  le réclame pour les boss ; on le garde pour tout le monde.
- **Rien n'est irréversible avant la fin de l'activation.** Un bouton
  Annuler est présent en permanence pendant le tour d'un personnage joueur.
- **Placement initial.** Le joueur pose son équipe avant le premier tour,
  sur les cases que la carte propose. Il y en a plus que de personnages :
  c'est ce qui en fait une décision.
- **Échelle des chiffres du § 47** : PV autour de 100, dégâts autour de 20.
  L'équipement et le critique ont besoin de cette granularité.

### Héros

- **Trois classes dans le MVP** : Guerrier, Archer, **Mage**. Les autres
  (Lancier, Assassin, Paladin, Druide, Berserker…) viendront après.
- **Le Mage utilise le sprite du Moine.** Le pack n'a pas de mage ; le
  Moine est une figure encapuchonnée avec une animation d'incantation et
  son effet séparé. Voir `etat-des-lieux.md` § 3.1.
- **Équipe de 4 personnages au maximum** dans le MVP (§ 23).

### Royaume

- **Quatre ressources** : bois, pierre, or, nourriture (§ 6). Ne pas en
  ajouter dans le MVP.
- **Ferme, scierie et mine sont des chantiers, pas des bâtiments** : un
  gisement + un Pawn assigné, avec ses animations d'interaction. Le pack
  dessine exactement ça, et ça montre la population au travail. Voir
  `etat-des-lieux.md` § 3.3.
- **Aucun bâtiment décoratif.** Chaque bâtiment répond à « qu'est-ce que
  ça permet à mes héros ? »
- **L'évolution visuelle du royaume est une exigence, pas un bonus** (§ 5).

Si une tâche semble contredire une de ces décisions, **signale-le au lieu
de trancher tout seul**.

---

## Contraintes des assets

Tiny Swords (Pixel Frog). Grille **64×64**, animations à **10 fps**,
filtrage **Nearest** obligatoire.

**L'inventaire complet et vérifié est en annexe § 16 de
`docs/conception.md`.** Consulte-le avant de supposer qu'un sprite existe.
Les cinq manques qui touchent la vision sont analysés dans
`docs/etat-des-lieux.md` § 3.

Ce que le pack **ne fournit pas** :
- **pas de mage** → le Moine tient le rôle
- **pas de sprite de pierre, de ferme, de scierie, de forge, de marché, de
  taverne, d'écurie, de cavalerie, de mur ni de porte**
- **aucune animation de mort** sauf pour le Troll → effet universel
  (flash, fondu, poussière)
- une seule unité directionnelle, le **Lancer** (5 directions
  miroitables) ; toutes les autres sont en 2 directions
- pas de PNJ, pas d'intérieurs, pas de scènes de dialogue

Ce qu'il fournit et qu'il faut réutiliser plutôt que recréer :
- **8 bâtiments × 5 couleurs** : château, caserne, camp d'archers,
  monastère, tour, 3 maisons
- **46 portraits** (25 humains = 5 classes × 5 couleurs, 21 ennemis)
- **le Pawn et ses quatre outils** (hache, pioche, couteau, marteau) avec
  animations d'interaction → c'est la production du royaume, dessinée
- particules : 2 poussières, 3 feux, 2 explosions, 1 gerbe d'eau → de quoi
  dessiner une boule de feu
- **5 variantes de couleur du tileset** → 5 biomes ou 4 saisons, gratuitement
- 8 nuages, tuile de vagues animée, `Shadow.png`
- UI étirable : bannières, rubans, 16 boutons, barres de vie, papiers,
  table en bois, 12 icônes
- **poses de garde** (Troll Windup/Recovery, Turtle Guard In/Out,
  Minotaur, Panda, Skull, Warrior) → **c'est le télégraphe, dessiné**

**On conçoit avec ce que le pack sait dessiner, jamais contre.** Si une
fonctionnalité demande un asset inexistant, dis-le avant de commencer, pas
après.

Les feuilles d'animation ont des largeurs variables (768 à 5120 px).
Nombre d'images = largeur / 64. Ne jamais coder un chemin de fichier en
dur : passer par `data/assets.json`.

---

## Méthode de travail

- **Une tâche du listing = une session = un commit.** Les tâches ont des
  identifiants (`T1.7`) ; ils sont dans `docs/etat-des-lieux.md` § 5.
- **Commit avant toute modification structurante.**
- **Je ne peux pas jouer au jeu.** Je ne vois ni le ressenti, ni les
  performances. Sur toute tâche touchant au game feel, termine en indiquant
  précisément **quoi tester et quoi regarder**.
- Si une tâche est plus grosse que prévu, **découpe-la et propose le
  découpage** au lieu de tout faire d'un bloc.
- Les idées nouvelles vont dans `plus-tard.md`. Elles n'entrent pas dans le
  périmètre en cours.

---

## Où en est le projet

*(à tenir à jour à chaque fin de session)*

- **Phase courante : 1 — cœur tactique PA/PM.** Le pivot vers la vision
  Tiny Kingdoms a été acté le 2026-08-31.
- **Dernière tâche terminée :** T1.1 à T1.8 — le cœur PA/PM et la timeline
  d'initiative. **338 tests passent** sous Godot 4.6 en headless.
- **Reste en Phase 1 :** T1.9 (HUD : jauges PA/PM, timeline, barre de
  compétences), T1.10 (les 8 cartes à réécrire en 12 × 9), T1.11
  (équilibrage).

**Le combat se joue, sur PC.** Écran de titre → composition de l'équipe →
choix d'une des 8 cartes → placement → combat.
`pointing/emulate_touch_from_mouse` est actif, donc la souris se comporte
comme un doigt.

**Mais le HUD est en retard sur le moteur (T1.9).** Le joueur ne dispose
pour l'instant que de l'attaque de base du personnage que la timeline
désigne. Les huit autres compétences existent, sont testées, et ne sont
pas atteignables au doigt. Ce n'est pas une régression : c'est la tâche
suivante.

**Les huit cartes sont encore en 8 × 6** alors que la référence est
12 × 9. Elles se chargent et se jouent ; `verify_maps` les liste à part
sous « à réécrire (T1.10) ».

**PAS DE TÉLÉPHONE ANDROID pour l'instant.** Les étapes F, G et H de
`docs/installation.md` (SDK, préréglage d'export, déploiement) attendent.
Conséquences, et elles sont limitées :
- Le jeu ne peut pas être constaté sur un appareil. Le reste du
  développement n'en dépend pas.
- Deux points restent invérifiables : la taille réelle des cibles tactiles
  et les 60 fps sur l'appareil. Tous les autres se testent à la souris.
- Rien à refaire le jour venu : le projet est déjà réglé pour Android
  (paysage, gl_compatibility, filtrage Nearest). Compter deux heures.

**Je peux voir le rendu.** xvfb est disponible dans mon conteneur :
```bash
xvfb-run -a godot --path . --resolution 1280x720 \
  -s tools/dev/screenshot.gd -- res://scenes/ui/boot.tscn /tmp/x.png
xvfb-run -a godot --path . --resolution 1280x720 \
  -s tools/dev/combat_storyboard.gd -- /tmp/planche vallee_03
```
Cinq défauts n'ont été trouvés que comme ça, dont deux vrais bugs.

**Toutes les valeurs de ressenti sont dans `data/combat/view.json`.**

**Outils de vérification, à relancer après toute modification :**
```bash
godot --headless --path . -s tools/verify_assets.gd     # 535 entrées
godot --headless --path . -s tools/verify_audio.gd      # 30 entrées
godot --headless --path . -s tools/verify_font.gd       # 140 glyphes
godot --headless --path . -s tools/verify_maps.gd       # 8 cartes
godot --headless --path . -s tools/simulate_combats.gd  # équilibrage
```

**Ce qui saute aux yeux et qu'il faut régler (T1.11) :**

`tools/compare_squads.gd` : **les 15 compositions gagnent à 100 %**, en
2,8 à 3,2 rondes. Les ennemis meurent avant d'avoir frappé — un héros a
8 ou 9 PA, donc deux à trois attaques par activation à ~30 dégâts, contre
30 à 45 PV d'ennemi. Les valeurs des ennemis sont de mon invention, celles
des héros suivent l'échelle du § 47. C'est T1.11, et les deux outils
(`simulate_combats`, `compare_squads`) diront quand ce sera réglé.

**Questions ouvertes, à trancher par Gaetan :**

1. **Le Mage utilise le sprite du Moine.** Décision prise par défaut pour
   ne pas bloquer ; c'est le seul choix qui ne coûte rien. À confirmer à
   l'œil quand le combat tournera.
2. **La pierre n'a pas d'icône** dans le pack. Découper `Rock1` ou piocher
   dans `icon_01..12` ?
3. **Ferme, scierie et mine en chantiers plutôt qu'en bâtiments** — c'est
   ce que le pack sait dessiner, mais ça change la tête du royaume.
4. **Les affectations de `data/audio.json`**, faites au nom des fichiers,
   jamais écoutées.
