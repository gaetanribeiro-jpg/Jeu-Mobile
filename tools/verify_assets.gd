extends SceneTree

## Vérifie `data/assets.json` contre les fichiers réellement présents.
##
##     godot --headless --path . -s tools/verify_assets.gd
##
## À lancer après avoir copié le pack, et après chaque mise à jour de
## Pixel Frog. Contrôle trois choses par entrée :
##   1. le fichier existe au chemin annoncé ;
##   2. la largeur du PNG vaut bien frames × frame ;
##   3. la hauteur vaut frame — le cadre du pack est carré.
##
## Sort en code 1 s'il y a le moindre écart, pour pouvoir être branché
## sur une vérification automatique plus tard.

var _missing: Array[String] = []
var _mismatched: Array[String] = []
var _checked := 0


func _init() -> void:
	var entries := AssetTable.all_entries()
	print("Vérification de %d entrées déclarées dans data/assets.json…\n" % entries.size())

	for entry: Dictionary in entries:
		_check(entry)

	print("")
	print("Entrées vérifiées : %d" % _checked)
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
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path):
		_missing.append("%s → %s" % [entry["id"], path])
		return

	_checked += 1

	# Les bâtiments sont des images fixes : on contrôle w et h tels quels.
	if entry.has("w"):
		_check_size(entry, absolute, int(entry["w"]), int(entry["h"]))
		return

	var frames := int(entry.get("frames", 1))
	var frame := int(entry.get("frame", 0))
	if frame <= 0:
		return
	_check_size(entry, absolute, frames * frame, frame)


func _check_size(entry: Dictionary, absolute: String, expected_w: int, expected_h: int) -> void:
	var image := Image.load_from_file(absolute)
	if image == null:
		_mismatched.append("%s → image illisible" % entry["id"])
		return
	var size := image.get_size()
	if size.x != expected_w or size.y != expected_h:
		_mismatched.append(
			"%s → attendu %dx%d, trouvé %dx%d (%s)"
			% [entry["id"], expected_w, expected_h, size.x, size.y, entry["path"]]
		)
