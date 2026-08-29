# RECONQUÊTE
### Document de conception & plan de développement

*Jeu mobile — tactique au tour par tour + gestion de comté*
*Assets : Tiny Swords (Pixel Frog) — Free Pack + Enemy Pack (9,75 $, 21 ennemis livrés / 30 prévus)*
*Compléments gratuits : voir § 13*
*Document recalé sur l'inventaire réel du pack (29 août 2026)*
*Moteur : Godot 4.x — Android d'abord, iOS ensuite*

---

# PARTIE I — CONCEPTION

## 0. Fiche d'identité

| | |
|---|---|
| **Genre** | Tactique tour par tour + gestion, campagne structurée |
| **Références** | ActRaiser (structure), Into the Breach (combat), Darkest Dungeon (blessures, tension) |
| **Session** | 8 à 12 minutes (une saison) |
| **Campagne** | 12 à 15 heures, 32 à 40 saisons |
| **Orientation** | Paysage verrouillé |
| **Cible** | Joueur solo, hors ligne, pas de free-to-play |
| **Modèle** | Payant unique (3–5 €) ou gratuit avec achat unique pour débloquer l'Acte II |

---

## 1. Vision et piliers

> **Chaque victoire sur la carte devient une pierre de ta ville. Chaque pierre de ta ville rend tes héros plus forts. Mais plus tu t'étends, plus tu attires l'attention.**

**Trois piliers non négociables.** Toute décision de design doit servir au moins l'un d'eux ; toute fonctionnalité qui n'en sert aucun est coupée.

1. **Aucune décision gratuite.** Pas de bâtiment décoratif, pas de ressource sans usage, pas de tour où l'on passe. Si le joueur peut jouer en pilote automatique, le système est raté.
2. **Information parfaite, conséquences lourdes.** Le joueur voit toujours ce qui va arriver. Il perd parce qu'il a mal calculé, jamais parce qu'un dé lui a menti.
3. **Les héros ont un nom.** Ce sont des personnes, pas des unités. On les recrute, on les blesse, on les enterre. C'est ce qui transforme un tableur en histoire.

**Le contre-pilier — ce que le jeu n'est PAS :**
- Pas de dialogues, pas de PNJ, pas d'intérieurs (le pack ne les fournit pas)
- Pas de carte du monde ouverte, pas d'exploration libre
- Pas de temps réel, pas de gestion de foule
- Pas d'énergie, pas de timers, pas de monnaie premium

---

## 2. La boucle de jeu

### 2.1 La saison (unité de temps = un tour)

Une partie se compte en **saisons**. Quatre saisons font une **année**. Chaque saison suit cinq étapes fixes :

