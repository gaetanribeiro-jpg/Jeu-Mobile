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
| **T1.14** | L'Archer et les tireurs du bestiaire : la portée se paie | ✅ |

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

**~~L'Archer domine le jeu de portée.~~ Tranché en T1.14, plus bas.** Une
équipe entièrement à distance finissait ses combats à 97 % de PV : elle tire à 5 cases sur des ennemis qui
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

### T1.14 — l'Archer, tranché

La question ouverte depuis la Phase 1 : une équipe entièrement à distance
finissait ses combats à **97 % de PV**. Gaetan a proposé deux corrections ;
la mesure en a réclamé une troisième, et c'est celle-là qui portait tout.

**1. Deux tireurs de plus au bestiaire.** Le pack les dessinait déjà et ils
n'avaient jamais servi : le **gnoll lanceur d'os** (portée 2–5, 60 PV — il
ne meurt plus au premier tir comme le gnome à fronde) et le **chaman**
(portée 3–6, en **zone**). Le chaman est la réponse de forme plutôt que de
chiffre : une équipe à distance se masse hors de portée de la mêlée, et un
groupe immobile est un groupe rangé. Sa portée dépasse celle de l'Archer,
donc il faut **avancer** pour le faire taire.

Résultat : 97 % → 90 %. Réel, mais pas suffisant.

**2. L'Archer plus fragile — 85 PV → 72.** Presque **inerte** sur la mesure
(90 % → 90 %), et c'est logique : le pourcentage se calcule sur les PV
maximums, donc baisser le maximum baisse les deux côtés de la fraction. La
correction reste bonne en jeu — l'Archer encaisse maintenant 3 coups de
gobelin lancier au lieu de 4 — mais **elle ne pouvait pas régler le
problème**, et la croire suffisante aurait fait perdre une session.

**3. La portée doit se payer en dégâts.** C'était la vraie cause, et elle
n'était ni dans les ennemis ni dans les PV : l'Archer faisait **18+7 = 25**
par tir à cinq cases quand le Guerrier faisait **20+6 = 26** au contact,
avec un PM de plus et un repli gratuit. Il avait la puissance **et** la
portée, donc aucune contrepartie. `shot` descend à 15, `power_shot` à 30.

| | avant | après |
|---|---|---|
| meilleure composition | 4 archer, **97 %** | 4 archer / 4 mage, **92 %** |
| pire composition | archer + 3 mage, 83 % | warrior + archer + 2 mage, 82 % |
| écart | 14 points | **10 points** |

L'Archer ne domine plus : il **égalise** avec le Mage. Aucune classe n'est
gratuite.

**Ce que ça a coûté ailleurs, et c'est assumé.** Une rencontre coûte
maintenant **20 % des PV** au lieu de 13, et 0,6 personnage tombe par
combat. La courbe d'usure du § 29 est plus dure — et elle reste tenable
parce que l'étape de récompense rend 25 % et que le monastère en rend
jusqu'à 8 par étape. Une chaîne complète se finit autour de 45–50 % de PV.
C'est la tension que le roguelite demande, et elle est maintenant portée
par le bestiaire plutôt que par un déséquilibre entre les classes.

**L'ordre des cartes a été remesuré** et il a changé pour la deuxième fois :
01 (0 %), 06 (11 %), 05 (15 %), 02 (19 %), 03 (23 %), 04 (36 %). La fenêtre
du départ coûte 9 % en moyenne, celle du fond 26 % — près du triple.

**Une asymétrie assumée :** le chaman n'a pas de feu ami alors que la Boule
de feu du Mage en a. L'IA ne choisit pas son point d'impact pour épargner
les siens ; avec le feu ami, le chaman se saborderait sur sa propre mêlée
et deviendrait un cadeau. À rouvrir le jour où l'IA saura placer une zone.

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

### Phase 2 — RPG ✅

| Tâche | Contenu | État |
|---|---|---|
| **T2.1** | `Hero` : identité persistante, niveau, choix, fabrique son `Unit` | ✅ |
| **T2.2** | XP, seuils, montée en niveau, récompenses de rencontre | ✅ |
| **T2.3** | Équipement : armes, armures, accessoires, raretés | ✅ |
| **T2.4** | Butin : ce qu'une rencontre laisse tomber | ✅ |
| **T2.5** | `Company` : les héros, l'or, la réserve | ✅ |
| **T2.6** | Sauvegarde et rechargement de la partie | ✅ |
| **T2.7** | Écran de fiche de héros et de compagnie | ✅ |
| **T2.8** | Arbres de compétences (§ 34) : ils remplacent les choix de niveau | ✅ |

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

### L'équipement : le budget est la règle (T2.3)

Trente objets, cinq emplacements, cinq raretés. Le problème d'un système
d'objets est qu'il **n'a pas d'instrument** : on ne simule pas mille
combats pour un anneau, et un légendaire inventé un soir de fatigue casse
le jeu sans que rien ne le signale.

D'où la règle : chaque rareté vaut un nombre de points, et les gains d'un
objet doivent le valoir **exactement**. Le barème est en données — 5 PV
valent un point, un point de statistique deux, un PM cinq, un PA sept — et
`tools/verify_items.gd` refuse tout écart. Les trente objets y passent.

Le barème dit aussi ce qui est cher, et donc ce qui est intéressant : un
seul objet du jeu donne un PA, c'est l'Amulette de concentration, et elle
est légendaire. Un tiers d'attaque de base par activation vaut ce prix.

Les **armes sont réservées à leur classe** — c'est ce qui les rend
identitaires. Le reste est ouvert à tous : sur-restreindre laisserait des
emplacements morts sur deux classes, et `verify_items` vérifie aussi que
chaque classe peut remplir chacun de ses cinq emplacements.

### Le butin, et le levier du § 29 (T2.4)

Deux fils qui ne servent pas à la même chose. L'**or** est le fil sûr : il
tombe toujours, proportionnellement à ce qu'on a abattu, et c'est lui qui
alimentera le royaume. L'**équipement** est le fil incertain. Une défaite
laisse quand même une chance de butin — le § 41 refuse la punition absolue.

