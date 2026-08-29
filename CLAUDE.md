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
- **Adjacence orthogonale** : 4 voisins, distance de Manhattan. Une case en
  diagonale est donc à distance 2, ce qui la met à portée du Lancier (1–2)
  et de l'Archer (2–4) : les 8 directions dessinées servent à l'orientation
  de l'attaque, pas au déplacement.
- **Escouade de 3 héros pour 4 classes, doublons autorisés.** Le joueur ne
  peut pas prendre un exemplaire de chaque : il renonce toujours à quelque
  chose. 20 compositions possibles au lieu d'une. La Caserne de niveau 3
  rend le 4ᵉ emplacement (§ 5.4) — récompense tardive, pas état de départ.
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

- **Phase courante :** 1 — Moteur de combat. **TERMINÉE**, logique et rendu.
- **Dernière tâche terminée :** C1.22 (séquence du tour ennemi)
- **Jalon visé :** Jalon 0 et Jalon 1 en même temps, sur le téléphone

**Fait :** tout le § Phase 0 sauf F0.1, F0.9, F0.13 · **toute la Phase 1**.
P8.16 et T10.2 entamées.
**251 tests passent** sous Godot 4.6 en headless.

**Le combat se joue.** L'écran d'amorçage liste les 8 cartes de l'Acte I
(lanceur PROVISOIRE — le vrai menu est A9.1). Grammaire du § 11.2 :
tap sur un héros, tap sur une case, tap de confirmation ; glissement et
pincement pour la caméra ; Annuler toujours présent.

**Je peux voir le rendu.** xvfb est disponible dans mon conteneur, donc
Godot rend et je capture l'écran :
```bash
xvfb-run -a godot --path . --resolution 1280x720 \
  -s tools/dev/screenshot.gd -- res://scenes/ui/boot.tscn /tmp/x.png
xvfb-run -a godot --path . --resolution 1280x720 \
  -s tools/dev/combat_storyboard.gd -- /tmp/planche vallee_03
```
Trois défauts n'ont été trouvés que comme ça, dont un vrai bug de moteur.
Ce que je ne peux toujours PAS juger : le ressenti, la fluidité, la taille
réelle des cibles tactiles, et les performances.

**Toutes les valeurs de ressenti sont dans `data/combat/view.json`** —
couleurs, durées, hit stop, flottement, seuils de geste. C'est fait pour
être réglé sans toucher au code.

**Outils de vérification, à relancer après toute modification :**
```bash
godot --headless --path . -s tools/verify_assets.gd     # 535 entrées
godot --headless --path . -s tools/verify_audio.gd      # 30 entrées
godot --headless --path . -s tools/verify_font.gd       # 140 glyphes
godot --headless --path . -s tools/verify_maps.gd       # 8 cartes
godot --headless --path . -s tools/simulate_combats.gd  # équilibrage
godot --headless --path . -s tools/compare_squads.gd    # les 20 compositions
```

**Prochaine étape, côté Gaetan :** F0.1 (Godot 4.6 + SDK Android) puis
F0.9 (export APK). Les Jalons 0 et 1 arrivent ensemble.

**À regarder en jouant, et que je ne peux pas voir :**
1. Les cibles tactiles font-elles vraiment 48 dp ? Le § 11.3 vise une case
   à l'échelle 2 ; le cadrage automatique peut la rendre plus petite.
2. Les boutons du bas recouvrent le plateau. Gênant, ou acceptable ?
3. Les durées d'animation (`view.json`, section `durations`) : trop lentes,
   trop rapides ?
4. Le tour ennemi est rejoué un évènement à la fois. Comprend-on ce qui
   s'est passé, ou est-ce trop long ?
5. 60 fps sur le téléphone. Je rends en logiciel, je ne peux pas mesurer.

**Questions ouvertes, à trancher par Gaetan :**

1. **Les ennemis sont trop faibles**, et c'est maintenant chiffré autrement.
   `tools/compare_squads.gd` joue les 20 compositions sur les 8 cartes :
   **17 sur 20 gagnent à 100 %**. La règle des trois emplacements ne créera
   de vrais choix que quand les ennemis feront payer les mauvaises. Leurs
   valeurs sont de mon invention — le document ne chiffre que les héros au
   § 3.1. À régler en T10.5, et l'outil dira quand c'est réglé.
2. **Dégâts d'une poussée bloquée** (`rules.json`, `push.blocked_damage`),
   posé à 0 : le pousseur a gâché son coup.
3. **`.tres` ou `.json`** pour les données de classes (C1.23). Tout est en
   JSON aujourd'hui, plus simple à tester en headless.
4. **Les affectations de `data/audio.json`** ont été faites au nom des
   fichiers, pas à l'oreille. Rien n'est encore joué en jeu (P8.15/P8.17).

**Constat à connaître :** un combat ne dépend d'aucun tirage aléatoire —
ni les dégâts, ni le choix de cible, ni les départages de l'IA. C'est
conforme au deuxième pilier, et c'est un test explicite. Le générateur à
graine servira à la couche campagne.
