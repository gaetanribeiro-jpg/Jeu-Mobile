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

- **Phase courante : 11 — la bêta.** Les chantiers sont listés avec leur
  constat vérifié dans `docs/etat-des-lieux.md` § 5. **Faits :** T11.2 le
  son, T11.3 l'écran de titre, T11.4 le déverrouillage et la fin, T11.6
  la couleur partout, T11.7 l'acte 2, T11.8 la passe de finition, T11.9 le décor et
  l'air d'un acte, T12.1 l'acte 3, T12.2 l'acte 4.
  **Restent :** T11.1 le téléphone (il te faut le SDK) et T11.5 le
  tutoriel, volontairement gardé pour après ta première partie.
  **849 tests passent, les dix vérificateurs sont verts.**
  Le pivot vers la vision Tiny Kingdoms a été acté le 2026-08-31.
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
- **Phase 9 terminée.** T9.1 (le thème sort du code), T9.2 (jauges et
  panneaux du pack), T9.3 (boutons teintés), T9.4 (les widgets que Tiny
  Swords ne dessine pas, pris chez Kenney).
- **Phase 10 terminée.** T10.1 : le soin (`KIND_HEAL` était déclaré et
  jamais écrit), les potions du § 44, le sac commun. T10.2 : le butin et
  le marchand les distribuent enfin. **774 tests passent.**
- **T9.8 :** les trois reproches de Gaetan — texte illisible, plateau
  trop petit, fond fade. **T9.9 :** la mer autour du plateau.
  **T9.10 :** l'écume du rivage et les rochers, pour qu'elle fasse
  naturel.
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

**UNE POTION EST UNE COMPÉTENCE, PLUS UN STOCK (T10.1).** Pas de second
système de résolution : une entrée d'`abilities.json` de classe
`consumable`, plus un compteur. Trois choses à ne pas défaire :
- **Le sac vit dans le MOTEUR, pas dans `Company`**, et c'est
  l'annulation qui l'impose : seul ce qui est dans l'instantané peut être
  rendu. Et on retire la potion APRÈS `use_ability`, jamais avant —
  l'instantané est l'état où l'on revient, il doit montrer le sac encore
  plein.
- **Une potion ne monte à aucune statistique.** Sa puissance vient de
  l'objet, pas de qui le tient ; sinon il faudrait la réserver au
  personnage qui la valorise le mieux et le sac commun n'aurait plus de
  sens. `verify_items` le vérifie.
- **`simulate_combats` ne boit pas.** Ses chiffres sont désormais un
  plancher plus bas encore : le pilote ignore une ressource que le joueur
  a. Lui apprendre à boire reviendrait à écrire la stratégie qu'on veut
  laisser au joueur.

**LE SAC SE RENOUVELLE, ET C'EST UN TROISIÈME FIL (T10.2).** Une potion
qu'on ne peut pas obtenir n'est pas une mécanique. Quatre choses à ne pas
défaire :
- **Le tirage des potions est SÉPARÉ de celui de l'équipement.** Mêlées,
  elles lui prendraient sa place, et l'économie de l'équipement est
  mesurée au point de rareté. Elles tombent plus souvent (une victoire
  sur deux), et **une défaite n'en rend pas** : l'équipe a déjà vidé son
  sac, lui en rendre effacerait la dépense.
- **Une potion trouvée va dans le SAC, pas dans la besace**, donc elle
  est buvable à l'étape suivante. Même raisonnement que l'or d'un
  évènement, qui va à la bourse.
- **Le coup de pouce de rareté du marchand ne s'applique PAS aux
  potions.** Il n'y en a que dans deux raretés : relever le plancher ne
  laissait qu'une fiole possible et l'étal en proposait deux identiques.
- **L'échelle de rareté se réduit à ce qu'une famille possède.** Sinon le
  plancher de profondeur passe au-dessus de la meilleure potion et le fil
  se tarit — plus on s'enfonce, moins on se ravitaille.

**Ce que `verify_world` attrape et qu'aucun test unitaire ne dirait :**
une mécanique complète dont il manque le maillon d'obtention. Chaque
moitié était juste pendant toute la Phase 10.

**L'équilibrage d'un objet n'a pas d'instrument.** On ne simule pas mille
combats pour un anneau. La règle qui remplace la mesure : chaque rareté
vaut un budget de points, et les gains d'un objet doivent le valoir
exactement. Le barème est dans `data/items/equipment.json`, et
`verify_items` refuse tout écart. **Ne jamais ajouter un objet sans le
faire passer par là.**

**L'ÉCRAN DE TITRE EST UNE CARTE, PAS UNE IMAGE (T11.3).** L'île est un
vrai `CombatBoard` bâti par `from_rows` et rendue par le MÊME
`terrain_view` que les combats : elle hérite des rives, de l'écume, des
rochers et de la mer, et ne peut pas diverger du jeu. Quatre choses à ne
pas défaire :
- **Tout le décor est dans `data/ui/title.json`** — forme de l'île, place
  du château, vitesse de chaque nuage. C'est du ressenti (règle 1).
- **Un nombre de JSON arrive en FLOTTANT.** Un `%` dessus a fait tomber le
  décor entier sans qu'aucun test le dise : l'écran s'affichait, vide.
- **Le ruban de titre garde ses marges de tranches.** Lui en donner de
  plus PETITES fait passer le texte sous ses extrémités roulées — le
  piège de T9.6 pris par l'autre bout.
- **Le banc d'essai se replie, il ne disparaît pas.** Deux clics, comme
  avant : seize défauts n'ont été trouvés que par lui.

**UN TOTAL JUSTE NE PROUVE PAS UN DÉCOUPAGE JUSTE.** Deux arbres étaient
déclarés en 6 images de 256 alors qu'ils en font 8 de 192 — et
`6 × 256 = 8 × 192 = 1536`, donc `verify_assets` était satisfait. Chaque
image portait un arbre entier PLUS une tranche de son voisin. Il vérifie
désormais que les coupes tombent dans les GOUTTIÈRES (colonnes
transparentes) et pas dans le dessin ; il a trouvé un second cas tout
seul, `goblin_hut`, que personne n'aurait cherché. **Les feuilles ne sont
pas carrées** : 192 de large pour 256 de haut, et prendre la hauteur pour
la largeur est l'erreur naturelle.