```
┌─────────────────────────────────────────────────────────┐
│  1. INTENDANCE (ville)                                  │
│     Assigner les pions · Construire · Soigner · Équiper │
│     CONVOCATION : recruter ou verser à l'Ordre          │
│                          ↓                              │
│  2. CARTE DE RÉGION                                     │
│     Choisir une parcelle à reprendre                    │
│                          ↓                              │
│  3. EXPÉDITION                                          │
│     2 à 4 étapes : combats, événements, caches          │
│                          ↓                              │
│  4. RETOUR                                              │
│     Butin · XP · Blessures · La parcelle devient tienne │
│                          ↓                              │
│  5. FIN DE SAISON                                       │
│     Production · Consommation de vivres · Menace +1     │
│     (Année complète → CONTRE-ATTAQUE)                   │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Le rythme long

- **Saisons 1–3** : une seule expédition possible par saison, pas de contre-attaque. Tutoriel intégré.
- **Saison 4 et toutes les 4 saisons** : contre-attaque. Siège de ta ville.
- **À partir de la saison 8** : deux expéditions par saison possibles si les vivres suivent.
- **Hiver** (4ᵉ saison de chaque année) : production réduite de 40 %, coût en vivres doublé. Force à constituer des réserves.

### 2.3 La jauge de Menace

Le moteur de tension central. **La Menace monte quand tu t'étends.**

| Action | Menace |
|---|---|
| Fin de saison | +1 |
| Parcelle reprise | +2 |
| Camp gobelin détruit | +4 |
| Bâtiment de niveau 3 construit | +2 |
| Tour de guet active | −1 par saison |
| Contre-attaque repoussée | −5 |

La Menace détermine la **composition et la taille du siège** de fin d'année. Le joueur voit toujours la jauge et une estimation de la prochaine vague (« ~8 gobelins, 2 béliers »). Il peut donc choisir de temporiser une saison pour construire ses murs — ce qui est exactement la décision intéressante qu'on cherche.

---

## 3. Les héros

### 3.1 Les quatre classes

Le pack fournit quatre unités humaines principales. Chacune a un rôle tactique distinct et non redondant.

| Classe | PV | Dépl. | Portée | Dégâts | Capacité |
|---|---|---|---|---|---|
| **Guerrier** | 8 | 3 | 1 | 3 | **Provocation** — les ennemis adjacents doivent le cibler ce tour |
| **Archer** | 4 | 3 | 2–4 | 2 | **Tir tendu** — +2 dégâts s'il n'a pas bougé ce tour |
| **Lancier** | 6 | 3 | 1–2 | 2 | **Repousse** — pousse la cible d'une case dans la direction du coup |
| **Moine** | 5 | 4 | 1–2 | 1 | **Bénédiction** — annule une attaque télégraphiée sur une case |

Ces quatre capacités couvrent les quatre verbes tactiques : **attirer**, **frapper à distance**, **déplacer**, **annuler**. Toute la profondeur du combat vient de leurs combinaisons.

### 3.2 Identité individuelle

Chaque héros recruté est généré avec :
- **Un nom** (tirage dans une liste de 120 noms médiévaux)
- **Un trait** parmi ~20, positif ou négatif : *Vétéran* (+1 PV max), *Rancunier* (+1 dégât contre les gobelins), *Boiteux* (−1 déplacement), *Superstitieux* (refuse d'entrer dans les ruines), *Pilier* (les héros adjacents gagnent +1 PV)…
- **Une couleur de faction** parmi 5 (bleu, rouge, violet, jaune, noir) — chaque unité, pion et bâtiment existe dans les 5 teintes
- **Un portrait** : le pack fournit **25 avatars humains**, soit les 5 archétypes (Guerrier, Lancier, Archer, Moine, Pion) déclinés dans les 5 couleurs. Le portrait d'un héros découle donc de sa classe et de sa couleur, pas de son individualité — mais c'est largement assez pour la fiche de héros, le roster, la Convocation et les cartes d'événement.

Le trait est visible au recrutement. C'est un vrai choix, pas une loterie.

### 3.3 Niveaux

XP gagnée par combat gagné, par ennemi tué, par expédition terminée. **6 niveaux maximum.**

| Niveau | Gain |
|---|---|
| 2 | +1 PV max |
| 3 | Choix : +1 dégât **ou** +1 déplacement |
| 4 | +1 PV max |
| 5 | **Élévation** — possible si la classe est au rang 5 de l'Ordre (§ 3.5) |
| 6 | Choix : +1 portée **ou** +2 PV max |

Les deux pistes de progression se rejoignent au niveau 5 : la piste individuelle (l'expérience du héros) et la piste collective (la maîtrise de sa classe). Il faut les deux pour s'élever.

### 3.4 Blessures — le moteur de tension

**Un héros qui tombe à 0 PV n'est pas mort.** Il est hors de combat pour le reste de l'expédition et gagne une **blessure**.

| Blessures | Effet |
|---|---|
| 1 | −1 PV max, indisponible 1 saison |
| 2 | −2 PV max, −1 déplacement, indisponible 2 saisons |
| 3 | **Mort.** Le héros est retiré définitivement. |

Les blessures se soignent au **Monastère** (1 blessure par saison, coût en or). Sans monastère, elles ne se soignent pas.

C'est ce système qui rend la caserne, le monastère et la ferme nécessaires plutôt que décoratifs : il te faut un banc de remplaçants, il te faut de quoi les soigner, il te faut de quoi les nourrir.

**Mémorial.** Les héros morts apparaissent sur un écran dédié avec leur nom, leur niveau et la parcelle où ils sont tombés. Coût de développement : quasi nul. Impact émotionnel : énorme.

---

## 3.5 L'Ordre

> **Ce que le héros apprend meurt avec lui. Ce que l'Ordre apprend reste.**

Le système qui donne à chaque saison son rendez-vous, et qui empêche la mort d'un vétéran de ruiner une partie.

### 3.5.1 La Convocation

Chaque saison, à la Caserne, tu peux tenir une **Convocation** contre du **Renom**. Elle présente 2 ou 3 **candidats** générés aléatoirement, tous visibles en entier avant de choisir : classe, nom, trait, couleur, qualité.

| Qualité | Fréquence | Effet |
|---|---|---|
| **Commun** | 65 % | statistiques de base |
| **Aguerri** | 28 % | démarre au niveau 2, +1 PV max |
| **Élite** | 7 % | démarre au niveau 3, +1 PV max, second trait positif |

**Tu n'en recrutes qu'un.** Les autres sont **versés à l'Ordre**. Tu peux aussi n'en recruter aucun et tout verser — un choix légitime quand ton banc est plein et que tu veux pousser une maîtrise.

### 3.5.2 Les pistes de maîtrise

Chaque versement alimente la piste de **la classe du candidat**. Quatre pistes indépendantes.

| Rang | Versements cumulés | Gain — pour **tous** les héros de la classe, présents et futurs |
|---|---|---|
| 1 | — | état de départ |
| 2 | 2 | +1 PV max |
| 3 | 4 | **seconde capacité de classe** |
| 4 | 7 | Choix unique : +1 dégât **ou** +1 déplacement |
| 5 | 11 | débloque l'**Élévation** |

Les bonus sont **rétroactifs et permanents** : ils s'appliquent immédiatement à tous les héros de la classe, y compris ceux recrutés dix saisons plus tard.

Sur une campagne complète, tu auras de quoi mener **deux ou trois classes** au rang 5, jamais les quatre. C'est l'arbitrage central du système : concentrer ou étaler.

### 3.5.3 Les secondes capacités (rang 3)

| Classe | Capacité |
|---|---|
| **Guerrier** | **Riposte** — inflige 1 dégât à tout ennemi qui l'attaque au corps à corps |
| **Archer** | **Barrage** — attaque une case et ses 4 voisines pour 1 dégât |
| **Lancier** | **Charge** — se déplace jusqu'à 3 cases en ligne droite et frappe la première unité rencontrée |
| **Moine** | **Relève** — remet debout un héros tombé avec 1 PV, une fois par combat |

La Relève du Moine est la plus importante : elle permet d'annuler une blessure *avant* qu'elle ne soit inscrite. Elle change la valeur du Moine du tout au tout et justifie à elle seule de monter sa piste.

### 3.5.4 L'Élévation (rang 5)

Un héros de **niveau 5 ou plus** dont la **classe est au rang 5** peut s'élever. Choix définitif entre deux voies :

| Classe | Voie A | Voie B |
|---|---|---|
| **Guerrier** | **Champion** — +2 dégâts, −1 PV max | **Sergent** — les alliés adjacents gagnent +1 dégât |
| **Archer** | **Éclaireur** — +2 déplacement, voit les intentions ennemies un tour plus tôt | **Arbalétrier** — +1 portée, ignore le couvert de la forêt |
| **Lancier** | **Hallebardier** — Repousse pousse de 2 cases | **Garde** — frappe automatiquement tout ennemi qui passe à sa portée |
| **Moine** | **Prêcheur** — Bénédiction protège 2 cases | **Guérisseur** — soigne 3 PV, et retire une blessure légère en fin d'expédition |

**Quatre classes deviennent huit unités jouables, sans un seul sprite supplémentaire.** L'Élévation change la couleur de faction du héros et ajoute un élément d'UI du pack (bannière, ruban) : c'est visible d'un coup d'œil sur le champ de bataille.

### 3.5.5 La Retraite

Tu peux verser un héros de ton roster à l'Ordre. Il quitte la compagnie, sa formation reste.

| Niveau du héros | Versements |
|---|---|
| 1–2 | 1 |
| 3–4 | 2 |
| 5–6 | 3 |

C'est la décision la plus dure du jeu : un vétéran qui traîne deux blessures et coûte des vivres chaque saison vaut peut-être plus à l'Ordre que sur le terrain. Il apparaît ensuite au Mémorial, section *Retraités* — vivant, ce qui n'est pas rien.

### 3.5.6 Le Renom

Cinquième ressource, réservée à la Convocation. Elle ne s'achète pas : elle se gagne au combat.

| Source | Renom |
|---|---|
| Parcelle reprise | +2 |
| Gardien vaincu | +1 |
| Contre-attaque repoussée | +5 |
| Certains événements | variable |

| Caserne | Coût de la Convocation | Candidats |
|---|---|---|
| Niveau 1 | 4 Renom | 2 |
| Niveau 2 | 5 Renom | 3 |
| Niveau 3 | 6 Renom | 3, dont **une classe garantie au choix** |

Le niveau 3 de la Caserne est ce qui te permet de **piloter** ta spécialisation au lieu de la subir. C'est la montée de bâtiment la plus structurante du jeu.

### 3.5.7 Pourquoi ce système est nécessaire

Sans lui, perdre définitivement un héros de niveau 5 après vingt saisons est assez brutal pour faire abandonner la partie — et un joueur qui redoute trop la perte joue prudemment, donc ennuyeusement.

Avec l'Ordre, **la maîtrise survit au héros**. Aldric meurt, mais sa classe reste au rang 4, et son remplaçant naît déjà meilleur qu'Aldric ne l'était à ses débuts. La perte fait mal sans annuler la progression. C'est le ressort de *Hadès* et de *Darkest Dungeon*, et c'est ce qui autorise le jeu à être dur.

Et personne n'est fusionné avec personne : les héros restent des personnes qui ont un nom.

---

## 4. Le combat tactique

### 4.1 Règles de base

- Grille **8 × 6** en vue de dessus, tuiles 64×64
- **4 héros maximum** engagés, 3 à 7 ennemis
- Tour du joueur (toutes les unités, dans l'ordre choisi) → **résolution des ennemis** → nouveau tour
- Un combat dure **3 à 6 tours**. Au-delà, c'est trop long pour du mobile.

### 4.2 Le télégraphe (règle centrale)

À la fin de son tour, le joueur voit **exactement** ce que chaque ennemi va faire au tour suivant : une icône sur la ou les cases visées, avec les dégâts chiffrés.

Le tour du joueur consiste donc à répondre à une question claire : *comment j'empêche ça ?* Trois réponses possibles — **sortir de la case**, **tuer l'ennemi avant**, **déplacer l'ennemi pour dévier son attaque**.

Conséquence : **on ne perd jamais injustement**, et pousser un gobelin devient plus intéressant que le tuer.

**Le pack dessine déjà le télégraphe.** C'est la meilleure nouvelle de tout l'inventaire. Le Troll possède une animation **Windup** séparée de son attaque ; la Tortue a **Guard In / Guard Out** ; le Minotaure, le Panda et le Squelette ont chacun une pose de **Guard** ; le Guerrier humain aussi. Le télégraphe n'a donc pas besoin d'être une icône plaquée sur la case : c'est une **posture**. L'ennemi lève son arme, et tu comprends qu'il va frapper avant même de lire l'icône.

Implémentation : la pose animée porte l'information, l'icône chiffrée la confirme. Les deux ensemble, jamais l'icône seule.

### 4.3 Terrain

| Tuile | Effet |
|---|---|
| Herbe | neutre |
| **Eau** | infranchissable pour tes héros — toute unité poussée dedans **meurt instantanément**. Mais les ennemis aquatiques y circulent librement et y tirent |
| **Forêt** | −1 dégât subi, bloque la ligne de vue |
| **Colline** | +1 portée et +1 dégât pour les unités à distance |
| **Rocher** | bloque le déplacement et les tirs |
| **Pont** | franchissable, destructible (2 dégâts) |
| **Ruine** | +1 dégât subi, mais contient parfois une cache |

L'eau est l'outil le plus puissant du jeu et il est gratuit visuellement (le pack fournit les tuiles d'eau animées). Chaque carte doit en contenir.

### 4.4 Le bestiaire

**Roster réel du pack : 21 ennemis livrés**, tous animés en Idle / Run / Attack, **tous avec un avatar de portrait**.

| Ennemi | Animations fournies | Rôle dans Reconquête |
|---|---|---|
| **Spear Goblin** | Idle, Run, Attack Fast, **Attack Strong**, + version **Pig Rider** | Piétaille de base. Deux attaques = deux télégraphes distincts. Monté sur cochon = cavalerie |
| **Torch Goblin** | Idle, Run, Attack | Incendiaire — laisse du feu persistant sur la case |
| **Thief** | Idle, Run, Attack | Rôdeur — se déplace après avoir frappé, vise l'Archer |
| **Hex Shaman** | Idle, Run, Attack, Projectile, Explosion, **Transformation Spell** | **Contrôle** — transforme un héros en cochon : tour perdu, capacité perdue |
| **Gnome** | Idle, Run, Attack | Piétaille rapide, faible, en nombre |
| **Slingshot Gnome** | Idle, Run, Shoot, + projectile **Acorn** | Tirailleur — 3 cases, recule si on l'approche |
| **Gnoll** | Idle, Walk, Throw, **Hit**, + projectile **Bone** | Tirailleur en cloche — ignore les obstacles |
| **Snake** | Idle, Run, Attack | Empoisonneur — 1 dégât par tour pendant 2 tours |
| **Spider** | Idle, Run, Attack | Empoisonneur mobile — déplacement 5 |
| **Lizard** | Idle, Run, Attack, **Hit** | Épineux — blesse quiconque l'attaque au corps à corps |
| **Turtle** | Idle, Walk, Attack, **Guard In / Guard Out** | **Bloqueur** — invulnérable en carapace, occupe le terrain |
| **Bear** | Idle, Run, Attack | Brute intermédiaire |
| **Minotaur** | Idle, Walk, Attack, **Guard** | **Brute** — lent, dégâts en ligne, télégraphe énorme |
| **Troll** | Idle, Walk, **Windup, Attack, Recovery**, **Dead + massue en morceaux** | **Boss de zone** — voir ci-dessous |
| **Panda** | Idle, Run, Attack, **Guard** | Élite — deux attaques par tour |
| **Skull** | Idle, Run, Attack, **Guard** | Élite mort-vivant, Acte III |
| **Giant Bat** | Idle, Move, Attack | Volant — ignore le terrain, vise l'arrière |
| **Bumblebee** | Idle, Move, Attack | Volant rapide et fragile, en essaim |
| **Bomb Fish** | Idle, Run, Shoot, + **Bombe** (mèche, rotation) | **Artilleur aquatique** — tire depuis l'eau |
| **Harpoon Shark** | Idle, Run, Throw, + **Harpon** | Aquatique — **tire un harpon et tracte sa cible dans l'eau** |
| **Paddle Shark** | Idle, Run, Attack, + **Row** (rame le bateau) | Aquatique — transporte les autres |

**Ce que ça change : l'eau devient un territoire ennemi.** Le pack fournit trois créatures aquatiques, une **barque**, un **bateau hippocampe** qui embarque les trois, et une **tour pirate** en version sol et eau. Ma règle initiale « poussé dans l'eau = mort » reste valable pour tes héros, mais l'eau cesse d'être un simple décor mortel : c'est une voie d'attaque que tu ne peux pas emprunter. Le Harpoon Shark qui tracte un héros dans l'eau est à lui seul une mécanique de combat entière.

**Le Troll est un cadeau.** Windup → Attack → Recovery, trois animations distinctes, plus une mort en morceaux. C'est un **boss sur trois tours** entièrement dessiné : il charge (tu as un tour pour réagir), il frappe, il est vulnérable pendant qu'il récupère. Aucun autre ennemi n'a cette structure. À réserver aux gardiens de parcelle.

**Répartition par acte :**

| Acte | Ennemis |
|---|---|
| **I — La Vallée** | Spear Goblin, Gnome, Slingshot Gnome, Torch Goblin, Thief |
| **II — Le Comté** | + Gnoll, Snake, Spider, Lizard, Turtle, Bear, Giant Bat, Bumblebee |
| **III — La Marche** | + Hex Shaman, Minotaur, Panda, Skull, et les trois aquatiques |
| **Gardiens** | Troll (Actes I-II), Minotaur puis Skull (Acte III) |

**Structures ennemies fournies :** Goblin Hut, Gnome Hut, Gnome Tower, Fish Hut, Pirate Tower (sol et eau), Maison de troll dans un **Dead Tree**, **Cave**, **Wooden Fence** (tuile 64×64), décorations d'os et de crânes, et un **Cannon orienté sur 5 directions**.

La **grotte** est le meilleur cadeau du lot : elle fait apparaître des ennemis en continu, ce qui donne gratuitement un objectif de combat — *détruis la grotte, sinon ils ne s'arrêteront jamais*.

**Ce que le pack ne contient pas**, contrairement à ce que j'avais supposé : pas de chaman de soin (le Hex Shaman fait du contrôle, pas du soin), pas de chevalier-mouton, **pas d'animation de mort** sauf pour le Troll.

**Règle de conception :** on n'ajoute jamais un ennemi qui fait juste « plus de dégâts ». Chaque nouvel ennemi doit poser une **question tactique inédite** au joueur.

### 4.5 Objectifs de combat variés

Ne jamais enchaîner six fois « tue tout le monde ». Rotation :

- **Éliminer** — tuer tous les ennemis
- **Survivre** — tenir 4 tours, les renforts arrivent en continu
- **Escorter** — un pion doit atteindre le bord opposé
- **Protéger** — une structure ne doit pas tomber (2 PV)
- **Saisir** — atteindre une case précise avant le tour 5
- **Extraire** — récupérer une cache et sortir par le bord

---

## 5. La ville

### 5.1 Principe

La ville est bâtie sur les parcelles reprises. Chaque parcelle offre **1 à 3 emplacements** de construction et **1 à 2 postes de travail**.

### 5.2 Les pions (travailleurs)

Les *pawns* du pack. Assignés en début de saison à un **gisement** présent sur une parcelle : un arbre, un filon d'or, un troupeau de moutons. Un pion produit une quantité fixe par saison. Ils sont **perdables** : une contre-attaque réussie sur ta ville en tue.

**La production ne passe par aucun bâtiment.** Le pack anime le pion avec sa hache, sa pioche, son couteau et son marteau, et fournit les gisements eux-mêmes (4 arbres, 4 souches, 6 filons d'or de tailles différentes, moutons, ainsi que les ressources posées au sol). Le pion va au gisement, point. C'est plus simple à coder, plus lisible à l'écran, et entièrement couvert par les assets.

Le nombre de pions que tu peux entretenir dépend du **Hameau** (§ 5.4). Le nombre que tu peux employer dépend des gisements sur tes parcelles — donc de ta conquête.

### 5.3 Les ressources

| Ressource | Source | Usage |
|---|---|---|
| **Bois** | arbres et souches (4 + 4 dans le pack) | construction, réparations, flèches |
| **Or** | filons d'or (6 tailles dans le pack) | murs, tours, équipement, recrutement, soins |
| **Vivres** | moutons de la forêt | **consommées par héros et par expédition** |
| **Renom** | parcelles, gardiens, sièges | **Convocation uniquement** (§ 3.5.6) |

> **Décision imposée par le pack.** Tiny Swords ne fournit **que trois ressources** — les pions savent couper du bois, miner de l'or et chasser le mouton. Il n'existe ni carrière ni sprite de pierre. J'avais prévu une quatrième ressource : elle est supprimée. C'est une bonne nouvelle : trois matières + le Renom, c'est plus lisible sur un écran de téléphone, et la Pierre faisait doublon avec l'Or. La leçon vaut pour toute la suite — **on conçoit avec ce que le pack sait dessiner**, jamais contre.

Les vivres sont le régulateur : sans elles, pas d'expédition. Elles empêchent de foncer.

Le Renom est à part : il ne se produit pas, il se mérite. C'est la seule ressource qu'un pion ne peut pas fabriquer.

### 5.4 Les bâtiments

**Le pack fournit exactement 8 sprites de bâtiment** (Castle, Barracks, Archery, Monastery, Tower, House1, House2, House3), en 5 couleurs. Ma liste de 10 bâtiments était de l'invention : ni ferme, ni scierie, ni carrière, ni marché, ni mur n'existent. La voici recalée sur ce qui est réellement dessiné.

| Bâtiment | Sprite | Nv 1 | Nv 2 | Nv 3 |
|---|---|---|---|---|
| **Château** | Castle | cœur, 6 PV, +1 emplacement | 10 PV, +1 pion | 14 PV, débloque l'Acte III |
| **Hameau** | House1 → 2 → 3 | +2 pions | +4 pions | +6 pions, réserve d'hiver |
| **Caserne** | Barracks | Convocation à 2 candidats | 3 candidats | 3 candidats dont une classe garantie ; +1 héros en expédition |
| **Arsenal** | Archery | équipement commun | équipement rare | amélioration d'équipement |
| **Monastère** | Monastery | soigne 1 blessure/saison | 2 blessures/saison | annule une mort, une fois par partie |
| **Tour de guet** | Tower | révèle les parcelles adjacentes, −1 Menace | portée 2, tire pendant le siège | +1 tour d'avertissement avant le siège |
| **Palissade** | Wooden Fence (tuile) | segment 4 PV | 8 PV | 12 PV |
| **Canon** | Cannon (5 directions) | — | — | tourelle de siège, débloquée à l'Acte II |

**Sept bâtiments au lieu de dix, et aucun n'est inventé.** Le Marché disparaît (il était déjà premier sur la liste des coupes) et la production ne passe plus par des bâtiments du tout — voir ci-dessous.

**Les trois maisons sont les trois niveaux du Hameau.** Le pack fournit House1, House2 et House3, visuellement de plus en plus grandes. C'est la montée de niveau la plus lisible du jeu : ton village grandit à l'écran.

**Le Canon est orienté sur 5 directions** (haut, haut-droite, droite, bas-droite, bas), miroitables pour couvrir les 8. C'est la seule pièce d'artillerie du pack : elle mérite d'être un déblocage tardif et marquant, pas un bâtiment de base.

### 5.5 Équipement

Trois emplacements par héros : **arme**, **armure**, **accessoire**. Fabriqué à la forge ou trouvé en expédition.

Effets simples et lisibles : +1 dégât, +2 PV, +1 déplacement, +1 portée, immunité au feu, survie à une poussée dans l'eau, contre-attaque au corps à corps…

**Pas de statistiques cachées, pas de pourcentages.** Tout est en nombres entiers, visible sur la fiche du héros.

---

## 6. La carte de région

### 6.1 Structure

Une carte de **parcelles hexagonales** (ou carrées — l'hexagone est plus joli, le carré plus simple ; le pack fournit des tuiles carrées, donc **carré**). Environ **40 parcelles** au total sur les trois actes.

Chaque parcelle possède :
- Un **type** : forêt, filon d'or, pâture, plaine, ruine, camp gobelin, grotte, village, sanctuaire
- Une **difficulté** (1 à 5 étoiles) — visible avant de partir
- Une **récompense** : postes de travail, emplacements de construction, ressource unique
- Éventuellement un **verrou** : « nécessite une Tour de guet », « nécessite un héros de niveau 4 »

### 6.2 Brouillard

Trois états : **inconnue** (silhouette grise), **repérée** (type et difficulté visibles, via Tour de guet ou parcelle adjacente), **reprise**.

### 6.3 Le double usage

C'est l'idée clé du jeu : **cette carte est à la fois la carte des quêtes et le plan d'urbanisme.** Reprendre une parcelle de forêt, c'est débloquer un chantier de scierie. Les parcelles frontalières sont exposées lors des sièges — bâtir loin du château est risqué.

Une seule carte, deux fonctions, zéro écran supplémentaire à concevoir.

---

## 7. Les expéditions

### 7.1 Structure

Une expédition = une chaîne de **2 à 4 nœuds** sur la parcelle ciblée, avec parfois un embranchement (choix entre deux chemins visibles).

| Nœud | Contenu |
|---|---|
| **Combat** | un affrontement tactique |
| **Événement** | une carte narrative, deux ou trois choix |
| **Cache** | butin gratuit, ou piège |
| **Camp** | repos : soigne 2 PV à tout le monde, coûte 1 vivre |
| **Gardien** | combat final de la parcelle, plus difficile |

### 7.2 Règles

- Les PV **ne se régénèrent pas** entre les nœuds (sauf Camp ou Moine). C'est ce qui crée l'usure.
- On peut **abandonner** après n'importe quel nœud : on garde le butin, on ne prend pas la parcelle.
- Coût : **1 vivre par héros** + 2 vivres fixes.

### 7.3 Les événements narratifs

Le format qui remplace les dialogues, faute d'assets de PNJ. **Objectif : 80 à 100 événements.** C'est du texte pur — la partie la moins coûteuse du projet, et celle qui donne le plus d'âme.

#### La règle de voix — validée, non négociable

Calibrée avec Gaetan sur dix cartes de référence. **Toute carte écrite ensuite s'y conforme.**

1. **Vouvoiement direct.** « Vous apercevez un puits », jamais un décor posé sans sujet. Le joueur est dans la scène, pas devant elle.
2. **Phrases liées, pas de staccato.** Des articulations explicites — *mais*, *en revanche*, *pourtant*, *lorsque*. Deux ou trois phrases qui s'enchaînent, pas trois fragments juxtaposés.
3. **Trois phrases maximum**, présent de l'indicatif.
4. **Aucun narrateur.** Personne ne commente, personne ne juge, personne n'annonce l'enjeu. On décrit, on s'arrête.
5. **Clôture par points de suspension** sur les cartes à mystère ou à tension. Point simple sur les cartes transactionnelles.
6. **Toujours terminer par « Que souhaitez-vous faire ? »**, formule identique à chaque carte. C'est un rituel, pas une répétition — il ne varie jamais.

#### Exemple canonique

> Vous apercevez un puits, mais il n'y a pas d'eau au fond. Il y a en revanche des marches, qui descendent plus bas que la vallée ne devrait aller…
>
> Que souhaitez-vous faire ?
>
> → Descendre
> → Le reboucher

#### Les règles d'effets

1. **Aucun choix strictement dominant.** Si une option est meilleure que les autres sous tous les angles, la carte n'a pas de choix — elle a un bouton.
2. **Une carte sur cinq n'a aucun effet mécanique.** Le canard de bois ne rapporte rien. Un jeu où tout rapporte quelque chose devient un tableur, et le joueur cesse de lire.
3. **Les choix conditionnés** — par une classe présente, un trait, un bâtiment, un rang de l'Ordre — sont toujours *intéressants*, jamais *gratuits* : ils ouvrent une voie différente, ils ne suppriment pas le coût.
4. **Une carte sur huit rend un résultat incertain** (le rescapé de la grange, ou l'embuscade). Jamais plus : l'information parfaite est un pilier du combat, elle ne doit pas être trahie ailleurs.
5. **Les récompenses restent petites.** Une carte d'événement ne change pas une partie. Elle la colore.

#### Schéma de données

```json
{
  "id": "puits",
  "act": 1,
  "sprite": "extra.cave_cave_idle",
  "weight": 1,
  "once": true,
  "text": "Vous apercevez un puits, mais il n'y a pas d'eau au fond...",
  "choices": [
    { "label": "Descendre",
      "effects": [ {"codex": "citadelle_1"}, {"wound": {"target": "random", "count": 1}} ] },
    { "label": "Le reboucher",
      "effects": [ {"resource": "renown", "delta": 1} ] }
  ]
}
```

`prompt` n'est pas un champ : « Que souhaitez-vous faire ? » est ajouté par le moteur, pour qu'il soit impossible de l'oublier ou de le faire varier.

`requires` sur un choix accepte : `class`, `trait`, `building`, `order_rank`, `resource_min`.

#### Les dix cartes de référence

Elles sont écrites et validées. Elles servent de jeu de test au moteur d'événements (tâche N6.2) et d'étalon de style :
batelier · canard · grange · cochon · les trois hommes · le blessé · colporteur · tambour · **puits** · pierre levée.

---

## 8. La contre-attaque

Tous les 4 saisons. **Le rendez-vous que le joueur redoute et attend.**

### 8.1 Déroulement

Un combat tactique sur une grille plus grande (**10 × 8**), qui représente ta ville avec ses vrais bâtiments et ses vrais murs.

- Les ennemis arrivent par les bords, en **2 ou 3 vagues**
- Objectif : **tenir 6 tours** sans que le Château tombe
- Tes murs et tes tours **participent réellement** (les tours tirent, les murs bloquent)
- Tous tes héros disponibles participent, y compris les blessés légers

### 8.2 Conséquences de l'échec

Une défaite n'est **pas un game over**. Le siège se termine, mais :
- Les bâtiments détruits le restent (à reconstruire)
- Des pions sont morts
- Une parcelle frontalière est perdue
- Les héros tombés gardent leurs blessures

Le joueur repart plus faible mais il repart. **C'est un revers, pas une fin.** (Un mode « Fer » optionnel rendra la défaite définitive, pour ceux qui le veulent.)

---

## 9. Économie et courbe

### 9.1 Ordres de grandeur de départ

| | Valeur |
|---|---|
| Pions au départ | 3 |
| Héros au départ | 2 (Guerrier + Archer) |
| Ressources de départ | 20 bois, 25 or, 12 vivres, 4 renom |
| Production par pion | 2 / saison |
| Coût caserne nv 1 | 15 bois |
| Coût d'une Convocation | 4 renom |
| Coût de recrutement | 10 or |
| Coût soin d'une blessure | 8 or |
| Renom moyen par saison | ~2 (Acte I) → ~4 (Acte III) |

### 9.2 Principe d'équilibrage

**Le joueur doit finir chaque saison avec le sentiment d'avoir dû renoncer à quelque chose.** S'il peut tout construire ET tout recruter ET tout soigner, les coûts sont trop bas.

Règle pratique : viser **60 à 70 % des dépenses souhaitées** réalisables chaque saison.

### 9.3 Ce qu'il faudra mesurer en playtest

- Nombre de saisons pour reprendre la première parcelle difficile
- Taux de mort des héros par acte (cible : 1 à 2 morts sur la campagne, pas 0, pas 8)
- Durée réelle d'un combat en tours et en minutes
- Taux d'échec de la première contre-attaque (cible : ~40 %)
- **Nombre de classes menées au rang 5 en fin de campagne (cible : 2, jamais 4)**
- **Saison d'arrivée du premier rang 5** (cible : autour de la saison 20 — trop tôt, la fin de partie s'aplatit ; trop tard, l'Élévation ne sert à rien)

---

## 10. Campagne et narration

### 10.1 Trois actes

| Acte | Titre | Saisons | Contenu |
|---|---|---|---|
| **I** | **La Vallée** | 1–10 | Tutoriel intégré. 4 classes, 6 ennemis, 12 parcelles. Se termine sur la reprise du Pont de Cendre. |
| **II** | **Le Comté** | 11–26 | Ennemis d'élite, équipement rare, bâtiments nv 3, 18 parcelles. Sièges à deux fronts. |
| **III** | **La Marche** | 27–40 | La Citadelle. 10 parcelles très difficiles, un siège final scénarisé. |

### 10.2 Le fil narratif

Léger, servi par les écrans de transition d'acte et les cartes d'événement. Pas de cinématiques.

**Le mystère de fond :** les gobelins ne pillent pas au hasard. Ils cherchent quelque chose sous la Citadelle. Révélé par fragments dans les caches et les ruines, résolu à l'Acte III.

C'est suffisant. Un jeu de stratégie n'a pas besoin de plus, et le joueur écrit lui-même la vraie histoire — celle de ses héros.

---

## 11. UX mobile

### 11.1 Orientation

**Paysage verrouillé.** La grille de combat et la vue de ville ont besoin de largeur. Le jeu se joue assis, à deux mains, par sessions de 10 minutes — pas d'une main dans le métro. C'est un arbitrage assumé.

### 11.2 Grammaire d'interaction

| Geste | Action |
|---|---|
| **Tap** sur unité | sélectionner, afficher les cases valides |
| **Tap** sur case valide | prévisualiser (fantôme du sprite) |
| **Tap** confirmation | valider le déplacement |
| **Tap long** sur unité | fiche détaillée |
| **Pincer / glisser** | zoom et déplacement de caméra |
| **Bouton Annuler** | toujours présent tant que le tour n'est pas validé |

**Règle absolue : rien n'est irréversible avant la validation du tour.** Le double-tap de confirmation évite 90 % des erreurs de gros doigts.

### 11.3 Tailles

Cible tactile minimale **48 dp**. Une case de 64 px affichée à l'échelle 2 fait largement l'affaire. Les boutons d'action en bas, à portée de pouce, jamais dans les coins hauts.

### 11.4 Écrans

1. Menu principal
2. Ville (vue isométrique-ish, construction)
3. Carte de région
4. Écran d'expédition (chaîne de nœuds)
5. Combat
6. Carte d'événement
7. Fiche de héros
8. Roster / caserne
9. **Convocation** (présentation des candidats, recrutement ou versement)
10. **L'Ordre** (les 4 pistes de maîtrise)
11. **Élévation** (choix de la voie)
12. Butin de fin d'expédition
13. Écran de siège (variante du combat)
14. Mémorial (tombés + retraités)
15. Options

---

## 12. Direction artistique et « juice »

Les sprites sont déjà beaux. **La beauté perçue viendra de tout ce qu'il y a autour.** Liste concrète, par ordre de rentabilité :

| Effet | Coût | Impact |
|---|---|---|
| **Hit stop** — gel de 80 ms à l'impact | trivial | énorme |
| **Screen shake** — 3 px, 150 ms | trivial | énorme |
| **Nombres de dégâts** flottants | faible | fort |
| **Flottement** des sprites au repos (sinusoïde 2 px) | trivial | fort |
| **Eau animée** — le pack fournit la **tuile de vagues animée** et les ombres | trivial | fort |
| **Poussière et impacts** — le pack fournit **2 poussières, 3 feux, 2 explosions, 1 gerbe d'eau** | trivial | fort |
| **Parallaxe de nuages** — le pack fournit les **nuages** | trivial | fort |
| **Ombres portées** (ellipse noire 30 % sous chaque unité) | trivial | fort |
| **Transitions** de scène (fondu + volet) | faible | moyen |
| **Punch de caméra** vers la cible pendant l'attaque | moyen | fort |
| **Brouillard de guerre** dégradé animé sur la carte | moyen | fort |
| **Cycle jour/nuit** teinté selon la saison | moyen | fort |
| **Les 4 saisons** — le pack fournit **5 variantes de couleur du tileset** (Tilemap_color1 à 5), soit un jeu d'herbe par saison, gratuitement | trivial | énorme |

Palette : celle du pack, sans y toucher. Pour l'UI, utiliser les éléments d'interface du Free Pack **plutôt que d'en dessiner** : bannière papier et table en bois étirables, épée et rubans étirables en 5 couleurs, 2 petits papiers, 2 barres de vie, boutons carrés et ronds, 4 curseurs, 12 icônes.

**5 couleurs de faction** (bleu, rouge, violet, jaune, noir) existent pour chaque unité, pion et bâtiment. C'est de la variété visuelle gratuite : ta compagnie en bleu, les factions rivales dans les autres teintes, et le noir réservé aux unités élevées.

---

## 13. Les assets complémentaires

Ce que Tiny Swords **ne fournit pas** et qu'il faut aller chercher. Tout ce qui suit est gratuit et utilisable commercialement — **vérifie chaque licence au téléchargement**, elles changent.

### 13.1 Ce qui manque vraiment

*Révisé après inventaire complet du pack. Deux besoins que j'annonçais ont disparu : les portraits existent (25 humains + 21 ennemis), et les particules aussi.*

| Besoin | Pourquoi le pack ne couvre pas | Priorité |
|---|---|---|
| **Musique** | rien du tout | **critique** |
| **Effets sonores** | rien du tout | **critique** |
| **Police avec accents** | aucune police fournie | **critique** |
| **Icônes de capacités et d'états** | les 12 icônes couvrent bois, or, viande, attaque, défense et la navigation — rien pour les capacités, les traits, le poison, le feu, le Renom | haute |
| **Animations de mort** | seul le Troll en a une | haute — à compenser par un effet |
| **Fond de carte de région** | pas de vue stratégique | moyenne |

### 13.2 Audio — musique

| Source | Licence | Remarque |
|---|---|---|
| **OpenGameArt — collection « CC0 Fantasy Music »** | CC0 | Orchestral, non chiptune. Contient déjà un thème de ville, un thème de bataille, un thème de boss et des ambiances — soit exactement mes trois pistes. **Le premier endroit où chercher.** |
| **Kenney — Music Jingles** | CC0 | Pour les fanfares courtes (victoire, montée de niveau, Élévation), pas pour les boucles longues |
| **alkakrab — Fantasy Medieval Ambient Music Pack** | libre pour usage commercial | 10 pistes ambiantes avec versions bouclées, en mp3/wav/ogg |
| **HZSMITH — Free Medieval Epic Loops** | CC BY-SA 4.0 | 30 boucles. **Attention au SA** : le partage à l'identique complique les choses, à éviter si tu vends le jeu |

**Format :** privilégier l'**OGG**, qui boucle proprement dans Godot ; le MP3 introduit un micro-silence en début de fichier qui s'entend sur une boucle.

### 13.3 Audio — effets

- **Kenney — RPG Audio, Impact Sounds, UI Audio, Interface Sounds** : CC0, sans attribution, la référence. Couvre les impacts, les clics, les validations.
- **freesound.org**, filtré sur CC0 : pour les manques ponctuels (bêlement de mouton, marteau sur enclume, corne de guerre).

Il te faut environ **25 sons** : épée, flèche, impact, mort, chute dans l'eau, feu, construction, ramassage, clic, validation, échec, apparition de candidat, fanfare de victoire, corne de siège.

### 13.4 Police

**C'est le piège classique en français.** La plupart des pixel-fonts anglophones n'ont ni é, ni è, ni ê, ni à, ni ç, ni ù, ni œ. Le texte s'affichera avec des trous ou des carrés, et tu ne t'en apercevras qu'après avoir écrit 90 cartes d'événement.

| Police | Verdict |
|---|---|
| **Silver** (Poppy Works) | **Le meilleur choix.** Couvre le latin étendu, le cyrillique et bien d'autres jeux de caractères. Accents français garantis. |
| **m5x7 / m6x11** (Daniel Linssen) | Très jolies, très utilisées — **vérifier les accents avant de s'engager** |
| **monogram** (datagoblin) | La version bitmap n'a pas les accents, la question revient régulièrement chez l'auteur. À éviter pour du français. |

**Test à faire le premier jour** (tâche F0.10) : afficher `ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸÆŒ àâäçéèêëîïôöùûüÿæœ` et regarder. Cinq minutes maintenant contre une semaine de reprise plus tard.

### 13.4bis Compenser l'absence d'animation de mort

Aucune unité ne meurt à l'écran, sauf le Troll. Il faut donc une **solution unique et systématique**, appliquée à tout le monde :

- teinte blanche 100 ms, puis fondu de la transparence sur 200 ms
- **Dust_01 + Dust_02** du pack par-dessus, en explosion de poussière
- **Water Splash** du pack à la place, si la mort est une chute dans l'eau
- pour le Troll seul : sa vraie animation de mort, avec les deux morceaux de massue qui volent

Bien fait, c'est plus lisible qu'une animation de mort et ça coûte une heure. Le Troll devient au passage la seule créature qui meurt « pour de vrai » — ce qui souligne son statut de gardien.

### 13.5 Icônes

Le pack n'en fournit que 12. Il t'en faut une par capacité, par ressource, par état, par trait — soit **60 à 80**.

- **game-icons.net** — plusieurs milliers d'icônes vectorielles en CC BY 3.0, recolorables et redimensionnables. Le fonds le plus complet pour un jeu médiéval-fantastique.
- **Kenney — Game Icons** — CC0, plus géométriques
- Bonne pratique : les passer toutes dans la palette de Tiny Swords pour qu'elles ne jurent pas. Un script de remappage de couleurs suffit.

### 13.6 Ce que tu peux fabriquer toi-même

Les fichiers **Aseprite** sont fournis avec le pack. Aseprite coûte une vingtaine d'euros — ou se compile gratuitement depuis les sources. Avec, tu peux :

- Créer tes propres couleurs de faction (au-delà des 5 fournies)
- Recadrer des sprites d'unité en **portraits** pour les fiches de héros et les cartes d'événement
- Composer les vignettes de tes cartes d'événement à partir des décors existants

C'est la façon la moins chère de combler les vrais manques, et ça reste dans le style.

### 13.7 Règle de licence

Ouvre un fichier `CREDITS.md` **dès le premier jour** et note chaque asset avec sa source, sa licence et la date de téléchargement. Le jour de la publication, remplir ça de mémoire est un cauchemar — et une licence CC BY oubliée est une vraie infraction, pas un détail.

Rappel pour Tiny Swords : usage commercial autorisé, modification autorisée, crédit non obligatoire mais bienvenu, **redistribution des fichiers interdite même modifiés**.

Le silence tue davantage la sensation de qualité que des sprites moyens. **Ne pas repousser l'audio à la toute fin.**

---

## 14. Architecture technique

### 14.1 Choix

- **Godot 4.x**, GDScript
- Tout est **piloté par les données** : unités, bâtiments, ennemis, événements, parcelles définis dans des fichiers `.tres` (Resources Godot) ou JSON. Aucune valeur chiffrée en dur dans le code.
- **Logique de combat séparée du rendu** : une classe `CombatEngine` sans aucune dépendance visuelle, testable en headless. C'est ce qui permet à Claude Code d'écrire des tests automatiques et de trouver les bugs sans que tu aies à jouer.
- **RNG à graine** : chaque combat stocke sa graine, ce qui permet de rejouer un bug à l'identique.

### 14.2 Arborescence

```
res://
├── data/            # .tres et .json — unités, bâtiments, ennemis, événements, parcelles
├── engine/          # logique pure, sans nœuds Godot
│   ├── combat/      # CombatEngine, Grid, Unit, Ability, AI
│   ├── economy/     # production, coûts, consommation
│   └── campaign/    # saisons, menace, progression
├── scenes/
│   ├── combat/
│   ├── city/
│   ├── map/
│   ├── expedition/
│   └── ui/
├── autoload/        # GameState, SaveManager, AudioManager, EventBus
├── assets/          # Tiny Swords + audio + polices
├── shaders/
└── tests/
```

### 14.3 Sauvegarde

- JSON dans `user://save_0.json`, **versionné** (`"version": 3`) avec fonction de migration
- **Sauvegarde automatique** après chaque nœud d'expédition et chaque action de ville. Sur mobile, l'app peut être tuée à tout moment — c'est non négociable.
- Un slot unique + une sauvegarde de secours (`save_0.bak`)

