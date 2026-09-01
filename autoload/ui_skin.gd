extends Node

## Construit l'apparence de l'interface à partir du pack (T9.1, T9.2, T9.3).
##
## POURQUOI CETTE CLASSE EXISTE. Un bouton du pack n'est PAS une image
## étirable : c'est une grille 3×3 de morceaux posés sur une toile, avec un
## espace vide de 64 px entre chacun. Donné tel quel à un
## `StyleBoxTexture`, il étirerait les trous en même temps que le décor.
## Il faut donc recomposer les neuf morceaux bord à bord — et c'est
## précisément ce qui manquait pour que ces 70 assets servent à quelque
## chose.
##
## RIEN N'EST ÉCRIT SUR LE DISQUE. Le pack n'est pas dans le dépôt
## (licence), et un dérivé du pack ne le serait pas davantage : il
## faudrait le régénérer à la main sur chaque poste, ce que personne ne
## ferait. La recomposition se fait en mémoire au démarrage — neuf copies
## de 64×64 par style, une fois.
##
## LA TEINTE EST CE QUI SORT DU BLEU ET DU ROUGE. Le pack ne livre que ces
## deux couleurs, une langue « confirmer / renoncer » qui ne suffit pas à
## un menu de sept entrées. La source est passée en NIVEAUX DE GRIS puis
## reteintée par rôle : six boutons de couleurs différentes sortent de la
## même image, et le rôle porte le sens plutôt que la couleur.
##
## PAS « Skin » : CE NOM EST DÉJÀ PRIS PAR GODOT (la peau d'un squelette).
## L'autoload se résolvait silencieusement sur la classe native, et le
## seul message était « Cannot find member "theme" in base "Skin" » — le
## même piège exactement que `reload()` contre `Script.reload()` en T7.4.
## Un nom d'autoload se vérifie avant de l'écrire.
##
## LE CODE NE DOIT JAMAIS PLANTER PARCE QU'UN ASSET MANQUE. Les assets
## Tiny Swords ne sont pas versionnés ; sans eux, `Skin` rend un thème
## plat aux couleurs du thème, et le jeu reste jouable.

## Rôle de surface → StyleBox construit. Rempli une fois au démarrage.
var _styles: Dictionary = {}

## Textures recomposées, par « clé d'asset + échelle + désaturation ».
## Deux rôles qui partagent une source ne la recomposent pas deux fois.
var _textures: Dictionary = {}

## Le thème Godot appliqué à la racine de chaque écran.
var theme: Theme = null


func _ready() -> void:
	rebuild()


## (Re)construit tout. Public pour les tests et le rechargement à chaud.
func rebuild() -> void:
	_styles.clear()
	_textures.clear()
	theme = Theme.new()
	_build_styles()
	_build_theme()


# --- Ce que les écrans demandent ------------------------------------------

## Le fond d'un panneau, prêt à poser sur un `Panel` ou un `PanelContainer`.
func panel_style(role: StringName = &"panel") -> StyleBox:
	return _styles.get(role, _flat(UiTheme.color(&"backdrop")))


## Un bouton de la couleur d'un RÔLE — « primary », « danger », « muted »…
## Jamais d'une couleur : c'est le thème qui décide à quoi ressemble un
## danger.
func button_style(role: StringName = &"default", pressed: bool = false) -> StyleBox:
	var key := StringName("button_%s_%s" % [role, "pressed" if pressed else "regular"])
	if _styles.has(key):
		return _styles[key]
	var built := _button_style(role, pressed)
	_styles[key] = built
	return built


