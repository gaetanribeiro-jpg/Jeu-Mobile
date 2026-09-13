# Tiny Swords — à copier à la main

**Ces fichiers ne sont pas dans le dépôt.** La licence de Pixel Frog
autorise l'usage commercial et la modification, mais **interdit la
redistribution des fichiers, même modifiés**. Chaque poste de travail doit
donc copier le pack lui-même.

## Où mettre quoi

| Archive | Dossier à copier | Destination |
|---|---|---|
| `Tiny Swords (Free Pack).zip` | le dossier `Tiny Swords (Free Pack)/` | `assets/tiny_swords/free/` |
| `Tiny Swords (Enemy Pack).zip` | le **sous-dossier** `Enemy Pack/` | `assets/tiny_swords/enemy/` |

Attention au second : dans l'archive, le contenu utile est sous
`Tiny Swords (Enemy Pack)/Enemy Pack/`, pas à la racine.

Après copie, `assets/tiny_swords/free/` doit contenir directement
`Units/`, `Buildings/`, `Terrain/`, `UI Elements/`, `Particle FX/`, et
`assets/tiny_swords/enemy/` doit contenir directement `Bear/`, `Troll/`,
`Extra/`, etc.

## Vérifier

```bash
godot --headless --path . --import
godot --headless --path . -s tools/verify_assets.gd
```

Attendu : **535 entrées vérifiées, 0 manquante, 0 incohérente**. L'outil
nomme chaque fichier qu'il ne trouve pas — s'il en liste beaucoup, c'est
presque toujours un niveau de dossier en trop ou en moins.

## L'ancien pack « Update 010 »

Il existe une version antérieure, sous licence CC0, avec une arborescence
entièrement différente (`Factions/`, `Deco/`, `Effects/`). **Ne pas
l'installer** : le § 16 de la conception dit de ne pas mélanger les deux
styles, et aucun chemin de `data/assets.json` ne lui correspond.