Le paramètre `depth` est la place que la Phase 3 viendra occuper : plus le
joueur enchaîne les rencontres sans rentrer, plus l'or grossit, plus les
objets tombent, et **plus le commun cesse de sortir**. C'est ce qui rend
« je rentre ou je continue ? » tentant plutôt que seulement risqué. Il
vaut zéro aujourd'hui et ne change rien ; les tests le vérifient déjà.

### La compagnie et la sauvegarde (T2.5, T2.6)

`Company` tient les héros, l'or et la réserve — le seul état qui traverse
les rencontres, et donc le seul à écrire sur le disque. Une règle la
gouverne : **rien ne se perd**. Un objet remplacé retourne à la réserve,
un héros qui quitte la compagnie rend son équipement, et une sauvegarde
qui a vu ses données changer se charge quand même en oubliant l'objet
disparu — perdre un anneau vaut mieux que perdre la partie.

`GameState.to_save()` et `from_save()` sont la frontière : `SaveManager` ne
sait rien du jeu, il écrit un dictionnaire, le versionne, et garde une
copie de secours. **La graine fait partie de la sauvegarde** — sans elle,
une partie rechargée ne serait plus la même partie, et la règle 4 tomberait
avec elle.

Un détail qui n'en est pas un : `_next_id` est sauvegardé. Sans lui, un
rechargement réattribuerait l'identifiant d'un héros vivant au recrutement
suivant, et la sauvegarde en écraserait un.

### L'écran de compagnie, et la boucle qui se referme (T2.7)

Sans cet écran, toute la Phase 2 est invisible : un niveau gagné, un objet
trouvé, un choix à faire n'existent pour le joueur que s'il peut les voir
et y toucher. Trois colonnes, une question chacune — qui compose ma
compagnie, que vaut celui-ci, qu'ai-je en réserve.

**Les choix de niveau sont ici, et nulle part ailleurs.** Trois niveaux sur
dix en demandent un, définitif ; un joueur qui ne peut pas le faire ne
monte pas de niveau, il regarde un compteur augmenter. Les boutons disent
donc ce que chaque option donne : « Endurant » ne dit rien, « Endurant —
PV +15 » dit tout.

L'écran **ne sauvegarde pas lui-même** : il émet `changed`, et l'appelant
décide. Sans cette séparation il serait intestable hors d'une partie
chargée, et il faudrait un singleton pour afficher trois portraits.

L'écran de titre part maintenant de la vraie compagnie, envoie ses héros au
combat avec leurs niveaux et leur équipement, et lui rend l'expérience et
le butin au retour. **C'est le plus court chemin complet de la boucle du
§ 3, et il tourne** — il y manque le monde et le royaume, qui sont les
Phases 3 et 4.

### Une leçon d'outillage payée deux fois

`tools/dev/screenshot.gd` monte une scène dans un script lancé par `-s`, et
un tel script ne reçoit **aucun autoload**. Pire : l'identifiant
`GameState` est résolu à la **compilation**, donc l'écran de titre a cessé
de compiler sous l'outil le jour où il a lu la partie sauvegardée. Il
restait sur son texte de secours — et on en conclut que l'écran est cassé.

Installer les singletons à la main ne répare rien, puisque l'échec est
antérieur. La seule façon de photographier un écran qui touche à la
campagne est de lancer le **jeu**, pas une simulation de jeu. D'où
l'autoload `Capture` : inerte sans son argument, il photographie le vrai
jeu après quelques images et rend la main.

```bash
xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png
```

### Phase 3 — Monde ✅

| Tâche | Contenu | État |
|---|---|---|
| **T3.1** | `Region` : les six régions du § 26, une seule ouverte | ✅ |
| **T3.2** | `Expedition` : la chaîne du § 28, la décision du § 29 | ✅ |
| **T3.3** | Évènements du § 40 : autel, village, ruines, embuscade, coffre | ✅ |
| **T3.4** | Le marchand : ce qu'on achète est à l'abri | ✅ |
| **T3.5** | Écran d'expédition : la route, la besace, rentrer ou continuer | ✅ |
| **T3.6** | Écran de carte du monde, et la boucle branchée de bout en bout | ✅ |

### Les régions, et l'escalade sans toucher aux chiffres (T3.1)

Six régions déclarées (§ 26), **une seule ouverte**. Les cinq autres
existent pour que la carte du monde ait quelque chose à montrer et que le
joueur voie où il ira ; elles n'ont ni cartes ni chaîne, et rien dans le
code n'a le droit de leur en réclamer. `verify_world` s'arrête d'ailleurs
au nom pour une région verrouillée : exiger d'elle un contenu qu'on a
délibérément remis à plus tard ferait échouer une vérification pour une
décision, pas pour un défaut.

**L'escalade du § 29 ne touche à aucun chiffre de combat.**
`encounter_maps` est rangée du plus facile au plus dur, et le tirage d'une
rencontre pioche dans une **fenêtre qui glisse** avec la profondeur : trois
cartes sur six. Plus le joueur s'enfonce, plus les cartes faciles cessent
de sortir.

**L'ordre est MESURÉ, pas supposé** — et rangé à l'œil, il était faux.
`simulate_combats` donne ce qu'une carte coûte à l'équipe sur cinquante
graines, et c'est l'instrument établi en T1.11 :

| carte | 01 | 05 | 06 | 02 | 03 | 04 |
|---|---|---|---|---|---|---|
| coût en PV | 0 % | 7 % | 12 % | 14 % | 14 % | 24 % |

Le numéro de carte disait l'inverse pour `vallee_05` et `vallee_02`, si
bien que la fenêtre du fond proposait une rencontre **plus facile** que
celle du départ. Une fois rangée sur la mesure : 6 % en moyenne au départ,
17 % au fond. L'escalade est réelle, et elle est chiffrée. Un ordre mesuré
est un ordre qui périme : à relancer après toute modification d'une carte
ou d'un ennemi.

C'est délibérément la SÉLECTION qui monte, pas les ennemis. Gonfler les PV
ou les dégâts avec la profondeur aurait invalidé tout l'équilibrage de
T1.11 — les 13 % par rencontre, le télégraphe qui laisse une ronde, le
gobelin lancier qui retire 35 % des PV du Guerrier — et il aurait fallu le
refaire pour chaque palier. Ici, un combat profond reste un combat mesuré ;
c'est juste un combat plus dur du même catalogue.