## Habille un bouton d'un rôle, d'un coup : fond, survol, appui, et la
## couleur de texte qui va avec.
func dress_button(button: Button, role: StringName = &"default") -> void:
	button.add_theme_stylebox_override("normal", button_style(role, false))
	button.add_theme_stylebox_override("hover", button_style(role, false))
	button.add_theme_stylebox_override("pressed", button_style(role, true))
	button.add_theme_stylebox_override("focus", button_style(role, false))
	button.add_theme_stylebox_override("disabled", button_style(&"muted", false))
	# TEXTE CLAIR SUR CERCLÉ DE SOMBRE. Les six teintes sont des tons
	# moyens : ni le clair ni le sombre ne passe sur toutes. Le contour
	# règle la question une fois pour toutes, et c'est ce que fait déjà le
	# HUD de combat pour les chiffres de dégâts.
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, UiTheme.color(&"ink_inverse"))
	button.add_theme_color_override(
		"font_disabled_color", UiTheme.color(&"ink_disabled")
	)
	button.add_theme_color_override("font_outline_color", UiTheme.color(&"ink"))
	button.add_theme_constant_override(
		"outline_size", UiTheme.metric(&"text_outline")
	)


## Fabrique une jauge complète : l'auge de bois du pack, et dedans le
## remplissage teinté par ce qu'il mesure.
##
## C'EST UN ASSEMBLAGE, PAS UN `ProgressBar` HABILLÉ, et il a fallu se
## cogner au second pour comprendre pourquoi. Un `ProgressBar` dessine son
## remplissage sur TOUTE sa surface, embouts compris : la barre débordait
## de l'auge. Et ses marges de tranches s'appliquent aux quatre côtés,
## alors qu'une jauge ne se découpe qu'HORIZONTALEMENT — le bois se
## répétait deux fois en hauteur. Un panneau qui porte l'auge, une marge
## qui écarte des embouts, et une barre nue à l'intérieur : chaque morceau
## fait une seule chose.
##
## LE REMPLISSAGE EST DÉSATURÉ AVANT D'ÊTRE TEINTÉ, comme les boutons. Le
## pack le livre en rouge : tel quel, une barre de PV pleine serait rouge
## vif, c'est-à-dire exactement le signal qu'on réserve à une barre vide.
func build_bar(value: float, maximum: float, fill_color: Color) -> Control:
	var block := UiTheme.bars()
	var scale := int(block.get("scale", 1))
	var base := _sliced_texture(
		StringName(block.get("base_asset", "")), scale, false, 3
	)
	var fill := _plain_texture(
		StringName(block.get("fill_asset", "")), scale, true,
		bool(block.get("normalise_fill", false)), true
	)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(maximum, 1.0)
	bar.value = clampf(value, 0.0, bar.max_value)

	if base == null or fill == null:
		# Sans le pack, on retombe sur des rectangles pleins : moins joli,
		# toujours lisible, et le jeu démarre.
		bar.add_theme_stylebox_override("background", _flat(UiTheme.color(&"ink")))
		bar.add_theme_stylebox_override("fill", _flat(fill_color))
		bar.custom_minimum_size = Vector2(0, UiTheme.metric(&"bar_height"))
		return bar

	# LA RAINURE DÉCIDE DE LA HAUTEUR, et il faut la lui DONNER. Laisser
	# le conteneur étirer la jauge ne marche pas : sans hauteur minimale
	# elle tombe à un pixel, un trait vert sur le bord du creux. On calcule
	# donc le creux — hauteur du bois moins ses deux bords — et on la pose.

	var painted := StyleBoxTexture.new()
	painted.texture = fill
	painted.modulate_color = fill_color
	bar.add_theme_stylebox_override("fill", painted)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var groove: Dictionary = AssetTable.sprite(
		&"ui", StringName(block.get("base_asset", ""))
	).get("groove", {})
	var divisor := maxi(scale, 1)
	var edges := (int(groove.get("top", 0)) + int(groove.get("bottom", 0))) / divisor
	bar.custom_minimum_size = Vector2(
		0, maxi(UiTheme.metric(&"bar_height") - edges, 1)
	)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# L'ENCART VIENT DU STYLEBOX, PAS D'UN `MarginContainer`. Un
	# `StyleBoxTexture` écarte déjà son contenu de ses marges de tranches ;
	# en ajouter un second par-dessus faisait 64 px de chaque côté sur une
	# barre large de 110, et la jauge se retrouvait à zéro. On voyait
	# l'auge et jamais rien dedans — deux fois de suite, avant de penser à
	# mesurer la largeur restante plutôt que la couleur du remplissage.
	var trough := PanelContainer.new()
	trough.custom_minimum_size = Vector2(0, UiTheme.metric(&"bar_height"))
	# SANS CE DRAPEAU, LE PANNEAU RESTE À SA TAILLE MINIMALE et la jauge
	# lui déborde dessus : mesuré à la capture, 76 px de bois sous 105 px
	# de vert. Un `PanelContainer` ne s'étire pas de lui-même quand son
	# style porte des marges de tranches.
	trough.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wood := _boxed(base, UiTheme.color(&"wood"), false)
	# La rainure est déclarée dans la table des assets, en pixels de
	# l'image recomposée : c'est une propriété du dessin, pas un réglage.
	wood.content_margin_left = int(groove.get("left", 0)) / divisor
	wood.content_margin_right = int(groove.get("right", 0)) / divisor
	wood.content_margin_top = int(groove.get("top", 0)) / divisor
	wood.content_margin_bottom = int(groove.get("bottom", 0)) / divisor
	trough.add_theme_stylebox_override("panel", wood)
	trough.add_child(bar)
	return trough