### 14.4 Performance

Cible : **60 fps sur un téléphone d'entrée de gamme de 2021**. Pièges à surveiller : trop de nœuds instanciés sur la carte de région (utiliser du `MultiMeshInstance2D` ou un TileMap), particules non poolées, atlas de textures mal configuré (activer l'importation par atlas, filtrage **Nearest** obligatoire pour le pixel art).

---

## 15. Ce qu'on coupe si ça déborde

Par ordre de sacrifice, du plus au moins acceptable :

1. Le Marché
2. Le mode « Fer »
3. Les qualités de candidat (Commun / Aguerri / Élite)
4. La Retraite (§ 3.5.5)
5. Les traits de héros (garder juste les noms)
6. Le troisième niveau des bâtiments
7. L'Acte III (le jeu se termine à la fin de l'Acte II, on ajoute l'Acte III en mise à jour)
8. iOS

**Ne jamais couper :** les blessures, le télégraphe, l'Ordre, le juice, l'audio, la sauvegarde automatique.

Si l'Ordre devait être réduit faute de temps, garder les rangs 2 et 3 et repousser l'Élévation en mise à jour — mais ne jamais le supprimer entièrement : c'est lui qui rend la mort d'un héros supportable.

---
---

## 16. Annexe — inventaire réel du pack

