# Crédits et licences

Tenu à jour **au moment du téléchargement**, jamais après coup (règle § 13.7
de `docs/conception.md`). Chaque ligne : quoi, qui, quelle licence, quand.

---

## Moteur et outils

| Élément | Auteur | Licence | Ajouté le |
|---|---|---|---|
| Godot Engine 4.6-stable | Godot Engine contributors | MIT | 2026-08-28 |
| GUT 9.5.0 (`addons/gut/`) | Tom « Butch » Wesley | MIT | 2026-08-28 |

GUT est versionné dans le dépôt (`addons/gut/LICENSE.md` conservé intact).

---

## Graphismes

| Élément | Auteur | Licence | Ajouté le |
|---|---|---|---|
| Tiny Swords — Free Pack | Pixel Frog | Usage commercial et modification autorisés, **redistribution des fichiers interdite même modifiés** | 2026-08-29 |
| Tiny Swords — Enemy Pack | Pixel Frog | idem (pack payant, 9,75 $) | 2026-08-29 |
| UI Pack — Adventure (`assets/kenney/widgets/`) | Kenney (kenney.nl) | **CC0 1.0** — domaine public | 2026-09-01 |
| 18 icônes de compétences (`assets/gameicons/abilities/`) | game-icons.net — Lorc (14), Delapouite (3), Caro Asercion (1) | **CC BY 3.0** — attribution OBLIGATOIRE | 2026-09-01 |

**C'est la seule ligne du projet où l'attribution est une OBLIGATION et pas
une politesse.** CC0 n'en demande aucune ; CC BY 3.0 en exige une. Les
auteurs sont donc nommés ci-dessus et dans `assets/gameicons/LICENSE-gameicons.txt`,
conservé intact. Si le jeu sortait un jour de son cadre personnel, cette
mention devrait apparaître à l'écran, pas seulement dans ce fichier.

Icônes retenues : `sword-wound`, `broadsword`, `shouting`, `axe-swing`,
`mantrap`, `bow-arrow`, `broadhead-arrow`, `jump-across`, `arrow-cluster`,
`chained-arrow-heads`, `magic-swirl`, `fireball`, `snowflake-1`,
`sinusoidal-beam`, `snowing`, `health-potion`, `round-potion`, `fire-bomb`.

Le fond noir de chaque SVG a été retiré à l'import — c'est la seule
modification, et CC BY l'autorise expressément.

**Les assets Kenney SONT dans le dépôt, contrairement à Tiny Swords**, et la
différence est la licence : CC0 autorise la redistribution, Pixel Frog
l'interdit même modifiée. Un clone neuf dessine donc déjà ses barres de
défilement et ses cases à cocher, là où il lui manque tout le reste.

On n'a repris que **cinq fichiers** — barre de défilement, trois cases à
cocher — c'est-à-dire strictement ce que Tiny Swords ne dessine pas. Le
reste des packs Kenney (boutons, panneaux, bordures, curseurs) ferait
doublon avec Tiny Swords dans un autre style, et le § 16 a déjà tranché ce
genre de mélange : « ne pas mélanger les deux, le style diffère ». La
règle qui en découle, et qui autorise l'exception ci-dessus : **on ne
mélange que là où le premier pack ne dessine rien.**

CC0 ne demande aucune attribution ; cette ligne existe parce que le
fichier existe, pas parce que la licence l'exige.

410 PNG dans le Free Pack, 138 dans l'Enemy Pack, plus 60 fichiers Aseprite.

L'ancien pack **« Tiny Swords (Update 010) », sous licence CC0, n'est pas
installé** — décision du § 16 : ne pas mélanger les deux, le style diffère.
Il reste disponible si un besoin précis se présente, mais il porte une
arborescence entièrement différente et ne correspond à aucun chemin de
`data/assets.json`.

> **Conséquence directe :** les fichiers du pack ne sont **pas** committés.
> `assets/tiny_swords/free/` et `assets/tiny_swords/enemy/` sont dans le
> `.gitignore`. Chaque poste de travail copie le pack à la main.

