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

- **La portée se paie en dégâts** (T1.14). Un tir porte moins fort qu'un
  coup au contact ; sinon la portée est un avantage gratuit et une équipe
  à distance ne se fait jamais toucher.
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

- **Phase courante : 8 — le cycle jour / nuit.** Le pivot vers la vision
  Tiny Kingdoms a été acté le 2026-08-31.
- **Phase 1 terminée.** T1.1 à T1.14 sont faites et testées.
- **Phase 2 terminée.** T2.1 à T2.7 : le `Hero`, les niveaux,
  l'équipement, le butin, la `Company`, la sauvegarde, l'écran de
  compagnie.
- **Phase 3 terminée.** T3.1 à T3.6 : `Region`, `Expedition`, les
  évènements du § 40, le marchand, l'écran d'expédition et la carte du
  monde.
- **T1.14 :** la portée se paie. **T2.8 :** les arbres de compétences du
  § 34, qui remplacent les choix de niveau. **T6.1 :** options, pause,
  volume, tremblement d'écran.
- **Phase 5 terminée.** T5.1 (l'exploration nourrit le royaume), T5.2 (les
  invasions du § 37) et T5.3 (la bataille de défense du § 38, dont la carte
  se fabrique à partir du royaume bâti). **687 tests passent.**
- **Phase 4 terminée.** T4.1 à T4.4 : `Kingdom`, `Buildings`, l'écran du
  royaume et le branchement sur la boucle. **640 tests passent** sous
  Godot 4.6 en headless.
- **Phase 7 terminée — les dettes.** T7.1 (sauvegarde en plein combat et
  sortie à tout moment), T7.2 (`vallee_09`, le vrai mini-boss), T7.3
  (l'IA frappe ce qui barre la route), T7.4 (`reload()` → `clear_cache()`,
  472 erreurs moteur par campagne).
- **Phase 8 terminée.** T8.1 : le cycle jour / nuit du § 36, dernier item
  du périmètre annoncé de la Phase 5 qui n'avait jamais été écrit.
  **724 tests passent.**
- **La boucle du § 3 tourne en entier :** royaume → carte du monde →
  expédition → combat → butin et expérience → compagnie → royaume. Une
  sortie conclue déclenche un cycle de production ; le royaume rend des
  modificateurs aux héros et du soin à l'expédition.

**Le sens de la dépendance, à ne pas inverser :** `Hero` connaît `Unit`,
jamais l'inverse. Le combat ignore ce qu'est un niveau. Toutes les
modifications sont appliquées une seule fois, dans
`Hero.effective_stats()` ; `Unit.from_stats` reçoit un bloc déjà calculé.

**Les arbres de compétences remplacent les choix de niveau.** Un tronc,
deux branches, onze nœuds pour neuf points : on ne finit jamais un arbre.
`verify_skills` PÈSE les deux branches au barème de l'équipement et refuse
qu'une vaille plus de 25 % de plus que l'autre — sinon ce n'est pas un
choix, c'est une bonne réponse et une erreur.

**L'équilibrage d'un objet n'a pas d'instrument.** On ne simule pas mille
combats pour un anneau. La règle qui remplace la mesure : chaque rareté
vaut un budget de points, et les gains d'un objet doivent le valoir
exactement. Le barème est dans `data/items/equipment.json`, et
`verify_items` refuse tout écart. **Ne jamais ajouter un objet sans le
faire passer par là.**

**L'expédition se joue, sur PC.** Écran de titre → carte du monde →
composition de l'équipe → départ → route du § 28 (combats, évènements,
marchand, mini-boss, boss) → rentrer ou continuer.
`pointing/emulate_touch_from_mouse` est actif, donc la souris se comporte
comme un doigt. **Le banc d'essai des cartes reste sur l'écran de
titre** : ouvrir une carte précise en deux clics est la seule façon de
vérifier un combat sans traverser une sortie entière.

**Les neuf cartes sont au format 12 × 9** et se jouent en 3 à 8 rondes.
Sept en rencontre ordinaire, `vallee_09` en mini-boss, `vallee_08` en
boss ; l'ordre du § 28 suit le coût mesuré, pas l'ordre d'écriture.

