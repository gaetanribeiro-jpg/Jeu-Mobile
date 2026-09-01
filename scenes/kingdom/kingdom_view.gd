extends Control

## Le royaume, dessiné (T4.3).
##
## LE § 5 EN FAIT UNE EXIGENCE, PAS UN BONUS : « au départ, un petit
## territoire, un bâtiment principal rudimentaire ; à la fin, un véritable
## royaume fortifié — cette évolution visuelle est extrêmement
## importante ». Une liste de bâtiments avec un compteur de niveau ne
## montre rien de tout ça. Il fallait donc un TERRAIN, avec les bâtiments
## posés dessus et les habitants au travail.
##
## LES TROIS CHOSES QUI RENDENT L'ÉVOLUTION VISIBLE, dans l'ordre de leur
## poids :
##  1. le NOMBRE de bâtiments debout — un hameau à deux toits n'a rien à
##     voir avec cinq bâtiments qui remplissent le terrain ;
##  2. les HABITANTS au travail — un Pawn par bras affecté, pioche ou
##     hache en main, à son gisement. Le § 9 réclame de voir la
##     population, et un bâtiment fermé ne la montre jamais ;
##  3. les MAISONS, seul bâtiment dont le pack sait dessiner trois âges.
##
## Ce que le pack ne sait PAS montrer : le niveau d'une caserne. Il n'y a
## qu'un sprite par bâtiment. Le niveau s'écrit donc en chiffre sur une
## pastille — c'est un pis-aller assumé, et le § 8 ne réclame la visibilité
## que « quand c'est possible ».
##
## UN CONTROL QUI SE DESSINE LUI-MÊME, pas une nuée de nœuds. Le terrain,
## les bâtiments, les gisements et les Pawns tiennent dans un `_draw` et
## une table de rectangles cliquables. Une trentaine de sprites ne
## justifient pas trente nœuds à tenir synchronisés avec un état qui
## change à chaque clic.

## Le joueur a désigné quelque chose : un bâtiment ou un chantier.
signal picked(kind: StringName, id: StringName)

const KIND_BUILDING := &"building"
const KIND_WORKSITE := &"worksite"

## Toile de référence. Les positions des données sont en pixels de
## celle-ci ; la vue la met à l'échelle de ce qu'on lui donne.
const CANVAS := Vector2(900.0, 560.0)

const BUILDING_SCALE := 0.55
const PAWN_SCALE := 0.5
const TILE := 64
const COLOR := "Blue"

var kingdom: Kingdom
## Ce que le joueur a désigné. Le château au départ, jamais rien : un
## panneau vide au premier regard n'apprend pas qu'on peut toucher le
## terrain, il donne l'impression que l'écran ne fait rien.
var selected_kind: StringName = KIND_BUILDING
var selected_id: StringName = Buildings.KEYSTONE

var _ground: Texture2D
var _ground_region := Rect2()
var _frame := 0.0
var _hits: Array[Dictionary] = []
var _cache: Dictionary = {}

## Vrai quand aucune image ne sera jamais dessinée — les tests, les outils.
##
## POURQUOI CE DRAPEAU EXISTE. En headless, `queue_redraw()` empile un
## rappel que RIEN NE VIDE JAMAIS. Une horloge d'animation qui en demande
## un par image remplit la file de messages du moteur en quelques
## secondes, et Godot tombe sur un signal 11 — c'est arrivé, et le message
## d'erreur ne désigne pas le coupable.
var _blind := false


func _ready() -> void:
	_blind = DisplayServer.get_name() == "headless"
	var tileset := AssetTable.sprite(&"terrain", &"tilemap_color1")
	if not tileset.is_empty():
		_ground = load(tileset["path"]) as Texture2D
		# La tuile d'herbe pleine : celle qui a de l'herbe des quatre côtés.
		_ground_region = ViewSettings.terrain_tile_region(&"grass", TILE)
	set_process(not _blind)


func _process(delta: float) -> void:
	# Une seule horloge pour tout le monde. Les animations du pack sont à
	# 10 images par seconde, et rien ici ne demande mieux.
	var before := int(_frame)
	_frame += delta * float(AssetTable.fps())
	# On ne redessine qu'au changement d'image. Sans ce garde, on demande
	# soixante redessins par seconde pour en montrer dix.
	if int(_frame) != before:
		refresh()


