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

## Couleur de faction des bâtiments posés sur un plateau. Celle du joueur :
## une carte de défense montre SON royaume.
const BUILDING_COLOR := "Blue"

var _tileset: Texture2D
var _water: Texture2D
var _decorations: Dictionary = {}
var _tile_size: int = 0

## La mer qui bouge : l'écume du rivage et les rochers des deux bandes.
##
## LE PACK LES DESSINE DÉJÀ, et ils dormaient depuis le premier jour.
## « Water Foam » est une plaque d'écume animée en 16 images, faite pour
## être posée SOUS une case de terre : ce qui dépasse fait le rivage. Les
## « Water Rocks » sont quatre tailles de rocher, chacune avec son anneau
## d'écume qui bat. Une mer d'aplat turquoise n'est pas naturelle ; une
## mer avec un rivage qui mousse et des cailloux qui affleurent, si.
var _foam: SpriteFrames
var _rocks: Array[SpriteFrames] = []
var _sea_frame := 0
var _sea_clock := 0.0

## Décide où tombent les rochers. PAS UN TIRAGE ALÉATOIRE : une fonction
## du plateau et de la case. La règle 4 veut une graine, mais le décor
## n'a pas à en consommer une — et surtout pas celle du combat, qu'il
## décalerait (c'est la leçon du renfort de nuit, T8.1). Une valeur
## calculée est reproductible par construction, et elle change d'une
## carte à l'autre parce que le terrain change.
var _decor_seed := 0


func setup(combat_board: CombatBoard) -> void:
	board = combat_board
	_tile_size = AssetTable.tile_size()
	_tileset = _texture_of(AssetTable.sprite(&"terrain", &"tilemap_color1"))
	_water = _texture_of(AssetTable.sprite(&"terrain", &"water_background_color"))
	# La mousse animée du pack (Water Foam) est un ANNEAU de rivage, pas une
	# tuile d'eau : posée case par case elle donne des blocs de glace. Elle
	# sera reprise correctement en P8.7, avec le shader de scintillement.
	_load_decorations()
	_load_sea()
	queue_redraw()


func _draw() -> void:
	if board == null:
		return
	# L'eau est le FOND, pas une tuile : le tileset dessine des rives, ce
	# qui suppose de l'eau dessous. On peint donc tout en eau, puis on pose
	# la terre par-dessus avec le bord qui convient.
	#
	# ET ELLE DÉBORDE LA GRILLE À GAUCHE ET À DROITE. Le plateau est une
	# île — c'est déjà ce que dit `_is_land`, qui compte le hors-grille
	# comme de l'eau pour dessiner les rives. Il lui manquait sa mer.
	#
	# CE N'EST QUE DU DÉCOR, et ça ne doit jamais devenir autre chose : la
	# grille reste 12 × 9, la caméra cadre TOUJOURS sur elle seule, et le
	# clamp de déplacement ne bouge pas. Élargir la zone CADRÉE coûterait
	# 17 % de la taille des cases — c'est la hauteur qui contraint le
	# cadrage, donc ajouter des colonnes fait passer la contrainte en
	# largeur et tout rétrécit d'un coup.
	if _water != null:
		draw_texture_rect(_water, _sea(), true)
		_draw_foam()
		_draw_water_rocks()
		# LE FONDU PASSE APRÈS LES ROCHERS, pas avant : sinon un rocher
		# posé dans la partie éteinte de la bande flotterait, net, sur du
		# noir. Il doit s'éteindre avec l'eau qui le porte.
		_fade_sea_edges()
	for cell: Vector2i in board.grid.cells():
		var tile := board.tile_at(cell)
		var origin := Vector2(cell.x * _tile_size, cell.y * _tile_size)
		if _is_land(cell):
			_draw_land(cell, tile, origin)
		_draw_hazard(tile, origin)
		_draw_decoration(tile, origin)

	# Falaises en second passage : elles débordent sur la case du dessous,
	# donc elles doivent passer après toutes les tuiles de base.
	for cell: Vector2i in board.grid.cells():
		_draw_cliff(cell)