**UNE EXPÉDITION EST UNE JOURNÉE (§ 36, T8.1).** On part au matin et
chaque étape avance l'heure : aller plus loin, c'est rentrer plus tard.
La route montre les heures dès le départ (jour gris-vert, crépuscule
brun, nuit bleue), donc « rentrer ou continuer » devient « rentrer avant
la nuit ou pas ». La nuit **ajoute un ennemi et paie 20 % de plus, avec
un cran de rareté**. Les deux moitiés vont ensemble — `verify_world`
refuse une heure qui coûte sans payer.

Quatre règles que la mesure a imposées contre l'intention, et qu'il ne
faut pas défaire :
- **Le renfort rejoint le CENTRE de la formation ennemie**, jamais la
  case la plus loin du joueur : sur une carte dont le placement est au
  milieu (`vallee_05`), « le plus loin » est un coin *derrière* l'équipe.
- **Pas de tirailleur dans le vivier de nuit.** Le gnoll recule quand on
  l'approche : `vallee_02` passait de 5,0 à 9,8 rondes. Un renfort ajoute
  de la pression, pas de la durée.
- **Pas de renfort sur une carte à échéance.** `vallee_04` tombait de
  100 % à 44 % de réussite. La pression est déjà dans l'horloge.
- **Le renfort tire sur un générateur DÉRIVÉ**, sinon il décale le hasard
  du combat et jour et nuit ne sont plus comparables.

**La nuit ne coûte qu'un point de PV en moyenne, et c'est écrit tel
quel** dans `data/world/day_night.json`. L'écart par carte va de −8 à
+10 : à sept bêtes l'IA répartit ses coups au lieu de les concentrer, et
des dégâts répartis ne mettent personne à terre. La récompense est
réglée sur cette mesure, pas sur l'intention. **À rejuger à l'œil.**

**LE COMBAT SE SAUVEGARDE (T7.1).** Le jeu écrit tout seul à chaque fin
d'activation, le menu de pause offre « Sauvegarder et quitter », et
l'écran de titre propose « Reprendre le combat » avant tout le reste. Ce
qui est écrit, c'est le PLATEAU, pas l'identifiant de la carte : la
bataille de défense du royaume se fabrique et ne vit dans aucun fichier.
Le télégraphe et la position de la graine sont dedans ; la pile
d'annulation, non — elle ne vaut qu'à l'intérieur d'une activation.

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
# Le JEU RÉEL, autoloads compris. À préférer, toujours.
xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png
# --press navigue : il presse des boutons par leur texte, dans l'ordre.
xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png \
  --press "Partir en expédition|Partir pour"
# Une étape « @x,y » TOUCHE UNE CASE au lieu de presser un bouton. Sans
# elle, le combat est inatteignable : « Commencer » reste désactivé tant
# que l'équipe n'est pas posée.
xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png \
  --press "Le goulet du minotaure|@0,4|@1,4|@0,3|@1,5|Commencer"
# Le banc d'essai ouvre aussi une rencontre DE NUIT : sans ce bouton il
# faudrait gagner cinq combats avant d'en voir une.
xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png \
  --press "La route basse — de nuit|@0,3|@1,3|@0,4|@1,4|Commencer"
xvfb-run -a godot --path . --resolution 1280x720 \
  -s tools/dev/combat_storyboard.gd -- /tmp/planche vallee_03
```
**Seize défauts n'ont été trouvés que comme ça**, dont quatre vrais bugs.

**Un script lancé par `-s` ne reçoit AUCUN autoload**, et l'identifiant
`GameState` est résolu à la COMPILATION : un écran qui lit la partie
sauvegardée ne compile même pas sous `tools/dev/screenshot.gd`, il reste
sur son texte de secours, et on croit l'écran cassé. Les installer à la
main ne répare rien — l'échec est antérieur. D'où l'autoload `Capture`,
inerte sans son argument, qui photographie le vrai jeu.

**Toutes les valeurs de ressenti sont dans `data/combat/view.json`.**

**Les réglages du joueur sont à part de la sauvegarde**, dans
`user://settings.json` (autoload `Settings`, défauts dans
`data/settings.json`). Une partie neuve ne doit pas remettre le volume à
zéro. `AudioManager` crée les bus `Music` et `SFX` à l'exécution ; le choix
des sons reste à faire, le câblage non.