func refresh() -> void:
	if not _blind:
		queue_redraw()


## DEUX ÉCHELLES, ET C'EST VOULU. Les POSITIONS s'étirent sur les deux axes
## pour occuper tout l'espace disponible : sinon le royaume se recroqueville
## dans un coin et laisse une bande noire, ce qui a l'air d'un écran cassé
## plutôt que d'un petit royaume. Les IMAGES, elles, gardent une échelle
## uniforme — un château étiré n'est plus un château.
func _spread() -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	return Vector2(size.x / CANVAS.x, size.y / CANVAS.y)


func _scale() -> float:
	var spread := _spread()
	return minf(spread.x, spread.y)


func _draw() -> void:
	_hits.clear()
	if kingdom == null:
		return
	var factor := _scale()
	_draw_ground(factor)

	# Du fond vers l'avant : ce qui est plus bas sur le terrain est plus
	# près, et doit donc être dessiné par-dessus.
	var pieces: Array[Dictionary] = []
	for building_id: StringName in Buildings.ids():
		if kingdom.level_of(building_id) > 0:
			pieces.append({"kind": KIND_BUILDING, "id": building_id,
				"spot": Buildings.spot_of(building_id)})
	for worksite_id: StringName in Worksite.ids():
		pieces.append({"kind": KIND_WORKSITE, "id": worksite_id,
			"spot": Worksite.spot_of(worksite_id)})
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["spot"] as Vector2).y < (b["spot"] as Vector2).y)

	for piece: Dictionary in pieces:
		if StringName(piece["kind"]) == KIND_BUILDING:
			_draw_building(StringName(piece["id"]), factor)
		else:
			_draw_worksite(StringName(piece["id"]), factor)


## Le terrain couvre TOUT le contrôle, pas la seule toile de référence :
## une bande noire sous l'herbe se lit comme un écran cassé.
##
## La dernière colonne de tuiles DÉPASSE forcément le bord — une tuile ne
## se coupe pas. C'est pour ça que le nœud a `clip_contents` : sans lui,
## l'herbe glissait sous le panneau de droite et le recouvrait sur
## soixante pixels.
func _draw_ground(factor: float) -> void:
	var span := size
	if _ground == null:
		draw_rect(Rect2(Vector2.ZERO, span), Color(0.42, 0.62, 0.34))
		return
	var step := float(TILE) * factor
	var columns := int(ceil(span.x / step))
	var rows := int(ceil(span.y / step))
	for row in rows:
		for column in columns:
			draw_texture_rect_region(
				_ground,
				Rect2(Vector2(float(column) * step, float(row) * step), Vector2(step, step)),
				_ground_region
			)


# --- Les bâtiments ---------------------------------------------------------

func _draw_building(building_id: StringName, factor: float) -> void:
	var level := kingdom.level_of(building_id)
	var reference := Buildings.asset_of(building_id, level)
	var texture := _texture(reference)
	if texture == null:
		return
	var rect := _place(
		Buildings.spot_of(building_id), texture.get_size(), BUILDING_SCALE * factor
	)
	draw_texture_rect(texture, rect, false)
	_hits.append({"kind": KIND_BUILDING, "id": building_id, "rect": rect})

	if selected_kind == KIND_BUILDING and selected_id == building_id:
		_draw_halo(rect)
	# Le pack n'a qu'un sprite par bâtiment : le niveau ne peut pas se lire
	# sur l'image, il se lit sur une pastille. Pis-aller assumé.
	_draw_pip(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y), str(level), factor)


# --- Les chantiers ---------------------------------------------------------

func _draw_worksite(worksite_id: StringName, factor: float) -> void:
	var spot := Worksite.spot_of(worksite_id)
	var texture := _texture(Worksite.asset_of(worksite_id))
	if texture != null:
		var rect := _place(spot, texture.get_size(), Worksite.scale_of(worksite_id) * factor)
		draw_texture_rect(texture, rect, false)
		_hits.append({"kind": KIND_WORKSITE, "id": worksite_id, "rect": rect})
		if selected_kind == KIND_WORKSITE and selected_id == worksite_id:
			_draw_halo(rect)

	# Un Pawn par bras affecté, outil en main, à sa tâche. C'est la
	# population au travail du § 9, et c'est ce qui distingue un royaume
	# qui produit d'un royaume qui existe.
	var hands := kingdom.assigned_to(worksite_id)
	var pawn := _pawn_texture(Worksite.tool_of(worksite_id))
	if pawn == null:
		return
	# Les ouvriers se serrent SOUS leur gisement, centrés sur lui. Écartés
	# de part et d'autre, ils dérivaient sur le chantier voisin — on voyait
	# un mineur à la mine d'or alors que personne n'y était affecté.
	for hand in hands:
		var offset := Vector2(
			(float(hand) - float(hands - 1) * 0.5) * 32.0, 10.0
		)
		draw_texture_rect(
			pawn, _place(spot + offset, pawn.get_size(), PAWN_SCALE * factor), false
		)


