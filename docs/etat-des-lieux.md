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

### Phase 1 — Cœur tactique PA/PM ✅

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

**État au 2026-08-31 : la Phase 1 est terminée.** T1.1 à T1.14 sont
faites et testées. Le combat se joue de bout en bout : placement, timeline
entremêlée, PA/PM, neuf compétences atteignables au doigt, portées et
zones affichées, télégraphe, annulation, décor destructible, et la portée
qui se paie en dégâts.

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

### Phase 6 — Confort ✅

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

### Phase 7 — Les dettes ✅

Pas une phase du § 45 : quatre choses qui traînaient et que rien ne
justifiait plus de laisser traîner.

| Tâche | Contenu | État |
|---|---|---|
| **T7.1** | Sauvegarde en plein combat, et une porte de sortie à tout moment | ✅ |
| **T7.2** | `vallee_09`, le vrai mini-boss des Terres Vertes | ✅ |
| **T7.3** | L'IA frappe ce qui barre la route | ✅ |
| **T7.4** | `reload()` → `clear_cache()` : 472 erreurs par campagne de tests | ✅ |

### Ce que le combat oubliait de sauvegarder (T7.1)

La règle 5 dit « sauvegarde après chaque action significative », et le
combat — l'écran où le joueur passe le plus de temps — n'en écrivait
aucune. Un appel téléphonique pendant un combat de la ronde 6 coûtait le
combat, et l'expédition avec.

**Ce qui est écrit est ce qu'on regrette de perdre** : les positions et les
PV, la timeline (avec sa position dans la ronde), le télégraphe, et le
terrain dans l'état où il est. Pas la carte : le PLATEAU. La bataille de
défense du royaume (§ 38) se fabrique à partir de ce que le joueur a bâti
et ne vit dans aucun fichier — rejouer un identifiant de carte ne la
retrouverait jamais.

**La pile d'annulation n'est PAS sauvegardée, et c'est délibéré.** Elle ne
sert qu'à l'intérieur d'une activation ; une reprise recommence
l'activation en cours, donc il n'y a rien à annuler. La sauvegarder aurait
alourdi le fichier de tout l'historique du combat pour rendre un bouton
grisé.

**Le télégraphe, lui, est sauvegardé.** « Information parfaite, toujours »
ne peut pas s'arrêter à un rechargement : reprendre un combat sans savoir
ce que le Minotaure a annoncé, c'est se faire encorner par une règle qui
promettait le contraire.