## Le rectangle de mer : la grille, élargie À L'HORIZONTALE seulement.
##
## HORIZONTALE SEULEMENT, ET C'EST TOUT LE RÉGLAGE. Une mer qui déborde
## aussi en haut et en bas remplit l'écran entier — « ça fait trop d'eau,
## le fond est entièrement bleu ». Le fond sombre à motif reste le fond ;
## la mer ne fait que deux bandes, à gauche et à droite du plateau, là où
## il y avait du vide entre les panneaux et l'île.
##
## LA MARGE EST BIEN PLUS LARGE QUE CE QU'ON VOIT, et exprès : ce qui se
## voit, c'est l'écart entre le bord d'un panneau et le bord du plateau —
## environ deux cases. Le reste passe SOUS les panneaux, qui sont opaques.
## Déborder largement est ce qui empêche une couture d'apparaître quand le
## joueur fait glisser la caméra ou l'écarte au pincement.
func _sea() -> Rect2:
	var margin := ViewSettings.number(&"sizes", &"sea_side_tiles", 0.0) * float(_tile_size)
	# EN HAUTEUR, JUSTE DE QUOI PORTER L'ÉCUME. La plaque d'écume déborde
	# d'une trentaine de pixels au-dessus de la première rangée : sans ce
	# liseré d'eau, elle se posait à même le fond sombre et l'île avait un
	# contour blanc au lieu d'un rivage. Ce n'est pas une bande — c'est
	# l'épaisseur du rivage, et elle passe sous les bandeaux du HUD.
	var edge := ViewSettings.number(&"sizes", &"sea_edge_tiles", 0.0) * float(_tile_size)
	return Rect2(
		Vector2(-margin, -edge),
		Vector2(
			board.grid.width * _tile_size + margin * 2.0,
			board.grid.height * _tile_size + edge * 2.0
		)
	)


## Les quatre bords extérieurs de la mer se fondent dans le fond.
##
## SANS ÇA, LA MER SE TERMINE PAR UNE COUPURE FRANCHE. Elle ne peut pas
## s'arrêter sous les panneaux : ceux-ci ne descendent pas jusqu'en bas,
## et sous eux le turquoise redevient visible jusqu'au bord de la fenêtre.
## Un dégradé vers la couleur du FOND — pas vers une eau profonde
## inventée — fait que l'eau s'éteint au lieu d'être tranchée.
##
## LES QUATRE CÔTÉS, PAS SEULEMENT LES DEUX BANDES. En hauteur la marge
## ne vaut que trois quarts de case — l'épaisseur du rivage, de quoi
## porter l'écume — mais tranchée net elle faisait une barre turquoise
## au-dessus de l'île. Éteinte, elle ne se lit plus comme une bande.
##
## QUATRE TRAPÈZES : `draw_polygon` interpole entre les couleurs de ses
## sommets, et ils se rejoignent sur les diagonales des coins, où les
## deux voisins portent déjà la même valeur.
##
## `UiTheme` plutôt qu'une couleur de `view.json` : la cible est
## exactement le fond de l'interface, et la recopier ici garantirait
## qu'un jour les deux ne diront plus la même chose.
func _fade_sea_edges() -> void:
	var sea := _sea()
	var fade := ViewSettings.number(&"sizes", &"sea_fade_tiles", 0.0) * float(_tile_size)
	var edge := ViewSettings.number(&"sizes", &"sea_edge_tiles", 0.0) * float(_tile_size)
	if fade <= 0.0 and edge <= 0.0:
		return
	var inner := sea.grow_individual(-fade, -edge, -fade, -edge)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return

	var ground := UiTheme.color(&"backdrop")
	var clear := Color(ground.r, ground.g, ground.b, 0.0)
	var outside := [
		sea.position, Vector2(sea.end.x, sea.position.y),
		sea.end, Vector2(sea.position.x, sea.end.y),
	]
	var inside := [
		inner.position, Vector2(inner.end.x, inner.position.y),
		inner.end, Vector2(inner.position.x, inner.end.y),
	]
	for side in 4:
		var next := (side + 1) % 4
		draw_polygon(
			PackedVector2Array([
				outside[side], outside[next], inside[next], inside[side]
			]),
			PackedColorArray([ground, ground, clear, clear])
		)


