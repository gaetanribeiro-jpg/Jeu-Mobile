# État des lieux et plan de migration

> Réponse au § 56 de `docs/vision.md` : *analyser l'architecture actuelle,
> identifier ce qui peut être conservé, refactorisé ou supprimé, établir un
> plan de migration.*
>
> Rédigé le 2026-08-31, sur la base du commit `e382c82` — 277 tests verts,
> Phase 1 de l'ancienne conception terminée.

---

## 1. Ce qui existe aujourd'hui

Le dépôt n'est pas un début : c'est un **moteur de combat tactique complet
et testé**, avec toute sa chaîne d'assets. Ce qui a été construit sous le
nom « Reconquête » vaut largement d'être repris.

| Domaine | État | Verdict |
|---|---|---|
| Pipeline d'assets (`AssetTable`, `assets.json`, 535 entrées vérifiées) | complet | **conservé tel quel** |
| Découpe des feuilles d'animation (`SpriteFrameFactory`) | complet | **conservé tel quel** |
| Table audio + `AudioManager` (30 entrées) | complet | **conservé tel quel** |
| Police, thème, glyphes (140 vérifiés), i18n `fr.csv` | complet | **conservé tel quel** |
| Grille, tuiles, terrain (`Grid`, `Tile`, `terrain.json`) | complet | **conservé, étendu** |
| Aléatoire à graine (`CombatRng`) avec journal et rembobinage | complet | **conservé — devient central** |
| Rendu du terrain (autotuilage 4 états/axe, falaises, eau) | complet | **conservé tel quel** |
| Rendu des unités (ombre, animation, barre de vie, badge) | complet | **conservé, étendu** |
| Caméra, calques de surbrillance | complet | **conservé, étendu** |
| Chargement des cartes (`CombatMap`) + 8 cartes | complet | **conservé, cartes à réécrire** |
| Sauvegarde (`SaveManager`, `GameState`, `EventBus`) | squelette | **conservé, étendu** |
| Outils de vérification (6 outils) | complet | **conservé, étendu** |
| Captures d'écran headless (xvfb) | complet | **conservé — irremplaçable** |
| **Modèle de tour (déplacement + action, tour par camp)** | complet | ❌ **refondu en PA/PM + initiative** |
| **`Unit` (portée et dégâts fixes)** | complet | ❌ **refondu** |
| **`Ability` (4 capacités scriptées)** | complet | ❌ **refondu** |
| **IA ennemie (budget déplacement/action)** | complet | ❌ **refondue** |
| **HUD de combat** | complet | ❌ **refondu (jauges PA/PM, timeline, barre de sorts)** |
| L'Ordre, les blessures, les saisons, le comté | données seules | 🗄️ **rangé dans `plus-tard.md`** |

**Bilan chiffré :** sur 3 908 lignes de GDScript, environ **1 500 sont à
refondre** (`unit.gd`, `combat_engine.gd`, `enemy_ai.gd`, `ability.gd`,
`combat_hud.gd`, une partie de `combat_scene.gd`). Les **2 400 autres sont
conservées**, ainsi que la totalité des données d'assets, d'audio et de
police. Rien de ce qui a été fait n'est perdu : ce qui change est le
**modèle de tour**, pas la plomberie.

---

## 2. Ce que la vision change, point par point

| Sujet | Avant | Vision | Conséquence |
|---|---|---|---|
| Modèle de tour | déplacement + 1 action par unité | **PA / PM** | refonte du cœur |
| Ordre des tours | tout le camp joueur, puis tout le camp ennemi | **timeline d'initiative entremêlée** | refonte du cœur |
| Équipe | 3 héros pour 4 classes, doublons autorisés | **4 personnages max** | données |
| Classes | Guerrier, Archer, Lancier, Moine | **Guerrier, Archer, Mage** | données + assets |
| Échelle des chiffres | PV 4–8, dégâts 1–3 | **PV ~120, dégâts ~20–45** (§ 47) | données |
| Mort | 3 blessures = mort définitive | **pas de mort définitive dans le MVP** (§ 25) | rangé |
| Méta-progression | l'Ordre (maîtrises de classe) | **le royaume** (§ 41) | rangé |
| Temps | saisons, menace, comté | **cycle jour/nuit, régions, expéditions** | à construire |
| Ressources | bois, or, vivres, Renom | **bois, pierre, or, nourriture** | +1 ressource |
| Grille | 8 × 6 | plus grande — un arc porte à 4–7 (§ 17) | cartes à réécrire |

### Ce qui survit intact de l'ancienne conception

Trois idées de « Reconquête » servent directement la vision et sont
gardées :