## Les deux textures d'une jauge : { base, fill }. Vides si le pack
## manque — l'appelant retombe alors sur un rectangle plein.
func bar_textures() -> Dictionary:
	var block := UiTheme.bars()
	if block.is_empty():
		return {}
	var scale := int(block.get("scale", 1))
	var base := _sliced_texture(
		StringName(block.get("base_asset", "")), scale, false, 3
	)
	var fill := _plain_texture(
		StringName(block.get("fill_asset", "")), scale, true,
		bool(block.get("normalise_fill", false)), true
	)
	if base == null or fill == null:
		return {}
	return {"base": base, "fill": fill}


func has_pack() -> bool:
	return not _textures.is_empty()


# --- Construction ----------------------------------------------------------

func _build_styles() -> void:
	for role: StringName in UiTheme.surface_roles():
		var built := _surface_style(role)
		if built != null:
			_styles[role] = built


## Le thème global : tailles de police et couleurs par défaut. Ce qui est
## ici n'a plus besoin d'être répété écran par écran — c'est la moitié des
## `add_theme_*_override` qui disparaît.
func _build_theme() -> void:
	var body := UiTheme.font_size(&"body")
	for type_name: String in ["Label", "Button", "CheckBox", "OptionButton"]:
		theme.set_font_size("font_size", type_name, body)
	theme.set_font_size("font_size", "Button", UiTheme.font_size(&"button"))
	theme.set_color("font_color", "Label", UiTheme.color(&"ink_inverse"))
	theme.set_color("font_color", "Button", UiTheme.color(&"ink_inverse"))
	# LE THÈME GLOBAL DOIT PORTER LA COULEUR DÉSACTIVÉE, pas seulement
	# `dress_button` : les boutons qui ne passent pas par lui — l'arbre de
	# compétences en a une trentaine — gardaient le gris par défaut de
	# Godot sur le fond gris du rôle « muted », et l'arbre devenait
	# illisible dès qu'un nœud n'était pas achetable, c'est-à-dire
	# presque toujours.
	theme.set_color("font_disabled_color", "Button", UiTheme.color(&"ink_disabled"))
	theme.set_color("font_hover_color", "Button", UiTheme.color(&"ink_inverse"))
	theme.set_color("font_pressed_color", "Button", UiTheme.color(&"ink_inverse"))
	theme.set_color("font_outline_color", "Button", UiTheme.color(&"ink"))
	theme.set_constant("outline_size", "Button", UiTheme.metric(&"text_outline"))

	for state: String in ["normal", "hover", "focus"]:
		theme.set_stylebox(state, "Button", button_style(&"default", false))
	theme.set_stylebox("pressed", "Button", button_style(&"default", true))
	theme.set_stylebox("disabled", "Button", button_style(&"muted", false))

	var panel := panel_style(&"panel")
	if panel != null:
		theme.set_stylebox("panel", "PanelContainer", panel)


func _surface_style(role: StringName) -> StyleBox:
	var block := UiTheme.surface(role)
	if block.is_empty():
		return null
	var texture := _sliced_texture(
		StringName(block.get("asset", "")), int(block.get("scale", 1)),
		bool(block.get("desaturate", false)), 3
	)
	if texture == null:
		return _flat(UiTheme.color(StringName(block.get("tint", "backdrop"))))
	return _boxed(texture, UiTheme.color(StringName(block.get("tint", "parchment"))))