**LE JEU A UNE VOIX, ET ELLE EST DANS LES DONNÉES (T11.2).** Le code
demande un MOMENT — `play_cue(&"unit_downed")` —, jamais un fichier. Les
repères vivent dans `data/audio.json`, parce que les affectations ont été
faites au nom des fichiers et jamais écoutées : elles changeront, et sans
rouvrir un `.gd`. Trois choses à ne pas défaire :
- **Le clic de tous les boutons tient dans `UiSkin.dress_button`.** Chaque
  écran y passe déjà ; le faire écran par écran garantissait qu'un bouton
  l'oublie. Un bouton désactivé n'émet pas `pressed` — le silence du refus
  est gratuit.
- **La voix d'une attaque vient de la COMPÉTENCE, pas de l'unité.** Le
  contact, le tir, le sort : trois voix, et les distinguer permet
  d'entendre le tour ennemi sans le regarder.
- **`verify_audio` refuse un repère qui pointe sur un son inexistant.**
  Il ne ferait aucun bruit et ne se plaindrait pas — renommer une entrée
  de `sfx` suffit à le provoquer.

**LE MONDE S'OUVRE PAR LES ACTES (T11.4).** `Campaign` vit dans la
SAUVEGARDE, pas dans `regions.json` : le fichier dit ce qui est ouvert au
départ d'une partie neuve, la partie dit ce qui s'est ouvert depuis. La
région d'acte n + 1 s'ouvre quand une région d'acte n est conclue —
ajouter une région ne demande donc rien d'autre qu'un numéro d'acte. La
campagne est finie quand tout le JOUABLE est conclu, pas tout le déclaré.

**UN ACTE 2 N'EST PAS UN ACTE 1 AUX CHIFFRES GONFLÉS (T11.7).** Chaque
ennemi porte une `question`, et c'est son critère d'admission : `verify_world`
et un test refusent une bête qui n'en pose pas de neuve. Trois choses à
ne pas défaire :
- **Le bestiaire se découpe par acte et se FOND dans `Unit.enemies()`.**
  Deux actes qui déclareraient le même identifiant se marcheraient dessus
  EN SILENCE, et une carte de l'acte 1 changerait de bête. Le moteur garde
  le premier écrit ; le vérificateur refuse la situation.
- **On corrige une carte molle en CORPS, pas en statistiques.** Gonfler
  les PV rend le combat plus long, pas plus dur — leçon du renfort de
  nuit. Plafond de sept ennemis par carte : la marge que la nuit occupe.
- **Aucune mécanique n'a été inventée pour l'acte 2.** `chilled` et le feu
  au sol existaient depuis la Phase 1 ; ce qui est neuf, c'est qui les
  emploie et contre qui.

**DEUX MOITIÉS JUSTES NE FONT PAS UNE MÉCANIQUE (T11.8).**
`Expedition.depart()` demandait `Region.is_unlocked()` — le FICHIER —
quand la carte du monde demandait la `Campaign` — la PARTIE. Le joueur
qui battait le boss de l'acte 1 voyait les Dunes s'ouvrir, cliquait
« Partir », et **rien ne se passait**. Aucune erreur : chaque moitié
répondait juste à sa question. `depart()` reçoit désormais la campagne.
Quatre choses à ne pas défaire :
- **Une chaîne inter-écrans se teste EN LA PARCOURANT.**
  `test_act_transition.gd` conclut l'acte 1, relit la campagne et part
  pour l'acte 2. Aucun test unitaire ne pouvait attraper ça — c'est
  `verify_world` de la Phase 10, mais du côté des tests.
- **Les évènements se filtrent par ACTE.** `village` n'a pas de sens dans
  un désert. `verify_world` refuse un vivier sous quatre entrées : en
  dessous, une route de sept étapes se répète quoi qu'on tire.
- **Un acte tardif doit payer plus**, et c'est vérifié :
  `_reward_bonus()` MULTIPLIE l'heure par la région, donc une nuit dans
  les Dunes cumule. `verify_world` saute les régions sans carte — une
  coquille vide ne paie rien et ce n'est pas une faute.
- **Une carte molle se corrige en DISTANCE avant de se corriger en
  nombre.** `dunes_06` coûtait zéro pour cent : l'essaim courait une
  ronde entière et mourait à la seconde. Rapproché de trois cases, sans
  toucher à une seule statistique, il coûte 8 %.

**LE DESSIN N'EST PAS L'IDENTITÉ (T11.8).** Pendant tout l'acte 1, chaque
ennemi portait le nom de son sprite — `troll` dessine `troll` — et les
vues ont pris l'habitude de demander l'image à `class_id`. Ça marchait
par COÏNCIDENCE. L'acte 2 l'a rompue (`sand_serpent` se dessine avec
`snake`) et sept bêtes se sont affichées en OMBRE NUE, sans une seule
erreur : `has_enemy_animation` répond « non » poliment et la vue retombe
sur rien. `Unit.sprite_id` porte la déclaration des données, et c'est lui
qu'on demande. Trois choses à ne pas défaire :
- **Le pack a VINGT ET UN visages d'ennemis** — l'inventaire le disait
  depuis toujours et un commentaire du HUD affirmait le contraire. La
  timeline les montre ; `verify_world` exige un avatar par bête.
- **Une région déclare son `ground` À PART de son `accent`.** Le sol
  occupe l'écran pendant huit rondes et demande de la justesse ; l'accent
  teinte un liseré de 48 px et demande du contraste. Vide = le tileset du
  pack, et c'est la bonne réponse pour les Terres Vertes.
- **Le tileset se désature puis se reteinte.** Les cinq nuances du pack
  sont toutes VERTES : aucune ne fait du sable. Cinquième emploi de « une
  source ne se teinte que si elle est claire ».

**UNE RENCONTRE ANNONCE CE QU'ELLE CONTIENT (T11.8).** L'étape de combat
ne disait qu'un nom de carte, donc « rentrer ou continuer » (§ 29) se
posait à l'aveugle — l'inverse de ce que le jeu promet partout ailleurs.
Elle montre désormais le bestiaire, visage par visage. **La nuit est dite
À PART** : le renfort est ajouté au moment du combat, il n'est pas dans
la carte, et l'annoncer dans la liste ferait mentir la liste.