Le mini-boss et le boss sont **hors de la fenêtre**, sans quoi le boss
pourrait tomber au milieu de la chaîne. `vallee_08` (le Troll) est le boss
des Terres Vertes ; `vallee_07`, la carte d'extraction à six ennemis et la
plus dure des ordinaires, tient le rôle de mini-boss. **Une carte de
mini-boss dédiée reste à écrire** : c'est du dessin de carte, pas du
moteur, et la chaîne du § 28 est déjà tenue sans elle.

### L'expédition : trois choses font la décision (T3.2)

« Rentrer maintenant, ou continuer ? » est la mécanique fondamentale du
§ 29, et elle n'existe que si **trois** choses sont vraies en même temps :

| | où c'est réglé |
|---|---|
| continuer **rapporte** plus | `depth` passé à `Loot.roll` — +15 % d'or par rencontre, et le commun cesse de sortir |
| continuer **coûte** | rien ne se soigne : l'usure de T1.11 s'accumule d'une étape à l'autre |
| échouer **perd** | la besace ne rejoint la compagnie qu'au retour ; une déroute en laisse 40 % |

Enlever n'importe laquelle des trois rend la réponse automatique. Les
tests de `test_expedition.gd` sont rangés sous ces trois titres exactement,
et `verify_world` refuse qu'un de ces trois chiffres tombe à zéro : c'est
la seule chose qui dirait qu'on vient de supprimer la mécanique.

**La chaîne est tirée en entier au départ**, pas rencontre par rencontre.
Une route qui se découvre pas à pas ne demande rien au joueur, elle se
subit ; le § 28 la dessine d'ailleurs comme une suite qu'on lit d'un bout
à l'autre. Le corps (`combat, event, combat, merchant`, répété 3 à 6 fois)
est tiré, la fin (`miniboss, reward, boss`) est toujours la même : une
expédition courte n'est pas une expédition tronquée, elle a moins de corps
mais elle a son boss.

**Un héros mis à terre se relève à 10 % de ses PV.** C'est le § 25 et le
§ 41 lus ensemble : pas de mort définitive, mais mourir reste une
conséquence. À zéro, il repartirait à terre au combat suivant — une mort
définitive déguisée, et `verify_world` le refuse nommément.

**L'étape de récompense est la seule respiration de la chaîne** (25 % des
PV). Le levier `healing.between_steps` existe et vaut zéro : c'est le
premier chiffre à bouger si l'usure se révèle trop dure à l'usage, et il
est écrit plutôt que sous-entendu.

`Expedition` se sérialise. Sur mobile l'application meurt en pleine
sortie, et perdre une expédition pour cette raison serait la pire des
punitions — celle-là même que le § 41 refuse.

### Les évènements : une seule règle, et elle est vérifiable (T3.3)

Le § 40 tient en une phrase : **« les événements doivent créer des
décisions »**. C'est la seule règle qu'un fichier de données peut violer
sans que rien ne plante — un évènement à une option, ou dont une option
est meilleure que l'autre sur toute la ligne, se joue parfaitement. Il ne
demande simplement plus rien.

`verify_world` la vérifie donc littéralement : il calcule l'**espérance**
de chaque option sur chacune des monnaies de l'échange, et refuse tout
évènement dont une option en **domine** une autre sur tous les axes à la
fois. Ça a servi tout de suite : le coffre avait une option « crocheter »
strictement meilleure que « forcer » — moins chère en PV, plus généreuse
en objets, plus généreuse en or. La table est passée de deux options à un
seul vrai choix sans que personne ne s'en aperçoive.

**Quatre monnaies, et il en faut plusieurs.** Les PV (que rien ne rend),
l'or (dont le royaume aura besoin, § 32), la besace (qui n'est pas encore
à l'abri) et le risque (une chance déclarée). Un évènement qui n'échange
que de l'or contre de l'or ne demande rien à personne.

**L'évènement se tire à l'arrivée, pas au départ.** La route est connue —
c'est ce qui permet de décider si l'on rentre — mais elle dit « un
évènement », pas lequel. Le § 40 les appelle aléatoires ; les afficher
trois rencontres à l'avance leur retirerait le seul effet que ce mot
décrit. Une fois tiré, il est retenu : une partie rechargée retrouve celui
qu'elle avait déjà découvert.

**Un évènement ne tue jamais.** L'autel fait payer en sang, et le plancher
est à un PV. Mourir se fait sur un plateau, où le joueur peut agir ; pas
dans un menu, où il ne peut que regarder.

**L'embuscade intercale un vrai combat** dans la chaîne. Elle rallonge la
route, ce qui est déjà un prix, et la carte se tire comme les autres. Fuir
coûte 30 % de la besace : c'est le même levier qu'une déroute, à un tarif
choisi plutôt que subi.

### Le marchand : l'or achète de la sécurité (T3.4)

Ce qui distingue le marchand d'un tas de butin de plus : **ce qu'on
trouve va dans la besace et reste en jeu jusqu'au retour ; ce qu'on
achète rejoint la réserve tout de suite**. Une déroute ne reprend pas ce
qui a été payé. L'or n'achète donc pas seulement un objet, il achète de la
sécurité — et en face, le § 32 lui a déjà donné un autre usage : dépenser
ici, c'est ne pas bâtir là-bas. Deux tests se font écho pour tenir cette
paire ; casser l'une casse le sens de l'autre.

**Le prix sort du barème de l'équipement**, jamais d'une liste à part : le
budget de rareté multiplié par `gold_per_point`. Ce sont les mêmes points
qui servent à `verify_items` pour vérifier qu'un objet est équilibré. Un
objet ajouté un jour a donc son prix le jour même, et il est juste par
construction ; une table de prix séparée aurait dérivé du barème dès le
deuxième objet ajouté, et personne ne l'aurait vu.

Commun 44, peu commun 88, rare 132, épique 198, légendaire 286, pour une
rencontre qui rapporte environ 57. Le rachat est à 35 % : revendre doit
rester l'aveu qu'on n'avait pas l'usage d'un objet, pas une façon de faire
de la monnaie. `verify_world` refuse d'ailleurs un rachat qui atteindrait
le prix — acheter puis revendre deviendrait gratuit, et l'or et les objets
seraient la même chose.

