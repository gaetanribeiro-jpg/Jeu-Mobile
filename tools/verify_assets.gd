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
var _miscut: Array[String] = []
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
	print("Découpages suspects  : %d" % _miscut.size())

	for line: String in _missing:
		print("  MANQUANT   %s" % line)
	for line: String in _mismatched:
		print("  DIMENSIONS %s" % line)
	for line: String in _miscut:
		print("  DÉCOUPAGE  %s" % line)

	if _missing.is_empty() and _mismatched.is_empty() and _miscut.is_empty():
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
		return
	if kind == String(AssetTable.KIND_STRIP):
		_check_cuts(entry, image)


## LE TOTAL PEUT TOMBER JUSTE ET LE DÉCOUPAGE ÊTRE FAUX.
##
## C'est arrivé, et rien ne l'a vu : deux arbres étaient déclarés en 6
## images de 256 px alors qu'ils en font 8 de 192. Or 6 × 256 = 8 × 192 =
## 1536 — le contrôle de dimensions ci-dessus était donc SATISFAIT, et
## chaque image contenait un arbre entier plus une tranche de son voisin.
## L'écran de titre montrait des arbres coupés en deux.
##
## CE QUI TRAHIT UN MAUVAIS DÉCOUPAGE : les coupes tombent dans le dessin
## au lieu de tomber dans le vide qui sépare deux images. Une bande bien
## découpée a des GOUTTIÈRES — des colonnes entièrement transparentes —
## là où on la coupe.
##
## LE SEUIL EST INDULGENT, ET IL LE FAUT. Un sprite peut légitimement
## toucher le bord de son cadre : la poussière qui remplit son image, le
## canard qui l'occupe en entier, l'anneau d'écume d'un rocher qui déborde.
## Mesuré sur les 34 bandes du pack, ces cas-là dépassent rarement un quart
## des coupes, quand les deux arbres mal déclarés en rataient quatre sur
## cinq. On refuse donc à partir de la MOITIÉ, et seulement sur les bandes
## d'au moins cinq images — en dessous, une seule coupe malheureuse
## suffirait à crier au loup.
func _check_cuts(entry: Dictionary, image: Image) -> void:
	var frames := int(entry.get("frames", 0))
	var frame_width := int(entry.get("frame_w", 0))
	if frames < 5 or frame_width <= 0:
		return
	if image.is_compressed():
		image.decompress()

	var height := image.get_size().y
	var hollow := 0
	var on_ink := 0
	for cut in range(1, frames):
		var x := cut * frame_width
		if x >= image.get_size().x:
			continue
		var clear := true
		for y in height:
			if image.get_pixel(x, y).a > 0.0:
				clear = false
				break
		if clear:
			hollow += 1
		else:
			on_ink += 1

	# Une bande SANS AUCUNE gouttière est pleine par nature — un dégradé,
	# une barre — et n'a rien à dire sur son découpage.
	if hollow <= 0:
		return
	if on_ink * 2 > hollow + on_ink:
		_miscut.append(
			"%s → %d coupes sur %d tombent dans le dessin : « frames » et "
			% [entry["id"], on_ink, hollow + on_ink]
			+ "« frame_w » ne décrivent pas ce fichier (%s)" % entry["path"]
		)