**TROIS DÉFAUTS QUE SEULE LA CAPTURE A VUS, ENCORE (T12.1).**
- **Une image FIXE n'est pas une bande, et `SpriteFrameFactory` la
  REFUSAIT** en poussant une erreur. Le poisson-bombe est le premier
  ennemi du pack dont l'attente soit une image fixe : il s'affichait en
  ombre nue avec sa barre de vie. Une image fixe est une animation d'UNE
  image ; refuser n'a jamais protégé de rien. Le test de T11.8 ne
  demandait que la DÉCLARATION — il va jusqu'à la fabrique maintenant.
- **La teinte d'un terrain suit le BIOME, comme son dessin.** Le brun du
  sable mouvant posé sur de la glace donnait une bande de BOUE au milieu
  d'un col enneigé. `terrain_tints_by_ground`, même mécanisme que les
  décors.
- **De la terre INJOIGNABLE au quart de l'écran.** Le premier trône du
  Jarl avait un bloc coupé du reste par l'eau : rien ne pouvait y aller,
  rien ne s'en plaignait, et ça se voyait d'un coup d'œil.

**UN TERRAIN QUI RALENTIT L'ENNEMI NE COÛTE RIEN AU JOUEUR (T12.1).**
Avec un objectif « éliminer » et une IA qui vient au contact, l'équipe a
toujours intérêt à ne pas bouger : ce qui arrive lentement arrive un par
un. `gel_05` l'a prouvé trois fois — congère au milieu 94 % de PV, en
bordure de placement 100 %, côté archers 100 %. Trois choses à ne pas
défaire :
- **CE QUI RÈGLE LE PROBLÈME EST LA PORTÉE, PAS LE NOMBRE DE TIREURS.**
  Les vingt-sept cartes en ont déjà toutes au moins un. Mais l'acte 1 a le
  chaman à SIX cases et l'acte 2 le feu follet à six, quand l'acte 3
  n'avait que des tireurs à cinq — la portée de l'Archer. Un échange
  équitable se gagne à quatre contre un sans avancer. `verify_world` exige
  désormais par acte quelqu'un qui porte au moins aussi loin que le
  joueur, les deux portées lues dans les données.
- **DONNER DES PM AUX BÊTES DE MÊLÉE SE RETOURNE.** Mesuré : +1 PM sur
  seize bêtes donne acte 1 → 77 %, acte 3 → 68 %, mais acte 2 → 80 %, soit
  PLUS FACILE. Les cartes de l'acte 2 ont été réglées à la DISTANCE, et la
  vitesse est l'autre moitié de la même quantité. Écarté.
- **UN ENNEMI DE CONTACT A UNE ZONE MORTE.** Posé à plus de sa portée et à
  moins de celle de l'Archer, il traverse sous le feu et meurt sans avoir
  frappé. L'en sortir — le rapprocher ou l'éloigner — vaut mieux que lui
  donner des PM.

**LE COUP D'ÉPAULE EST UNE ATTAQUE, PAS UN `KIND_PUSH` (T12.1).**
`push_away_from`, la noyade et leur prévisualisation étaient écrits depuis
la Phase 1 avec leurs tests, et aucune donnée ne les employait —
troisième mécanique morte après `KIND_HEAL` et les 70 entrées `ui`. Trois
choses à ne pas défaire :
- **UNE POUSSÉE PURE NE S'ANNONCE PAS.** `CombatIntent` ne connaît que
  `Kind.ATTACK` : un ennemi qui projetterait dans un lac sans prévenir
  violerait le § 39. Un coup qui BLESSE et repousse est une attaque
  ordinaire pour tout le reste du moteur.
- **`telegraph()` REND LA CASE D'ARRIVÉE** (`shoves`), en bleu-blanc et
  SANS chiffre. « Tu prendras 14 » et « tu finiras là » sont deux
  informations ; les peindre pareil ferait lire un total de dégâts sur une
  case qui n'en porte aucun.
- **Les dégâts d'abord, la poussée ensuite, et seulement sur qui tient
  debout.** Pousser un mort dans l'eau le noierait deux fois.

**LES ENNEMIS HUMAINS OUVRENT VINGT ET UN SPRITES (T12.1).** Le pack
dessine cinq classes en cinq couleurs et le jeu n'employait que le Bleu
des héros. `sprite_color` dit dans quelle table chercher — unités ou
bêtes — et `verify_world` refuse un ennemi qui porterait le bleu. Deviner
d'après le nom marcherait jusqu'au jour où une bête s'appellerait comme
une classe.

**UN TIRAILLEUR À PORTÉE UN NE FRAPPE JAMAIS (T12.1).** `_score_cell`
retranche cinquante points par héros à moins d'une case : avec une
compétence qui porte à UNE case, ce malus interdit exactement les cases
depuis lesquelles il pourrait attaquer. Trois guêpes ont fui pendant une
mesure entière, la carte rendait 100 % des PV et aucun outil ne s'en
plaignait. `verify_world` le refuse.

**UN ENNEMI AQUATIQUE INJOIGNABLE REND LA CARTE INGAGNABLE (T12.1).** Un
harponneur au milieu d'un lac ne peut être abattu que par un tireur, et le
§ 23 laisse la composition au joueur : `verify_maps` exige qu'une case de
TERRE touche chaque ennemi aquatique ou volant. Il a attrapé un
poisson-bombe au centre du lac. Le même outil demande maintenant à
`can_stand_on` et plus à `is_walkable` — un requin nage.

**UN ACTE QUI N'A QU'UN MOT SE JOUE NEUF FOIS PAREIL (T11.9).** Sept
cartes des Dunes sur neuf n'employaient QUE du rocher, et les neuf
partageaient la même zone de placement : la couleur du sol les
distinguait des Terres Vertes, leur forme non. `verify_maps` compte
désormais le vocabulaire d'un ACTE et refuse en dessous de trois
terrains — ça ne se voit sur aucune carte prise seule. Quatre choses à ne
pas défaire :
- **Le même terrain, un autre DESSIN.** Un bosquet des Terres Vertes est
  un arbre vert ; celui des Dunes est un arbre MORT. Mêmes règles, autre
  image : `terrain_decorations_by_ground`, indexé par la couleur de SOL et
  pas par la région, donc deux régions de sable partagent leur décor.