*Relevé sur les fichiers, pas sur la fiche de vente. À vérifier à chaque mise à jour de Pixel Frog.*

**Chiffres clés**

| | |
|---|---|
| Fichiers PNG | ~1 700 |
| Ennemis | 21, tous en Idle / Run / Attack, tous avec avatar |
| Unités humaines | 5 (Warrior, Lancer, Archer, Monk, Pawn) × 5 couleurs |
| Bâtiments | 8 × 5 couleurs |
| Portraits | 25 humains + 21 ennemis = **46** |
| Icônes | 12 |
| Tileset | 5 variantes de couleur, 576×384 chacune (9 × 6 tuiles de 64) |
| Particules | 2 poussières, 3 feux, 2 explosions, 1 gerbe d'eau |
| Nuages | 8 |
| Décors | 4 buissons, 4 rochers, 4 rochers d'eau, os, crânes, canard en plastique |
| Gisements | 4 arbres, 4 souches, 6 filons d'or, moutons, ressources au sol, 4 outils |
| UI | bannières, 2 barres, 16 boutons, 4 curseurs, 2 papiers, rubans, épées, table en bois |

**Animations par unité humaine**

| Unité | Animations |
|---|---|
| Warrior | Idle, Run, Attack1, Attack2, **Guard** |
| Lancer | Idle, Run, **Attack et Defence sur 5 directions** (Up, UpRight, Right, DownRight, Down) |
| Archer | Idle, Run, Shoot, + flèche |
| Monk | Idle, Run, Heal, + effet de soin |
| Pawn | Idle et Run × (mains nues, hache, pioche, couteau, marteau, bois, or, viande) + 4 animations d'interaction |