**L'étal se tire à l'arrivée et ne change plus**, comme l'évènement. Un
stock qui se retirerait à chaque rechargement permettrait de le relancer
jusqu'à voir un légendaire. Et lire un étal ne le remplit pas : un bogue
attrapé par les tests faisait qu'interroger la boutique sans générateur la
figeait vide pour de bon.

**La chaîne la plus courte n'a pas de marchand du tout.** Le corps fait 3
à 6 étapes sur un motif de quatre ; à 3, la boutique tombe hors du compte.
C'est une variance qu'on garde : une sortie sans boutique est une sortie
différente, et savoir qu'elle est possible donne du prix à celle qui
l'offre.

### L'écran d'expédition : les trois termes ensemble (T3.5)

« Rentrer maintenant, ou continuer ? » n'est une question que si les trois
termes de la décision sont à l'écran **en même temps** :

| | ce que ça répond |
|---|---|
| la **route** | ce qui reste — combien de combats, où est le boss |
| la **besace** | ce qu'on perdrait |
| l'**équipe** | ce avec quoi on continuerait |

Les séparer sur trois écrans reviendrait à demander au joueur d'en retenir
deux pendant qu'il regarde le troisième : il choisirait au sentiment, et la
mécanique fondamentale du § 29 deviendrait un bouton. Ils tiennent donc sur
une seule page, quitte à ce qu'aucun ne soit détaillé — la route est une
rangée de badges, l'équipe trois barres de vie.

**Le pari est annoncé avant d'être couru.** C'est le télégraphe du combat
appliqué aux évènements : les ennemis disent leurs dégâts avant de frapper,
un évènement dit sa chance avant qu'on la coure. Et une option trop chère
reste affichée, grisée : savoir ce qu'on ne peut pas s'offrir fait partie
de la décision.

Comme l'écran de compagnie, il **ne sauvegarde pas lui-même** : il émet
`changed` et l'appelant décide. Sans cette frontière il serait intestable
hors d'une partie chargée.

### GUT n'échoue pas sur un test cassé — il l'ignore (T3.5)

Le fichier de test de cet écran est parti avec une erreur d'analyse. GUT ne
l'a pas signalée comme un échec : il a **ignoré le fichier**, avec un
avertissement noyé dans son journal, et annoncé « tous les tests passent »
avec treize tests de moins. Le compte total était le seul indice, et il
faut le connaître par cœur pour le remarquer.

Un test qui disparaît est pire qu'un test qui échoue. `verify_scripts`
couvre donc maintenant `res://tests` comme le reste — c'est exactement le
défaut qu'il avait lui-même en T3.1, à un dossier près.

### La carte du monde, et la boucle branchée (T3.6)

Le § 28 met les décisions avant le départ. Une seule est réelle au MVP —
l'équipe — puisqu'une seule région est ouverte. **Les cinq autres sont
affichées et lisibles**, verrouillées : une carte qui ne montrerait que les
Terres Vertes ne serait pas une carte du monde, ce serait un bouton. Le
verrou dit qu'il y a une suite, et il ne coûte rien.

**L'équipe se compose ici et pas dans l'expédition.** Une fois partie, elle
ne change plus : c'est ce qui fait de sa composition une décision, et d'une
déroute une conséquence de cette décision-là.

`boot.gd` devient un menu : expédition, compagnie, et **le banc d'essai des
huit cartes, qui reste**. Ce n'est pas un reliquat. Je ne peux pas jouer au
jeu ; pouvoir ouvrir une carte précise en deux clics est la seule façon de
vérifier un combat sans traverser une sortie entière. Il est nommé pour ce
qu'il est.

**L'expédition fait partie de la sauvegarde**, et la reprise passe avant
tout le reste à l'écran comme sur le disque : sans ça on repartirait de
zéro sans s'apercevoir qu'on vient de perdre une sortie de six étapes.

### Ce que les captures ont montré, encore (T3.6)

Quatre défauts, dont deux qu'aucun test n'aurait vus.

1. **Le résumé de région sortait une lettre par ligne.** Un
   `ScrollContainer` qui autorise le défilement horizontal laisse son
   enfant à sa largeur minimale, et l'autowrap s'effondre.
2. **Les barres de vie étaient grises sur gris.** C'est LE chiffre de la
   décision du § 29 ; il doit se lire sans être lu. Vert, ambre, rouge.
3. **Les options d'évènement ne disaient pas leurs termes.** « Le forcer à
   l'épaule » ne dit rien ; « Le forcer à l'épaule — −10 % PV, un objet de
   valeur » dit tout. C'est le télégraphe du combat appliqué aux
   évènements : un ennemi annonce ses dégâts chiffrés avant de frapper, et
   on ne décide pas de ce qu'on ignore.
4. **L'étal ne disait pas ce que ses objets font.** « Pavois, rare, 132 »
   ne permet pas de savoir si c'est mieux que ce qu'on porte, donc pas de
   comparer l'achat au fait de ne pas acheter.

Pour les voir, `Capture` sait maintenant **naviguer** : `--press` presse
des boutons par leur texte, dans l'ordre. Un écran qu'on n'atteint qu'en
naviguant se photographie donc tel que le joueur l'atteint, et pas monté à
la main dans un banc d'essai — c'était précisément la leçon de T2.7. Une
pression qui échoue **n'enregistre pas d'image** : elle montrerait l'écran
précédent, et on en conclurait que la navigation marche.

### Un outil de vérification qui mentait (T3.1)

`tools/verify_scripts.gd` annonçait « tous les scripts compilent »
**juste après avoir affiché l'erreur de compilation de `boot.gd`**. Un
script qui ne compile pas revient quand même de `load()` comme un GDScript
valide, source chargée et analyse en échec ; le test `script == null` ne
voyait rien. C'est exactement le défaut que cet outil existait pour ne pas
laisser passer.

Deux corrections : l'échec se mesure à `can_instantiate()`, et les scripts
qui **citent un singleton** sont exclus **nommément** — un script lancé par
`-s` ne reçoit aucun autoload et l'identifiant est résolu à la
compilation, donc leur échec n'est pas un défaut du script. La liste des
singletons est lue dans les réglages du projet, jamais écrite dans
l'outil : un autoload ajouté un jour et oublié là rouvrirait le trou. Les
commentaires ne comptent pas — trois fichiers citent un singleton pour
expliquer qu'ils ne s'en servent pas, et les exclure pour ça reviendrait à
ne plus vérifier les scripts les mieux documentés.