- **Le rocher et la colline ne sont PAS déclinés, exprès.** Le rocher
  marque l'infranchissable : le fondre dans la couleur du sol le rendrait
  illisible, et un rocher gris est juste dans un désert. La colline est
  dessinée par le tileset, donc déjà teintée — une dune de sable sort
  gratuitement d'un plateau d'herbe.
- **Un terrain qui coûte plus d'un PM doit se VOIR.** La boue n'a aucun
  sprite dans le pack, et la note de `view.json` réclamait une teinte
  depuis dix phases avant qu'une carte l'emploie. `terrain_tints` la
  donne, et un test refuse tout terrain coûteux ni dessiné ni teinté.
- **Une carte molle se corrige en DISTANCE, encore.** `dunes_03` : bande
  de sable sur toute la hauteur = 52 % de PV (plus cher que le boss) ;
  tortues posées SUR le gué = 34 % ; tortues reculées d'une colonne =
  63 %. Troisième fois de l'acte.

**L'AIR D'UN ACTE PASSE PAR LE TRAIT DOUX, PAS PAR LE FOND (T11.9).**
Deux mesures ont fermé les autres portes. **Le fond** : à la luminance
d'un presque-noir, deux teintes opposées ne se séparent que de DEUX
niveaux sur 255, et l'éclaircir ferait passer la crête du motif devant le
panneau le plus sombre (T9.8). **L'or vif** : il dit « c'est à lui »
(T9.7), et pour les Dunes c'est pire qu'une règle — `sand` EST l'or de
l'interface, l'écart tombe à 0,038. Trois choses à ne pas défaire :
- **Le trait doux ne portait aucune information, et c'est ce qui permet
  de lui en donner une.** Le vif dit le tour, le doux dit « ceci est un
  panneau ». Une couleur libre est celle qu'on peut donner.
- **La chrome du combat est passée du vif au doux, et c'est une
  CORRECTION.** Ni l'objectif, ni la fiche, ni la plaque d'action ne
  veulent dire « c'est à lui » : ils portaient l'or vif par habitude.
- **`verify_ui` mesure les six airs contre l'or vif ET contre le
  neutre.** Il a attrapé `ash` du premier coup, à 0,035 du neutre :
  l'Empire Noir n'aurait pas eu d'air. Un air qui ne bouge pas est une
  mécanique qui ne fait rien.

**DEUX DÉFAUTS SILENCIEUX QUE SEULE LA CAPTURE A VUS (T11.9).** Une
fonction insérée AU MILIEU d'une autre (`_air()` dans `_build_from_map`)
rend tout ce qui suit mort après un `return` — `verify_scripts` compile
ça sans broncher. Et un cadre habillé dans `_ready`, avant que
`lay_backdrop` ne pose l'air, garde le neutre pour toujours : la
mécanique est branchée et ne se voit pas. **Le second ne s'est vu qu'en
MESURANT le pixel du liseré, pas en le regardant.**

**L'ARBRE SE LIT EN DEUX NIVEAUX, PAS EN SEPT (T11.8).** Chaque rangée
était décalée de sa profondeur ; onze nœuds donnaient un escalier qui
filait vers la droite. Un arbre à deux branches a le tronc, puis le
choix — la profondeur est déjà écrite dans « il faut d'abord Poigne ».
Les six voies portent leur nom en données (`branch_name_key`), et
`verify_skills` refuse une branche anonyme : les deux l'avaient déjà,
enfoui dans la prose d'un nœud, et sous un AUTRE mot que celui du titre.

**LA COULEUR PORTE UNE INFORMATION, JAMAIS UNE DÉCORATION (T11.6).**
Six régions dans six boîtes identiques obligent à LIRE. Trois choses à ne
pas défaire :
- **Chaque classe et chaque région déclare sa couleur dans SES données**
  (`hero_classes.json`, `regions.json`), par le NOM d'une couleur de la
  palette et jamais par un code. `verify_ui` refuse une couleur inconnue,
  et deux régions de la même teinte.
- **La teinte va dans le LISERÉ, jamais dans le fond** — règle de T9.7. Le
  héros qui joue garde l'or : « c'est à lui » prime sur « c'est un archer ».
- **Le carré de terre d'une région est DÉSATURÉ puis reteinté.** Le pack
  ne livre que cinq nuances de vert ; c'est ce qui donne du sable, du gel
  et de la cendre sans redessiner un pixel. Quatrième fois que la règle
  « une source ne se teinte que si elle est claire » sert.

**LES CRÉDITS SONT UNE OBLIGATION, PAS UNE POLITESSE (T11.3).** CC BY 3.0
exige l'attribution des dix-huit icônes de game-icons.net. `verify_ui` et
un test refusent que l'entrée disparaisse ou qu'un des trois auteurs
cesse d'être nommé. Le liseré porte le RÉGIME de licence, comme un bouton
porte son rôle.

**L'INSTRUMENT D'ÉQUILIBRAGE MESURAIT LA MAUVAISE ÉQUIPE, PENDANT QUATRE
ACTES.** `simulate_combats` jouait avec `Unit.from_hero_class` : des héros
de **niveau 1, sans équipement, sans arbre de compétences, sans les bonus
du royaume**. Mesuré : un Guerrier au niveau maximum a **1,60 × ses points
de vie et 1,83 × sa force**, avant même le premier objet.

**LA COURBE DE DIFFICULTÉ ÉTAIT DONC INVERSÉE**, et c'est le chiffre qui
compte :

| acte | contre des héros nus | contre l'équipe réelle |
|---|---|---|
| 1 | 19 % | 15 % |
| 2 | 27 % | 15 % |
| 3 | 30 % | **12 %** |
| 4 | 33 % | **11 %** |

Plus le joueur avance, plus c'est FACILE — parce que chaque acte a été
réglé contre une équipe figée au niveau 1 pendant que la sienne triplait.
Le jeu entier coûte **13 % des PV** et fait tomber **0,03 personnage par
combat**, c'est-à-dire personne. La difficulté n'est pas trop basse par
accident : elle est ANTI-réglée.

