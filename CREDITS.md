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

> **C'est le seul point bloquant pour la publication.** Le § 13.7 est
> explicite : une licence CC BY oubliée est une infraction, pas un détail,
> et le § 13.2 met en garde contre le CC BY-SA si le jeu est vendu. Ces
> trois pistes sont installées et jouables, mais elles ne peuvent pas
> partir en production tant que ces lignes ne sont pas remplies.
>
> Il faut, pour chacune : l'URL de la page d'origine, le nom de l'auteur,
> et la licence exacte. Si l'une est en CC BY-SA, il vaut mieux la
> remplacer maintenant que d'y revenir après avoir monté tout le mixage.

**Format.** Les trois sont en MP3, dont deux à 128 kbps. Le § 13.2
recommande l'OGG, qui boucle sans le micro-silence du MP3. Je ne les ai
**pas** converties : transcoder du MP3 128 kbps vers de l'OGG, c'est une
seconde perte sur une qualité déjà modeste. Quand la page d'origine sera
retrouvée pour la licence, prendre l'OGG ou le WAV s'il y en a un.

---

## Icônes

| Élément | Auteur | Licence | Ajouté le |
|---|---|---|---|
| *(rien pour l'instant)* | | | |

game-icons.net est en **CC BY 3.0** : l'attribution sera obligatoire et
devra nommer chaque auteur d'icône utilisée. Noter le nom de l'auteur
icône par icône au fur et à mesure, pas à la fin.