**La graine reprend où elle en était.** `CombatRng` sait déjà se
positionner — c'est ce qui fait marcher l'annulation. Recharger sans cela
donnerait un combat qui repart sur d'autres tirages, et le § 4 du CLAUDE.md
(rejouer un bug à l'identique) tomberait au premier rechargement.

**La sortie est à tout moment**, pas seulement entre deux tours : le menu
de pause a un « Sauvegarder et quitter » et l'écran de titre propose
« Reprendre le combat » avant tout le reste. Le jeu écrit aussi tout seul
à chaque fin d'activation — sur mobile, l'application meurt sans prévenir
et personne ne pense à sauvegarder avant.

### Un mini-boss qui n'existait pas (T7.2)

L'étape « mini-boss » du § 28 servait `vallee_07`, une rencontre
ordinaire. Une étape annoncée qui ne tient pas sa promesse est pire qu'une
étape absente.

**`vallee_09` est construite autour d'une seule idée.** Le Minotaure —
210 PV, 6 PA — a l'**Encornade**, qui traverse deux cases EN LIGNE. Se
ranger derrière son Guerrier, la bonne réponse partout ailleurs, devient
ici la mauvaise. C'est tout ce que la carte a à enseigner, et c'est assez.

Quatre éperons de rocher réduisent le passage à une bande centrale de
trois rangées plus deux couloirs d'une case le long des bords — la sortie
de secours existe, elle est longue et exposée. Les bosquets ne bloquent
pas le passage mais la vue, et c'est ce qui fait hésiter entre avancer à
couvert et foncer.

**Elle coûte 29 % des PV, contre 35 % pour le boss.** Un mini-boss plus
dur que le boss aurait inversé la courbe de l'expédition. Une première
version à 180 PV plus un gobelin torche montait à 46 % et mettait deux
héros à terre : le gobelin est reparti, les 210 PV sont restés.

**Le simulateur sous-évalue cette carte, et c'est structurel.** Sa
politique de joueur est triviale — elle ne se met jamais en ligne exprès,
donc elle ne se fait jamais encorner à trois. Le chiffre est un plancher,
pas une mesure.

**Deux gnolls étaient plantés DANS un rocher.** Posés derrière les
éperons, sur des cases infranchissables : aveugles, incapables d'y
revenir, et `verify_maps` disait « 0 problème ». Les cases de placement
des héros étaient contrôlées depuis toujours, celles des ennemis jamais —
l'outil vérifie désormais l'assise des ennemis comme celle des héros, et
qu'il n'y en a pas deux sur la même case.

### L'IA frappe ce qui barre la route (T7.3)

Ouvert depuis T1.12, et c'est la Phase 5 qui l'a rendu criant. L'IA ne
visait que des UNITÉS : un pont ne se cassait jamais tout seul, et un
objectif « protéger une structure » ne pouvait donc pas échouer. Une carte
dont l'objectif ne peut pas être perdu n'est pas une carte. Une palissade
que personne n'attaque n'est pas un mur, c'est une frontière.

**La règle est sobre, et c'est le point.** Un ennemi qui n'a RIEN à
frapper frappe ce qui le sépare de sa cible ; il ne casse jamais un décor
quand il peut cogner quelqu'un. Sans cette sobriété, les assaillants
s'occuperaient du paysage pendant que le joueur les contourne — un défaut
plus visible que celui qu'on corrige. Parmi les obstacles à portée il
choisit le plus proche de sa cible : on ouvre la brèche en face de ce
qu'on veut atteindre.

Les huit cartes de la vallée ne bougent pas d'un point — vérifié au
simulateur : 79 % de PV, 4,8 rondes, avant comme après.

### 472 erreurs par campagne de tests (T7.4)

Chaque table de données offrait un `static func reload()` pour vider son
cache entre deux tests. **`Object` a déjà un `reload()`** — celui d'un
script. GDScript ne signale rien à la compilation ; il appelle
`Script.reload()` et pousse une erreur moteur.

Ce n'était donc pas du bruit : **les caches n'étaient jamais vidés**.
Chaque test lisait la table du test précédent. Tout passait quand même —
ce qui est exactement ce qui rendait le défaut durable. La méthode
s'appelle `clear_cache()`, les 472 erreurs ont disparu, et les 704 tests
passent toujours.

### Ce que la capture d'écran ne savait pas faire

`--press` presse des boutons. Or « Commencer » reste désactivé tant que
l'équipe n'est pas posée, et poser un héros demande de toucher la
grille : **le combat était le seul écran du jeu impossible à
photographier dans le vrai jeu**. Une étape `@x,y` touche maintenant une
case, par `handle_tap()` — la porte même du doigt. C'est ce qui a permis
de constater que le combat rechargé est identique au combat quitté, au
pixel près hors images d'animation.


### Phase 8 — Le cycle jour / nuit ✅

| Tâche | Contenu | État |
|---|---|---|
| **T8.1** | Le § 36 : une expédition est une journée | ✅ |

Il était dans le périmètre annoncé de la Phase 5 — « loot → royaume,
royaume → héros, exploration → ressources, invasions, défense tactique,
cycle jour/nuit » — et c'est le seul de la liste qui n'avait jamais été
écrit.

### Une expédition est une journée

On part au matin, et chaque étape franchie avance l'heure. Aller plus
loin ne veut plus seulement dire « `depth + 1` » : ça veut dire rentrer
plus tard. Le § 29 y gagne sa formulation la plus concrète — **rentrer
avant la nuit, ou pas** — et le § 36 le « véritable intérêt gameplay »
qu'il réclame, puisque le moment cesse d'être un décor pour devenir un
terme de la décision.

**La route montre l'heure au départ.** Chaque pastille prend la couleur
de son moment, donc le joueur voit où la nuit commence avant d'y être.
Un moment qu'on ne découvrirait qu'en arrivant ne se déciderait pas.

**Le calendrier est lu par indice d'étape, et la dernière valeur tient
au-delà.** Une chaîne de six étapes finit sa journée au boss ; une chaîne
de neuf passe aussi le mini-boss dans le noir. La route longue est la
route gourmande, et c'est elle qui paie — faire tourner l'horloge
rendrait la route longue *plus sûre* que la courte, exactement l'inverse
de ce que le § 29 demande.

**Deux moitiés, et il en faut deux.** La nuit ajoute un ennemi et paie
davantage. Livrer la première seule ferait une punition gratuite ; la
seconde seule, un cadeau gratuit. Dans les deux cas le § 29 tombe, et le
cycle n'est plus qu'un filtre de couleur. `verify_world` refuse
désormais une heure qui coûte sans payer.

### Quatre choses que la mesure a refusées

Le cycle a été réglé quatre fois, et chaque fois c'est `simulate_combats`
qui a tranché contre l'intention. **`simulate_combats` joue maintenant
chaque carte deux fois, de jour puis de nuit** — sans cette colonne, on
réglerait à l'estime la moitié des rencontres d'une expédition profonde.

1. **Le renfort apparaissait DANS LE DOS de l'équipe.** La première règle
   était « la case libre la plus loin de la zone de placement ». Sur
   `vallee_05`, dont la zone de placement est au CENTRE de la carte, la
   case la plus lointaine est un coin : le renfort sortait en (0,0),
   derrière les héros. Une règle qui suppose que le joueur se déploie sur
   un bord ne tient pas sur une carte où il se déploie au milieu. Il
   rejoint maintenant le centre de la formation ennemie, et jamais plus
   près du joueur que la bête la plus avancée — le § 39 veut qu'on puisse
   compter ses adversaires avant de placer.
2. **Le gnoll allongeait le combat au lieu de le durcir.** C'était le
   premier renfort choisi, parce qu'il tire. Mais son rôle est
   *tirailleur* : il RECULE quand on l'approche. `vallee_02` passait de
   5,0 à 9,8 rondes les nuits où il sortait — une poursuite, pas une
   bataille, et le § 28 veut trois à huit rondes. **Un renfort doit
   ajouter de la pression, pas de la durée** : le vivier ne prend plus que
   des bêtes qui viennent au contact. Un test le vérifie, parce que rien
   d'autre ne le dirait.
3. **Sur une carte à horloge, la nuit n'est pas une pente, c'est une
   falaise.** `vallee_04` demande trois cases en six rondes. L'ennemi de
   plus allonge le combat d'une demi-ronde, et la réussite tombait de
   100 % à 44 % : on ne perdait pas un peu plus de PV, on ratait
   l'objectif ou pas. La règle qui en sort tient en une ligne — **la
   pression est déjà dans l'horloge** — et une carte à échéance ne reçoit
   plus de renfort.
4. **Le tirage du renfort décalait le hasard du combat.** Tirer dans le
   flux du combat décale tous ses tirages suivants : la même carte, aux
   mêmes graines, ne se jouait plus pareil de jour et de nuit, et l'outil
   comparait deux échantillons en croyant comparer deux réglages. Le
   renfort tire sur un générateur dérivé.

### Ce que la nuit coûte vraiment, et pourquoi c'est peu

**83 % de PV le jour, 82 % la nuit.** Un point. Ce n'est pas ce qu'on
attendait d'un ennemi de plus, et il vaut mieux l'écrire que le maquiller.

L'écart par carte va de **−8 à +10, dans les deux sens** : `vallee_09`
perd huit points et un héros de plus, `vallee_03` en *gagne* dix. Le
mécanisme est lisible — à sept bêtes, l'IA répartit ses coups au lieu de
les concentrer, et des dégâts répartis ne mettent personne à terre.
**« Plus d'ennemis » n'est donc pas mécaniquement « plus dur ».**

L'instrument sous-lit, et c'est structurel : la politique du simulateur
ne protège pas son Archer, n'utilise pas le terrain et ne renonce jamais.
Une bête de plus dans la timeline ne peut pas lui gâcher un plan,
puisqu'elle n'en fait pas.

**La récompense est donc réglée sur ce qui est mesuré, pas sur ce qu'on
espérait :** ×1,2 sur l'or et un cran de rareté, là où le premier jet
donnait ×1,4. Payer ×1,4 un risque mesuré à un point aurait fait de la
nuit un choix évident, et un choix évident n'est pas un choix (§ 55).
**C'est le chiffre à rejuger à l'œil** : sept ennemis au lieu de six, ça
se sent en jouant bien avant que ça se voie dans une moyenne.

### Deux défauts de l'OUTIL, découverts en réglant le cycle

Les deux faussaient des mesures depuis longtemps, et il a fallu ajouter
un ennemi pour qu'ils se voient.

**Le plafond du simulateur était en ACTIVATIONS.** Trente activations,
c'est trois rondes à onze combattants et sept rondes à quatre : le
plafond dépendait donc du nombre d'ennemis. Avec la bête de la nuit, des
combats parfaitement gagnés se sont mis à sortir « perdus » —
`vallee_06` rendait 56 % de victoires avec 91 % de PV et personne à
terre, ce qui ne veut rien dire. On mesurait le plafond de l'outil. Il
est maintenant en rondes, l'unité du jeu.

**Le pilote garait son propre Guerrier sur la case d'objectif.** Il
visait `cells[0]` — la première case déclarée — alors que les cases
d'objectif sont des ALTERNATIVES, pas une file. Sur `vallee_06`,
l'escorté arrivait en (10,3) et passait quinze rondes à viser (11,3)
occupée par son escorte, avec (11,4) libre à côté. Corrigé, `vallee_06`
passe de 89 à 93 % et `vallee_07` de 81 à 95 % — **et l'ordre des cartes
de `regions.json`, qui est une mesure, a dû être refait une quatrième
fois.** `vallee_07` y bondit de la cinquième place à la deuxième, et ce
n'est pas la carte qui a changé.

### L'heure se sauvegarde, elle ne se déduit pas

`Expedition.moment()` la déduit de l'indice d'étape, et c'est juste —
pour une expédition. Mais un combat n'en vient pas toujours d'une : le
banc d'essai et la défense du royaume n'ont aucun indice d'où la tirer.

Le premier jet la déduisait quand même, et la nuit se rechargeait **en
plein jour** : plateau identique, unités identiques, teinte disparue.
Trouvé en capture d'écran, comme d'habitude — aucun test ne l'aurait dit,
puisque le plateau, lui, revenait juste. L'heure est une propriété de CE
combat ; elle va donc dans la sauvegarde, à côté de son identifiant de
carte.

### Ce qu'il faut regarder en jouant

- **La route, au départ.** Voit-on d'un coup d'œil où la nuit commence ?
  Le crépuscule brun et la nuit bleue se distinguent-ils du jour ?
- **Une rencontre de nuit.** Le banc d'essai de l'écran de titre en ouvre
  une directement — sans ce bouton il faudrait gagner cinq combats
  d'abord. Sept ennemis au lieu de six : est-ce que ça se sent ?
- **La teinte.** Les barres de vie et les chiffres restent-ils lisibles ?
  Le HUD n'est volontairement pas teinté ; seul le plateau l'est.
- **La décision.** Arrivé à l'étape 4, avec la nuit visible deux pastilles
  plus loin, est-ce qu'on hésite ? C'est la seule question qui compte.


### Phase 9 — L'interface prend la peau du pack ✅

| Tâche | Contenu | État |
|---|---|---|
| **T9.1** | Le thème sort du code : `data/ui/theme.json`, `UiTheme`, `UiSkin` | ✅ |
| **T9.2** | Jauges et panneaux du pack | ✅ |
| **T9.3** | Boutons teintés — six couleurs à partir de deux images | ✅ |

Gaetan a posé la question qui manquait : « il y avait un pack UI dans
Tiny Swords, non ? Pourquoi ne pas l'exploiter ? »

**Le constat était gênant.** 70 entrées `ui` dans `assets.json`,
contrôlées à chaque exécution par `verify_assets` — et **pas un seul
écran ne les dessinait**. Les seuls appels `AssetTable` de tout le code
d'interface étaient `portrait()` et `tile_size()`. Le projet vérifiait
religieusement des images qu'il ne montrait jamais.

**Et la règle 1 était violée partout.** Sept fichiers d'écran portaient
des `Color(0.13, 0.15, 0.13)` et des tailles de police en dur. Une
couleur est une valeur de ressenti — exactement ce que le § 46 veut
pouvoir régler sans réécrire la logique — et c'était le seul domaine du
jeu où on ne le pouvait pas. Il en reste zéro dans `scenes/`.

### Le pack ne livre pas des images étirables

C'est la découverte qui a tout conditionné, et elle ne se voit qu'en
regardant les fichiers.

**Un bouton du pack est une grille 3×3 de morceaux séparés par 64 px de
VIDE.** Donné tel quel à un `StyleBoxTexture`, il étire les trous en même
temps que le décor : le résultat reste reconnaissable comme un bouton,
mais il est faux — donc facile à ne pas voir. `UiSkin` recompose les neuf
morceaux bord à bord, en mémoire, au démarrage.

La géométrie est régulière : espace de 64, morceau central de 64, coin de
`(largeur − 192) / 2`. Elle est **écrite dans `assets.json` plutôt que
déduite** — une règle déduite dans le code est un nombre dans le code, et
le jour où un asset s'en écarte, c'est la donnée qui doit pouvoir le dire.

**Rien n'est écrit sur le disque.** Le pack n'est pas dans le dépôt
(licence), et un dérivé du pack ne le serait pas davantage : il faudrait
le régénérer à la main sur chaque poste, ce que personne ne ferait.

### Six couleurs à partir de deux images (T9.3)

Le pack ne livre que du bleu et du rouge — une langue « confirmer /
renoncer » qui ne dit rien sur « Royaume » ou « Compagnie ». Gaetan a
tranché pour la teinte plutôt que de s'y cantonner.

**La source est passée en NIVEAUX DE GRIS avant d'être teintée.** Sans
ça, la teinte ne sert à rien : multiplier un bouton bleu par de l'or
donne du vert sale. Désaturé sur la luminance perçue — pas sur la moyenne,
qui écraserait le relief que le pack a dessiné — il prend n'importe quelle
couleur proprement.

Six rôles en sortent : `default`, `primary`, `positive`, `danger`,
`arcane`, `muted`. **Le rôle porte le sens, jamais la couleur** : un écran
demande « danger », et le thème décide de quoi ça a l'air. Le menu de
pause en est la démonstration — vert reprendre, or sauvegarder, acier
options, rouge abandonner, lisible sans lire.

`verify_ui` refuse deux rôles de même couleur : deux rôles identiques ne
sont pas deux rôles.

### La jauge, ou quatre erreurs d'affilée

Elle a coûté plus cher que tout le reste, et chaque étape ne se voyait
qu'à la capture.

1. **Le bois se répétait deux fois en hauteur.** Mes marges de tranches
   s'appliquaient aux quatre côtés ; une jauge ne se découpe
   qu'HORIZONTALEMENT, et des coins de 32 ne tiennent pas dans une barre
   de 22.
2. **Le remplissage était invisible.** Le pack le livre en rouge sombre :
   mesuré, sa luminance plafonne à 0,71 et vaut 0,37 en moyenne. Désaturé
   puis multiplié par un vert de PV, il tombait sous 0,3 — du brun foncé
   dans une auge brun foncé. On remonte donc le plus clair à blanc avant
   de teinter.
3. **La jauge débordait de son auge.** Un `StyleBoxTexture` écarte déjà
   son contenu de ses marges ; le `MarginContainer` que j'avais ajouté
   par-dessus faisait 64 px de chaque côté sur une barre large de 110, et
   la barre tombait à zéro. Deux captures de suite à chercher pourquoi le
   vert ne se voyait pas, avant de penser à mesurer la LARGEUR plutôt que
   la couleur.
4. **Le remplissage n'occupait qu'un tiers de la rainure.** C'est une
   bande de 24 px peinte dans une toile de 64, le reste transparent :
   étirée telle quelle, elle laissait deux tiers de vide. Il faut la
   recadrer sur ce qu'elle dessine.

La rainure du bois est **mesurée et déclarée** dans `assets.json` — 44 px
d'embout de chaque côté sur 192, près du quart de la largeur. Supposée,
elle était fausse.

### Deux pièges de nommage, et le second est le premier

**`Skin` est déjà une classe de Godot** (la peau d'un squelette).
L'autoload se résolvait silencieusement sur la classe native, et le seul
message était « Cannot find member "theme" in base "Skin" ». C'est
exactement `reload()` contre `Script.reload()` de T7.4, deux phases plus
tard : **un nom d'autoload se vérifie avant de l'écrire.** D'où `UiSkin`.

**Une clé `_note` a fait tomber la table des assets.** Tous les fichiers
de données du projet en portent ; `assets.json` n'y échappait que parce
qu'il n'en avait pas encore. `all_entries()` la lisait comme une entrée et
recevait une chaîne là où il attendait un objet. `AssetTable.is_note()`
règle la question pour toutes les familles à la fois.

### Ce qu'il faut regarder en jouant

- **Les six teintes.** Le menu principal et le menu de pause se
  distinguent-ils au coup d'œil, sans lire ? C'est toute la raison d'être
  de T9.3.
- **Le texte sur les boutons.** Il est clair, cerclé de sombre. Tient-il
  sur les six couleurs, ou faut-il en assombrir une ?
- **Les jauges de PV** sur l'écran d'expédition : le vert / ambre / rouge
  se lit-il aussi vite qu'avant, avec le bois autour ?
- **L'arbre de compétences.** Une trentaine de nœuds désactivés :
  lisibles, ou ternes ?


### T9.4 — ce que Tiny Swords ne dessine pas ✅

Gaetan a fourni cinq packs Kenney. **Aucun ne contient d'icône de
compétence** — vérifié en balayant les 717 noms de fichiers : les
`arrow_*` sont des flèches de navigation, pas des projectiles. Ce sont
tous du chrome d'interface : panneaux, bordures, boutons, curseurs.

La question des icônes de sorts reste donc entière, et j'avais d'ailleurs
mal chiffré le manque : ce n'est pas « 12 icônes pour 15 compétences »,
c'est **zéro**. Les 12 icônes du pack sont bois, bûche, or, viande, épées
croisées, bouclier, deux flèches, croix, engrenage, info, note de
musique — des icônes de ressources et de chrome.

**Mais ils comblent un manque réel, et ce n'était pas celui qu'on
cherchait.** Dix `ScrollContainer` répartis sur six écrans rendaient la
barre grise par défaut de Godot au milieu d'une interface en bois, et le
curseur de volume des options avec. Tiny Swords n'a ni barre de
défilement, ni case à cocher, ni poignée : ce n'est pas un oubli de
câblage, c'est un manque du pack.

**La règle qui autorise le mélange, et qui le borne :** on ne mélange que
là où le premier pack ne dessine rien. Un bouton ou un panneau Kenney à
côté d'un bouton Tiny Swords se verrait ; une barre de défilement que
Tiny Swords n'a jamais dessinée ne trahit rien. Le § 16 avait déjà
tranché contre le mélange de deux styles — cette exception ne l'annule
pas, elle en précise la frontière.

Cinq fichiers repris, pas un de plus. Le curseur de volume, lui, reprend
**l'auge des jauges de PV** : c'est le même objet — une valeur dans une
gouttière — et lui donner un second dessin reviendrait à dire qu'il
s'agit d'autre chose.

**`assets/kenney/` EST dans le dépôt**, contrairement à
`assets/tiny_swords/`, et la différence est la licence : CC0 autorise la
redistribution, Pixel Frog l'interdit même modifiée. Un clone neuf dessine
donc déjà ses barres de défilement. C'est le seul endroit du jeu où un
asset manquant est un vrai défaut plutôt qu'un poste mal installé, et un
test le vérifie à ce titre.

### Trois fois le même piège, sous trois formes

Chacune faisait disparaître un widget **sans un mot**, et chacune n'a été
trouvée qu'en mesurant la capture au lieu de la regarder.

1. **La barre de défilement a disparu.** Godot déduit l'épaisseur d'un
   `ScrollBar` de la taille minimale de son style ; un `StyleBoxFlat` nu
   en a une nulle. Mesuré : 68 de luminosité dans la colonne avant, 16
   après — c'est-à-dire le fond.
2. **Le rail du curseur ne se voyait pas.** Même mécanisme : Godot dessine
   le rail à la hauteur minimale du style, nulle sans marges verticales.
   Le bois était bien posé, sur zéro pixel de haut.
3. **Une barre de défilement se découpe EN HAUTEUR**, pas en largeur :
   c'est une pastille verticale dont seuls les bouts sont arrondis.
   L'inverse exact d'une jauge, et le même piège si on ne l'écrit pas.


### Phase 10 — Les consommables ✅

| Tâche | Contenu | État |
|---|---|---|
| **T10.1** | Le soin, les potions, le sac commun | ✅ |
| **T10.2** | Le butin et le marchand distribuent des potions | ✅ |

Le § 44 les liste dans le butin du MVP — « or, quelques armes, armures,
**potions** » — et le § 48 leur donne un bouton dans la barre d'action :
« ⚔️ Attaque 🔥 Sort 🧪 Item ». Ni l'un ni l'autre n'existait. C'est le
dernier trou franc de la liste du MVP.

### `KIND_HEAL` était déclaré depuis le premier jour et jamais écrit

`Ability` connaissait la constante ; `resolve_ability` ne la lisait pas.
Une compétence de soin aurait donc **silencieusement infligé des dégâts
aux siens**. Personne ne s'en était aperçu parce qu'aucune compétence ne
l'utilisait — c'est exactement le genre de défaut qui attend qu'on
s'appuie dessus.

Un soin vise les siens ET lui-même : c'est le seul endroit du moteur où
le camp change de sens. `friendly_fire` dit « mes alliés encaissent
aussi » ; un soin dit « il n'y a qu'eux ». Il ne relève pas un
personnage à terre — le § 25 réserve la relève à l'expédition, et une
potion qui remet debout retirerait tout son poids à la mise à terre.

### Une potion EST une compétence, plus un stock

Le moteur sait déjà porter un coût en PA, une portée, une zone et un
effet. Leur donner un second système de résolution aurait doublé sa
surface pour rien, ce que le § 46 interdit en toutes lettres. Une potion
est donc une entrée d'`abilities.json` de classe `consumable`, plus un
compteur.

Une seule ligne les distingue : **une potion n'appartient à personne**.
`is_available_to` saute la vérification de propriété pour elles, parce
qu'elles sont dans le sac de l'équipe et que n'importe quel héros peut
les prendre.

**Et elle ne monte à aucune statistique.** Une bombe lancée par le Mage
et par le Guerrier fait les mêmes dégâts : sa puissance vient de l'objet.
Sinon il faudrait la réserver au personnage qui la valorise le mieux, et
le sac commun n'aurait plus de sens. L'invariant « toute compétence qui
fait des dégâts monte à une statistique » a donc gagné son exception, et
`verify_items` vérifie l'inverse pour les potions.

### Le sac vit dans le MOTEUR, et c'est l'annulation qui l'impose

« Rien n'est irréversible avant la fin de l'activation » vaut aussi pour
une potion bue. Si le compteur vivait sur `Company`, l'instantané
d'annulation ne le verrait pas et la potion serait perdue pour de bon —
**le seul geste du jeu qu'on ne pourrait pas reprendre**, et précisément
celui qu'on veut pouvoir reprendre.

**L'ORDRE EST TOUT, et je l'ai eu à l'envers.** Le premier jet retirait
la potion AVANT d'appeler `use_ability`. Or c'est `use_ability` qui empile
l'instantané, et cet instantané est l'état où l'on REVIENT : il doit
montrer le sac encore plein. Annuler rendait le soin et gardait la potion
bue. Le test qui l'a attrapé était écrit avant le code.

Bénéfice second de l'ordre correct : une compétence qui refuse (cible
hors de portée) n'a rien à remettre dans le sac.

### Trois verbes, pas trois puissances

- **Élixir de réparation** — 45 PV, 2 PA, sur soi ou un voisin.
- **Philtre de hâte** — 3 PM par-dessus le maximum, 2 PA. La seule
  contre-mesure au Gel, et la porte de sortie quand on s'est trop avancé.
- **Bombe incendiaire** — 28 dégâts en croix à 2–4 cases, 3 PA. Elle ne
  dépend de personne, donc l'Archer peut ouvrir une mêlée.

Trois potions de soin d'intensités différentes n'auraient fait qu'un seul
choix déguisé en trois.

**Le barème remplace la mesure**, comme pour l'équipement : on ne simule
pas mille combats pour un flacon. L'unité est le point de vie épargné, à
1,6 pièce d'or le point, et `verify_items` refuse plus de 20 % d'écart.
La bombe est évaluée sur **deux** cibles touchées et non cinq : la croix
en atteint jusqu'à cinq, mais un joueur qui en aligne cinq a déjà gagné.
On paie l'ordinaire, pas le meilleur cas.

### Ce que ça change pour le § 29, et ce que la mesure ne voit pas

Une réserve **finie** traverse toute l'expédition : chaque potion bue est
une potion que le boss n'aura pas. « Je rentre ou je continue ? » gagne un
troisième terme après les PV et la besace — et c'est le seul des trois sur
lequel le joueur décide au coup par coup au lieu de subir.

**`simulate_combats` ne boit pas.** Sa politique triviale ignore le sac,
donc ses chiffres sont inchangés (81 % de PV, 4,7 rondes) et sont
désormais un plancher plus bas encore qu'avant : un vrai joueur dispose
d'une ressource que le pilote n'utilise jamais. Le mesurer demanderait
d'apprendre au pilote quand boire, c'est-à-dire d'écrire la stratégie
qu'on veut justement laisser au joueur.

### T10.2 — le sac se renouvelle ✅

**Une potion qu'on ne peut pas obtenir n'est pas une mécanique, c'est une
déclaration.** Pendant toute la Phase 10, `consumables.json` déclarait
trois potions, le combat savait les boire, la barre d'action les
affichait — et rien au monde n'en distribuait une seule. Le sac de départ
tenait lieu d'économie. Une réserve qui ne se renouvelle pas est un
compte à rebours, et le troisième terme de « je rentre ou je
continue ? » (§ 29) disparaît avec elle.

Aucun test unitaire ne l'aurait dit : chaque moitié était juste.
`verify_world` le refuse désormais — c'est le genre de faute que seul un
contrôle de bout en bout attrape.

### Un troisième fil de butin, pas une part du premier

Mêlées au sac de l'équipement, les potions lui auraient pris sa place.
L'économie de l'équipement est **mesurée au point de rareté**, et une
consommable n'est pas un remplacement acceptable pour un objet qu'on
garde : le joueur qui voit une fiole là où il espérait une épée se sent
volé. Le tirage est donc séparé, et le taux d'équipement n'a pas bougé —
un test le vérifie.

Elles tombent **plus souvent** que l'équipement (une victoire sur deux
contre 0,7 tirage) : une potion se boit et disparaît, il en faut un flux.
Et **une défaite n'en rend pas** : le § 41 refuse la punition absolue, ce
qui explique que l'équipement tombe quand même, mais une équipe qui vient
de perdre a déjà vidé son sac — lui rendre une fiole effacerait la
dépense.