**Le Lancier est la seule unité directionnelle du pack**, et la seule avec une pose de **Défense**. Ces deux propriétés doivent se retrouver dans ses règles : c'est l'unité qui tient une orientation et qui bloque. Sa capacité Repousse et son Élévation en Garde s'appuient directement là-dessus.

**Le Guerrier a deux attaques distinctes** (Attack1, Attack2) — de quoi différencier visuellement son attaque normale de sa Riposte au rang 3 de l'Ordre.

**Ancien pack CC0.** Le fichier `TS_old version` contient une version antérieure sous licence CC0, avec une faction gobeline complète (Torch, TNT, Barrel) et des bâtiments gobelins. Le style est légèrement différent de la version actuelle. **Ne pas mélanger les deux** : la cohérence visuelle vaut mieux que trois sprites de plus.

---

# PARTIE II — LISTING DES TÂCHES

**Convention.** Chaque tâche porte un identifiant (`C2.4`) : tu peux les citer directement à Claude Code (« fais C2.4 et C2.5 »). Les estimations sont en **heures de travail effectif**, soirées de 2 h.

---

## PHASE 0 — Fondations (16 h)

- [ ] **F0.1** Installer Godot 4.x et le SDK Android (JDK, SDK, clé de debug)
- [x] **F0.2** Créer le projet, verrouiller l'orientation paysage, résolution de référence 1280×720, mode d'étirement `canvas_items` / `keep`
- [x] **F0.3** Initialiser git + `.gitignore` Godot, dépôt privé
- [x] **F0.4** Écrire le `CLAUDE.md` à la racine : conventions de nommage, arborescence, règle « pas de valeurs en dur », règle « logique séparée du rendu »
- [x] **F0.5** Importer Tiny Swords, configurer le filtrage **Nearest** par défaut sur toutes les textures
- [x] **F0.6** Découper les spritesheets en `AtlasTexture` et `SpriteFrames` (script d'import automatique)
- [x] **F0.7** Créer les autoloads vides : `GameState`, `SaveManager`, `AudioManager`, `EventBus`
- [x] **F0.8** Mettre en place le framework de test (GUT) et un premier test qui passe
- [ ] **F0.9** Réussir un export APK de debug et l'installer sur ton téléphone — **avant d'écrire une ligne de gameplay**
- [x] **F0.10** Choisir et importer la police pixel, **afficher `ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸÆŒ àâäçéèêëîïôöùûüÿæœ` et vérifier chaque glyphe** — *Silver, vérifiée sur les 140 glyphes, réglée en pixel art et posée comme thème du projet. Reste le contrôle de rendu sur le téléphone.*
- [x] **F0.11** Créer `CREDITS.md` et y noter Tiny Swords + chaque asset complémentaire dès son téléchargement
- [x] **F0.12** Rapatrier les effets de particules du pack (2 poussières, 3 feux, 2 explosions, gerbe d'eau) et les nuages
- [ ] **F0.13** Installer Aseprite pour créer des couleurs de faction et composer les vignettes d'événement
- [x] **F0.14** Script d'import automatique : découper chaque PNG d'animation en `SpriteFrames` à partir de sa largeur / 64 (les feuilles font de 768 à 5120 px de large, le nombre d'images varie par animation)
- [x] **F0.15** Table de correspondance `data/assets.json` : nom logique → chemin de fichier, pour ne jamais coder un chemin en dur

> **Jalon 0 : un écran noir avec « Reconquête » s'affiche sur ton téléphone.**

---

## PHASE 1 — Moteur de combat (45 h)

*C'est le cœur. 40 % de la valeur du jeu. À faire parfaitement avant tout le reste.*

### Logique pure

- [x] **C1.1** Classe `Grid` : coordonnées, voisinage, distance, conversion monde ↔ grille
- [x] **C1.2** Classe `Tile` : type de terrain, occupant, propriétés (bloquant, mortel, modificateurs)
- [x] **C1.3** Classe `Unit` : PV, déplacement, portée, dégâts, camp, état
- [x] **C1.4** Calcul des cases de déplacement atteignables (parcours en largeur avec coût)
- [x] **C1.5** Ligne de vue et calcul des cases attaquables
- [x] **C1.6** Résolution d'une attaque : dégâts, modificateurs de terrain, mort
- [x] **C1.7** Système de poussée : direction, case de destination, collision, chute dans l'eau
- [ ] **C1.8** Machine à états de tour : tour joueur → télégraphe → tour ennemi → vérification victoire
- [ ] **C1.9** Système de télégraphe : chaque ennemi calcule et publie son intention
- [ ] **C1.10** IA ennemie de base : choix de cible, pathfinding, comportement par rôle
- [ ] **C1.11** Conditions de victoire et de défaite (les 6 types d'objectif)
- [x] **C1.12** RNG à graine, journalisable et rejouable
- [ ] **C1.13** Pile d'annulation (undo) tant que le tour n'est pas validé
- [~] **C1.14** **Tests unitaires** : déplacement, poussée dans l'eau, ligne de vue, cohérence du télégraphe, fin de combat — *faits pour C1.1 à C1.7 et C1.12 ; restent le télégraphe et la fin de combat*

### Rendu et interaction

- [ ] **C1.15** Scène `Combat` : TileMap de terrain, couche d'unités, caméra
- [ ] **C1.16** Affichage des cases valides (surbrillance déplacement / attaque)
- [ ] **C1.17** Contrôles tactiles : tap, tap long, pincement, glissement de caméra
- [ ] **C1.18** Prévisualisation fantôme avant validation
- [ ] **C1.19** Animations d'unité : repos, marche, attaque, dégât, mort
- [ ] **C1.20** Rendu du télégraphe : icônes et zones de menace lisibles
- [ ] **C1.21** HUD de combat : PV, tour en cours, objectif, bouton Fin de tour, bouton Annuler
- [ ] **C1.22** Séquence d'animation du tour ennemi (résolution ordonnée, pas simultanée)

### Contenu de base

- [ ] **C1.23** Définir les 4 classes de héros en données (`.tres`)
- [ ] **C1.24** Implémenter les 4 capacités : Provocation, Tir tendu, Repousse, Bénédiction
- [ ] **C1.25** Définir 6 ennemis de l'Acte I en données
- [ ] **C1.26** Éditeur de carte de combat (ou format JSON + 8 cartes écrites à la main) — *le format texte est en place : `CombatBoard.from_rows`, un caractère par case, symboles dans `terrain.json`*

> **Jalon 1 : un combat complet et satisfaisant, jouable au doigt sur ton téléphone.**
> **C'est ici qu'il faut s'arrêter et jouer 20 fois avant de continuer.**

---

## PHASE 2 — Héros, Ordre et persistance (40 h)

- [ ] **H2.1** Classe `Hero` persistante : identité, classe, niveau, XP, blessures, équipement
- [ ] **H2.2** Générateur de noms (liste de 120)
- [ ] **H2.3** Système de traits : définir 20 traits en données + application des effets
- [ ] **H2.4** XP et montée de niveau, avec les choix aux niveaux 3 et 6
- [ ] **H2.5** Système de blessures : accumulation, effets, indisponibilité, mort
- [ ] **H2.6** Équipement : 3 emplacements, application des effets, ~30 objets en données
- [ ] **H2.7** Écran de fiche de héros
- [ ] **H2.8** Écran de roster : liste, tri, sélection de l'escouade
- [ ] **H2.9** Écran Mémorial
- [ ] **H2.10** `SaveManager` : sérialisation JSON, chargement, versionnage, migration
- [ ] **H2.11** Sauvegarde automatique + sauvegarde de secours
- [ ] **H2.12** Tests : sauvegarde/chargement d'un état complet, montée de niveau, seuils de blessure

### L'Ordre

- [ ] **H2.13** Générateur de candidats : classe, nom, trait, couleur, qualité — pondération par niveau de Caserne
- [ ] **H2.14** Système de qualité (Commun / Aguerri / Élite) et effets sur les statistiques de départ
- [ ] **H2.15** Modèle de données `Ordre` : 4 pistes, versements cumulés, rangs atteints
- [ ] **H2.16** Versement d'un candidat non recruté, avec possibilité de tout verser
- [ ] **H2.17** Retraite : verser un héros du roster, barème par niveau
- [ ] **H2.18** Application **rétroactive** des bonus de rang à tous les héros de la classe, présents et futurs
- [ ] **H2.19** Les 4 secondes capacités de classe : Riposte, Barrage, Charge, Relève
- [ ] **H2.20** Les 8 spécialisations d'Élévation, en données
- [ ] **H2.21** Rituel d'Élévation : vérification des conditions (héros nv 5 + classe rang 5), écran de choix, irréversibilité
- [ ] **H2.22** Marqueur visuel d'un héros élevé (couleur de faction + élément d'UI du pack)
- [ ] **H2.23** Écran de l'Ordre : 4 pistes, progression, prochains paliers, aperçu des gains
- [ ] **H2.24** Tests : rétroactivité des bonus, franchissement des seuils, Élévation, barème de retraite

---

## PHASE 3 — Ville et économie (40 h)

- [ ] **V3.1** Modèle de données `City` : parcelles, emplacements, bâtiments, pions
- [ ] **V3.2** Les 4 ressources, production, consommation, stockage
- [ ] **V3.3** Les 10 bâtiments en données, 3 niveaux, coûts et effets
- [ ] **V3.4** Système de pions : assignation aux postes, production par saison
- [ ] **V3.5** Résolution de fin de saison : production, consommation de vivres, malus d'hiver
- [ ] **V3.6** Jauge de Menace : accumulation, affichage, prévision de vague
- [ ] **V3.7** Scène `Ville` : rendu des parcelles et bâtiments avec les sprites du pack
- [ ] **V3.8** Interaction de construction : sélection d'emplacement, menu, prévisualisation fantôme, confirmation
- [ ] **V3.9** Interface d'assignation des pions (glisser-déposer)
- [ ] **V3.10** Fonctions de la Caserne : Convocation, recrutement, versement
- [ ] **V3.11** Fonctions du Monastère : soin des blessures
- [ ] **V3.12** Fonctions de la Forge : fabrication et amélioration d'équipement
- [ ] **V3.13** HUD de ville : ressources, saison, année, Menace, bouton Partir en expédition
- [ ] **V3.14** Tests d'économie : simuler 20 saisons et vérifier que les courbes tiennent
- [ ] **V3.15** Ressource **Renom** : sources de gain, stockage, affichage au HUD
- [ ] **V3.16** Écran de **Convocation** : coût, présentation des candidats côte à côte, recrutement ou versement, choix de classe garantie au niveau 3
- [ ] **V3.17** Test d'économie du Renom : simuler 40 saisons, vérifier qu'on atteint 2 rangs 5 et pas 4

---

## PHASE 4 — Carte de région et expéditions (30 h)

- [ ] **R4.1** Modèle de données `RegionMap` : parcelles, adjacence, états, verrous
- [ ] **R4.2** Définir les 12 parcelles de l'Acte I en données
- [ ] **R4.3** Brouillard de guerre à trois états, révélation par adjacence et Tour de guet
- [ ] **R4.4** Scène `Carte` : rendu, défilement, sélection de parcelle
- [ ] **R4.5** Panneau d'information de parcelle : type, difficulté, récompense, verrou
- [ ] **R4.6** Générateur de chaîne d'expédition (2–4 nœuds, embranchements)
- [ ] **R4.7** Scène `Expédition` : affichage de la chaîne, progression, nœud courant
- [ ] **R4.8** Nœud Camp : soin, coût
- [ ] **R4.9** Nœud Cache : butin, pièges
- [ ] **R4.10** Abandon d'expédition
- [ ] **R4.11** Écran de butin de fin d'expédition (avec animation de gain — moment de plaisir, ne pas le bâcler)
- [ ] **R4.12** Prise de parcelle : déblocage des emplacements et postes, +2 Menace
- [ ] **R4.13** Enchaînement complet Ville → Carte → Expédition → Ville

> **Jalon 2 : la boucle complète tourne. Le jeu existe.**

---

## PHASE 5 — Contre-attaque (20 h)

- [ ] **S5.1** Déclencheur de siège tous les 4 saisons
- [ ] **S5.2** Grille de siège 10×8 générée à partir de la ville réelle du joueur
- [ ] **S5.3** Bâtiments comme entités de combat : PV, destruction, effets
- [ ] **S5.4** Tours de guet qui tirent automatiquement
- [ ] **S5.5** Murs bloquants et destructibles, créneaux au niveau 3
- [ ] **S5.6** Système de vagues : arrivée par les bords, composition selon la Menace
- [ ] **S5.7** Objectif « tenir 6 tours », condition de défaite (Château détruit)
- [ ] **S5.8** Conséquences de la défaite : bâtiments détruits, pions morts, parcelle perdue
- [ ] **S5.9** Écran d'avertissement avant le siège avec estimation de la vague
- [ ] **S5.10** Ambiance visuelle spécifique au siège (nuit, torches, ciel rouge)

---

## PHASE 6 — Narration et événements (30 h)

- [ ] **N6.1** Format de données des cartes d'événement (JSON : texte, sprite, choix, conditions, effets)
- [ ] **N6.2** Moteur d'événement : évaluation des conditions, application des effets
- [ ] **N6.3** Scène `Carte d'événement` avec sa mise en page
- [ ] **N6.3b** Saisir les **10 cartes de référence** en JSON et s'en servir de jeu de test du moteur
- [ ] **N6.4** Écrire **30 événements** pour l'Acte I, **en respectant la règle de voix du § 7.3**
- [ ] **N6.5** Écrire **40 événements** pour l'Acte II
- [ ] **N6.6** Écrire **20 événements** pour l'Acte III
- [ ] **N6.7** Écrans de transition d'acte
- [ ] **N6.8** Fragments de lore dans les caches (le mystère de la Citadelle)
- [ ] **N6.9** Textes de fin (victoire, défaite définitive)
- [ ] **N6.10** Relecture orthographique complète (**important** — les fautes détruisent la crédibilité d'un jeu payant)

---

## PHASE 7 — Contenu complet (50 h)

- [ ] **X7.1** 18 parcelles de l'Acte II
- [ ] **X7.2** 10 parcelles de l'Acte III
- [ ] **X7.3** 12 ennemis supplémentaires (Actes II et III) : Serpent, Araignée, Tortue, Lézard, Gnoll, Chauve-souris, Bourdon, Minotaure, Panda, Gobelin sorcier, Boompuff, Chevalier-mouton
- [ ] **X7.4** États persistants requis par le bestiaire : poison, feu au sol, métamorphose, invulnérabilité alternée, épines
- [ ] **X7.5** Structures ennemies : hutte gobeline, maison de troll, tour à canon, et **grotte comme point d'apparition** (objectif « détruire la grotte »)
- [ ] **X7.6** Boss final scénarisé
- [ ] **X7.7** 25 cartes de combat supplémentaires
- [ ] **X7.8** Niveaux 2 et 3 de tous les bâtiments
- [ ] **X7.9** Équipement rare (~20 objets)
- [ ] **X7.10** Conditions de fin de partie et écran de victoire

---

## PHASE 8 — Polish et juice (42 h)

- [ ] **P8.1** Hit stop à l'impact (80 ms)
- [ ] **P8.2** Screen shake paramétrable
- [ ] **P8.3** Nombres de dégâts flottants
- [ ] **P8.4** Flottement des sprites au repos
- [ ] **P8.5** Ombres portées sous les unités (le pack fournit `Shadow.png`)
- [ ] **P8.5b** Effet de mort universel : flash blanc, fondu, poussière — et gerbe d'eau pour les chutes
- [ ] **P8.6** Système de particules poolé, **à partir des effets fournis par le pack** (poussière, feu, explosion, gerbe d'eau) + étincelles maison
- [ ] **P8.7** Eau animée **avec la tuile de vagues du pack** + shader de scintillement
- [ ] **P8.8** Parallaxe sur 2 couches **avec les nuages du pack**
- [ ] **P8.9** Punch de caméra pendant les attaques
- [ ] **P8.10** Transitions de scène
- [ ] **P8.11** Animations d'interface (apparition des panneaux, compteurs qui défilent)
- [ ] **P8.12** Teinte de saison (printemps/été/automne/hiver) sur la vue de ville
- [ ] **P8.13** Cohérence visuelle de l'UI à partir des éléments du Free Pack
- [ ] **P8.14** Retour haptique sur les actions importantes (vibration légère)
- [ ] **P8.15** Intégrer 3 pistes musicales
- [~] **P8.16** Intégrer ~25 effets sonores (Kenney RPG Audio / UI Audio, CC0) — *232 sons CC0 installés, 27 affectés dans `data/audio.json`, 8 manques nommés. Reste à jouer réellement (P8.15/P8.17) et à valider les affectations à l'oreille.*
- [ ] **P8.16b** Rassembler 60 à 80 icônes (game-icons.net) et les remapper dans la palette Tiny Swords
- [ ] **P8.16c** Recadrer des portraits de héros depuis les fichiers Aseprite du pack
- [ ] **P8.17** Mixage : volumes séparés musique/effets, réglages dans les options
- [ ] **P8.18** **Animation de Convocation** : révélation des candidats un par un, éclat particulier sur un Élite. C'est le petit plaisir de chaque saison — il doit briller, ne pas le bâcler.
- [ ] **P8.19** Cérémonie d'Élévation : transition, changement de couleur, fanfare

---

## PHASE 9 — Systèmes annexes (20 h)

- [ ] **A9.1** Menu principal (nouvelle partie, continuer, mémorial, options, crédits)
- [ ] **A9.2** Écran d'options : volumes, vitesse d'animation, secousse d'écran on/off, langue
- [ ] **A9.3** Tutoriel contextuel intégré aux 3 premières saisons (pas de tutoriel séparé)
- [ ] **A9.4** Codex : bestiaire, bâtiments, règles — consultable à tout moment
- [ ] **A9.5** Gestion de la pause / mise en arrière-plan Android
- [ ] **A9.6** Écran de crédits (y compris Pixel Frog — non obligatoire mais c'est la moindre des choses)
- [ ] **A9.7** Localisation : externaliser 100 % des textes en fichiers de traduction dès le début, même si tu ne sors qu'en français
- [ ] **A9.8** Mode « Fer » optionnel (défaite définitive)

---

## PHASE 10 — Équilibrage et tests (42 h)

- [ ] **T10.1** Console de debug interne : donner des ressources, sauter une saison, forcer un siège, tuer un héros
- [ ] **T10.2** Simulateur de combat automatique (1000 combats, taux de victoire par carte)
- [ ] **T10.3** **Terminer la campagne complète toi-même, au moins 3 fois**
- [ ] **T10.4** Ajuster la courbe économique selon les mesures
- [ ] **T10.5** Ajuster la difficulté des combats par acte
- [ ] **T10.6** Ajuster la courbe de Menace et la taille des sièges
- [ ] **T10.7** Ajuster les gains de Renom et les seuils de l'Ordre — vérifier qu'on atteint le premier rang 5 vers la saison 20
- [ ] **T10.8** Faire tester par 5 personnes extérieures, les regarder jouer sans rien dire
- [ ] **T10.9** Corriger les points de blocage constatés (il y en aura, et ce ne seront pas ceux que tu attends)
- [ ] **T10.10** Tests sur au moins 3 tailles d'écran et un téléphone d'entrée de gamme
- [ ] **T10.11** Profilage des performances, optimisation des points chauds
- [ ] **T10.12** Test de la consommation de batterie sur une session de 30 minutes

---

## PHASE 11 — Publication (15 h)

- [ ] **B11.1** Créer le compte développeur Google Play (25 $, une fois, délai de vérification d'identité à anticiper)
- [ ] **B11.2** Générer la clé de signature de release et **la sauvegarder en trois endroits** (la perdre = ne plus jamais pouvoir mettre à jour le jeu)
- [ ] **B11.3** Icône d'application (toutes tailles) et bannière de la fiche
- [ ] **B11.4** 8 captures d'écran soignées + une vidéo de 30 s
- [ ] **B11.5** Rédiger la fiche Play Store (titre, description courte, description longue)
- [ ] **B11.6** Politique de confidentialité (obligatoire, même sans collecte de données) hébergée sur une URL publique
- [ ] **B11.7** Remplir le questionnaire de classification par âge et la déclaration de sécurité des données
- [ ] **B11.8** Build AAB de release, test en piste interne
- [ ] **B11.9** Test fermé avec ~12 testeurs (Google l'exige désormais pour les nouveaux comptes personnels — **prévoir plusieurs semaines**)
- [ ] **B11.10** Publication en production
- [ ] **B11.11** Vérifier les conditions de la licence Tiny Swords dans le fichier fourni avec le pack

---

## Récapitulatif de charge

| Phase | Heures |
|---|---|
| 0 — Fondations | 16 |
| 1 — Combat | 45 |
| 2 — Héros et Ordre | 40 |
| 3 — Ville | 40 |
| 4 — Carte & expéditions | 30 |
| 5 — Contre-attaque | 20 |
| 6 — Narration | 30 |
| 7 — Contenu | 50 |
| 8 — Polish | 42 |
| 9 — Annexes | 20 |
| 10 — Équilibrage | 42 |
| 11 — Publication | 15 |
| **Total** | **390 h** |

**Traduction en calendrier réel :**

| Rythme | Durée |
|---|---|
| 3 soirées de 2 h par semaine | ~15 mois |
| 5 soirées de 2 h par semaine | ~10 mois |
| 5 soirées + 4 h le week-end | ~7 mois |

Ces chiffres supposent que Claude Code écrit l'essentiel du code. Ton temps va surtout aux **décisions, aux tests et à l'équilibrage** — c'est-à-dire aux phases 1, 8 et 10, qui pèsent à elles seules un tiers du total.

**Ajoute 20 % de marge.** Tout le monde sous-estime, y compris moi.

---

## Règles de travail avec Claude Code

1. **Un `CLAUDE.md` à la racine**, tenu à jour : conventions, arborescence, décisions de design déjà prises. C'est ce qui évite que le code parte dans quatre directions selon les sessions.
2. **Une tâche = une session = un commit.** Ne jamais demander « fais la phase 3 ». Demander « fais V3.4 ».
3. **Exiger des tests sur toute logique pure.** C'est le seul moyen d'attraper les bugs que je ne peux pas voir puisque je ne joue pas.
4. **Toujours committer avant de lancer une grosse modification.** Pouvoir revenir en arrière vaut mieux que tout débat.
5. **Décrire les problèmes de ressenti en termes concrets.** Pas « c'est mou » mais « il y a 400 ms entre le tap et le début de l'animation, et l'unité glisse au lieu de marcher ».
6. **Ne jamais laisser une phase à 90 %.** Le contenu à moitié fini est ce qui tue les projets, pas le contenu manquant.

---

## Les trois vrais risques

**1. L'abandon vers le mois 4.** Le moment où la nouveauté est passée et où la fin n'est pas en vue. La parade : le Jalon 1 doit être *amusant* tout seul. Si le combat est bon, tu auras envie d'y revenir. S'il ne l'est pas, arrête-toi et corrige-le avant d'aller plus loin — construire une ville par-dessus un combat médiocre, c'est perdre 300 heures.

**2. Le gonflement du contenu.** Chaque bonne idée en fait naître trois. Tiens un fichier `plus-tard.md` et **mets tout dedans**. Rien n'entre dans le périmètre en cours de route.

**3. L'équilibrage.** Personne ne le réussit du premier coup. C'est pour ça que la phase 10 pèse 40 heures et que la console de debug (T10.1) est la première tâche de la phase — sans elle, tu passerais des heures à rejouer pour tester une seule valeur.