**Deux pièges d'interface qui font TOMBER le moteur en headless.** Un
`ScrollContainer` dont la barre verticale apparaît selon la hauteur du
contenu oscille avec tout texte replié, et empile un redessin par tour :
mettre `vertical_scroll_mode = 2` (toujours visible). Et `queue_redraw()`
dans un `_process` empile une file que rien ne vide en headless : ne pas
s'animer quand `DisplayServer.get_name() == \"headless\"`. Les deux se
signalent par un signal 11 dont la trace ne désigne personne.

**Après toute modification de `data/i18n/fr.csv`, relancer `--import`.**
Le moteur lit le `.translation` compilé, pas le CSV : une clé ajoutée sans
réimport se renvoie elle-même, et un `tr("MA_CLE") % [...]` échoue alors
sur un « Method/function failed » qui ne désigne rien.

**Outils de vérification, à relancer après toute modification :**
```bash
godot --headless --path . -s tools/verify_scripts.gd    # engine, scenes, tools, tests
godot --headless --path . -s tools/verify_assets.gd     # 535 entrées
godot --headless --path . -s tools/verify_audio.gd      # 30 entrées
godot --headless --path . -s tools/verify_font.gd       # 140 glyphes
godot --headless --path . -s tools/verify_maps.gd       # 8 cartes
godot --headless --path . -s tools/verify_items.gd      # 30 objets
godot --headless --path . -s tools/verify_skills.gd     # 3 arbres, 33 nœuds
godot --headless --path . -s tools/verify_world.gd      # régions, évènements, étal
godot --headless --path . -s tools/verify_kingdom.gd    # ressources, chantiers, bâtiments
godot --headless --path . -s tools/simulate_combats.gd  # équilibrage
```

**Comment on juge l'équilibrage (acquis en T1.11) :**

Le taux de victoire ne dit rien. Une rencontre du MVP est faite pour être
gagnée ; le risque vit à l'échelle de l'**expédition** (§ 29). L'instrument
est donc la colonne **PV** des deux outils : ce qu'il reste à l'équipe à la
fin. Un combat coûte aujourd'hui **20 % en moyenne** (13 % avant T1.14). Une
chaîne complète se finit autour de 45–50 % de PV, l'étape de récompense et
le monastère compris — la courbe d'usure que le roguelite demande.

**Les statistiques sont des modificateurs, pas des multiplicateurs.** Les
dégâts du § 47 sont des chiffres finaux ; empiler une Force à 12 par-dessus
une Frappe de 20 ajoutait 60 % et vidait le combat de son enjeu. Elles
tiennent dans une fourchette de 1 à 8.

**Tranché (T1.14) : la portée se paie en dégâts.** L'Archer faisait 25 par
tir à 5 cases quand le Guerrier faisait 26 au contact — puissance ET
portée, sans contrepartie. `shot` descend à 15, l'Archer à 72 PV, et le
bestiaire reçoit deux tireurs (gnoll, chaman en zone). Le meilleur
assemblage passe de 97 % à 92 % de PV et l'écart entre compositions de 14 à
10 points. **Une rencontre coûte désormais 20 % des PV** au lieu de 13.

**Questions ouvertes, à trancher par Gaetan :**

1. **Le Mage utilise le sprite du Moine.** Décision prise par défaut pour
   ne pas bloquer ; c'est le seul choix qui ne coûte rien. À confirmer à
   l'œil quand le combat tournera.
2. ~~**La pierre n'a pas d'icône**~~ — **tranché : `decorations/rock4`.**
   Les 12 icônes d'interface du pack sont bois, or, viande, épées,
   bouclier, engrenage… : pas de pierre. Les trois autres ressources
   prennent déjà leur image dans la famille des TAS du monde
   (`wood_resource`, `gold_resource`, `meat_resource`), donc un rocher du
   monde reste dans la même langue visuelle. `Rock1` est un caillou de
   trois pixels ; `Rock4` est le plus gros, et c'est le seul qui se lise
   à la taille d'une icône. **À revoir à l'œil si le royaume paraît
   incohérent.**
3. **Ferme, scierie et mine en chantiers plutôt qu'en bâtiments** — c'est
   ce que le pack sait dessiner, mais ça change la tête du royaume.
4. **Les affectations de `data/audio.json`**, faites au nom des fichiers,
   jamais écoutées.