1. **Le télégraphe** — les ennemis annoncent leur attaque un tour à
   l'avance, avec les dégâts chiffrés. Le § 39 le réclame explicitement
   pour les boss. C'est déjà construit, et c'est la meilleure pièce du
   moteur actuel.
2. **L'annulation permanente** — rien n'est irréversible avant la
   validation du tour. Devient : rien n'est irréversible tant que
   l'activation du personnage en cours n'est pas terminée.
3. **Le placement initial** — le joueur pose son équipe avant le premier
   tour sur les cases proposées par la carte. Le § 20 en fait un pilier.

---

## 3. Conflits entre la vision et le pack d'assets

**Cinq points où ce que la vision demande n'existe pas dans Tiny Swords.**
Ils demandent une décision de Gaetan ; ma proposition est en gras.

### 3.1 🔮 Le Mage — aucun sprite

Le pack fournit cinq unités humaines : **Warrior, Archer, Monk, Lancer,
Pawn**. Il n'y a pas de mage, pas de sorcier, pas de bâton.

**Proposition : le Moine devient le Mage.** C'est une figure encapuchonnée
en robe longue, et le pack lui donne déjà une animation d'incantation
(`Monk_Heal`) **avec son effet séparé** (`Monk_HealEffect`) — exactement ce
qu'il faut pour un lanceur de sorts. Les 5 couleurs de faction et le
portrait existent. Coût : zéro. Le nom de classe passe de `monk` à `mage`,
le sprite reste `monk`.

*Alternative écartée :* le `hex_shaman` du pack ennemi est un vrai caster,
mais il n'existe qu'en teinte ennemie, sans portrait ni déclinaison de
couleur.

### 3.2 🪨 La pierre — pas d'icône, mais tout le reste existe

Le pack fournit trois ressources ramassables : `wood_resource`,
`gold_resource`, `meat_resource`. **Pas de pierre.**

Mais il fournit `Rock1` à `Rock4` (gisements au sol), les `Gold Stones`
(rochers exploitables), et surtout **le Pawn à la pioche** — `idle_pickaxe`,
`run_pickaxe`, `interact_pickaxe`, une animation de minage complète.

**Proposition : la pierre est jouable.** Le gisement est un `Rock`, le
mineur est le Pawn à la pioche, et il ne manque qu'une **icône 32 × 32**
pour le compteur de ressource — qu'on peut découper dans `Rock1` ou dans
`icon_01..12` de l'UI.

### 3.3 🏗️ Les bâtiments — 8 sprites pour 15 bâtiments demandés

Le pack fournit, en 5 couleurs : `Castle`, `Barracks`, `Archery`,
`Monastery`, `Tower`, `House1`, `House2`, `House3`.

| Demandé (§ 7) | Sprite | Verdict |
|---|---|---|
| 🏰 Château | `Castle` | ✅ |
| ⚔️ Caserne | `Barracks` | ✅ |
| 🏹 Camp d'archers | `Archery` | ✅ |
| 🗼 Tour | `Tower` | ✅ |
| 🏠 Maisons | `House1/2/3` | ✅ — et les 3 variantes font 3 niveaux |
| 🏥 Infirmerie | `Monastery` | ✅ par reskin |
| 🌾 Ferme · 🪵 Scierie · ⛏️ Mine | — | ⚠️ voir ci-dessous |
| ⚒️ Forge · 🍺 Taverne · 🛒 Marché | — | ❌ aucun sprite |
| 🐎 Écurie (et la cavalerie) | — | ❌ aucun sprite, ni bâtiment ni monture |
| 🧱 Mur · 🚪 Porte | — | ❌ aucun sprite |

**Proposition pour la production : ce ne sont pas des bâtiments, ce sont
des chantiers.** Un arbre (`tree1-4`) + un Pawn à la hache = une scierie.
Un rocher + un Pawn à la pioche = une mine. Un mouton (`sheep_idle`,
`sheep_move`, `sheep_grass`) + un Pawn au couteau = une ferme. Le pack
dessine **exactement** cela, animations d'interaction comprises. C'est plus
vivant qu'un bâtiment statique, ça montre la population au travail (§ 9),
et ça ne coûte pas un pixel.

**Forge, taverne et marché** peuvent réutiliser `House2`/`House3` avec une
enseigne prise dans les décorations, ou attendre. **Écurie et cavalerie
sont à repousser** — il n'y a aucun sprite monté dans le pack.

### 3.4 🧱 Les murs et les portes — rien