### Elles ne passent pas par la besace

Une potion trouvée rejoint **le sac de la compagnie tout de suite**, donc
elle est buvable à l'étape suivante. Une fiole qui attendrait le retour
au royaume ne serait un ravitaillement pour personne. C'est le même
raisonnement que l'or d'un évènement, qui va déjà à la bourse plutôt qu'à
la besace : ce qu'on dépense en chemin n'est pas un butin qu'une déroute
pourrait reprendre.

### L'étal réserve deux places

Pas un tirage mêlé aux trois autres : le marchand est le seul endroit où
le joueur **choisit** ce qu'il emporte, et un étal qui ne proposerait des
potions qu'une fois sur trois ne serait pas un ravitaillement. Le butin,
lui, décide à sa place — c'est toute la différence entre trouver et
acheter. Et c'est ce qui donne enfin à l'or trouvé un usage **en cours de
route**.

Deux leçons prises en les ratant :

- **Le coup de pouce de rareté du marchand ne s'applique pas aux
  potions.** Il n'y en a que dans deux raretés : relever le plancher d'un
  cran ne laissait qu'une fiole possible, et l'étal proposait deux fois
  la même. L'avantage du marchand sur les potions n'est pas d'en vendre
  de meilleures, c'est d'en vendre tout court.
- **L'échelle de rareté se réduit à ce qu'une famille possède.** Sans ça,
  au troisième palier de profondeur le plancher passait au-dessus de la
  meilleure potion et le fil s'arrêtait : plus on s'enfonce, moins on se
  ravitaille — exactement l'inverse du § 29.