Aujourd'hui : 44 scripts vérifiés, 1 nommé comme non vérifiable
(`boot.gd`), et un script cassé volontairement est bien détecté.

### Phase 4 — Royaume ✅

| Tâche | Contenu | État |
|---|---|---|
| **T4.1** | `Kingdom` : ressources, habitants, chantiers, cycle de production | ✅ |
| **T4.2** | `Buildings` : construction, niveaux, ce qu'ils accordent aux héros | ✅ |
| **T4.3** | L'écran du royaume, dessiné | ✅ |
| **T4.4** | Le branchement : le cycle sur l'expédition, les bonus sur les héros, le recrutement | ✅ |

### Le cycle est une expédition, pas une minute (T4.1)

Aucun timer, aucune énergie — c'est une décision verrouillée, et le § 2
refuse le free-to-play. Le royaume produit **une fois par sortie conclue**,
quelle qu'en soit la longueur.

Ce n'est pas un détail d'implémentation. C'est ce qui relie les deux
moitiés de la boucle du § 3 : une sortie **courte** rapporte plus de
cycles, une sortie **longue** rapporte plus de butin. Les deux se disputent
le même temps, et « je rentre ou je continue ? » gagne un troisième terme
sans qu'on ait rien ajouté à l'expédition.

**Des chantiers, pas des bâtiments de production.** Le pack ne dessine ni
ferme, ni scierie, ni mine — mais il dessine des arbres qu'on abat, un
gisement d'or, des rochers, des moutons, et un Pawn avec quatre outils et
une animation d'interaction pour chacun. Un bûcheron devant un arbre montre
en plus la **population au travail**, que le § 9 réclame et qu'un bâtiment
fermé ne montre jamais.

Effet de bord heureux : il n'y a **pas d'animation de Pawn portant de la
pierre** dans le pack (bois, or et viande seulement). Un chantier montre
l'ouvrier *à la tâche*, pioche en main, pas son aller-retour — le manque ne
se voit donc jamais.

**Une bourse, pas deux.** L'or vit avec la compagnie, parce que ce sont les
héros qui le gagnent sur la route et le dépensent chez le marchand, loin du
royaume. Lui faire une seconde bourse au royaume obligerait à tenir les
deux d'accord, et deux bourses qui doivent rester d'accord finissent
toujours par ne plus l'être. `resources.json` déclare donc où vit chaque
ressource, et c'est la seule chose que l'appelant a besoin de savoir.

**Personne ne meurt de faim.** La réserve tombe à zéro, le royaume
n'accueille plus, et c'est tout. Affamer un village pendant que le joueur
est en expédition serait une punition qu'il n'était même pas là pour
empêcher, et le § 41 les refuse.

### Les bâtiments, et la question qu'ils doivent savoir répondre (T4.2)

« Qu'est-ce que ça permet à mes héros ? » Cinq bâtiments y répondent :
château, maisons, caserne, camp d'archers, monastère.

**Ce que le MVP ne bâtit pas, et pourquoi.** La **tour** est dessinée par
le pack et reste absente : elle sert à la défense, les invasions sont la
Phase 5, et une tour sans invasion ne répond à rien — « aucun bâtiment
décoratif » est une décision verrouillée. La **forge**, le **marché**, la
**taverne**, l'**écurie**, le **mur** et la **porte** du § 7 n'ont aucun
sprite dans le pack.

**Le château plafonne tout le reste.** Sans cette règle on monterait une
caserne au niveau 5 dans un hameau. C'est sa vraie fonction ; l'habitant
qu'il ajoute par niveau n'est que la prime.

**Les coûts sont engendrés, les gains sont écrits.** Vingt-cinq prix à la
main auraient dérivé les uns des autres dès la première retouche ; les
gains, eux, sont la conception et ne se déduisent d'aucune formule.

**Le monastère est le seul bâtiment qui touche à l'expédition** : il rend
des PV entre deux rencontres, et déplace donc la courbe d'usure mesurée en
T1.11. C'est la réponse la plus directe au § 45 — « connecter le royaume au
RPG » — et le levier que je chercherai si les 13 % par rencontre se
révèlent trop durs.

Le sens de la dépendance ne bouge pas : le royaume rend un bloc de
modificateurs, `Hero.effective_stats` l'ajoute **comme il ajoute un
anneau**, et ni `Hero` ni `Unit` ne savent qu'un royaume existe. Le crochet
`bonuses` existait depuis T2.1 et attendait exactement ça.

### L'écran du royaume : le terrain à gauche, la décision à droite (T4.3)

Le § 5 fait de l'évolution visuelle une exigence : il fallait donc que le
royaume se **voie**, et pas seulement se lise dans un tableau. Mais un
royaume qu'on voit sans pouvoir agir dessus est un fond d'écran — le
panneau de droite est la moitié qui décide.

**Trois choses rendent l'évolution visible**, dans l'ordre de leur poids :
le **nombre** de bâtiments debout ; les **habitants au travail**, un Pawn
par bras affecté, pioche ou hache en main, à son gisement ; et les
**maisons**, seul bâtiment dont le pack sait dessiner trois âges. Ce que le
pack ne sait pas montrer — le niveau d'une caserne — s'écrit en chiffre sur
une pastille : le § 8 ne réclame la visibilité que « quand c'est possible ».

**Deux décisions, et deux seulement.** Bâtir (dépenser maintenant, ou
garder pour la prochaine sortie) et affecter (quelle ressource manque le
plus, ce cycle-ci). Elles se disputent la même bourse et les mêmes bras.
Tout le reste de l'écran les éclaire : les réserves en haut, les bras
libres à côté d'elles, le coût du niveau suivant **avec ce qu'on n'a pas
encore entre parenthèses**, et un bouton grisé qui dit ce qui manque —
de l'argent, ou un château plus haut.

**Un Control qui se dessine lui-même**, pas une nuée de nœuds : le terrain,
les bâtiments, les gisements et les Pawns tiennent dans un `_draw` et une
table de rectangles cliquables. Une trentaine de sprites ne justifient pas
trente nœuds à tenir synchronisés avec un état qui change à chaque clic.