Aucune tuile de mur, aucune porte. La défense du royaume (§ 38) devra
s'appuyer sur ce qui existe : les **tours**, le **relief** du tileset
(falaises infranchissables), l'**eau**, et les gisements comme obstacles.
Ce n'est pas un appauvrissement : une bataille de défense dans un goulet
naturel gardé par deux tours se lit très bien.

### 3.5 💀 Aucune animation de mort

Sauf pour le Troll. Traité comme avant : effet universel (flash, fondu,
poussière). `fx/dust_01-02`, `explosion_01-02`, `fire_01-03` et
`water_splash` couvrent aussi les zones d'effet magiques — une boule de feu
a de quoi être dessinée.

---

## 4. Décisions techniques prises pour la migration

Trois choix que je prends maintenant, parce qu'ils conditionnent le code.
Ils sont réversibles, tout est en données.

### 4.1 L'échelle des chiffres suit le § 47

PV autour de 100, dégâts autour de 20. Non par goût, mais parce que
l'équipement (§ 30), le critique (§ 12) et la défense ont besoin de
granularité : un +5 dégâts sur une base de 20 est un choix, sur une base de
3 c'est un doublement. Toutes les valeurs de l'ancien barème sont donc
recalculées.

### 4.2 La grille passe à 12 × 9

L'arc porte à 4–7 (§ 17) et un personnage a 4 à 5 PM. Sur 8 × 6, un Archer
couvre tout le plateau depuis n'importe où et le positionnement disparaît —
c'est exactement le problème déjà mesuré sur l'adjacence diagonale.
**12 × 9 = 108 cases**, soit 768 × 576 pixels : cela tient dans les
1280 × 720 de référence avec la place du HUD en dessous.

La taille de la grille vient de la carte, pas des règles : les 8 cartes
existantes continuent de charger. Elles seront **réécrites** pour le
nouveau format, c'est une tâche à part.

### 4.3 L'adjacence reste orthogonale

4 voisins, distance de Manhattan. C'était déjà tranché et mesuré, et le
système PM le confirme : 1 case = 1 PM n'a de sens que si toutes les cases
voisines coûtent la même chose. Une diagonale reste à distance 2.

---

## 5. Feuille de route technique

Suit l'ordre du § 45, adapté à ce qui existe déjà.

### Phase 1 — Cœur tactique PA/PM ⏳ *en cours*

| Tâche | Contenu | État |
|---|---|---|
| **T1.1** | Données : `hero_classes.json` (3 classes, PA/PM/stats), `abilities.json` (15 compétences), `rules.json` | ✅ |
| **T1.2** | `Unit` : PA, PM, initiative, bloc de statistiques, recharges, statuts | ✅ |
| **T1.3** | `Ability` : coût en PA, portée, forme de zone, statistique d'échelle | ✅ |
| **T1.4** | `TurnOrder` : timeline d'initiative entremêlée | ✅ |
| **T1.5** | `CombatBoard` : déplacement au coût en PM, portée et zone par compétence | ✅ |
| **T1.6** | `CombatEngine` : boucle d'activation, dépense de PA/PM, annulation | ✅ |
| **T1.7** | `Damage` : base + statistique − défense, terrain compris | ✅ |
| **T1.8** | IA ennemie qui gère un budget PA/PM | ✅ |
| **T1.9** | HUD : jauges PA/PM, timeline, barre de compétences, portée et zone | ✅ |
| **T1.10** | Les 8 cartes réécrites en 12 × 9 | ✅ |
| **T1.11** | Équilibrage : le combat coûte quelque chose | ✅ |
| **T1.12** | Le décor encaisse, et le feu brûle | ✅ |
| **T1.13** | `tools/verify_scripts.gd` : né du constat que `--quit` ne voit pas les scripts chargés à l'exécution | ✅ |

**État au 2026-08-31 : la Phase 1 est terminée.** T1.1 à T1.11 sont
faites et testées, **354 tests passent**. Le combat se joue de bout en
bout : placement, timeline entremêlée, PA/PM, neuf compétences
atteignables au doigt, portées et zones affichées, télégraphe, annulation.
Reste T1.12, qui n'est pas un défaut de combat mais un manque de terrain.

### Ce que T1.9 a apporté

Le moteur savait déjà tout faire ; c'est le HUD qui ne le donnait pas. Le
§ 48 en fait une exigence chiffrée, et elle est maintenant tenue :

- **une barre de compétences**, une par capacité, avec son coût en PA
  écrit dessus. Un bouton indisponible est grisé et dit pourquoi — pas
  assez de PA, en recharge, a déjà bougé.
- **des jauges en pastilles** plutôt qu'en barres. Huit pastilles se
  comptent d'un coup d'œil et disent « deux attaques à trois, il m'en
  reste deux » ; une barre pleine à 62 % ne dit rien de tel.
