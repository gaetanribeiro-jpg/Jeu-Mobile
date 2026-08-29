# Reconquête

Jeu mobile Android : tactique au tour par tour + gestion de comté.
Moteur **Godot 4.x**, GDScript. Orientation **paysage verrouillée**.

**La conception complète est dans `docs/conception.md`.** Lis-la avant toute tâche de gameplay.
Ce fichier ne contient que les règles de travail.

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
│   ├── combat/     CombatEngine, Grid, Unit, Ability, AI
│   ├── economy/    production, coûts, consommation
│   └── campaign/   saisons, menace, Ordre, progression
├── scenes/     # combat/ city/ map/ expedition/ ui/
├── autoload/   # GameState, SaveManager, AudioManager, EventBus
├── assets/     # tiny_swords/ audio/ fonts/ icons/
├── shaders/
├── tests/
├── tools/      # scripts hors jeu : import de sprites, vérification d'assets
└── docs/       # conception.md
```

---

## Les six règles dures

1. **Aucune valeur chiffrée dans le code.** PV, dégâts, coûts, seuils, probabilités : tout dans `data/`. Si tu écris un nombre dans un `.gd` autre qu'un index ou une constante technique, c'est une erreur.
2. **`engine/` ne connaît pas Godot.** Pas de `Node`, pas de `Sprite2D`, pas de `get_tree()`. Uniquement des classes GDScript pures. C'est ce qui rend la logique testable en headless.
3. **Tout ce qui est dans `engine/` a des tests.** Une tâche de logique n'est pas finie sans son test dans `tests/`.
4. **Aléatoire à graine.** Toujours passer par `GameState.rng`. Jamais `randi()` en direct. Chaque combat stocke sa graine pour pouvoir rejouer un bug à l'identique.
5. **Sauvegarde après chaque action significative.** Sur mobile, l'app peut être tuée à tout moment.
6. **Zéro texte en dur dans l'UI.** Tout passe par les clés de traduction, même si le jeu ne sort qu'en français.

---

## Conventions

- **Code, identifiants, noms de fichiers, clés de données : en anglais.** `hero_warrior.tres`, `CombatEngine.gd`, `push_target()`.
- **Commentaires et messages de commit : en français.**
- **Textes joueur : en français**, dans `data/i18n/fr.csv`, jamais dans le code.
- Fichiers en `snake_case`, classes en `PascalCase`, signaux au passé (`unit_died`).
- Communication entre systèmes par `EventBus`, pas par références directes entre scènes.

---

## Décisions verrouillées — ne pas rouvrir

- **Projet personnel.** Le jeu ne sera ni vendu ni publié publiquement.
  Aucune licence d'asset n'est donc bloquante tant que ce cadre tient.
  Si ce cadre change un jour, `CREDITS.md` garde la liste de ce qu'il
  faudrait alors établir.

- **Le télégraphe** : les ennemis annoncent leur attaque un tour à l'avance, avec les dégâts chiffrés. Information parfaite, toujours.
- **Rien n'est irréversible avant validation du tour.** Un bouton Annuler est présent en permanence pendant le tour du joueur.
- **Blessures, pas mort instantanée.** 0 PV = hors de combat + 1 blessure. 3 blessures = mort définitive.
- **L'Ordre** : les maîtrises de classe sont permanentes et rétroactives, elles survivent à la mort des héros.
- **Trois ressources matérielles** (bois, or, vivres) + le Renom. Il n'y a pas de pierre : le pack d'assets n'en fournit pas.
- **Grille 8×6** en combat, 10×8 en siège. Combats de 3 à 6 tours.
- **Aucun bâtiment décoratif.** Chaque bâtiment répond à « qu'est-ce que ça permet à mes héros ? »
- **Pas de free-to-play** : pas d'énergie, pas de timer, pas de monnaie premium, pas de publicité.

Si une tâche semble contredire une de ces décisions, **signale-le au lieu de trancher tout seul**.

---

## Contraintes des assets

Tiny Swords (Pixel Frog). Grille **64×64**, animations à **10 fps**, filtrage **Nearest** obligatoire.

**L'inventaire complet et vérifié est en annexe § 16 de `docs/conception.md`.** Consulte-le avant de supposer qu'un sprite existe.

Ce que le pack **ne fournit pas** :
- **aucune animation de mort** sauf pour le Troll → effet universel (flash, fondu, poussière)
- une seule unité directionnelle, le **Lancer** (5 directions miroitables) ; toutes les autres sont en 2 directions
- pas de PNJ, pas d'intérieurs, pas de scènes de dialogue
- **pas de sprite de pierre, de ferme, de scierie, de marché ni de mur en dur** — la palissade est une tuile 64×64

Ce qu'il fournit et qu'il faut réutiliser plutôt que recréer :
- **46 portraits** (25 humains = 5 classes × 5 couleurs, 21 ennemis)
- particules : 2 poussières, 3 feux, 2 explosions, 1 gerbe d'eau
- **5 variantes de couleur du tileset** → les 4 saisons, gratuitement
- 8 nuages, tuile de vagues animée, `Shadow.png`
- UI étirable : bannières, rubans, 16 boutons, barres de vie, papiers, table en bois
- **poses de garde** (Troll Windup/Recovery, Turtle Guard In/Out, Minotaur, Panda, Skull, Warrior) → **c'est le télégraphe, dessiné**

**On conçoit avec ce que le pack sait dessiner, jamais contre.** Si une fonctionnalité demande un asset inexistant, dis-le avant de commencer, pas après.

Les feuilles d'animation ont des largeurs variables (768 à 5120 px). Nombre d'images = largeur / 64. Ne jamais coder un chemin de fichier en dur : passer par `data/assets.json`.

---

## Méthode de travail

- **Une tâche du listing = une session = un commit.** Les tâches ont des identifiants (`C1.7`, `V3.4`) ; ils sont dans `docs/conception.md`.
- **Commit avant toute modification structurante.**
- **Je ne peux pas jouer au jeu.** Je ne vois ni le rendu, ni le ressenti, ni les performances. Sur toute tâche touchant au game feel, termine en indiquant précisément **quoi tester et quoi regarder**.
- Si une tâche est plus grosse que prévu, **découpe-la et propose le découpage** au lieu de tout faire d'un bloc.
- Les idées nouvelles vont dans `plus-tard.md`. Elles n'entrent pas dans le périmètre en cours.

---

## Où en est le projet

*(à tenir à jour à chaque fin de session)*

- **Phase courante :** 1 — Moteur de combat. **Toute la logique est écrite.**
  Reste le rendu et l'interaction (C1.15 à C1.22).
- **Dernière tâche terminée :** C1.26 (cartes de combat)
- **Jalon visé :** Jalon 0, puis Jalon 1 — un combat complet jouable au doigt

**Fait :** tout le § Phase 0 sauf F0.1, F0.9, F0.13 · C1.1 à C1.14 ·
C1.24 · C1.25 · C1.26. P8.16 et T10.2 entamées.
**234 tests passent** sous Godot 4.6 en headless, dont 8 sur les vrais
fichiers du pack et un qui rejoue les 8 cartes de combat entières.

**Reste pour le Jalon 1 :** C1.15 à C1.22 — scène de combat, surbrillance
des cases, contrôles tactiles, prévisualisation fantôme, animations,
rendu du télégraphe, HUD, séquence du tour ennemi. C'est la partie que je
ne peux pas valider seul : je ne vois ni le rendu ni le ressenti.

**Outils de vérification, à relancer après toute modification :**
```bash
godot --headless --path . -s tools/verify_assets.gd     # 535 entrées
godot --headless --path . -s tools/verify_audio.gd      # 30 entrées
godot --headless --path . -s tools/verify_font.gd       # 140 glyphes
godot --headless --path . -s tools/verify_maps.gd       # 8 cartes
godot --headless --path . -s tools/simulate_combats.gd  # équilibrage
```

**En attente de Gaetan, sur un poste de travail :**
F0.1 (Godot 4.6 + SDK Android) · F0.9 (export APK → Jalon 0 constaté) ·
F0.13 (Aseprite, seulement pour de nouvelles couleurs).

**Questions ouvertes, à trancher par Gaetan :**

1. **Adjacence de la grille** (`data/combat/rules.json`, `grid.adjacency`).
   `orthogonal` = 4 voisins, distance de Manhattan. `diagonal` = 8 voisins,
   distance de Chebyshev. Le moteur marche dans les deux modes ; **c'est
   avant le rendu qu'il faut trancher**, parce que les surbrillances et
   les animations de déplacement se dessinent différemment.

   Mesuré sur la grille 8 × 6, unité au centre :

   | | orthogonal | diagonal |
   |---|---|---|
   | Guerrier (dépl. 3) atteint | 24 / 48 | 42 / 48 |
   | Moine (dépl. 4) atteint | 35 / 48 | **48 / 48** |
   | Archer (portée 2–4) vise | 30 / 48 | 39 / 48 |
   | Lancier (portée 1–2) vise | 12 / 48 | 24 / 48 |

   **Recommandation : garder `orthogonal`.** En diagonal, le Moine traverse
   toute la carte en un déplacement et le Guerrier en atteint 87 % : le
   placement cesse d'être une décision, donc la grille cesse d'être un jeu.
   L'argument des sprites tombe de lui-même — en distance de Manhattan une
   case en diagonale est à distance 2, donc le Lancier (portée 1–2) et
   l'Archer (portée 2–4) peuvent tous deux attaquer en diagonale. Les 8
   directions du Lancier et du Canon servent à l'orientation de l'attaque ;
   c'est le déplacement qui reste à 4 directions.
2. **Les ennemis sont trop faibles.** `tools/simulate_combats.gd` donne
   100 % de victoires avec une politique de joueur triviale. Leurs valeurs
   sont de mon invention — le document ne chiffre que les héros au § 3.1.
   À régler en T10.5, mais autant le savoir maintenant.
3. **Dégâts d'une poussée bloquée** (`rules.json`, `push.blocked_damage`),
   posé à 0 : le pousseur a gâché son coup.
4. **`.tres` ou `.json`** pour les données de classes (C1.23). Tout est en
   JSON aujourd'hui, plus simple à tester en headless.
5. **Les affectations de `data/audio.json`** ont été faites au nom des
   fichiers, pas à l'oreille.

**Constat à connaître :** un combat ne dépend d'aucun tirage aléatoire —
ni les dégâts, ni le choix de cible, ni les départages de l'IA. C'est
conforme au deuxième pilier, et c'est désormais un test explicite. Le
générateur à graine servira à la couche campagne (Convocation, cartes
d'événement, butin), pas au combat.