### Le sac se lit avant le combat, pas pendant

Le nombre de potions restantes s'affiche à côté de la besace sur l'écran
d'expédition. Le § 29 fait de « rentrer ou continuer » une question à
trois termes — les PV, la besace, et ce qu'il reste à boire — et le
troisième ne se lisait qu'une fois le combat commencé, c'est-à-dire trop
tard.

### Ce qu'il faut regarder en jouant

- **La barre d'action.** Les trois potions sont en violet, les
  compétences en acier : la différence se voit-elle avant de lire ? Une
  potion confondue avec un sort gratuit, c'est la dernière du sac brûlée
  par distraction.
- **Le compte `×2`.** Suffit-il à faire hésiter, ou faut-il le montrer
  plus gros ?
- **Le Philtre de hâte.** 2 PA pour 3 PM : trop cher, ou juste ?
  C'est le chiffre le plus estimé des trois — les deux autres se
  raccrochent à des PV, celui-là à une intuition.


### T9.5 — les icônes de compétences ✅

La question ouverte depuis le début de la Phase 9 : **la barre d'action
du § 48 était en texte nu**, parce qu'aucun pack n'avait de glyphe de
sort. Gaetan a fourni trois paquets de plus, et la réponse est enfin
franche.

| Pack | Verdict |
|---|---|
| **game-icons.net** — 4133 SVG, CC BY 3.0 | **Les quinze y sont.** Le seul qui les ait toutes. |
| **Kenney Board Game Icons** — 255 PNG 64 px, CC0 | Grille parfaite, mais thématique jeu de plateau : cartes, dés, pions. Quatre glyphes utilisables sur quinze. |
| **Kenney Platformer Art Pixel** — 900 tuiles 21 px, CC0 | Hors sujet : un side-scroller cartoon, en 21 px, qui ne cohabite avec rien ici. |

