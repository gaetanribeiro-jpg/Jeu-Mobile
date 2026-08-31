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

| Tâche | Contenu |
|---|---|
| **T1.1** | Données : `classes.json` (3 classes, PA/PM/stats), `abilities.json` (9 compétences), `rules.json` |
| **T1.2** | `Unit` : PA, PM, initiative, bloc de statistiques |
| **T1.3** | `Ability` : coût en PA, portée, forme de zone, statistique d'échelle |
| **T1.4** | `TurnOrder` : timeline d'initiative entremêlée |
| **T1.5** | `CombatBoard` : déplacement au coût en PM, portée par compétence |
| **T1.6** | `CombatEngine` : boucle d'activation, dépense de PA/PM, annulation |
| **T1.7** | Formule de dégâts (base + statistique − défense) |
| **T1.8** | IA ennemie qui gère un budget PA/PM |
| **T1.9** | HUD : jauges PA/PM, timeline, barre de compétences, portée et zone |
| **T1.10** | Les 8 cartes réécrites en 12 × 9 |
| **T1.11** | Équilibrage : `simulate_combats.gd` remis en service |

### Phase 2 — RPG

XP, niveaux, statistiques, arbre de compétences, équipement, loot, raretés.
Reprend `data/heroes/progression.json`, réécrit sans l'Élévation.

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
