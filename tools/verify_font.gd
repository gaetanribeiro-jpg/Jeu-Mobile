extends SceneTree

## Vérifie qu'une police contient tous les glyphes dont le jeu a besoin.
##
##     godot --headless --path . -s tools/verify_font.gd -- assets/fonts/Silver.ttf
##
## Sans argument, teste toutes les polices trouvées dans `assets/fonts/`.
##
## C'est le piège classique du français : la plupart des pixel-fonts
## anglophones n'ont ni é, ni è, ni ç, ni œ. On s'en aperçoit après avoir
## écrit quatre-vingt-dix cartes d'événement. Cinq minutes ici valent une
## semaine de reprise plus tard.
##
## La liste des glyphes exigés est dans `data/i18n/required_glyphs.txt` —
## y compris les guillemets français, les points de suspension et
## l'apostrophe courbe, qui sont dans la règle de voix du § 7.3 et donc
## présents dans presque chaque carte.

const GLYPHS_PATH := "res://data/i18n/required_glyphs.txt"
const FONTS_DIR := "res://assets/fonts/"
const FONT_EXTENSIONS := ["ttf", "otf", "fnt", "font", "woff", "woff2"]


func _init() -> void:
	var groups := _required_glyphs()
	var essential: PackedStringArray = groups.get("indispensable", PackedStringArray())
	var comfort: PackedStringArray = groups.get("confort", PackedStringArray())
	if essential.is_empty():
		push_error("Aucun glyphe indispensable : %s est vide ou absent." % GLYPHS_PATH)
		quit(1)
		return

	var paths := _fonts_to_check()
	if paths.is_empty():
		print("Aucune police à vérifier.")
		print("Déposer un fichier dans %s, ou passer un chemin en argument." % FONTS_DIR)
		print("\n%d glyphes indispensables :" % essential.size())
		print("  " + "".join(essential))
		quit(1)
		return

	var all_ok := true
	for path: String in paths:
		if not _check(path, essential, comfort):
			all_ok = false

	quit(0 if all_ok else 1)


## Lit le fichier de glyphes et renvoie { "indispensable": [...],
## "confort": [...] }. Les lignes vides et les commentaires sont ignorés.
func _required_glyphs() -> Dictionary:
	var groups := {"indispensable": PackedStringArray(), "confort": PackedStringArray()}
	if not FileAccess.file_exists(GLYPHS_PATH):
		return groups
	var file := FileAccess.open(GLYPHS_PATH, FileAccess.READ)
	if file == null:
		return groups
	var text := file.get_as_text()
	file.close()

	var current := "indispensable"
	var seen := {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2)
			if not groups.has(current):
				groups[current] = PackedStringArray()
			continue
		for character: String in line:
			if character == " " or seen.has(character):
				continue
			seen[character] = true
			groups[current].append(character)
	return groups


func _fonts_to_check() -> PackedStringArray:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		var out := PackedStringArray()
		for argument: String in arguments:
			out.append(argument if argument.begins_with("res://") else "res://" + argument)
		return out

	var out2 := PackedStringArray()
	var dir := DirAccess.open(FONTS_DIR)
	if dir == null:
		return out2
	for name_ in dir.get_files():
		var clean: String = name_.trim_suffix(".import").trim_suffix(".remap")
		if FONT_EXTENSIONS.has(clean.get_extension().to_lower()):
			if not out2.has(FONTS_DIR + clean):
				out2.append(FONTS_DIR + clean)
	return out2


func _check(path: String, essential: PackedStringArray, comfort: PackedStringArray) -> bool:
	print("\n── %s" % path)
	if not FileAccess.file_exists(path):
		print("  INTROUVABLE")
		return false

	var font: Font = load(path)
	if font == null:
		print("  ILLISIBLE — Godot n'a pas su charger ce fichier comme police.")
		return false

	var missing := _missing_from(font, essential)
	var missing_comfort := _missing_from(font, comfort)

	print("  Nom : %s" % font.get_font_name())
	if missing_comfort.is_empty():
		print("  Confort : les %d glyphes de confort sont présents." % comfort.size())
	else:
		print("  Confort : %s absent(s) — remplaçables par un sprite ou une autre tournure."
			% "".join(missing_comfort))

	if missing.is_empty():
		print("  ✓ Les %d glyphes indispensables sont tous présents." % essential.size())
		return true

	print("  ✗ %d glyphe(s) indispensable(s) absent(s) : %s" % [missing.size(), "".join(missing)])
	print("    Un glyphe absent s'affiche en carré vide dans le jeu.")
	return false


func _missing_from(font: Font, characters: PackedStringArray) -> PackedStringArray:
	var missing := PackedStringArray()
	for character: String in characters:
		if not font.has_char(character.unicode_at(0)):
			missing.append(character)
	return missing