## Charge l'écume et les rochers, et met le nœud en marche s'il y a de
## quoi animer.
##
## PAS D'ANIMATION EN HEADLESS. `queue_redraw()` dans un `_process` y
## empile une file que rien ne vide, et le moteur tombe sur un signal 11
## dont la trace ne désigne personne. Le projet s'est déjà cogné à ça une
## fois — c'est la même règle que pour les jauges.
func _load_sea() -> void:
	_foam = SpriteFrameFactory.for_sprite(&"terrain", &"water_foam")
	_rocks.clear()
	for index in range(1, 5):
		var frames := SpriteFrameFactory.for_sprite(
			&"decorations", StringName("water_rocks_%02d" % index)
		)
		if frames != null and frames.get_frame_count(&"default") > 0:
			_rocks.append(frames)

	_decor_seed = board.grid.width * 31 + board.grid.height
	for cell: Vector2i in board.grid.cells():
		var tile := board.tile_at(cell)
		if tile != null:
			_decor_seed = (_decor_seed * 33 + String(tile.terrain_id).length()
				+ cell.x + cell.y * 7) & 0x3FFFFFFF

	var animated := _foam != null or not _rocks.is_empty()
	set_process(animated and DisplayServer.get_name() != "headless")


## Avance l'animation de la mer au rythme du pack, et RIEN QUE quand
## l'image change. Redessiner à chaque trame reviendrait à repeindre tout
## le terrain soixante fois par seconde pour une écume qui en a dix.
func _process(delta: float) -> void:
	var count := _sea_frames()
	if count <= 0:
		set_process(false)
		return
	_sea_clock += delta
	var wanted := int(_sea_clock * float(maxi(AssetTable.fps(), 1))) % count
	if wanted != _sea_frame:
		_sea_frame = wanted
		queue_redraw()


func _sea_frames() -> int:
	if _foam != null:
		return _foam.get_frame_count(&"default")
	if not _rocks.is_empty():
		return _rocks[0].get_frame_count(&"default")
	return 0


## L'écume du rivage : une plaque sous chaque case de terre qui touche
## l'eau.
##
## SOUS LA TERRE, ET C'EST TOUT L'ASTUCE. La plaque du pack fait 192 px
## pour une case de 64 : centrée sur la case, elle déborde d'une trentaine
## de pixels tout autour, et la terre dessinée par-dessus n'en laisse voir
## que ce débord. Les plaques des cases voisines se recouvrent, donc le
## rivage est continu sans qu'on ait à choisir un morceau par orientation
## — ce que le pack ne fournit d'ailleurs pas.
##
## Quatre voisins, pas huit : c'est l'adjacence du jeu, et une plaque
## large de trois cases bouche de toute façon les diagonales.
func _draw_foam() -> void:
	if _foam == null:
		return
	var texture := _foam.get_frame_texture(&"default", _sea_frame)
	if texture == null:
		return
	var span := texture.get_size()
	for cell: Vector2i in board.grid.cells():
		if not _is_land(cell):
			continue
		if not _touches_water(cell):
			continue
		var centre := Vector2(
			(float(cell.x) + 0.5) * _tile_size, (float(cell.y) + 0.5) * _tile_size
		)
		draw_texture_rect(texture, Rect2(centre - span * 0.5, span), false)


