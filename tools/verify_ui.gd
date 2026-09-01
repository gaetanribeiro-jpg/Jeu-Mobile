extends SceneTree

## Vérifie que le thème de l'interface tient debout.
##
##     godot --headless --path . -s tools/verify_ui.gd
##
## CE QUI SE CASSE ICI NE PLANTE PAS, ÇA S'AFFICHE EN MAGENTA — ou pire,
## ça s'affiche presque bien. Une couleur mal nommée rend du magenta au
## milieu d'un écran, une surface qui pointe sur un asset absent rend un
## rectangle plat qu'on peut prendre pour une intention, et un rôle de
## bouton oublié fait un menu où deux entrées se ressemblent.
##
## Il contrôle aussi la chose qui a coûté le plus de temps à voir : la
## GÉOMÉTRIE DES TRANCHES. Un bouton du pack est une grille 3×3 de
## morceaux séparés par du vide ; sans sa géométrie déclarée, on étire les
## trous avec le décor et le résultat est méconnaissable sans être vide.

var _problems: Array[String] = []


func _init() -> void:
	print("Vérification du thème de l'interface…\n")
	_check_palette()
	_check_typography()
	_check_metrics()
	_check_surfaces()
	_check_button_roles()
	_check_bars()

	if _problems.is_empty():
		print("\nLe thème tient debout.")
		quit(0)
		return
	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	quit(1)


func _check_palette() -> void:
	var palette: Dictionary = UiTheme.section(&"palette")
	var named := 0
	for key: Variant in palette.keys():
		if AssetTable.is_note(String(key)):
			continue
		named += 1
		var raw: Variant = palette[key]
		if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
			_problems.append("couleur « %s » : il faut au moins [r, v, b]" % key)
			continue
		for channel: Variant in raw:
			# Une seule exception admise plus bas pour les flashs, qui
			# multiplient au lieu de peindre — mais pas dans un thème
			# d'interface, où une valeur hors bornes est une faute de
			# frappe.
			if float(channel) < 0.0 or float(channel) > 1.0:
				_problems.append("couleur « %s » : %s est hors de [0, 1]" % [key, channel])
	print("palette      : %d couleurs" % named)
	if named == 0:
		_problems.append("le thème n'a aucune couleur")


func _check_typography() -> void:
	var block: Dictionary = UiTheme.section(&"typography")
	var sizes := PackedStringArray()
	for key: Variant in block.keys():
		if AssetTable.is_note(String(key)):
			continue
		var size := int(block[key])
		if size <= 0:
			_problems.append("taille de police « %s » nulle ou négative" % key)
		# Silver est une police pixel : une taille impaire tombe entre deux
		# pixels et le texte bave. Ça ne plante pas, ça se lit mal.
		if size % 2 != 0:
			_problems.append("taille de police « %s » impaire (%d)" % [key, size])
		sizes.append("%s %d" % [key, size])
	print("typographie  : %s" % ", ".join(sizes))


func _check_metrics() -> void:
	var block: Dictionary = UiTheme.section(&"metrics")
	for key: Variant in block.keys():
		if AssetTable.is_note(String(key)):
			continue
		if int(block[key]) < 0:
			_problems.append("mesure « %s » négative" % key)
	print("mesures      : %d" % block.size())


func _check_surfaces() -> void:
	for role: StringName in UiTheme.surface_roles():
		var block := UiTheme.surface(role)
		var tint := StringName(block.get("tint", ""))
		if not tint.is_empty() and not UiTheme.has_color(tint):
			_problems.append("surface « %s » : teinte « %s » absente de la palette"
				% [role, tint])
		var scale := int(block.get("scale", 1))
		if scale < 1:
			_problems.append("surface « %s » : échelle %d, il en faut au moins 1"
				% [role, scale])
		for key: String in ["asset", "pressed_asset"]:
			if not block.has(key):
				continue
			_check_sliced(role, StringName(block[key]), scale)


## Un asset découpé doit déclarer sa géométrie, et cette géométrie doit
## tomber juste dans l'image. Une tranche qui dépasse ne se voit qu'à
## l'écran, sous la forme d'un bord répété.
func _check_sliced(role: StringName, key: StringName, scale: int) -> void:
	var entry := AssetTable.sprite(&"ui", key)
	if entry.is_empty():
		_problems.append("surface « %s » : asset « %s » absent de la table"
			% [role, key])
		return
	var slice: Dictionary = entry.get("slice", {})
	if slice.is_empty():
		_problems.append("« %s » n'a pas de géométrie de tranches" % key)
		return
	var corner := int(slice.get("corner", 0))
	var middle := int(slice.get("middle", 0))
	var gap := int(slice.get("gap", 0))
	var span := corner * 2 + middle + gap * 2
	var width := int(entry.get("w", AssetTable.pixel_size(entry).x))
	if span != width:
		_problems.append(
			"« %s » : les tranches couvrent %d px pour une image de %d"
				% [key, span, width]
		)
	# Le coin réduit doit rester un nombre entier de pixels, sinon la
	# bordure tombe entre deux et bave — c'est tout l'intérêt d'imposer
	# une échelle entière.
	if corner % maxi(scale, 1) != 0:
		_problems.append("« %s » : coin de %d px indivisible par l'échelle %d"
			% [key, corner, scale])


func _check_button_roles() -> void:
	var roles := UiTheme.button_roles()
	var seen := {}
	var line := PackedStringArray()
	for role: StringName in roles:
		var tint := UiTheme.button_tint(role)
		# DEUX RÔLES DE MÊME COULEUR NE SONT PAS DEUX RÔLES. Le pack ne
		# livre que du bleu et du rouge ; tout l'intérêt de la teinte est
		# qu'un menu cesse de se lire uniquement au texte.
		var key := tint.to_html(false)
		if seen.has(key):
			_problems.append("les rôles « %s » et « %s » ont la même couleur"
				% [seen[key], role])
		seen[key] = role
		line.append("%s %s" % [role, key])
	print("boutons      : %s" % ", ".join(line))
	if roles.size() < 3:
		_problems.append("moins de trois rôles de bouton : la teinte ne sert à rien")


func _check_bars() -> void:
	var block := UiTheme.bars()
	if block.is_empty():
		_problems.append("aucune jauge déclarée")
		return
	var base := AssetTable.sprite(&"ui", StringName(block.get("base_asset", "")))
	if base.is_empty():
		_problems.append("jauge : l'auge est absente de la table")
		return
	var groove: Dictionary = base.get("groove", {})
	if groove.is_empty():
		_problems.append("jauge : l'auge n'a pas de rainure déclarée")
		return
	var scale := maxi(int(block.get("scale", 1)), 1)
	var height := int(base.get("frame_h", base.get("h", 0)))
	var edges := int(groove.get("top", 0)) + int(groove.get("bottom", 0))
	if edges >= height:
		_problems.append("jauge : la rainure ne laisse aucune place au remplissage")
	if AssetTable.sprite(&"ui", StringName(block.get("fill_asset", ""))).is_empty():
		_problems.append("jauge : le remplissage est absent de la table")
	print("jauges       : auge de %d px, rainure %d en haut %d en bas, échelle %d"
		% [height, int(groove.get("top", 0)), int(groove.get("bottom", 0)), scale])
