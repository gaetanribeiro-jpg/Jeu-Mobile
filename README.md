# Reconquête

Jeu mobile Android : tactique au tour par tour + gestion de comté.
Godot 4.6, GDScript, orientation paysage verrouillée.

- **Conception complète** → `docs/conception.md`
- **Règles de travail** → `CLAUDE.md`
- **Licences des assets** → `CREDITS.md`

## Démarrer

```bash
# 1. Copier le pack Tiny Swords (non versionné, licence oblige) :
#    assets/tiny_swords/free/   et   assets/tiny_swords/enemy/
# 2. Importer et lancer :
godot --headless --path . --import
godot --path .
```

## Tests

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit
```

Toute la logique de `engine/` est testable sans moteur graphique : aucune
de ces classes ne connaît Godot au-delà de GDScript lui-même.