### Mêler du vectoriel au pixel art, et à quelle condition

C'est le seul endroit du jeu où on le fait, et ça ne tient qu'à **une
ligne de code** : le seuil d'alpha.

Une silhouette vectorielle est LISSE. Rendue à 32 px et posée à côté d'un
sprite de 64 px en filtrage Nearest, ça se voit immédiatement — le bord
dégradé trahit l'origine. En jetant ce dégradé (alpha binaire au-dessus
de 0,5), le glyphe redevient un **masque franc** : du pixel, comme le
reste.

L'ordre compte : on réduit d'abord en **Lanczos** pour garder la forme,
PUIS on seuille. Réduire en Nearest depuis 512 px hacherait le trait
(un pixel sur huit) avant qu'on ait rien à seuiller.

Le glyphe est blanc à la source et se **repeint en blanc franc** au
passage : sans ça, les pixels à demi couverts gardent leur gris et le
seuil ne sert à rien.

### Le fond noir, et pourquoi il n'apparaît nulle part

Chaque SVG de game-icons.net est un **carré noir plein suivi du tracé
blanc**. Le laisser aurait posé un carré noir sur chaque bouton. Il est
retiré à l'import — c'est la seule modification, et CC BY l'autorise
expressément.

### La première obligation de licence du projet

`assets/gameicons/` est **en CC BY 3.0** : redistribuable, donc versionné,
mais **l'attribution est obligatoire** — pas une politesse comme pour les
packs CC0. Trois auteurs : Lorc (14 icônes), Delapouite (3), Caro Asercion
(1). Ils sont nommés dans `CREDITS.md`, et si le jeu sortait un jour de
son cadre personnel, la mention devrait apparaître **à l'écran**.

Le projet a donc maintenant trois régimes d'assets, et il faut les
distinguer : Tiny Swords (redistribution interdite → `.gitignore`),
Kenney (CC0 → versionné, aucune obligation), game-icons.net (CC BY →
versionné, attribution due).

### Un accesseur qui manquait

`AssetTable.has()` répond « cette entrée existe-t-elle ? » sans pousser
d'erreur, là où `sprite()` en pousse une. La différence compte : **une
compétence sans glyphe reste en texte**, ce qui est une réponse valable
et pas un défaut. Sans cet accesseur, chaque compétence ennemie affichée
aurait crié dans la console à chaque image.