func _touches_water(cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not _is_land(cell + step):
			return true
	return false


## Les rochers des deux bandes d'eau.
##
## ILS NE VONT QUE DANS LA PARTIE FRANCHE DE LA BANDE — la largeur totale
## moins le fondu — parce qu'un rocher net sur de l'eau éteinte se voit
## comme une erreur. Et jamais dans la grille : ce serait un décor qu'on
## prendrait pour un obstacle, alors qu'il n'en est pas un.
func _draw_water_rocks() -> void:
	if _rocks.is_empty():
		return
	var band := int(
		ViewSettings.number(&"sizes", &"sea_side_tiles", 0.0)
		- ViewSettings.number(&"sizes", &"sea_fade_tiles", 0.0)
		+ 1.0
	)
	if band <= 0:
		return
	var one_in := maxi(int(ViewSettings.number(&"sizes", &"sea_rock_one_in", 0.0)), 2)
	var columns: Array[int] = []
	for offset in range(1, band + 1):
		columns.append(-offset)
		columns.append(board.grid.width - 1 + offset)

	for x: int in columns:
		for y in board.grid.height:
			var noise := _decor_hash(x, y)
			if noise % one_in != 0:
				continue
			var frames: SpriteFrames = _rocks[(noise / one_in) % _rocks.size()]
			var count := frames.get_frame_count(&"default")
			# Chaque rocher bat à son propre décalage : tous en phase, la
			# bande clignoterait d'un seul bloc.
			var texture := frames.get_frame_texture(
				&"default", (_sea_frame + noise) % count
			)
			if texture == null:
				continue
			# DÉCALÉ DANS SA CASE, sinon la bande trahit la grille : des
			# rochers alignés au pixel près sur des colonnes, ça ne
			# ressemble à rien de naturel.
			var jitter := Vector2(
				float(noise % 29) - 14.0, float((noise / 29) % 29) - 14.0
			)
			var origin := Vector2(x * _tile_size, y * _tile_size) + jitter
			draw_texture_rect(
				texture, Rect2(origin, Vector2(_tile_size, _tile_size)), false
			)


func _decor_hash(x: int, y: int) -> int:
	var mixed := _decor_seed + x * 19349663 + y * 83492791
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return (mixed ^ (mixed >> 16)) & 0x3FFFFFFF


## Une case est « de la terre » si ce n'est pas de l'eau — et surtout PAS
## « si on peut marcher dessus ». Un rocher est infranchissable et reste
## de la terre ; le confondre avec de l'eau le fait apparaître au fond
## d'une mare. Hors grille compte comme de l'eau, ce qui donne au plateau
## une rive tout autour et le fait lire comme une île.
func _is_land(cell: Vector2i) -> bool:
	if not board.grid.contains(cell):
		return false
	var tile := board.tile_at(cell)
	if tile == null:
		return false
	return tile.is_walkable() or not tile.is_swimmable()


## Le voisin est-il peint dans le même bloc de tuiles ? L'eau et le hors
## grille n'en sont jamais, ce qui donne les rives ; une colline voisine
## d'herbe non plus, ce qui donne le relief.
func _same_block(cell: Vector2i, block: String) -> bool:
	if not _is_land(cell):
		return false
	return ViewSettings.terrain_block_name(board.tile_at(cell).terrain_id) == block


func _draw_land(cell: Vector2i, tile: Tile, origin: Vector2) -> void:
	if _tileset == null:
		draw_rect(Rect2(origin, Vector2(_tile_size, _tile_size)),
			ViewSettings.color(&"terrain_fallback"))
		return
	var block := ViewSettings.terrain_block_name(tile.terrain_id)
	var region := ViewSettings.terrain_tile_region(
		tile.terrain_id, _tile_size,
		_same_block(cell + Vector2i.LEFT, block), _same_block(cell + Vector2i.RIGHT, block),
		_same_block(cell + Vector2i.UP, block), _same_block(cell + Vector2i.DOWN, block)
	)
	draw_texture_rect_region(
		_tileset, Rect2(origin, Vector2(_tile_size, _tile_size)), region
	)


## Lèvre de pierre sous une colline, quand la case du dessous n'en est pas
## une. C'est ce qui rend le relief visible : sans elle, l'intérieur du
## plateau et celui de l'herbe sont la même image.
func _draw_cliff(cell: Vector2i) -> void:
	if _tileset == null:
		return
	var tile := board.tile_at(cell)
	if tile == null or tile.ranged_range_bonus() <= 0:
		return
	var below := board.tile_at(cell + Vector2i.DOWN)
	if below != null and below.ranged_range_bonus() > 0:
		return

	# La falaise PEND SOUS la colline plutôt que de mordre dedans : la case
	# de la colline garde son herbe entière, et le relief se lit au décroché.
	var height := ViewSettings.size_of(&"hill_cliff_height_px")
	var region := ViewSettings.hill_cliff_region(_tile_size)
	region.size.y = height
	draw_texture_rect_region(
		_tileset,
		Rect2(
			Vector2(cell.x * _tile_size, float((cell.y + 1) * _tile_size)),
			Vector2(_tile_size, height)
		),
		region
	)


## Une teinte franche sous tout terrain qui blesse celui qui s'y arrête.
##
## Le sprite seul ne suffit pas : une flamme du pack est étroite et laisse
## voir l'herbe autour, si bien qu'on ne sait pas où la case commence ni où
## elle finit. Or c'est exactement ce qu'il faut savoir avant de poser le
## pied. La teinte dit la CASE, le sprite dit ce que c'est.
func _draw_hazard(tile: Tile, origin: Vector2) -> void:
	if tile == null or tile.damage_per_activation() <= 0:
		return
	var rect := Rect2(origin, Vector2(_tile_size, _tile_size))
	draw_rect(rect, ViewSettings.color(&"hazard"))
	draw_rect(rect, ViewSettings.color(&"hazard_border"), false,
		ViewSettings.size_of(&"border_width_px"))


func _draw_decoration(tile: Tile, origin: Vector2) -> void:
	var texture: Texture2D = _decorations.get(String(tile.terrain_id), null)
	if texture == null:
		return
	# Les décors du pack sont plus grands que la case et posés au sol :
	# on les centre horizontalement et on les cale par le bas.
	#
	# UN PLAFOND DE LARGEUR, en cases. Les bâtiments font 128 à 320 pixels
	# pour des cases de 64 : posés à leur taille native sur la carte de
	# défense (§ 38), ils se recouvraient et débordaient du plateau. Les
	# décors plus petits ne sont pas touchés — un arbre garde sa taille.
	var span := texture.get_size()
	var ceiling := ViewSettings.size_of(&"decoration_max_tiles") * float(_tile_size)
	if ceiling > 0.0 and span.x > ceiling:
		span *= ceiling / span.x
	var position := Vector2(
		origin.x + (float(_tile_size) - span.x) * 0.5,
		origin.y + float(_tile_size) - span.y
	)
	draw_texture_rect(texture, Rect2(position, span), false)


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
		# Les BÂTIMENTS ne sont pas une catégorie simple : ils se résolvent
		# par couleur de faction. C'est la carte de défense du royaume
		# (§ 38) qui en a amené sur un plateau de combat, et `sprite()`
		# poussait une erreur pour chaque tuile de bâtiment.
		var declared := (
			AssetTable.building(StringName(entry["key"]), BUILDING_COLOR)
			if StringName(entry["category"]) == &"buildings"
			else AssetTable.sprite(entry["category"], entry["key"])
		)
		if declared.is_empty():
			continue
		var texture: Texture2D = null
		match StringName(declared["kind"]):
			AssetTable.KIND_STRIP:
				var frames := SpriteFrameFactory.for_sprite(entry["category"], entry["key"])
				var count := frames.get_frame_count(&"default") if frames != null else 0
				if count > 0:
					var wanted: int = clampi(int(entry.get("frame", 0)), 0, count - 1)
					texture = frames.get_frame_texture(&"default", wanted)
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
