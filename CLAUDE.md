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
│   ├── combat/     CombatEngine, Grid, Unit, Ability, AI
│   ├── economy/    production, coûts, consommation
│   └── campaign/   saisons, menace, Ordre, progression
├── scenes/     # combat/ city/ map/ expedition/ ui/
├── autoload/   # GameState, SaveManager, AudioManager, EventBus
├── assets/     # tiny_swords/ audio/ fonts/ icons/
├── shaders/
├── tests/
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

- **Phase courante :** 0 — Fondations
- **Dernière tâche terminée :** aucune
- **Jalon visé :** Jalon 0 — un écran noir affichant « Reconquête » sur le téléphone