`verify_ui` et un test vérifient l'inverse pour le joueur : **chaque
compétence de héros ou de potion DOIT avoir son glyphe.** Une seule qui
manque et la barre mélange icônes et texte nu, ce qui se lit plus mal que
du texte partout.


### T9.6 — l'écran de combat, pas seulement ses boutons ✅

Gaetan a mis trois jeux à côté d'une capture et posé la question : « la
l'interface te gêne pas ? Je trouve ça très fade. » Il avait raison, et le
diagnostic était précis : **j'avais habillé les BOUTONS, pas l'ÉCRAN.**

Les trois références — un tactique low-poly, un gacha mobile, Dofus —
n'ont pas grand-chose en commun sauf une seule chose, et c'est exactement
celle qui manquait : **aucune zone d'interface ne touche le fond.** Tout
repose sur un panneau, tout porte un portrait, tout a un cadre. Chez moi
le plateau flottait dans du noir et la liste des héros était du texte nu.

**Ce qui a changé :**

- **Les héros sont des cartes**, sur du papier, avec leur portrait, leur
  nom et une jauge de bois. C'était `1 Guerrier 120/120` en texte. Un
  visage se reconnaît plus vite qu'une ligne, et c'est ce qu'on lit vingt
  fois par combat.
- **La timeline porte des visages.** Le § 16 demande de lire « qui joue
  maintenant » d'un coup d'œil ; un portrait encadré s'y prête mieux
  qu'un chiffre dans une pastille. Cadre or pour l'actif, acier pour les
  héros, rouge pour les ennemis.
- **La barre d'action repose sur la table de bois du pack.** Thématiquement
  c'est l'endroit où l'on pose ses outils ; visuellement, c'est ce qui
  arrête les boutons de flotter.
- **L'objectif est sur du parchemin**, dernière ligne qui touchait
  encore le fond.

**Les 25 avatars du pack dormaient dans la table depuis toujours**,
employés par le seul écran de compagnie. C'est en combat qu'un visage sert
le plus.

**Le pack n'a pas de portrait d'ennemi** — 25 avatars humains et rien
d'autre. L'initiale de l'espèce tient donc le rôle sur le cadre rouge :
mieux vaut un cadre cohérent avec une lettre qu'un visage emprunté à
quelqu'un d'autre.

### Le même piège, quatre fois : les marges d'un StyleBox

Un `StyleBoxTexture` **écarte son contenu de ses marges de tranches**.
C'est logique et c'est ce qu'on veut — sauf que ces marges valent 32 px à
l'échelle 2, et que rien ne le signale.

1. **Les cartes de héros gonflaient de 64 px chacune.** Quatre cartes
   prenaient 256 px de trop et **chassaient la barre d'action hors de
   l'écran**. Godot rogne en silence.
2. **La table de bois refusait de mesurer moins de 256 px de haut** : elle
   est en 448 px avec des coins de 128, donc 128 minimum à l'échelle 2.
   Échelle 4, et le bandeau tient.
3. **Le portrait d'un badge de timeline disparaissait** dans un
   `PanelContainer` de 44 px avec 32 px de marge de chaque côté. Un
   `Panel` avec le portrait ancré par-dessus, et le cadre redevient un
   cadre.
4. **La ligne d'état chevauchait le bord du plateau de bois.**

`UiSkin.panel_style(role, pad)` prend maintenant un encart explicite.
C'est le même défaut que la jauge de T9.2 — un `MarginContainer` ajouté
par-dessus un style qui écartait déjà — et il a fallu se le reprendre
quatre fois pour aller le mettre à sa place.

### Un conteneur rabote ses DERNIERS enfants, sans rien dire

La ronde et le bouton de pause ont **purement disparu du bandeau** dès que
l'objectif a pris un panneau et que les badges ont grossi. Pas d'erreur,
pas de trace : quand la somme des tailles minimales d'un
`HBoxContainer` dépasse sa largeur, il rabote, et ce sont les derniers
qui trinquent.

Deux tentatives de bornage n'y ont rien fait. **La timeline et le coin
sont donc ANCRÉS sur le `CanvasLayer`, hors du flux** — et pas dans le
`MarginContainer`, parce qu'un `Container` écrase les ancrages de ses
enfants, c'est sa raison d'être. Trois zones ancrées valent mieux que
trois zones qui se disputent une largeur.

Ce n'est pas un détail cosmétique : sur mobile, un combat dont on ne peut
pas sortir est le pire des défauts (§ T6.1), et le bouton de pause était
invisible.

### Ce qui reste

**L'écran d'expédition et celui de compagnie n'ont pas eu le même
traitement.** Ils ont le thème, les boutons et les jauges, mais pas les
cartes à portrait — leurs listes de héros sont encore du texte au-dessus
d'une jauge. C'est le même travail, appliqué ailleurs.


### T9.7 — sombre et or, sur tous les écrans ✅

Gaetan a fourni une maquette : « ça reste léger… j'aimerais plutôt
quelque chose dans ce style, mais avec nos portraits et avec les éléments
que tu as en stock ». La maquette dit une chose que T9.6 n'avait pas
comprise — **le parchemin clair n'était pas le bon matériau.**

Le modèle est **sombre à liseré doré** : des panneaux presque noirs, un
trait d'or ouvragé sur chaque bord, des en-têtes en petites capitales
dorées. Un papier clair teinté en sombre devient une tache boueuse ; il
fallait autre chose.

**Cet autre chose dormait dans un pack jamais ouvert.** `kenney_fantasyuiborders`
— 302 fichiers, arrivé avec les autres, jamais regardé. Ce sont
exactement les cadres de la maquette : des 9-tranches de 48 px,
monochromes, avec des ornements de coin.

### Composer un cadre et un fond en une seule image

Un `StyleBox` ne s'empile pas : on ne peut pas poser un cadre sur un
aplat. Il faut donc **composer la texture**.

Les cadres de Kenney sont un tracé **blanc pleinement opaque** sur un
centre à demi transparent. On ne garde que les pixels dont l'alpha
dépasse 0,9 — le tracé — on les repeint en or, et on pose le tout sur un
aplat sombre. Le centre reste uniforme, ce qui est la condition pour
qu'un 9-tranches s'étire proprement.

**Le seuil haut est volontaire :** prendre le centre à demi transparent
pour du tracé remplirait le panneau d'or.

### Le rôle passe du fond au TRAIT

Les six teintes de bouton de T9.3 étaient justes tant que l'interface
était claire. Sur des panneaux sombres, un bouton en acier plein faisait
**deux matières pour une seule interface**.

Le rôle porte donc maintenant le sens dans la **couleur du liseré** :
l'or pour l'action principale, le vert pour le royaume, la prune pour les
potions, le rouge pour l'abandon. `framed_style` accepte indifféremment
une couleur de la palette ou un rôle de bouton — un écran demande
toujours « danger », jamais « rouge ».

### Ce que la maquette ajoutait et que le jeu n'avait pas

**Un panneau de détail de compétence.** Le § 48 veut que le joueur sache
ce qu'une action coûte ET ce qu'elle fait avant de la choisir. Le coût
était sur le bouton ; les dégâts, la portée et l'effet ne se lisaient
nulle part, sinon en lançant la compétence. Le panneau de droite les
montre.

**Un grand portrait du personnage actif**, en bas à gauche. La barre du
bas parle d'UN personnage, et rien ne le disait à part une ligne de texte.