`expected_hero_level` et `expected_rarity` vivent dans `regions.json`,
comme tout réglage. **Ce qui reste non modélisé :** les neuf points
d'arbre de compétences et les `grants` du royaume — les chiffres restent
un plancher, mais un plancher plausible au lieu d'un plancher absurde.
Même famille de réserve que « le pilote ne boit pas ».

**L'ACTE 4 OBLIGE LE JOUEUR À BOUGER, et c'est Gaetan qui a vu le défaut.**
« Pourquoi c'est toujours l'ennemi qui traverse ? À quoi servent les PM du
joueur ? » — **30 cartes sur 36 avaient « éliminer » pour seul objectif**,
et les actes 3 et 4 ne connaissaient QUE celui-là quand l'acte 1 employait
les six. Le jeu s'était RÉTRÉCI en avançant. Avec « éliminer » et une IA
qui vient au contact, attendre est toujours juste : les PM ne servent qu'à
se replacer de deux cases et tout terrain est gratuit pour le joueur.
Déplacer les obstacles de son côté ne soigne que le symptôme.

**UN EMPLACEMENT HORS DE PORTÉE N'EST PAS UN ENNEMI, C'EST DU DÉCOR.**
Treize sur dix-huit avaient été posés au bord du plateau, par le réflexe
qui met un ennemi « au fond ». **C'est l'inverse exact de la leçon sur les
obstacles :** pour une bête MOBILE la distance n'est qu'un délai — elle
finit par arriver, et c'est pour ça qu'une carte molle se corrige en la
rapprochant. Pour un emplacement, la distance est une ANNULATION, et
`fer_04` rendait 100 % des PV pour cette seule raison. `verify_maps` le
refuse, en exemptant les unités SANS attaque : un soutien n'a pas à tirer.

**MON INVENTAIRE DU PACK ÉTAIT FAUX, et c'est Gaetan qui a douté.** Je ne
comptais que la catégorie `enemies` : les « vingt et un visages ». La
catégorie `extra` dormait avec un **gobelin lancier MONTÉ SUR UN
SANGLIER** (attente, course ET attaque), un sanglier seul, un canon en
cinq directions, une tour au sol et sur l'eau, une hutte animée sur seize
images, une caverne, des barques. Le carnet déclarait « pas de cavalerie »
depuis le premier jour. **Compter une catégorie n'est pas compter le
pack.**