func _button_style(role: StringName, pressed: bool) -> StyleBox:
	var block := UiTheme.surface(&"button")
	if block.is_empty():
		return _flat(UiTheme.button_tint(role))
	var key := "pressed_asset" if pressed else "asset"
	var texture := _sliced_texture(
		StringName(block.get(key, block.get("asset", ""))),
		int(block.get("scale", 1)), bool(block.get("desaturate", false)), 3
	)
	if texture == null:
		return _flat(UiTheme.button_tint(role))
	return _boxed(texture, UiTheme.button_tint(role))


## Un `StyleBoxTexture` dont les marges valent le coin de la texture
## recomposée. Comme la recomposition met les trois morceaux bord à bord,
## le coin fait exactement le tiers... non : il fait ce que la table dit,
## divisé par l'échelle. On le relit sur la texture plutôt que de le
## recalculer, pour qu'il n'y ait qu'un seul endroit qui décide.
func _boxed(
	texture: Texture2D, tint: Color, vertical: bool = true
) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	var corner: int = _textures.get(_corner_key(texture), 0)
	box.texture_margin_left = corner
	box.texture_margin_right = corner
	# UNE JAUGE NE SE DÉCOUPE QU'EN LARGEUR. Lui donner des marges hautes
	# et basses répétait le bois deux fois dans une barre de 22 px : les
	# coins, qui font 32, ne tenaient pas dans la hauteur qu'on leur
	# donnait.
	box.texture_margin_top = corner if vertical else 0
	box.texture_margin_bottom = corner if vertical else 0
	box.modulate_color = tint
	return box