Crédit non obligatoire pour Tiny Swords, mais il figurera à l'écran des
crédits (tâche A9.6) — c'est la moindre des choses.

---

## Police

| Élément | Auteur | Licence | Ajouté le |
|---|---|---|---|
| Silver | Poppy Works | **à confirmer** — vérifier le fichier de licence fourni avec la police | 2026-08-29 |

`tools/verify_font.gd` confirme que Silver couvre les 136 glyphes
indispensables **et** les 4 glyphes de confort. C'était la recommandation
du § 13.4, et elle tient. Reste le contrôle de rendu à l'œil, sur le
téléphone : `scenes/ui/font_test.tscn`.

> **À faire avant publication :** noter la licence exacte de Silver. Poppy
> Works la distribue via itch.io ; le texte de licence accompagne le
> téléchargement.

---

## Audio

### Effets sonores — réglé

| Élément | Auteur | Licence | Ajouté le |
|---|---|---|---|
| Kenney — RPG Audio (51 sons) | Kenney Vleugels, kenney.nl | **CC0** | 2026-08-29 |
| Kenney — UI Audio (51 sons) | Kenney Vleugels, kenney.nl | **CC0** | 2026-08-29 |
| Kenney — Impact Sounds (130 sons) | Kenney Vleugels, kenney.nl | **CC0** | 2026-08-29 |

CC0 : aucune attribution obligatoire, mais Kenney sera cité à l'écran des
crédits. Le texte de licence de chaque paquet est conservé tel quel dans
`assets/audio/sfx/*/LICENSE.txt`. Les 232 sons sont en **OGG**, le format
que le § 13.2 recommande, et ils sont versionnés : la licence l'autorise.

### Musique — LICENCES À ÉTABLIR

| Fichier | Ce que le fichier déclare | Licence | Source |
|---|---|---|---|
| `music/town_theme.mp3` (`TownTheme.mp3`) | aucune métadonnée | **inconnue** | **à fournir** |
| `music/battle_theme.mp3` (`Battle.mp3`) | auteur « Theodore Kerr », 2012 | **inconnue** | **à fournir** |
| `music/boss_theme.mp3` (`bosstheme_WO_low.mp3`) | aucun auteur, encodé sous FL Studio | **inconnue** | **à fournir** |

> **Statut : non bloquant.** Décision de Gaetan, 2026-08-29 — *Reconquête*
> est un projet personnel, qui ne sera ni vendu ni publié publiquement.
> Un usage strictement privé ne met en jeu aucune des licences ci-dessus.
>
> **Ce que ça ne change pas.** Le jour où le jeu sortirait du cadre privé —
> une release sur itch.io, un APK envoyé à un ami, une vidéo publiée — ces
> trois lignes redeviennent bloquantes, et il faudra pour chacune l'URL
> d'origine, l'auteur et la licence exacte. Le § 13.2 met en garde contre
> le CC BY-SA en cas de vente. C'est pour ça que ce tableau reste ici,
> rempli à moitié, plutôt que d'être effacé : le jour où la question se
> reposera, elle se reposera avec ses trois cases vides bien visibles.

**Format.** Les trois sont en MP3, dont deux à 128 kbps. Le § 13.2
recommande l'OGG, qui boucle sans le micro-silence du MP3. Je ne les ai
**pas** converties : transcoder du MP3 128 kbps vers de l'OGG, c'est une
seconde perte sur une qualité déjà modeste. Si une piste boucle mal en
jeu, le réglage `loop_offset` de Godot corrige le micro-silence sans
retoucher au fichier.

---

## Icônes

| Élément | Auteur | Licence | Ajouté le |
|---|---|---|---|
| *(rien pour l'instant)* | | | |

game-icons.net est en **CC BY 3.0** : l'attribution sera obligatoire et
devra nommer chaque auteur d'icône utilisée. Noter le nom de l'auteur
icône par icône au fur et à mesure, pas à la fin.