**Des en-têtes en petites capitales dorées** sur chaque zone. C'est ce
qui, dans la maquette, dit à quoi sert un panneau avant qu'on lise son
contenu. Sans eux, un panneau n'est qu'une boîte.

### Une carte de héros, trois écrans

`UiSkin.hero_card()` est partagée par le combat, l'expédition et la
compagnie. C'est la même information partout — un visage, un nom, une
jauge — et **trois dessins pour une même chose est précisément ce qui
donnait à l'ensemble son air de brouillon** : chaque écran avait inventé
sa façon d'afficher un héros.

Les pastilles de route de l'expédition prennent le même cadre, et
gardent l'heure du § 36 dans la couleur de leur fond : gris-vert le jour,
brun au crépuscule, bleu la nuit.

### Deux tests qui vérifiaient la forme au lieu du fond

`test_la_route_montre_toutes_les_etapes` lisait `badges[i].get_child(0)`
en supposant un `Label` ; une pastille est devenue un panneau encadré qui
empile plusieurs enfants. Et le test des PV portés cherchait `"7 / 72"`
là où la carte partagée écrit `"7/72"`.

Ils cherchent désormais le texte **dans l'arbre**, à n'importe quelle
profondeur. La profondeur d'une carte est un détail d'habillage : un test
qui la fixe casse au premier changement de style sans que rien ne soit
faux.


### T9.8 — lisible, plus grand, et un fond qui a de la matière ✅

Trois reproches en une phrase : « certains textes sont illisibles, et
l'écran de jeu reste trop petit, et j'aimerais apporter de la texture sur
le fond noir pour le rendre moins fade ». Trois causes distinctes.

### Le contour était devenu clair sur clair

Chaque libellé du HUD portait un contour de 6 px tiré de `ink` — un
contour SOMBRE, du temps où le fond était du parchemin. `ink` est passé
au crème avec T9.7, et personne n'a rouvert `_label()` : le texte clair
se retrouvait cerclé de clair. Sur une police pixel, les glyphes se
rejoignent et le mot devient une tache.

**Le contour est retiré partout** — boutons et libellés, thème global
compris. Il ne reste que là où il sert : `_outlined()`, pour le texte
posé SUR LE PLATEAU, où le fond n'est pas maîtrisé.

### La zone sûre ignorait les panneaux latéraux

`safe_area()` rendait toute la largeur de la fenêtre moins les deux
bandeaux. Depuis T9.7 il y a une colonne de cartes à gauche et un panneau
de détail à droite : le plateau était cadré sur une zone dont un tiers
était couvert. Il est maintenant borné à gauche et à droite, et la caméra
recentre sur **les deux axes** — jusqu'ici seul le vertical était corrigé,
parce que jusqu'ici seul le vertical était borné.

### Un aplat noir n'est pas un fond

Le motif de Kenney se carrelle derrière tous les écrans. Deux pièges,
tous deux silencieux, et tous deux trouvés à la mesure :

- **Le motif est NOIR à la source.** Kenney le livre comme une ombre à
  poser sur du clair. Teinté d'or par-dessus un fond presque noir, il
  n'éclaircissait rien : mesuré, le fond passait de (14,12,10) à
  (12,11,9) — il s'assombrissait. `UiSkin` le REPEINT en blanc en gardant
  son alpha, comme le remplissage d'une jauge et comme un glyphe. **Une
  source ne se teinte que si elle est claire** ; c'est la troisième fois
  que le projet se cogne à cette règle.
- **Deux alphas se multiplient.** Le fichier plafonne à 51/255 et la
  teinte du thème vient par-dessus.

**La règle qui fixe la valeur, et elle vaut au-delà du motif : la crête
du fond reste SOUS le panneau le plus sombre.** Montée trop haut, elle
atteignait 32 quand `panel_deep` valait 18 — le fond devenait plus clair
que ce qu'on pose dessus, et un nœud de compétence désactivé s'y noyait.
`verify_ui` et un test le vérifient maintenant dans les deux sens : un
motif invisible est un défaut, un motif qui passe devant aussi.

### Six écrans portaient déjà un fond, et il recouvrait le nouveau

`_lay_backdrop()` insérait le motif à l'indice 0 — donc DERRIÈRE le
`Background` que chaque `.tscn` dessine déjà. L'écran de titre est resté
noir uni sans qu'aucune erreur ne le dise : **un nœud qui en cache un
autre ne se plaint pas.** `UiSkin.lay_backdrop()` remplace les six
copies : si l'écran a déjà un fond, on le repeint et on lui accroche le
motif ; sinon seulement on en insère un.


### T9.9 — l'île dans la mer ✅

Gaetan : « la map de jeu ne pourrait pas être étirée à l'horizontal ? […]
on ajouterait 2 carrés d'eau à droite et 2 carrés d'eau à gauche en
décor, ce qui augmente l'écran de jeu sans toucher réellement à la map ».

**L'intuition est juste, mais l'arithmétique impose de la faire hors du
cadrage.** Ajouter deux colonnes à ce que la caméra cadre ferait
RÉTRÉCIR le plateau de 17 % :

| | span | zone sûre | rapport |
|---|---|---|---|
| largeur | 12 × 64 = 768 | 720 | 0,94 |
| hauteur | 9 × 64 = 576 | 490 | **0,85** ← contraint |

C'est la **hauteur** qui contraint le cadrage. Passer à 16 colonnes porte
le span horizontal à 1024, le rapport en largeur tombe à 0,70, et c'est
lui qui contraint désormais : les cases passeraient de 54 px à 45.

**Le décor va donc en dehors de ce que la caméra cadre.** La grille reste
12 × 9, `frame_board` ne connaît que la grille, le clamp de déplacement
ne bouge pas — et l'eau déborde de 16 cases sur les quatre côtés, assez
pour atteindre le bord de l'écran au zoom minimal, caméra poussée au bout
de son clamp. Ça ne coûte rien : c'est **un** appel de dessin carrelé,
quelle que soit sa taille.

Rien à inventer côté rendu : `_is_land` compte déjà le hors-grille comme
de l'eau pour dessiner les rives, et l'eau était déjà le fond du plateau.
**Le plateau était déjà une île** — il lui manquait sa mer.

### Deux bandes, pas un océan

Premier essai : l'eau débordait des **quatre** côtés, sur seize cases.
Verdict de Gaetan : « ça fait trop d'eau, le fond est entièrement bleu ».
Il avait raison — le fond sombre à motif de T9.8 avait purement disparu,
et la mer était devenue le fond au lieu d'entourer l'île.

**La mer ne déborde donc qu'à l'horizontale**, sur trois cases, et sa
hauteur est exactement celle de la grille. Ce qui se voit, ce sont les
deux bandes entre les panneaux et l'île ; le reste de l'écran garde son
fond sombre.

**Et elle ne peut pas simplement s'arrêter sous les panneaux**, parce
qu'ils ne descendent pas jusqu'en bas de l'écran : sous eux, le turquoise
redevenait visible jusqu'au bord de la fenêtre. Les deux bords extérieurs
se fondent donc vers **la couleur du fond de l'interface** — pas vers une
eau profonde inventée : la cible est exactement `backdrop`, lue dans
`UiTheme`, et la recopier dans `view.json` garantirait qu'un jour les deux
ne disent plus la même chose. Une case d'eau franche contre l'île, deux
d'extinction.

### Les panneaux latéraux ont rétréci pour lui faire place