- **la timeline**, un badge par activation à venir, celle en cours cerclée.
  Elle déborde sur la ronde suivante, sinon elle se viderait en fin de
  ronde — au moment précis où le joueur a le plus besoin de voir venir.
- **la portée et la zone séparées** (§ 17 et § 18). Ce ne sont pas la même
  information : une Boule de feu vise vingt cases et n'en touche que cinq.
  Les confondre promettrait au joueur ce qu'il n'aura pas.

Deux défauts trouvés en capture d'écran et corrigés :

1. **Le plateau passait sous le HUD.** La caméra cadrait sur le plein
   écran ; elle cadre maintenant dans la zone que le HUD laisse libre, et
   `safe_area()` est la seule source de cette mesure.
2. **Une attaque à cible unique partait sur du terrain vide** : l'Archer
   dépensait 3 PA pour rien, sans aucun moyen de comprendre pourquoi. Une
   attaque à cible unique exige désormais une victime ; une compétence de
   zone, non — viser entre deux ennemis est son usage même.

### Ce que T1.11 a corrigé, et pourquoi

Le défaut n'était pas dans les ennemis, il était dans la **formule de
dégâts**. Les chiffres du § 47 — Frappe 20, Coup puissant 45 — sont des
chiffres FINAUX. Je les avais pris pour des chiffres de base et j'avais
empilé la statistique par-dessus : une Force à 12 ajoutait +60 % à une
frappe de base, et l'escouade effaçait toute rencontre avant que le
premier ennemi n'ait porté son coup annoncé.

Les statistiques redeviennent des **modificateurs** (1 à 8, pas 12 à 14).
Le Guerrier fait de nouveau 66 dégâts par activation, contre les 65 que le
§ 47 prescrit. En face, les ennemis encaissent assez pour survivre à la
ronde que le télégraphe leur offre, et frappent assez fort pour que ça
compte : un gobelin lancier retire 35 % des PV du Guerrier, et **71 % de
ceux du Mage**. Le positionnement du § 20 a enfin un prix.

### La vraie mesure : l'expédition, pas la rencontre

Une rencontre du MVP est faite pour être gagnée — la politique triviale du
simulateur les gagne toutes. Ce n'est pas un défaut : le § 29 place le
risque à l'échelle de l'**expédition**, pas du combat isolé. La question
« je rentre ou je continue ? » n'a de sens que si l'usure s'accumule.

| | coût moyen en PV |
|---|---|
| une rencontre | **13 %** |
| après 3 rencontres | il reste 65 % |
| après 5 rencontres | il reste 49 % |
| après 7 rencontres | il reste 37 % |

C'est la courbe d'usure que le roguelite demande, et c'est elle qu'il faut
surveiller, pas le taux de victoire d'un combat pris seul. Les deux outils
rendent maintenant cette colonne.

### Ce qui reste ouvert après T1.11

**L'Archer domine le jeu de portée.** Une équipe entièrement à distance
finit ses combats à 97 % de PV : elle tire à 5 cases sur des ennemis qui
avancent de 3 ou 4, et n'est jamais rattrapée. Donner au gnome à fronde la
même portée et un PM de plus n'a rien changé — il est seul de son espèce et
meurt le premier.

Ce n'est plus un réglage, c'est une décision de conception, et elle
appartient à Gaetan. Trois pistes :
1. **Plus d'ennemis à distance** dans le bestiaire — le pack fournit des
   sprites (arbalétriers gobelins, chamans).
2. **Une réaction au mouvement** : une unité qui traverse la portée d'un
   tireur se fait tirer dessus. C'est l'Élévation « Garde » de l'ancienne
   conception, et elle punit le kiting sans toucher aux chiffres.
3. **Assumer** : l'Archer est fort au MVP, et l'équilibrage viendra avec
   l'équipement et les classes suivantes (Phase 2).

**T1.12 est faite.** Deux choses étaient déclarées en données et jamais
appliquées : les points de vie d'un pont, et le `leaves_terrain` du Torch
Goblin. C'est le § 19 — « le terrain doit avoir un véritable impact » —
et il est tenu :

- une compétence qui touche une case VIDE portant un décor destructible
  frappe le décor. Casser le pont de `vallee_02` coupe le seul passage de
  la carte : c'est un coup qui vaut une activation entière. Une case
  occupée ne compte pas — on frappe qui se tient sur le pont, pas le pont
  sous ses pieds, sinon une Boule de feu dans une mêlée noierait tout le
  monde sans prévenir.
- une attaque à cible unique peut donc viser une case vide s'il y a
  quelque chose à casser, et seulement dans ce cas.