### Le branchement (T4.4)

**Une sortie conclue = un cycle de production.** C'est la couture des deux
moitiés de la boucle du § 3, et elle tient en une ligne dans `boot.gd`.
Une déroute compte aussi : les bûcherons ont travaillé pendant que les
héros tombaient.

**Le royaume ne parle pas à l'expédition.** `Expedition` ignore qu'un
royaume existe — c'est l'écran de titre qui pose ses modificateurs et son
soin sur la sortie, à chaque ouverture plutôt qu'au départ, parce que le
joueur a pu bâtir entre-temps et **une valeur dérivée qu'on garde finit par
mentir**. C'est aussi ce qui permet de jouer une sortie dans un test ou
dans le simulateur sans bâtir de royaume.

**Recruter est la seconde chose qu'un bâtiment militaire permet** (§ 45).
Le coût est en or et en nourriture : une seule monnaie aurait fait du
recrutement un robinet, deux en font un arbitrage contre les bâtiments, qui
puisent dans la même bourse. Et **l'habitant n'est pas un héros** : recruter
ne prend personne à la population. Un royaume qui perdrait un bûcheron
chaque fois qu'il forme un Guerrier punirait le joueur d'avoir joué.

### Trois heures perdues sur une barre de défilement

L'écran du royaume faisait **tomber le moteur** en headless — signal 11,
avec pour seul indice « Message queue out of memory » et un nom de méthode
qui ne désigne rien (`CanvasItem::_redraw_callback`, puis
`Control::_update_minimum_size`).

La cause : la **barre de défilement verticale** du panneau apparaissait et
disparaissait selon la hauteur du contenu. Quand elle apparaît, elle
rétrécit le contenu ; un texte replié qui rétrécit devient plus haut, donc
rappelle la barre. La mise en page **oscille**, empile un redessin par
tour, et rien ne vide cette file en headless. Le panneau ne passait de six
à sept enfants qu'avec le bouton de recrutement — ce qui a fait accuser le
bouton pendant longtemps, puis son libellé, puis `autowrap_mode`, qui n'a
fait que déplacer la boucle sous un autre nom.

Le correctif tient en une propriété : la barre est **toujours visible**, sa
présence ne dépend plus de rien. Les deux écrans à panneau la portent
maintenant.

Deux leçons qui valent au-delà de ce bug :
- **un plantage du moteur en headless n'a pas de coupable dans sa trace.**
  La bissection à coups de `print` a trouvé en dix minutes ce que la
  lecture de la pile n'aurait jamais donné ;
- `queue_redraw()` dans un `_process` est un **piège en headless** : rien
  ne vide la file. La vue du royaume ne s'anime donc que là où quelque
  chose sera dessiné, et ne redessine qu'au changement d'image — soixante
  redessins par seconde pour en montrer dix étaient de toute façon
  cinquante de trop.

### Ce que `verify_kingdom` a trouvé le jour de sa naissance

Une économie n'a pas plus d'instrument qu'un objet. On ne simule pas cent
parties pour savoir si une caserne est trop chère — mais on peut exiger
qu'elle soit **atteignable**, et dire en combien de cycles.

Deux vrais défauts, tous deux invisibles à la lecture :

1. **Un royaume plein ne pouvait pas se nourrir** : 42 nourriture produite
   au mieux, 78 mangée. Le plafond de population était un mensonge.
2. **Seize habitants sur vingt-six n'avaient nulle part où travailler.**
   Un habitant au-delà du nombre de places n'est plus qu'une bouche. Le
   plafond est descendu à 14 pour 12 places : il reste un ou deux bras
   libres, donc affecter est un arbitrage et jamais un remplissage.

Et un piège de moteur qui aurait pourri les gains en silence : **Godot
analyse tout nombre JSON en flottant**, `6` comme `0.02`. Distinguer un
gain fractionnaire par son TYPE ne pouvait pas marcher — tout était
flottant, et la distinction était une illusion qui affichait « +600 % »
pour six points de vie. On le distingue maintenant par sa clé.

Un troisième défaut, celui-là trouvé en capture d'écran : **la mine d'or
était un point jaune illisible**. `gold_resource` est la pépite que le Pawn
PORTE — vingt-quatre pixels de contenu perdus dans une toile de 128.
`gold_stone_4` est le rocher aurifère, et il se voit. C'est exactement le
feu invisible de T1.12, deux phases plus tard.

### Phase 4 — Royaume

Ressources (bois, pierre, or, nourriture), chantiers, construction,
amélioration des bâtiments, population, recrutement, armée.

### Phase 6 — Confort ⏳

| Tâche | Contenu | État |
|---|---|---|
| **T6.1** | Options, pause en combat, volume, tremblement d'écran | ✅ |

### Ce qu'un écran d'options oblige à faire vraiment (T6.1)

C'est la première chose qu'un testeur cherche, et son absence donne
l'impression d'un prototype même quand tout le reste tourne. Mais un écran
d'options **oblige à rendre vraies** les choses qu'il règle, sinon il est
exactement ce que le projet s'interdit ailleurs : du décoratif.

Deux choses étaient donc à écrire avant lui.

**`AudioManager` était un squelette vide.** Trois curseurs qui ne
commandent rien n'auraient rien valu. Les bus `Music` et `SFX` sont créés à
l'exécution — trois bus ne valent pas une ressource binaire à maintenir
hors du dépôt de texte — et la conversion linéaire → décibels vit à un seul
endroit : un curseur qui parle en décibels ne veut rien dire pour personne.
Le zéro coupe franchement, parce que `linear_to_db(0)` rend −∞ et que
certains pilotes n'aiment pas ça. **Le choix des sons reste à faire, et il
demande des oreilles** — le câblage, lui, est prêt.

**Le tremblement d'écran était déclaré dans `view.json` depuis T1.9 et
personne ne le lisait.** Le § 12 le met en tête du rapport impact/coût ;
c'était le coût qui n'avait pas été payé. Il est maintenant tenu à part du
décalage de cadrage — les mélanger ferait dériver le cadrage à chaque coup
— et une mise à terre secoue plus fort qu'un coup, ce qui est la seule
chose qui distingue les deux **sans animation de mort**, que le pack ne
fournit pas.