func _flat(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(UiTheme.metric(&"row_spacing"))
	return box


func _corner_key(texture: Texture2D) -> StringName:
	return StringName("corner:%d" % texture.get_instance_id())


# --- Recomposition ---------------------------------------------------------

## Recompose les morceaux d'un asset découpé et rend la texture, ou null
## si le fichier manque.
##
## `pieces` vaut 3 pour une jauge (trois morceaux en ligne) et 3 aussi
## pour une grille 3×3 — c'est le nombre de morceaux par axe. Une jauge
## n'a qu'une rangée, ce que la table dit par son `layout`.
func _sliced_texture(
	key: StringName, scale: int, desaturate: bool, pieces: int
) -> Texture2D:
	if key.is_empty():
		return null
	var cache := StringName("%s|%d|%s|%d" % [key, scale, desaturate, pieces])
	if _textures.has(cache):
		return _textures[cache]

	var entry := AssetTable.sprite(&"ui", key)
	if entry.is_empty():
		return null
	var source := _load_image(String(entry.get("path", "")))
	if source == null:
		return null

	var slice: Dictionary = entry.get("slice", {})
	if slice.is_empty():
		push_error("Skin : « %s » n'a pas de géométrie de tranches" % key)
		return null
	var corner := int(slice.get("corner", 0))
	var middle := int(slice.get("middle", 0))
	var gap := int(slice.get("gap", 0))
	var horizontal := _spans(corner, middle, gap)
	var vertical := horizontal if pieces > 1 and source.get_height() > corner * 2 else [
		[0, 0, source.get_height()]
	]

	var width := corner * 2 + middle
	var height: int = vertical[vertical.size() - 1][1] + vertical[vertical.size() - 1][2]
	var packed := Image.create_empty(width, height, false, source.get_format())
	for row: Array in vertical:
		for column: Array in horizontal:
			packed.blit_rect(
				source,
				Rect2i(int(column[0]), int(row[0]), int(column[2]), int(row[2])),
				Vector2i(int(column[1]), int(row[1]))
			)

	if desaturate:
		_desaturate(packed)
	if scale > 1:
		# Nearest, et une division ENTIÈRE : le pack est du pixel art sur
		# grille de 64. Diviser par 2 fait tomber quatre pixels sur un ;
		# une division fractionnaire ferait baver la bordure.
		packed.resize(
			maxi(width / scale, 1), maxi(height / scale, 1), Image.INTERPOLATE_NEAREST
		)

	var texture := ImageTexture.create_from_image(packed)
	_textures[cache] = texture
	_textures[_corner_key(texture)] = maxi(corner / maxi(scale, 1), 1)
	return texture


## Les trois tranches d'un axe : { départ dans la source, départ dans la
## sortie, longueur }.
func _spans(corner: int, middle: int, gap: int) -> Array:
	return [
		[0, 0, corner],
		[corner + gap, corner, middle],
		[corner + gap + middle + gap, corner + middle, corner],
	]


## Un asset qui n'est pas découpé — le remplissage d'une jauge.
func _plain_texture(
	key: StringName, scale: int, desaturate: bool = false,
	normalise: bool = false, crop: bool = false
) -> Texture2D:
	if key.is_empty():
		return null
	var cache := StringName(
		"plain|%s|%d|%s|%s|%s" % [key, scale, desaturate, normalise, crop]
	)
	if _textures.has(cache):
		return _textures[cache]
	var entry := AssetTable.sprite(&"ui", key)
	if entry.is_empty():
		return null
	var image := _load_image(String(entry.get("path", "")))
	if image == null:
		return null
	if crop:
		image = _cropped(image)
	if desaturate:
		_desaturate(image, normalise)
	if scale > 1:
		image.resize(
			maxi(image.get_width() / scale, 1), maxi(image.get_height() / scale, 1),
			Image.INTERPOLATE_NEAREST
		)
	var texture := ImageTexture.create_from_image(image)
	_textures[cache] = texture
	return texture


## Réduit l'image à ce qu'elle dessine vraiment.
##
## LE REMPLISSAGE D'UNE JAUGE EST UNE BANDE DANS UNE TOILE VIDE : 64×64 de
## fichier pour 24 px de peinture, le reste transparent. Étirée telle
## quelle dans un creux de 13 px, la bande n'en occupait que 4 — un trait
## vert au milieu du bois. Recadrée, elle remplit ce qu'on lui donne.
func _cropped(image: Image) -> Image:
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return image
	return image.get_region(used)


## Charge une image du pack. Rend null SANS PLANTER si elle manque : les
## assets ne sont pas dans le dépôt, et un poste qui ne les a pas encore
## copiés doit quand même pouvoir lancer le jeu.
func _load_image(path: String) -> Image:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	# `blit_rect` refuse une image compressée, et l'importateur peut en
	# rendre une selon les réglages du projet.
	if image.is_compressed():
		image.decompress()
	return image


## Passe l'image en niveaux de gris, en gardant l'alpha.
##
## C'EST CE QUI SORT DU BLEU ET DU ROUGE. Multiplier un bouton bleu par de
## l'or donne du vert sale ; passé en gris, il prend n'importe quelle
## teinte proprement. Les six rôles de bouton sortent de cette ligne-là.
func _desaturate(image: Image, normalise: bool = false) -> void:
	# `normalise` remonte le plus clair à blanc.
	#
	# SANS ÇA, LE REMPLISSAGE D'UNE JAUGE EST INVISIBLE. Le pack le livre
	# en rouge sombre : mesuré, sa luminance plafonne à 0,71 et vaut 0,37
	# en moyenne. Passé en gris puis multiplié par un vert de PV, il
	# tombait sous 0,3 — du brun foncé dans une auge brun foncé. On voyait
	# le bois, jamais la vie.
	var ceiling := 1.0
	if normalise:
		ceiling = 0.0
		for y in image.get_height():
			for x in image.get_width():
				var sample := image.get_pixel(x, y)
				if sample.a > 0.0:
					ceiling = maxf(ceiling, sample.get_luminance())
		if ceiling <= 0.0:
			ceiling = 1.0

	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			# Luminance perçue : un bleu et un rouge de même intensité ne
			# donnent pas le même gris, et prendre la moyenne écraserait
			# le relief que le pack a dessiné.
			var grey := clampf(pixel.get_luminance() / ceiling, 0.0, 1.0)
			image.set_pixel(x, y, Color(grey, grey, grey, pixel.a))
