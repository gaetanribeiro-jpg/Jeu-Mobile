extends Control

## La carte du monde, DESSINÉE (T12.11).
##
## LE NOM MENTAIT DEPUIS T3.6. L'écran s'appelait « carte du monde » et
## empilait six BOÎTES rectangulaires avec un carré de terre dedans. Rien
## n'y disait où sont les Dunes par rapport aux Terres Vertes, ni que
## l'Empire est au bout du monde — donc le § 27, « le joueur découvre »,
## n'avait rien à découvrir. C'est le reproche de Gaetan, et il était juste.
##
## AUCUN PIXEL N'A ÉTÉ DESSINÉ POUR CET ÉCRAN. La mer est la tuile d'eau
## du pack, les terres sont son tileset DÉSATURÉ puis reteinté à l'accent
## de chaque région — la même opération que le carré qu'elles remplacent,
## donc les deux ne peuvent pas diverger — et les villes sont ses
## bâtiments, teints à leur crédit.
##
## UN CONTROL QUI SE DESSINE LUI-MÊME, comme la vue du royaume. Sept
## polygones et trois maisons ne justifient pas dix nœuds à tenir
## synchronisés avec une campagne qui change à chaque retour.

## Le joueur a désigné une région.
signal picked(region_id: StringName)

const TOWN_COLOR := "Blue"

var campaign := Campaign.new()
var kingdom: Kingdom = null
var selected: StringName = &""

var _hits: Array[Dictionary] = []
var _sea: Texture2D
var _blind := false


func _ready() -> void:
	_blind = DisplayServer.get_name() == "headless"
	# LA MER SE RÉPÈTE. Sans ce mode, la tuile d'eau du pack s'étire sur
	# toute la largeur et devient un aplat flou : c'est du pixel art de 64,
	# il se carrelle, il ne s'agrandit pas.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var entry := AssetTable.sprite(&"terrain", &"water_background_color")
	if not entry.is_empty():
		_sea = load(entry["path"]) as Texture2D
	resized.connect(refresh)


func refresh() -> void:
	if not _blind:
		queue_redraw()


## Le facteur d'échelle de la toile vers l'écran. UNIFORME : une carte
## étirée sur un axe n'est plus une carte, et le tileset baverait.
func _factor() -> float:
	var canvas := WorldAtlas.canvas()
	if size.x <= 0.0 or size.y <= 0.0 or canvas.x <= 0.0 or canvas.y <= 0.0:
		return 1.0
	return minf(size.x / canvas.x, size.y / canvas.y)


func _origin() -> Vector2:
	return (size - WorldAtlas.canvas() * _factor()) * 0.5


func _screen(point: Vector2) -> Vector2:
	return _origin() + point * _factor()


func _draw() -> void:
	_hits.clear()
	if WorldAtlas.canvas() == Vector2.ZERO:
		return
	_draw_sea()
	# LES ROUTES PASSENT SOUS LES TERRES, et c'est ce qui leur donne l'air
	# d'aborder une côte : leurs deux bouts disparaissent sous le rivage au
	# lieu de s'arrêter net au milieu de la mer.
	_draw_roads()
	_draw_land(WorldAtlas.HOME, UiTheme.color(&"homeland"), true)
	for region_id: StringName in WorldAtlas.ids():
		_draw_region(region_id)
	_draw_castle()
	_draw_towns()
	_draw_labels()


## La mer, carrelée. Elle couvre TOUT le contrôle, pas la seule toile :
## une bande noire au bord d'une carte se lit comme un écran cassé.
func _draw_sea() -> void:
	if _sea == null:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.color(&"steel"))
		return
	var span := _sea.get_size() * _factor()
	if span.x <= 0.0 or span.y <= 0.0:
		return
	draw_texture_rect(_sea, Rect2(Vector2.ZERO, size), true)


## Une terre : le tileset du pack désaturé puis reteinté, carrelé dans le
## polygone, et son rivage souligné.
func _draw_land(node_id: StringName, tint: Color, open: bool) -> void:
	var shape := WorldAtlas.shape_of(node_id)
	if shape.size() < 3:
		return
	var texture := UiSkin.terrain_swatch(tint, AssetTable.tile_size())
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var tile := float(AssetTable.tile_size())
	for point: Vector2 in shape:
		points.append(_screen(point))
		uvs.append(point / tile)
	# UNE RÉGION FERMÉE EST ASSOMBRIE, PAS CACHÉE. « Le verrou dit qu'il y
	# a une suite » (T3.6) : une terre qu'on ne voit pas n'apprend rien, et
	# la carte redeviendrait un bouton.
	# `ink_disabled` serait le réflexe et c'est un PIÈGE : il porte un
	# alpha de 0,38, donc la terre verrouillée devenait transparente EN PLUS
	# d'être sombre, et se noyait dans la mer. Une teinte de lavage doit
	# être opaque.
	var wash := Color.WHITE if open else UiTheme.color(&"wood_dim")
	if texture == null:
		draw_colored_polygon(points, tint * wash)
	else:
		draw_colored_polygon(points, wash, uvs, texture)

	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(
		outline,
		UiTheme.color(&"parchment" if open else &"ink_muted"),
		ViewSettings.number(&"sizes", &"map_coast_width", 2.0) * _factor(),
		true
	)


func _draw_region(region_id: StringName) -> void:
	var open := campaign.is_open(region_id)
	_draw_land(region_id, UiTheme.color(Region.accent_of(region_id)), open)
	_hits.append({"id": region_id, "shape": WorldAtlas.shape_of(region_id)})

	if selected != region_id:
		return
	# LE CHOISI PORTE L'OR, comme le héros dont c'est le tour (T9.7).
	var points := PackedVector2Array()
	for point: Vector2 in WorldAtlas.shape_of(region_id):
		points.append(_screen(point))
	if points.is_empty():
		return
	points.append(points[0])
	draw_polyline(
		points, UiTheme.color(&"ink_gold"),
		ViewSettings.number(&"sizes", &"map_select_width", 3.0) * _factor(), true
	)