**Les réglages vivent à part de la sauvegarde de partie**, dans
`user://settings.json`. Commencer une nouvelle partie ne doit pas remettre
le volume à zéro, et un joueur qui a coupé la musique ne veut pas la voir
revenir parce qu'il a perdu une expédition. Chaque mouvement de curseur est
écrit tout de suite : sur mobile l'application peut mourir entre le réglage
et la fermeture de l'écran.

### La pause n'est pas une pause, c'est une sortie (T6.1)

Le combat est au tour par tour : rien ne « tourne ». Ce menu ne suspend
donc rien — il offre une **porte**. Sur mobile on est interrompu, et un
combat dont on ne peut pas sortir se quitte par le bouton système, ce qui
tue l'application et l'expédition avec elle. Mieux vaut une défaite que le
joueur a choisie qu'une partie qu'il a perdue en fermant la fenêtre.

`CombatEngine.surrender()` produit donc une **vraie défaite**, journalisée
comme les autres, que l'expédition encaisse comme les autres — besace
amputée du § 41 comprise. Abandonner demande deux pressions, et la seconde
dit ce qu'elle coûte.

### Trois pièges payés en chemin (T6.1)

1. **Une lambda GDScript capture une variable locale par VALEUR.** Un
   compteur local incrémenté dans un `connect` reste à zéro, et
   l'assertion échoue sans que rien ne soit faux dans le code qu'elle
   vise. Le compteur d'un test est donc un membre.
2. **Une scène de pause est un `CanvasLayer`, pas un `Control`.** La
   ranger dans une variable typée `Control` faisait échouer l'affectation
   à l'exécution : le menu ne s'ouvrait jamais, **sans le moindre
   message**. Trouvé en capture d'écran, comme d'habitude.
3. **`--press` de `Capture` laissait douze images entre deux pressions.**
   C'est assez pour un panneau qui se reconstruit, pas pour une pression
   qui CHARGE UNE SCÈNE. La séquence échouait alors sur le bouton suivant
   et la capture montrait l'écran d'avant — le pire des résultats,
   puisqu'il ressemble à un vrai. Quarante images, et l'échec nomme
   maintenant **les boutons qui étaient à l'écran**.

### Les arbres de compétences (T2.8, § 34)

**Ils REMPLACENT les choix de niveau, ils ne s'y ajoutent pas.** Deux
monnaies de progression pour le même acte — monter d'un niveau — auraient
été exactement la complexité que le § 31 refuse. Les six options d'alors
(Endurant, Affûté, Vif, Concentré, Mortel, Cuirassé) n'ont rien perdu :
elles sont devenues des nœuds, et le joueur choisit maintenant dans quel
**ordre** il les prend, pas seulement laquelle.

**Un tronc, deux branches, onze nœuds pour neuf points.** Le tronc est
l'identité de la classe ; les branches sont les builds du § 35 — Guerrier
Tank contre Berserker, Archer Critique contre Mobilité, Mage Destruction
contre Survie. On ne prend pas tout, et c'est ce qui fait qu'un Guerrier ne
ressemble pas à un autre Guerrier. `verify_skills` refuse un arbre qu'on
pourrait finir : un arbre qu'on finit n'est plus un arbre, c'est une liste.

**Six compétences nouvelles**, toutes dans le vocabulaire que le moteur
sait déjà dire — aucune mécanique inventée, donc rien à re-tester en
profondeur. Fendre (une ligne de deux cases : le « Tourbillon » du § 34),
Entaille, Tir entravant, Salve, Trait arcanique, Givre.

**La classe garde ses trois compétences de départ.** L'arbre en ajoute, il
n'en reprend aucune : un héros de niveau 1 doit pouvoir jouer, et
l'équilibrage mesuré en T1.11 et T1.14 suppose ces trois-là.

**Monter de niveau ne demande plus rien.** Le niveau donne un point, le
point se dépense dans l'arbre quand le joueur veut. C'est ce qui permet
d'encaisser l'expérience d'une expédition entière sans ouvrir un menu au
milieu d'un combat — ce que l'ancien `level_up_free()` devait contourner.

### Peser une branche avec le barème de l'équipement

Le § 35 promet des builds. **Deux branches ne sont un choix que si elles se
valent** : une branche qui donne deux fois plus que l'autre n'est pas une
voie, c'est la bonne réponse et une erreur.

`verify_skills` les pèse donc, au **barème de l'équipement** — les nœuds
accordent les mêmes statistiques que les objets, et deux barèmes auraient
divergé dès la première retouche. Un nœud de compétence est compté pour un
point d'action, le gain le plus fort du barème : c'est une convention
assumée plutôt qu'une mesure, et elle est écrite comme telle.

Il a servi le jour de sa naissance. Avec Fendre dans le tronc, la branche
Tank du Guerrier valait **15** contre **23** pour le Berserker — la branche
sans compétence vaut structurellement moins. Le tronc ne porte donc plus
aucune compétence : chaque branche a la sienne, et les trois arbres tombent
maintenant à moins de 8 % d'écart (22/23, 28/27,6, 25/27).

`initiative` a gagné un coût au barème au passage : elle décide **quand**
on joue, ce qui vaut cher en positionnement mais ne change aucun chiffre.

### Phase 5 — Interconnexion ✅

| Tâche | Contenu | État |
|---|---|---|
| **T5.1** | Exploration → ressources : une sortie nourrit le royaume | ✅ |
| **T5.2** | Invasions (§ 37) : la menace, le choix, la défense par l'armée | ✅ |
| **T5.3** | Bataille de défense (§ 38) : le royaume devient une carte | ✅ |

### Une sortie nourrit le royaume (T5.1)

C'était le maillon manquant du § 45. Le royaume ne mangeait que ses propres
chantiers, et une expédition ne servait qu'aux héros : les deux moitiés de
la boucle se touchaient par l'or et par rien d'autre.

**La région dicte sa nature.** Les Terres Vertes sont des prairies et des
bosquets : beaucoup de bois, de quoi manger, peu de pierre. Une région de
montagne inversera le tableau, et c'est ce qui donnera une raison d'aller
ailleurs que « les ennemis y sont plus durs ».