# --- Outils de dessin ------------------------------------------------------

## Pose une image PAR LE PIED, pas par le coin : un bâtiment et un Pawn
## posés au même endroit doivent avoir les pieds au même endroit, quelles
## que soient leurs hauteurs — et elles vont de 128 à 320 pixels.
func _place(spot: Vector2, source: Vector2, factor: float) -> Rect2:
	var span := source * factor
	var at := spot * _spread()
	return Rect2(Vector2(at.x - span.x * 0.5, at.y - span.y), span)


func _draw_halo(rect: Rect2) -> void:
	draw_rect(rect.grow(4.0), Color(1, 0.85, 0.35, 0.9), false, 3.0)


func _draw_pip(anchor: Vector2, text: String, factor: float) -> void:
	var radius := 13.0 * maxf(factor, 0.6)
	var centre := anchor + Vector2(0.0, radius)
	draw_circle(centre, radius, Color(0.09, 0.10, 0.09, 0.85))
	draw_circle(centre, radius, Color(1, 0.85, 0.35), false, 2.0)
	var font := ThemeDB.fallback_font
	var size := int(radius * 1.3)
	var span := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(
		font, centre + Vector2(-span.x * 0.5, span.y * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.92, 0.72)
	)


# --- Les images ------------------------------------------------------------

## Une image nommée « catégorie/clé ». Une bande d'animation rend son image
## courante, une image fixe se rend elle-même. On regarde ce que la table
## déclare avant d'aller chercher, plutôt que de tenter un découpage qui
## échouera bruyamment deux fois sur trois.
func _texture(reference: String) -> Texture2D:
	if reference.is_empty():
		return null
	var parts := reference.split("/", false)
	if parts.size() != 2:
		return null
	if parts[0] == "buildings":
		return _still("b:" + reference, AssetTable.building(StringName(parts[1]), COLOR))

	var declared := AssetTable.sprite(StringName(parts[0]), StringName(parts[1]))
	if declared.is_empty():
		return null
	if StringName(declared["kind"]) != AssetTable.KIND_STRIP:
		return _still("s:" + reference, declared)
	return _animated(reference, SpriteFrameFactory.for_sprite(
		StringName(parts[0]), StringName(parts[1])
	))


func _pawn_texture(tool_id: StringName) -> Texture2D:
	if tool_id.is_empty():
		return null
	var animation := StringName("interact_%s" % tool_id)
	if not AssetTable.has_unit_animation(&"pawn", animation):
		return null
	return _animated("pawn:%s" % tool_id, SpriteFrameFactory.for_unit(&"pawn", animation, COLOR))


func _still(key: String, entry: Dictionary) -> Texture2D:
	if entry.is_empty():
		return null
	if not _cache.has(key):
		_cache[key] = load(entry["path"]) as Texture2D
	return _cache.get(key)


func _animated(key: String, frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	var count := frames.get_frame_count(&"default")
	if count <= 0:
		return null
	# Un décalage par sujet : sans lui, quatre moutons et trois bûcherons
	# battent la même mesure, et le royaume a l'air d'une horloge.
	var offset := absi(key.hash()) % count
	return frames.get_frame_texture(&"default", (int(_frame) + offset) % count)


# --- Le doigt --------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var at: Vector2 = (event as InputEventMouseButton).position
	# À l'envers : ce qui est dessiné en dernier est devant, et c'est lui
	# que le doigt doit toucher.
	for index in range(_hits.size() - 1, -1, -1):
		var hit := _hits[index]
		if (hit["rect"] as Rect2).has_point(at):
			picked.emit(StringName(hit["kind"]), StringName(hit["id"]))
			accept_event()
			return
