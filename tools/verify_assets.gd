extends SceneTree

## Vérifie `data/assets.json` contre les fichiers réellement présents.
##
##     godot --headless --path . -s tools/verify_assets.gd
##
## À lancer après avoir copié le pack, et après chaque mise à jour de
## Pixel Frog. Contrôle deux choses par entrée :
##   1. le fichier existe au chemin annoncé ;
##   2. ses dimensions réelles sont exactement celles que la table annonce,
##      selon son `kind` — `frames × frame_w` pour une bande, `columns ×
##      cell_w` pour un atlas, `w × h` pour une image.
##
## Sort en code 1 s'il y a le moindre écart. C'est cet outil qui a démasqué
## les 28 entrées que la table décrivait comme des bandes de cadres carrés
## alors qu'elles étaient des tilesets, des planches d'UI ou, pour la tour
## pirate sur l'eau, une animation à cadres rectangulaires.

var _missing: Array[String] = []
var _mismatched: Array[String] = []
var _by_kind := {}
var _checked := 0


func _init() -> void:
	var entries := AssetTable.all_entries()
	print("Vérification de %d entrées déclarées dans data/assets.json…\n" % entries.size())

	for entry: Dictionary in entries:
		_check(entry)

	print("Entrées vérifiées : %d" % _checked)
	for kind: String in _by_kind.keys():
		print("  %-6s : %d" % [kind, _by_kind[kind]])
	print("Fichiers manquants : %d" % _missing.size())
	print("Dimensions incohérentes : %d" % _mismatched.size())

	for line: String in _missing:
		print("  MANQUANT   %s" % line)
	for line: String in _mismatched:
		print("  DIMENSIONS %s" % line)

	if _missing.is_empty() and _mismatched.is_empty():
		print("\nLa table est conforme au pack installé.")
		quit(0)
	else:
		print("\nLa table ne correspond pas au pack installé.")
		quit(1)


func _check(entry: Dictionary) -> void:
	var path: String = entry["path"]
	if not FileAccess.file_exists(path):
		_missing.append("%s → %s" % [entry["id"], path])
		return

	_checked += 1
	var kind := String(entry.get("kind", "image"))
	_by_kind[kind] = int(_by_kind.get(kind, 0)) + 1

	var expected := AssetTable.pixel_size(entry)
	if expected.x <= 0 or expected.y <= 0:
		_mismatched.append("%s → la table n'annonce aucune dimension" % entry["id"])
		return

	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		_mismatched.append("%s → image illisible" % entry["id"])
		return

	var size := image.get_size()
	if size.x != expected.x or size.y != expected.y:
		_mismatched.append(
			"%s (%s) → attendu %dx%d, trouvé %dx%d (%s)"
			% [entry["id"], kind, expected.x, expected.y, size.x, size.y, entry["path"]]
		)
