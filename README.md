# ⚔️ Tiny Kingdoms

Jeu mobile Android : Tactical RPG de gestion et d'exploration. Construis
ton royaume, développe tes héros, explore un monde dangereux et mène
toi-même tes compagnons dans des combats au tour par tour fondés sur les
PA, les PM et le positionnement.

Godot 4.6, GDScript, orientation paysage verrouillée.

- **Vision fondatrice** → `docs/vision.md`
- **État du chantier et plan de migration** → `docs/etat-des-lieux.md`
- **Installer et exporter sur le téléphone** → `docs/installation.md`
- **Règles de travail** → `CLAUDE.md`
- **Licences des assets** → `CREDITS.md`
- **Conception précédente (« Reconquête », caduque sauf son annexe
  d'assets)** → `docs/conception.md`

## Démarrer

```bash
# 1. Copier le pack Tiny Swords — non versionné, la licence l'interdit.
#    Instructions : assets/tiny_swords/README.md
# 2. Importer DEUX FOIS (le premier passage se plaint de la police, c'est
#    l'ordre d'import du thème ; le second est propre) :
godot --headless --path . --import
godot --headless --path . --import
# 3. Lancer :
godot --path .
```

## Tests

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit
```

Toute la logique de `engine/` est testable sans moteur graphique : aucune
de ces classes ne connaît Godot au-delà de GDScript lui-même.
