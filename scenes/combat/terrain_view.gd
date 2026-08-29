extends Node2D

## Dessine le terrain d'un CombatBoard (C1.15).
##
## Un `_draw()` plutôt qu'un TileMap : sur une grille 8 × 6, c'est 48
## rectangles par image, ce qui ne coûte rien, et ça évite d'avoir à
## construire et maintenir une ressource TileSet pour six types de tuile.
## Le jour où la carte de région affichera quarante parcelles, un TileMap
## se justifiera là-bas — pas ici.
##
## Aucun chemin de fichier : tout passe par AssetTable, et le choix de
## tuile par ViewSettings.

var board: CombatBoard

var _tileset: Texture2D
var _water: Texture2D
var _decorations: Dictionary = {}
var _tile_size: int = 0


func setup(combat_board: CombatBoard) -> void:
	board = combat_board
	_tile_size = AssetTable.tile_size()
	_tileset = _texture_of(AssetTable.sprite(&"terrain", &"tilemap_color1"))
	_water = _texture_of(AssetTable.sprite(&"terrain", &"water_background_color"))
	# La mousse animée du pack (Water Foam) est un ANNEAU de rivage, pas une
	# tuile d'eau : posée case par case elle donne des blocs de glace. Elle
	# sera reprise correctement en P8.7, avec le shader de scintillement.
	_load_decorations()
	queue_redraw()


func _draw() -> void:
	if board == null:
		return
	# L'eau est le FOND, pas une tuile : le tileset dessine des rives, ce
	# qui suppose de l'eau dessous. On peint donc tout en eau, puis on pose
	# la terre par-dessus avec le bord qui convient.
	if _water != null:
		draw_texture_rect(
			_water,
			Rect2(Vector2.ZERO, Vector2(
				board.grid.width * _tile_size, board.grid.height * _tile_size
			)),
			true
		)
	for cell: Vector2i in board.grid.cells():
		var tile := board.tile_at(cell)
		var origin := Vector2(cell.x * _tile_size, cell.y * _tile_size)
		if _is_land(cell):
			_draw_land(cell, tile, origin)
		_draw_decoration(tile, origin)


## Une case est « de la terre » si on peut marcher dessus. L'eau et le
## pont détruit n'en sont pas ; hors grille non plus, ce qui donne au
## plateau une rive tout autour et le fait lire comme une île.
func _is_land(cell: Vector2i) -> bool:
	if not board.grid.contains(cell):
		return false
	var tile := board.tile_at(cell)
	return tile != null and tile.is_walkable()


func _draw_land(cell: Vector2i, tile: Tile, origin: Vector2) -> void:
	if _tileset == null:
		draw_rect(Rect2(origin, Vector2(_tile_size, _tile_size)), Color(0.35, 0.45, 0.3))
		return
	var region := ViewSettings.terrain_tile_region(
		tile.terrain_id, _tile_size,
		_is_land(cell + Vector2i.LEFT), _is_land(cell + Vector2i.RIGHT),
		_is_land(cell + Vector2i.UP), _is_land(cell + Vector2i.DOWN)
	)
	draw_texture_rect_region(
		_tileset, Rect2(origin, Vector2(_tile_size, _tile_size)), region
	)


func _draw_decoration(tile: Tile, origin: Vector2) -> void:
	var texture: Texture2D = _decorations.get(String(tile.terrain_id), null)
	if texture == null:
		return
	# Les décors du pack sont plus grands que la case et posés au sol :
	# on les centre horizontalement et on les cale par le bas.
	var span := texture.get_size()
	var position := Vector2(
		origin.x + (float(_tile_size) - span.x) * 0.5,
		origin.y + float(_tile_size) - span.y
	)
	draw_texture(texture, position)


## Un décor peut être une bande d'animation (un arbre qui bouge), une image
## fixe (un rocher) ou une cellule d'atlas (un morceau de palissade). On
## regarde ce que la table déclare avant d'aller chercher, plutôt que de
## tenter un découpage qui échouera bruyamment deux fois sur trois.
func _load_decorations() -> void:
	_decorations.clear()
	for terrain_id: StringName in CombatRules.terrain_ids():
		var entry := ViewSettings.terrain_decoration(terrain_id)
		if entry.is_empty():
			continue
		var declared := AssetTable.sprite(entry["category"], entry["key"])
		if declared.is_empty():
			continue
		var texture: Texture2D = null
		match StringName(declared["kind"]):
			AssetTable.KIND_STRIP:
				var frames := SpriteFrameFactory.for_sprite(entry["category"], entry["key"])
				if frames != null and frames.get_frame_count(&"default") > 0:
					texture = frames.get_frame_texture(&"default", 0)
			AssetTable.KIND_ATLAS:
				texture = _atlas_cell(declared, entry.get("cell", Vector2i(1, 1)))
			_:
				texture = _texture_of(declared)
		if texture != null:
			_decorations[String(terrain_id)] = texture


## Une cellule précise d'un atlas — la palissade fait 4 x 3 tuiles de 64,
## et on n'en veut qu'une.
func _atlas_cell(entry: Dictionary, cell: Vector2i) -> Texture2D:
	var source := _texture_of(entry)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(
		cell.x * int(entry["cell_w"]), cell.y * int(entry["cell_h"]),
		int(entry["cell_w"]), int(entry["cell_h"])
	)
	atlas.filter_clip = true
	return atlas


func _texture_of(entry: Dictionary) -> Texture2D:
	if entry.is_empty():
		return null
	return load(entry["path"]) as Texture2D