`card_width` et `detail_width` passent de 250 à 200. **Le plateau ne
bouge pas d'un pixel** : il est centré dans la zone sûre, et le calcul se
simplifie — l'écart entre le bord d'un panneau et le bord du plateau vaut
`295,5 − largeur`, quelle que soit cette largeur. À 250 il valait 45 px,
soit moins d'une case ; à 200 il en vaut 95, soit 1,75 case. C'est la
place de l'eau.

Rien n'a débordé dans les panneaux rétrécis : la carte de héros garde son
portrait de 44 px et ses deux libellés, le panneau de détail garde ses
quatre lignes.

### Un banc d'essai qui mentait sur ce qu'il ouvre

Le bouton de nuit annonçait « La route basse » et ouvrait `vallee_02`,
qui est **le gué de Cendre**. Le libellé sort désormais de la carte
elle-même. Un banc d'essai qui ment fait perdre plus de temps qu'il n'en
fait gagner.

### À juger à l'œil

L'équilibrage est intact — c'est du décor, `simulate_combats` rend les
mêmes chiffres. Ce qui reste à juger : **la largeur des deux bandes**
(`sea_side_tiles`, `sea_fade_tiles` dans `data/combat/view.json`) et
**celle des panneaux** (`card_width`, `detail_width` dans
`data/ui/theme.json`), qui sont les deux faces du même réglage : élargir
l'eau, c'est rétrécir les panneaux, et le plateau ne bouge dans aucun des
deux cas.


### T9.10 — la mer vivante ✅

« C'est déjà mieux, mais ça fait moins naturel. » Ce qui n'était pas
naturel, c'était l'aplat : deux bandes de turquoise uni, tranchées net
contre le vert de l'île.

**Ce qu'il fallait dormait dans le pack depuis le premier jour.**

- **`Water Foam`** — une plaque d'écume animée en 16 images, de 192 px
  pour une case de 64. Une note de T1.15 la disait « inutilisable, posée
  case par case elle donne des blocs de glace », et c'était vrai : elle
  n'est pas une tuile d'eau. Elle est faite pour être posée **SOUS** une
  case de TERRE. Centrée, elle déborde d'une trentaine de pixels, la
  terre dessinée par-dessus n'en laisse voir que ce débord, et les
  plaques des cases voisines se recouvrent — le rivage est continu sans
  qu'on ait à choisir un morceau par orientation, ce que le pack ne
  fournit pas.
- **`Water Rocks`** — quatre tailles de rocher, chacune animée avec son
  anneau d'écume qui bat. Ils vont dans les deux bandes.

### Où tombent les rochers : une fonction, pas un tirage

La règle 4 veut une graine, mais **le décor n'a pas à en consommer une**
— et surtout pas celle du combat, qu'il décalerait. C'est exactement la
leçon du renfort de nuit (T8.1). La position des rochers est donc une
**fonction** du plateau et de la case : reproductible par construction,
et différente d'une carte à l'autre parce que le terrain change.

Ils sont **décalés dans leur case**, sinon la bande trahit la grille :
des rochers alignés au pixel près sur des colonnes ne ressemblent à rien
de naturel. Et ils sont dessinés **avant** le fondu, pour s'éteindre avec
l'eau qui les porte au lieu de flotter, nets, sur du noir.

### Le liseré de rivage, trouvé en le ratant

Premier essai avec l'écume : l'île avait un **contour blanc** au lieu
d'un rivage. La mer ne débordait qu'à l'horizontale, donc en haut et en
bas la plaque d'écume se posait à même le fond sombre.

D'où trois quarts de case d'eau au-dessus et au-dessous — **l'épaisseur
du rivage, pas une bande.** Et tranchée net, cette épaisseur faisait une
barre turquoise au-dessus de l'île : le fondu porte donc maintenant sur
**les quatre côtés**, ce qui l'éteint au lieu de la couper.

### L'animation ne tourne pas en headless

`queue_redraw()` dans un `_process` y empile une file que rien ne vide,
et le moteur tombe sur un signal 11 dont la trace ne désigne personne. Le
projet s'est déjà cogné à ça pour les jauges. Le nœud ne redessine par
ailleurs **que quand l'image change** — dix fois par seconde, le rythme
du pack, pas soixante.

### Encore en réserve dans le pack

Huit nuages de 576 × 256 et une gerbe d'eau. Les nuages passeraient bien
au-dessus de la mer, mais pas au-dessus du plateau : le § 48 veut la
lisibilité avant le spectacle, et une ombre qui traverse une case en
change la couleur. À faire quand il y aura de quoi les borner.


### Phase 11 — la bêta 🚧

Le moteur est fini ; c'est la coquille autour qui manque. **Chaque
constat ci-dessous vient d'une commande lancée dans le dépôt, pas d'un
souvenir.**

| Tâche | Contenu | Constat vérifié | État |
|---|---|---|---|
| **T11.1** | Le mettre sur le téléphone | `export_presets.cfg` absent, `installation.md` § 4 à 6 jamais faits | ⬜ |
| **T11.2** | Brancher le son | 473 fichiers, 30 entrées déclarées, **0 appel** à `AudioManager` depuis le jeu | ⬜ |
| **T11.3** | Un vrai écran de titre | `BOOT_TEMPORARY` : « Écran de test provisoire — le vrai menu viendra plus tard » | ⬜ |
| **T11.4** | Une fin à la campagne | 5 régions sur 6 sont des coquilles vides, rien n'écrit jamais `unlocked` | ⬜ |
| **T11.5** | Apprendre à jouer | aucun tutoriel, aucune aide, aucune première partie guidée | ⬜ |

**L'ordre est celui-là et il se justifie.** Le téléphone d'abord parce que
tout le reste se juge dessus, et parce que deux questions n'ont de réponse
que sur l'appareil — la taille réelle des cibles tactiles et les 60 images
par seconde. Le son ensuite : c'est le meilleur rapport effet/coût de la
liste, la plomberie est entièrement faite et il ne manque que les appels.
Le titre et la fin referment la coquille. **Le tutoriel passe en dernier
volontairement** : écrit avant les quatre autres, il enseignerait le jeu
tel qu'il est aujourd'hui et serait à refaire.

### T11.4 — les deux sorties, et pourquoi je conseille la seconde

- **(a) Bâtir l'acte 2.** Nouveau biome — le tileset a cinq variantes de
  couleur, gratuites —, nouveaux ennemis, nouvelles cartes. C'est une
  phase de contenu, trois à cinq séances.
- **(b) Assumer l'acte 1 comme le périmètre de la bêta** et lui donner une
  vraie fin : battre le boss clôt la campagne, montre ce que le royaume
  est devenu, propose de recommencer. Une séance.

Faire (b) ne gâche pas (a) : **le mécanisme de déverrouillage manque dans
les deux cas**, et c'est lui qu'on écrit.

### Ce qui se voit sans bloquer

- **Le rail de défilement flotte** sur un panneau vide (expédition,
  compagnie). C'est le mode « toujours visible » qui évite l'effondrement
  du moteur en headless. Purement cosmétique.
- **Pas d'écran de récompense.** Une bannière, deux secondes, fini. Le
  butin d'une rencontre mérite un temps d'arrêt : c'est la moitié de la
  raison de continuer.
- **L'usure longue n'a jamais été mesurée.** L'instrument mesure une
  expédition ; une campagne entière, du niveau 1 au plafond de 10, n'a
  jamais été simulée.

### Ce que je ne peux pas trancher seul

Seul un téléphone répond à la taille réelle des cibles tactiles et aux 60
images par seconde. Et seul Gaetan juge le ressenti d'un coup, les
affectations sonores — faites au nom des fichiers, jamais écoutées — et la
densité de la mer de T9.10.


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