## La route des six actes. Elle rend l'ORDRE lisible : sans elle, six
## terres posées sur une mer sont six terres ; avec elle, c'est un chemin,
## et on voit d'un coup d'œil que l'Empire est au bout.
func _draw_roads() -> void:
	var width := ViewSettings.number(&"sizes", &"map_road_width", 3.0) * _factor()
	for road: Array in WorldAtlas.roads():
		var from: StringName = road[0]
		var to: StringName = road[1]
		# Une route vers une terre encore fermée est PÂLE : elle dit qu'il y
		# a une suite sans prétendre qu'on peut la prendre.
		var open := to == WorldAtlas.HOME or campaign.is_open(to)
		draw_line(
			_screen(WorldAtlas.anchor_of(from)),
			_screen(WorldAtlas.anchor_of(to)),
			UiTheme.color(&"sand" if open else &"ink_muted"),
			width, true
		)


func _draw_castle() -> void:
	var entry := AssetTable.building(&"castle", TOWN_COLOR)
	if entry.is_empty():
		return
	var texture := load(entry["path"]) as Texture2D
	if texture == null:
		return
	_blit(texture, WorldAtlas.castle(),
		ViewSettings.number(&"sizes", &"map_castle_scale", 0.5), Color.WHITE)


## LES VILLES DISENT LEUR CRÉDIT PAR LEUR COULEUR (T12.11) — grises tant
## qu'on ne les connaît pas, vertes quand on est cordial, or quand on est
## allié, rouges quand on est brouillé.
##
## ELLES SONT SUR L'ÎLE DU ROYAUME, pas au large : le texte dit « à deux
## jours de marche », et trois cailloux en pleine mer l'auraient contredit.
func _draw_towns() -> void:
	for town_id: StringName in WorldAtlas.towns():
		if not Neighbour.exists(town_id):
			continue
		var entry := WorldAtlas.town(town_id)
		var standing := kingdom.standing_of(town_id) if kingdom != null else 0
		var tint := Neighbour.standing_tint(standing)
		var texture := UiSkin.tinted_building(
			StringName(entry.get("asset", "")), UiTheme.color(tint),
			ViewSettings.number(&"sizes", &"map_town_lift", 1.0)
		)
		if texture == null:
			continue
		_blit(texture, WorldAtlas.town_at(town_id),
			float(entry.get("scale", 0.4)), Color.WHITE)
		_caption(
			tr(Neighbour.name_key(town_id)),
			WorldAtlas.town_at(town_id) + Vector2(0.0, ViewSettings.number(
				&"sizes", &"map_town_caption_drop", 12.0
			)),
			UiTheme.color(tint),
			&"map_town_font"
		)


## Le nom d'une région et son état, posés sous elle.
func _draw_labels() -> void:
	for region_id: StringName in WorldAtlas.ids():
		var open := campaign.is_open(region_id)
		var color := UiTheme.color(Region.accent_of(region_id) if open else &"ink_muted")
		_caption(tr(Region.name_key(region_id)), WorldAtlas.label_of(region_id),
			color, &"map_font")
		var note := (
			tr("WORLD_ACT") % Region.act_of(region_id) if open else tr("WORLD_LOCKED")
		)
		_caption(
			note,
			WorldAtlas.label_of(region_id) + Vector2(0.0, ViewSettings.number(
				&"sizes", &"map_caption_drop", 18.0
			)),
			UiTheme.color(&"ink_soft" if open else &"ink_disabled"),
			&"map_town_font"
		)


func _blit(texture: Texture2D, at: Vector2, factor: float, modulate: Color) -> void:
	var span := texture.get_size() * factor * _factor()
	var anchor := _screen(at)
	# Posé PAR LE PIED, comme au royaume : un château et une maison au même
	# endroit doivent poser leurs murs au même endroit, quelles que soient
	# leurs hauteurs.
	draw_texture_rect(
		texture,
		Rect2(Vector2(anchor.x - span.x * 0.5, anchor.y - span.y), span),
		false, modulate
	)


## UN CONTOUR, PARCE QUE LE FOND N'EST PAS MAÎTRISÉ. C'est la règle de
## T9.8 : l'interface n'a plus de contour de texte, sauf le texte posé SUR
## un décor — ici de l'eau claire et des terres de six couleurs.
func _caption(text: String, at: Vector2, color: Color, size_key: StringName) -> void:
	var font := get_theme_font(&"font", &"Label")
	if font == null:
		font = ThemeDB.fallback_font
	var points := int(ViewSettings.number(&"sizes", size_key, 16.0) * _factor())
	if points <= 0:
		return
	var span := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points)
	var anchor := _screen(at) - Vector2(span.x * 0.5, 0.0)
	draw_string_outline(
		font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1, points,
		int(ViewSettings.number(&"sizes", &"map_text_outline", 4.0)),
		UiTheme.color(&"backdrop")
	)
	draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1, points, color)


# --- Le doigt --------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var at: Vector2 = (event as InputEventMouseButton).position
	var factor := _factor()
	if factor <= 0.0:
		return
	var local := (at - _origin()) / factor
	for hit: Dictionary in _hits:
		if Geometry2D.is_point_in_polygon(local, hit["shape"] as PackedVector2Array):
			picked.emit(StringName(hit["id"]))
			accept_event()
			return