- le **feu** existe : il recouvre la case quelques rondes, brûle qui
  commence son activation dessus, puis s'éteint et **rend le terrain qu'il
  a remplacé**. Sans cette dernière règle, un incendie transformerait
  durablement une forêt en prairie et la carte ne serait plus celle que
  l'auteur a écrite.
- il ne prend ni sur l'eau ni sur la pierre.

Un défaut de rendu trouvé en capture d'écran : **le feu était invisible**.
La première image d'une bande d'animation de flamme n'est qu'une étincelle
de quelques pixels, illisible sur une case de 64 — un terrain qui inflige
des dégâts sans se voir est pire qu'inutile. Les décors peuvent maintenant
choisir leur image, et tout terrain qui blesse porte une teinte franche :
la teinte dit la case, le sprite dit ce que c'est.

**Ce qui reste ouvert.** Un objectif « protéger une STRUCTURE » ne peut
toujours pas échouer, pour une autre raison : l'IA ne vise que des unités,
jamais un décor. `vallee_05` protège donc encore un villageois. Faire
viser une structure par l'IA relève de la défense du royaume (§ 38), donc
de la Phase 5.

### Phase 2 — RPG ⏳ *en cours*

| Tâche | Contenu | État |
|---|---|---|
| **T2.1** | `Hero` : identité persistante, niveau, choix, fabrique son `Unit` | ✅ |
| **T2.2** | XP, seuils, montée en niveau, récompenses de rencontre | ✅ |
| **T2.3** | Équipement : armes, armures, accessoires, raretés | ⏳ |
| **T2.4** | Butin : ce qu'une rencontre laisse tomber | ⏳ |
| **T2.5** | Écran de fiche de héros et de compagnie | ⏳ |
| **T2.6** | Sauvegarde de la compagnie | ⏳ |

**Le sens de la dépendance est la décision structurante :** `Hero` connaît
`Unit`, jamais l'inverse. Le combat ne sait pas ce qu'est un niveau, et
c'est ce qui permet de le tester seul et de simuler mille rencontres en
headless. Toutes les modifications — gains de niveau, choix retenus,
équipement, bonus du royaume — sont donc appliquées **une seule fois**,
dans `Hero.effective_stats()` ; `Unit.from_stats` reçoit un bloc déjà
calculé et ne recalcule jamais rien.

`CombatRewards` est la couture : elle lit un combat terminé et rend des
chiffres que la couche campagne applique. C'est là que la Phase 3
branchera l'expédition et la Phase 4 le butin.

**Deux décisions prises en chemin :**

1. **L'expérience va à l'équipe, pas au tueur.** Le § 33 parle de la
   progression du héros sans jamais dire « celui qui porte le coup ».
   Récompenser le tueur pousserait le joueur à voler les mises à terre à
   son propre Guerrier — l'inverse exact d'un jeu où le Guerrier existe
   pour encaisser.
2. **Les niveaux sont OUVERTS, pas pris.** Trois niveaux sur dix demandent
   un choix définitif ; les prendre d'office volerait au joueur la seule
   décision que la montée en niveau contient. `level_up_free()` encaisse
   tout ce qui ne demande rien et s'arrête net devant le premier choix.

Les seuils d'expérience sont calés sur les combats, pas tirés au hasard :
une rencontre de cinq ennemis rapporte 75, le niveau 2 tombe pendant le
premier combat, le 10 vers le seizième — trois expéditions environ.

### Phase 3 — Monde

Carte du monde, régions, exploration, rencontres, coffres, expéditions,
choix rentrer/continuer, mini-boss et boss.

### Phase 4 — Royaume

Ressources (bois, pierre, or, nourriture), chantiers, construction,
amélioration des bâtiments, population, recrutement, armée.

### Phase 5 — Interconnexion

Loot → royaume, royaume → héros, exploration → ressources, invasions,
défense tactique, cycle jour/nuit.

---

## 6. Ce qui est rangé, pas jeté

Déplacé dans `plus-tard.md` avec ses données intactes :

- **L'Ordre** et ses quatre pistes de maîtrise, l'Élévation, la
  Convocation, le Renom, la Retraite
- **Les blessures** et la mort définitive (§ 25 l'interdit dans le MVP)
- **Les saisons**, la menace, la gestion de comté
- **Le Lancier** et le **Moine** comme classes distinctes — le Lancier est
  entièrement construit, sprites 5 directions compris, et rentrera dans le
  jeu au premier ajout de classe post-MVP

Rien n'est supprimé du dépôt : les fichiers de données restent, marqués
comme hors périmètre.