**LES CINQ COULEURS SONT UN BUDGET, et une couleur ne peut pas être à la
fois un rang et une faction.** Décision de Gaetan : trois vont aux héros
(**Bleu → Violet → Or**, l'ascension) et deux aux factions (**Rouge** des
Rougefer à l'acte 3, **Noir** de l'Empire à l'acte 6). Les actes 4 et 5
n'ont donc PAS d'humains. `Hero.color` existe déjà, avec sa valeur par
défaut `"Blue"` — sixième mécanique déclarée et jamais branchée ; seules
les vues figent le bleu en constante.

**UN AVATAR PEUT ÊTRE UNE BANDE.** Les bêtes d'`extra` n'ont pas de
portrait dessiné, donc leur avatar pointe sur leur propre attente — et le
badge affichait la BANDE ENTIÈRE, un ruban de 3072 × 256 écrasé dans
50 px, c'est-à-dire une ligne pointillée d'un pixel de haut. Deux badges
VIDES, sans une seule erreur. `enemy_portrait` prend la première image
puis RECADRE sur les pixels opaques : une attente n'est pas un buste, un
cavalier occupait le tiers de son cadre. Règle uniforme et sans seuil —
les vingt et un portraits serrés du pack ne bougent pas.

**L'ACTE 4 EST CELUI OÙ LES DÉGÂTS NE RESTENT PAS.** Vingt-huit bêtes en
trois actes et pas une ne récupérait un point de vie : entamer quelqu'un
était toujours un acquis. L'atelier qui répare les emplacements le reprend, et la bonne réponse
devient « aller le chercher AU FOND de la ligne plutôt que mordre le
premier canon venu ». **La mécanique a survécu au changement de faction —
écrite pour un aumônier humain, elle est passée à une hutte** : c'est ce
qui prouve qu'elle valait la peine, une mécanique qui ne survit pas au
déménagement de son porteur était une statistique déguisée. Quatre choses à ne
pas défaire :
- **`Kind.SUPPORT` est une TROISIÈME information, pas une attaque
  négative.** Le § 39 veut que le joueur voie le soin AVANT de choisir sa
  cible, sans quoi « qui tuer d'abord » se pose à l'aveugle. Peint en
  violet à 285° : la seule teinte libre de la couche, à 75° de la plus
  proche couleur saturée. Le vert aurait été le réflexe — c'est celui de
  l'objectif.
- **Le chiffre annoncé est PLAFONNÉ par ce qui manque.** Annoncer la
  valeur brute mentirait dans le seul cas qui compte : un ennemi presque
  intact afficherait « +29 » et n'en reprendrait que trois.
- **`damage` et `mends` font TOUJOURS la longueur de `cells`.** Laisser
  l'un vide était un piège : deux appelants avaient été protégés à la
  main, le troisième — un test d'intégration de la Phase 1 — est tombé. On
  retire le piège, on ne protège pas les appelants.
- **Un soigneur a son PROPRE barème de placement.** Un bonus ajouté ne
  suffit pas : sans attaque, `_useful_range` vaut 1 et la retombée « se
  rapprocher de la portée utile » le tire au CONTACT à dix points par
  case. Il partait droit sur le Guerrier.

**UN OBSTACLE ENTRE LES DEUX CAMPS EST GRATUIT POUR LE JOUEUR.**
Généralisation de la leçon de T12.1, et elle vaut pour TOUT relief, pas
seulement pour ce qui ralentit. Les trois cartes molles de l'acte 4 —
93 %, 90 %, 95 % de PV — avaient toutes leur relief au MILIEU : l'équipe
tirait pendant que la Compagnie traversait. Les ruines et la boue sont
passées du côté du joueur, une palissade sur deux derrière les
mercenaires. **Corollaire mesuré : la boue ne coûte RIEN à un joueur qui
n'a pas de raison d'avancer.** Ce qui coûte à un joueur immobile est la
PORTÉE, et elle seule — `fer_04` n'est devenu cher qu'en gagnant un
second tireur.

**DEUX MERCENAIRES SUR SIX NE FRAPPAIENT JAMAIS.** Trois causes, toutes
invisibles sans la mesure : un `blocker` ne bouge JAMAIS, donc sur une
carte ouverte il attend qu'on vienne à lui et meurt sans un coup (le rôle
n'a de sens que sur un goulet) ; un soigneur sans arme est un corps
gratuit tant qu'il ne soigne pas ; et une recharge sur la SEULE compétence
d'une bête la fait chômer une ronde sur deux. L'acte est passé de 25 % à
32 % du coût en PV, contre 30 % à l'acte 3.

**`requires_not_moved` ÉTAIT IGNORÉ PAR L'IA.** Elle choisissait sa
compétence sans jamais le lire : un ennemi se serait déplacé PUIS aurait
porté un coup réservé à qui reste planté. Personne ne l'avait vu parce
qu'aucune bête ne portait le champ — quatrième mécanique déclarée et
jamais branchée, après `KIND_HEAL`, `KIND_PUSH` et les 70 entrées `ui`.

**LE PAWN EST LE SEUL SPRITE DONT LA COULEUR NE SE VOIT PAS.** Mesuré sur
les images d'attente, passer du Bleu à une autre couleur change **51 %**
des pixels d'un Lancier, **49 %** d'un Archer, **38 %** d'un Guerrier,
**25 %** d'un Moine — et **7,9 %** d'un Pawn. Trois actes de factions
humaines auraient eu le même sapeur. `sprite_variant` est un SUFFIXE
(`idle_pickaxe`), jamais une table, et il RETOMBE sur l'animation nue :
ne rien dessiner est ce qui a donné sept ombres nues en T11.8.

**LE PACK EST À SEC, ET VOICI LE COMPTE.** C'est le constat que l'acte 4
avait pour but d'établir :
- **Les 21 visages de bêtes sont ENTIÈREMENT consommés** par les actes 1 à
  3. Il n'en reste zéro.
- Restent **5 classes humaines × 4 couleurs** (Rouge partiellement pris),
  soit trois factions pour les actes 4, 5 et 6 — et pas une de plus.
- **La famille des ossements compte CINQ images** et les actes en ont pris
  quatre. Il en reste UNE pour deux actes.
- Le vampire est la première réponse à ça : dessiné, versionné, et il
  n'entre encore dans aucun bestiaire.

**LA BOUE NE SE VOYAIT PAS, ET SEULE LA MESURE LE DISAIT.** `quicksand`
est un brun, le sol de l'acte 4 est un brun-rouge : **11 points de
luminance sur 255**, pour un terrain qui coûte deux PM. Sixième variante
de « une source ne se teinte que si elle est claire ». `churned_mud` est
calé sur ce qui marche déjà — la congère du Gel se sépare de 24,4 points,
celle-ci de 24,0. **Réglée à l'œil elle serait restée à 7.**

**LE BOSS DE L'ACTE 4 MESURE MOINS CHER QUE SON MINI-BOSS, ET LA MESURE
MENT ICI** — troisième fois du projet, après le Jarl et « le pilote ne boit
pas ». Sept corps donnent 9 rondes / 57 % de PV, six donnent 7 rondes /
62 %, et le Capitaine à 215 comme à 250 rend EXACTEMENT le même chiffre :
ce n'est pas sa barre de vie qui borne le combat, c'est le nombre de corps
qui frappent. On garde six, parce que le plafond de huit rondes est une
cible ÉCRITE quand le classement des coûts n'en est pas une — et parce que
`simulate_combats` ne concentre JAMAIS ses coups sur l'aumônier, donc il
subit le Ralliement sans jamais l'empêcher. Il joue le contraire de ce que
la carte demande. **À rejuger à l'œil.**

**LE PACK NE PARTAGE QU'UNE COULEUR (le vampire).** Les vingt et une
bêtes n'ont en commun que `#161c2e` — le contour à alpha 255, l'ombre au
sol à 69. Rien d'autre : chacune a ses 10 à 18 teintes propres. Un troll
vert, un crâne beige et un minotaure gris font une famille par le TRAIT,
pas par la palette, et c'est ce qui autorise une bête neuve. Cinq choses à
ne pas défaire :
- **Une entrée d'ennemi peut déclarer son `root`.** Tiny Swords vit dans
  le `.gitignore` parce que sa licence l'exige ; `assets/pixellab/` EST
  dans le dépôt, comme Kenney et game-icons. Sans ce champ, la seule façon
  d'ajouter une bête était de la poser dans un dossier ignoré — donc de la
  perdre au prochain clone. Quatrième régime d'assets.
- **Le registre du pack se mesure : saturation médiane 0,34**, jamais plus
  de 0,62, et 1,9 % seulement des couleurs au-dessus de 0,75. Les deux
  tentatives refusées étaient à 0,83 et 0,92 — c'est ça, en chiffres,
  « ça ne ressemble pas à Tiny Swords ».
- **Les proportions sont CHIBI**, tête énorme sur corps court. Un premier
  jet en proportions héroïques ne tient pas une seconde à côté du gnoll.
- **Un idle du pack déplace 54 à 71 % de ses pixels.** Des poses de deux
  pixels se font lisser jusqu'à 1 %, c'est-à-dire jusqu'à l'immobilité —
  le défaut exact qu'on reprochait aux tentatives extérieures. Il faut des
  poses franches.
- **PAS D'OMBRE CUITE DANS UNE FEUILLE.** `unit_view` en dessine déjà une
  sous chaque unité. Le pack cuit la sienne parce qu'il ne connaît pas
  notre vue ; nous, non.

**LE DESSIN N'EST PAS LA MÉCANIQUE.** Le vampire est commité, vérifié,
testé jusqu'à la fabrique — et il n'entre dans aucun bestiaire. La
question qu'il pose reste à écrire : sur vingt-huit bêtes, aucune ne
remonte jamais. La tortue enseigne « il vaut mieux l'ignorer » ; un
vampire qui se soigne de ce qu'il mord en est l'exact inverse, la seule
qu'on ne peut pas garder pour la fin. Ça se branche sur un champ `drain`
d'une attaque, comme `push` en T12.1 — et le piège est connu d'avance :
soigner un ennemi rend le combat plus LONG, pas plus dur (T11.7), donc le
gain doit être plafonné par ses PV maximum.

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

**Toutes les valeurs de ressenti sont dans `data/combat/view.json`** pour
le combat, et dans **`data/ui/theme.json`** pour l'interface. Deux
fichiers parce que ce sont deux métiers : le ressenti d'un coup n'est pas
la lisibilité d'un menu. **Il ne reste zéro `Color(...)` en dur dans
`scenes/`** — la règle 1 y était violée dans sept fichiers.

**L'INTERFACE PORTE LA PEAU DU PACK (T9.1–T9.3).** 70 entrées `ui` étaient
cataloguées et vérifiées depuis toujours, et pas un écran ne les
dessinait. Trois choses à savoir avant d'y toucher :
- **Le pack ne livre pas des images étirables.** Un bouton est une grille
  3×3 de morceaux séparés par 64 px de VIDE ; `UiSkin` les recompose en
  mémoire au démarrage. La géométrie est déclarée dans `assets.json`
  (`slice`, `groove`), jamais déduite dans le code. Rien n'est écrit sur
  le disque : le pack n'est pas versionné, un dérivé ne le serait pas non
  plus.
- **Six couleurs de bouton sortent de deux images**, en passant la source
  en niveaux de gris avant de la teinter. Un écran demande un RÔLE
  (`primary`, `danger`, `muted`…), jamais une couleur. `verify_ui` refuse
  deux rôles de même teinte.
- **L'échelle de réduction est un diviseur ENTIER.** Le pack est du pixel
  art sur grille de 64 en filtrage Nearest ; une division fractionnaire
  fait baver la bordure.

**DEUX ORIGINES D'ASSETS, ET ELLES NE SE VERSIONNENT PAS PAREIL (T9.4).**
Tiny Swords interdit la redistribution : ses dossiers sont dans le
`.gitignore`. **Kenney est en CC0, donc `assets/kenney/` EST dans le
dépôt** — un clone neuf en dessine déjà quelque chose, et un fichier
manquant y est un vrai défaut. On n'y met QUE ce que Tiny Swords ne
dessine pas : barre de défilement, case à cocher, poignée de curseur.
**La règle qui borne le mélange : on ne mélange que là où le premier pack
ne dessine rien.** Un bouton Kenney à côté d'un bouton Tiny Swords se
verrait ; une barre de défilement que Tiny Swords n'a jamais dessinée ne
trahit rien.

**LES GLYPHES DE COMPÉTENCES VIENNENT DE game-icons.net (T9.5).** Ni Tiny
Swords ni les packs Kenney n'en avaient : le premier a 12 icônes de
ressources et de chrome, le second est thématique jeu de plateau. Trois
choses à savoir :
- **`assets/gameicons/` est en CC BY 3.0 : l'attribution est OBLIGATOIRE**,
  pas une politesse comme pour le CC0. Lorc, Delapouite et Caro Asercion
  sont nommés dans `CREDITS.md`. Trois régimes coexistent désormais —
  Tiny Swords (interdit de redistribuer → `.gitignore`), Kenney (CC0),
  game-icons (CC BY).
- **Le seul mélange vectoriel / pixel du jeu, et il ne tient qu'au SEUIL
  D'ALPHA.** Une silhouette lisse à côté d'un sprite Nearest se voit ;
  seuillée, elle redevient un masque franc. On réduit en Lanczos PUIS on
  seuille — l'inverse hacherait le trait.
- **Le fond noir de chaque SVG a été retiré à l'import.** Chaque icône est
  un carré noir plein suivi du tracé blanc.

`AssetTable.has()` répond sans pousser d'erreur, contrairement à
`sprite()` : une compétence sans glyphe reste en texte, ce qui est une
réponse valable. Mais `verify_ui` exige un glyphe pour **chaque
compétence de héros et chaque potion**.

**L'INTERFACE EST SOMBRE À LISERÉ DORÉ (T9.7), sur TOUS les écrans.** Le
parchemin clair de T9.1–T9.6 n'était pas le bon matériau : la maquette de
Gaetan demande des panneaux presque noirs à trait d'or ouvragé. Quatre
choses à ne pas défaire :
- **Les cadres viennent de `kenney_fantasyuiborders`** (CC0), un pack
  arrivé avec les autres et jamais ouvert. `UiSkin.framed_style()`
  COMPOSE le cadre et le fond en une seule image, parce qu'un `StyleBox`
  ne s'empile pas : on ne garde du cadre que les pixels d'alpha > 0,9 —
  le tracé — et on les repeint sur un aplat sombre. Le seuil haut est
  volontaire ; le centre de ces cadres est du blanc à demi transparent,
  pas du vide.
- **Le rôle est passé du FOND au TRAIT.** Un bouton en acier plein sur un
  panneau sombre faisait deux matières pour une interface.
  `framed_style` accepte une couleur de palette OU un rôle de bouton.
- **`UiSkin.hero_card()` est partagée par trois écrans** — combat,
  expédition, compagnie. Trois dessins pour une même information est ce
  qui donnait à l'ensemble son air de brouillon.
- **Un test ne doit pas fixer la profondeur d'un nœud d'habillage.** Deux
  tests d'expédition lisaient `get_child(0)` et une chaîne « 7 / 72 » ;
  ils cherchent maintenant le texte dans l'arbre.

**L'ÉCRAN DE COMBAT EST HABILLÉ, PAS SEULEMENT SES BOUTONS (T9.6).**
Cartes de héros à portrait sur papier, timeline à visages, barre d'action
sur la table de bois, objectif sur parchemin. Deux pièges à retenir, tous
deux SILENCIEUX :
- **Un `StyleBoxTexture` écarte son contenu de ses marges de tranches**
  (32 px à l'échelle 2). Quatre cartes gonflées de 64 px chassaient la
  barre d'action hors de l'écran, et Godot rogne sans rien dire. D'où
  `UiSkin.panel_style(role, pad)`. Ne jamais ajouter un `MarginContainer`
  par-dessus un style qui écarte déjà.
- **Un `HBoxContainer` trop étroit rabote ses DERNIERS enfants**, sans
  erreur : la ronde et le bouton de pause avaient disparu. La timeline et
  le coin sont donc ANCRÉS sur le `CanvasLayer` — pas dans un
  `Container`, qui écrase les ancrages de ses enfants.

**LE PLATEAU EST UNE ÎLE DANS UNE MER DE DÉCOR (T9.9).** L'eau déborde
de 16 cases sur les quatre côtés pour remplir l'écran. Trois choses à ne
pas défaire :
- **La caméra cadre la GRILLE, jamais la mer.** Élargir la zone cadrée
  coûterait 17 % de la taille des cases : c'est la HAUTEUR qui contraint
  le cadrage (0,85 contre 0,94), donc ajouter des colonnes fait passer la
  contrainte en largeur et tout rétrécit d'un coup. Le décor vit en
  dehors du cadrage, et le clamp de déplacement ne bouge pas.
- **Elle ne déborde QU'À L'HORIZONTALE**, et sa hauteur est celle de la
  grille. Un premier essai débordait des quatre côtés : le fond sombre
  disparaissait et la mer devenait le fond. Ce qu'on veut voir, ce sont
  les deux bandes entre les panneaux et l'île.
- **Ses bords extérieurs se fondent vers `backdrop`**, lu dans `UiTheme`
  et jamais recopié dans `view.json`. Elle ne peut pas simplement
  s'arrêter sous les panneaux : ils ne descendent pas jusqu'en bas, et
  sous eux le turquoise repartait jusqu'au bord de la fenêtre.
- **L'écart entre un panneau et le plateau vaut `295,5 − largeur`**,
  quelle que soit cette largeur : le plateau est centré dans la zone sûre
  et ne bouge donc JAMAIS quand on rétrécit un panneau. C'est pour ça que
  `card_width` et `detail_width` sont passés de 250 à 200 — 45 px d'eau
  contre 95.

**LA MER EST VIVANTE, AVEC CE QUE LE PACK DESSINAIT DÉJÀ (T9.10).**
Un aplat turquoise n'est pas naturel. Trois choses à ne pas défaire :
- **`Water Foam` se pose SOUS une case de TERRE**, jamais sur l'eau. La
  plaque fait 192 px pour une case de 64 : la terre par-dessus n'en
  laisse voir que le débord, et les plaques voisines se recouvrent. C'est
  ce qui donne un rivage continu sans morceau par orientation — que le
  pack ne fournit pas. La note qui la disait inutilisable avait raison
  sur un point seulement : ce n'est pas une tuile d'eau.
- **La position des rochers est une FONCTION, pas un tirage.** Le décor
  n'a pas à consommer une graine, et surtout pas celle du combat qu'il
  décalerait — même leçon que le renfort de nuit. Ils sont décalés dans
  leur case (sinon la bande trahit la grille) et dessinés AVANT le fondu
  (sinon ils flottent, nets, sur du noir).
- **Trois quarts de case d'eau en haut et en bas : c'est l'ÉPAISSEUR DU
  RIVAGE, pas une bande.** Sans elle l'écume se pose à même le fond et
  l'île a un contour blanc. Le fondu porte sur les quatre côtés, sinon
  cette épaisseur fait une barre turquoise au-dessus de l'île.

**LE FOND A DE LA MATIÈRE, ET ELLE SE RÈGLE À LA MESURE (T9.8).** Un
motif de diagonales se carrelle derrière tous les écrans. Quatre choses à
ne pas défaire :
- **Une source ne se teinte que si elle est CLAIRE.** Le motif de Kenney
  est noir — il est fait pour ombrer du clair — donc le teinter d'or ne
  faisait rien : le fond s'ASSOMBRISSAIT de deux niveaux. `UiSkin` le
  repeint en blanc en gardant son alpha, comme le remplissage d'une jauge
  et comme un glyphe. Troisième fois que le projet se cogne à cette règle.
- **Deux alphas se multiplient** : celui du fichier (51/255) et celui du
  thème.
- **La crête du fond reste SOUS le panneau le plus sombre.** Sinon le
  fond passe devant ce qu'on pose dessus, et un nœud désactivé s'y noie.
  `verify_ui` et un test le refusent dans les deux sens — invisible ET
  trop marqué.
- **Passer par `UiSkin.lay_backdrop()`, jamais par `add_child`.** Six
  écrans portent déjà un `Background` dans leur `.tscn`, qui recouvrait
  le motif inséré derrière lui. Un nœud qui en cache un autre ne se
  plaint pas.

**AUCUN CONTOUR DE TEXTE DANS L'INTERFACE (T9.8).** Le contour de 6 px
datait du parchemin clair ; `ink` étant passé au crème, il était devenu
clair sur clair et les glyphes de la police pixel se rejoignaient. Il ne
reste que sur le texte posé SUR LE PLATEAU (`_outlined()`), où le fond
n'est pas maîtrisé.

**La zone sûre du combat est bornée à GAUCHE ET À DROITE** depuis que
T9.7 a posé des panneaux latéraux, et la caméra recentre sur les deux
axes. Cadrer sur toute la largeur mettait un tiers du plateau sous les
cartes.

**`UiSkin`, PAS `Skin` : ce nom est pris par Godot** (la peau d'un
squelette). L'autoload se résolvait silencieusement sur la classe native.
Même piège que `reload()` en T7.4 — un nom d'autoload se vérifie avant de
l'écrire.

**Les réglages du joueur sont à part de la sauvegarde**, dans
`user://settings.json` (autoload `Settings`, défauts dans
`data/settings.json`). Une partie neuve ne doit pas remettre le volume à
zéro. `AudioManager` crée les bus `Music` et `SFX` à l'exécution ; le choix
des sons reste à faire, le câblage non.

**Deux pièges d'interface qui font TOMBER le moteur en headless.** Un
`ScrollContainer` dont la barre verticale apparaît selon la hauteur du
contenu oscille avec tout texte replié, et empile un redessin par tour :
mettre `vertical_scroll_mode = 2` (toujours visible) — et pour qu'un rail
vide ne traîne pas dans un panneau, `UiSkin.dress_scroll()` met son ALPHA
à zéro quand `page >= max_value` : la place reste réservée, donc la mise
en page ne peut pas se remettre à osciller. Et `queue_redraw()`
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
godot --headless --path . -s tools/verify_ui.gd         # thème, teintes, tranches
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
   jamais écoutées. Le câblage est fait (T11.2), le choix des sons reste
   à juger à l'oreille — tout est dans `cues`, sans toucher au code.