**Les ressources vont dans la besace**, donc elles sont en jeu jusqu'au
retour, comme le butin. Le § 29 y gagne un terme de plus : continuer, c'est
aussi risquer le bois qui manquait à la caserne. Et le versement suit la
règle que `resources.json` posait déjà — l'or et les objets à la compagnie,
les ressources au royaume — plutôt que d'en inventer une seconde.

### Les invasions, et ce qu'elles réparent (T5.2)

Jusqu'ici, **partir ne coûtait rien au royaume** : il produisait pendant
l'absence, sans risque. L'invasion le met en jeu, et donne au § 29 une
seconde question — « je rentre pour le butin » devient « je rentre pour le
butin **ou pour défendre** ».

**La menace est un compteur, pas une probabilité.** Un tirage pourrait
épargner un joueur toute une partie, et une mécanique qu'on peut ne jamais
rencontrer n'en est pas une. Elle monte avec l'absence **et avec ce qu'il y
a à prendre** : un hameau n'intéresse personne, un royaume bâti attire.
Bâtir a donc un revers, et le § 50 veut qu'une récompense soit tentante,
pas gratuite.

**Elle retombe à zéro au retour.** Être chez soi protège — sinon la menace
s'accumulerait d'une sortie à l'autre et un royaume avancé vivrait sous
alarme permanente.

**L'assaut laisse deux étapes.** Sans délai, l'invasion serait une nouvelle
et pas un choix. « Rentrer défendre » est un bouton **à part** de
« Rentrer » : les deux referment la sortie, mais l'un ramène des héros à la
bataille et l'autre pas, et confondre les deux ferait perdre un royaume par
méprise.

**Une défense ratée pille, elle ne détruit pas.** Ni bâtiment rasé ni
habitant tué : le § 41 refuse la punition absolue, et voir son château
redescendre d'un niveau après trois heures de jeu ferait fermer
l'application. Le pillage fait mal et se rattrape.

`verify_kingdom` vérifie les trois choses qui ne se voient pas à la lecture
et qui rendraient la mécanique morte ou insupportable :

| | mesuré |
|---|---|
| royaume de départ | première invasion vers l'étape **8** — rarement, et seulement s'il s'attarde |
| royaume au maximum | étape **2** — la mécanique entre dans le jeu à mesure qu'il y a quelque chose à défendre |
| royaume au maximum, seul | défense **231** contre un assaut de **170** : il repousse sans le joueur, comme le § 37 l'exige |
| royaume de départ, seul | défense **15** contre **26** : il perd — mais quatre héros rentrés ajoutent 60, et rentrer compte |

L'outil l'a d'ailleurs corrigé : à son premier réglage, un royaume au
maximum était attaqué **dès la première étape** de chaque sortie, et la
menace ne retombait jamais.

### La bataille de défense : le royaume devient une carte (T5.3)

« Le terrain du royaume devient une carte de combat » est une phrase du
§ 38, pas une image. **Cette carte n'existe dans aucun fichier** : elle se
fabrique à partir de ce que le joueur a bâti. Plus le royaume est avancé,
plus il y a de murs de pierre sur le plateau, et le même assaut ne se joue
donc pas de la même façon. C'est le seul endroit du jeu où les deux moitiés
de la boucle se relient par le **terrain** et pas par des chiffres.

`CombatMap.from_data` a été séparé de `load_map` pour ça. Le reste du
combat ne voit aucune différence — c'est tout l'intérêt de n'avoir qu'un
seul type `CombatMap`.

**On protège l'intendant, pas un bâtiment.** L'IA ne vise que des unités —
ouvert depuis T1.12 — et un objectif « protéger une structure » ne pourrait
donc jamais échouer. L'intendant est un villageois posté derrière tout le
monde, et le protéger veut dire exactement ce que le § 38 demande : tenir
la ligne. C'est la même convention que `vallee_05`, et en inventer une
seconde pour le même manque aurait coûté plus cher que de vivre avec la
première.

**Les bâtiments ne se cassent pas, la palissade oui.** Le § 41 refuse la
punition absolue, et regarder son monastère tomber pendant qu'on le défend
serait exactement ça. La palissade — le mur du § 38, avec ce que le pack
sait dessiner, faute de mur et de porte — donne aux assaillants un verbe
autre que « contourner », et elle laisse une **porte** de trois cases :
sans elle, la carte serait un siège et pas une bataille.

**La bataille a lieu pour de vrai.** Résoudre l'assaut par une comparaison
de nombres alors que le joueur est rentré exprès reviendrait à lui dire
qu'il a gagné pour de faux. `Kingdom.settle_invasion` applique une issue
déjà décidée ; `resolve_invasion` reste le chemin de l'armée seule.

### Quatre défauts, et trois n'auraient jamais échoué un test

1. **Un défaut d'ORDONNANCEMENT, et il annulait la fonctionnalité.**
   Refermer l'expédition déclenche le cycle de production, qui résout un
   assaut imminent par l'armée seule. Le retour était annoncé *après* :
   le joueur rentrait donc défendre une bataille déjà perdue sans lui, et
   le jeu ne montrait rien d'anormal. L'annonce passe maintenant avant.
2. **Les bâtiments étaient dessinés à leur taille native** — 320 pixels
   sur des cases de 64. Ils se recouvraient et débordaient du plateau. Un
   plafond de largeur en cases, dans `view.json`.
3. **Les cinq bâtiments se dessinaient tous en château** : un terrain ne
   porte qu'un décor. Il y a maintenant un terrain par bâtiment.
4. **Le décor `houses` pointait sur un bâtiment que le pack ne dessine
   pas** — le royaume regroupe `house1/2/3` sous un seul bâtiment à trois
   âges. Un décor absent ne plante pas la carte : il pousse une erreur au
   moment de DESSINER, donc loin du problème. `verify_maps` vérifie
   maintenant **tous les décors de terrain** contre la table des assets,
   et **construit la carte de défense** pour la contrôler comme les
   autres — sinon elle serait la seule carte du jeu que personne ne
   vérifie. Il a d'ailleurs immédiatement refusé ses vingt-deux cases de
   placement : vingt-deux cases proposées ne sont pas vingt-deux
   décisions, c'est une décision noyée.

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
