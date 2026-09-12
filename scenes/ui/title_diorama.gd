extends Node2D

## Le décor animé de l'écran de titre (T11.3).
##
## UNE ÎLE, PAS UNE IMAGE. Le décor est un vrai `CombatBoard` bâti par
## `CombatBoard.from_rows`, rendu par le même `terrain_view` que les
## combats. Il hérite donc gratuitement des rives du tileset, de l'écume
## animée de T9.10, des rochers et de la mer — et il ne pourra jamais
## diverger du jeu, parce que c'est le même code qui le dessine.
##
## CE QUE LE PACK ANIMAIT DÉJÀ ET QUE PERSONNE N'UTILISAIT : les huit
## nuages, la barque, les moutons, les arbres qui frémissent. Un écran de
## titre est exactement l'endroit où ça se voit, et ça ne coûte que de les
## poser.
##
## RIEN N'EST CHIFFRÉ ICI. La forme de l'île, la place du château, la
## vitesse de chaque nuage : tout est dans `data/ui/title.json`, parce
## qu'un décor est du ressenti et que le ressenti se règle sans toucher au
## code (règle 1).

const TERRAIN_VIEW := "res://scenes/combat/terrain_view.gd"

var _board: CombatBoard
var _terrain: Node2D
var _clouds: Array[Sprite2D] = []
var _cloud_speeds: PackedFloat32Array = PackedFloat32Array()
var _bobbers: Array[Dictionary] = []
var _clock := 0.0
var _span := Vector2.ZERO


func _ready() -> void:
	_build()
	# LE DÉCOR NE S'ANIME PAS EN HEADLESS. Un `queue_redraw` ou un
	# `_process` qui bouge des nœuds y empile une file que rien ne vide, et
	# le moteur tombe sur un signal 11 dont la trace ne désigne personne.
	# Le projet s'est déjà cogné à ça deux fois.
	set_process(DisplayServer.get_name() != "headless")


func _build() -> void:
	var rows := TitleSet.island_rows()
	if rows.is_empty():
		return
	_board = CombatBoard.from_rows(rows)
	if _board == null:
		return
	var tile := TitleSet.tile_size()
	_span = Vector2(_board.grid.width * tile, _board.grid.height * tile)

	_terrain = Node2D.new()
	_terrain.set_script(load(TERRAIN_VIEW))
	add_child(_terrain)
	_terrain.setup(_board)

	for entry: Variant in TitleSet.props():
		_add_prop(entry as Dictionary, tile)
	for entry: Variant in TitleSet.actors():
		_add_actor(entry as Dictionary, tile)
	_add_clouds(tile)


## Cadre le décor sur la fenêtre. Appelé par l'écran à chaque
## redimensionnement.
##
## ON COUVRE, ON NE CONTIENT PAS : le plus GRAND des deux rapports, quitte
## à déborder. Contenir laisserait deux bandes noires sur un écran plus
## large que la référence, et une bande noire au bord d'un écran de titre
## est ce qui fait bricolage.
func frame_to(viewport: Vector2) -> void:
	if _span == Vector2.ZERO or viewport.x <= 0.0 or viewport.y <= 0.0:
		return
	var factor := maxf(viewport.x / _span.x, viewport.y / _span.y)
	scale = Vector2(factor, factor)
	position = (viewport - _span * factor) * 0.5


func _add_prop(entry: Dictionary, tile: int) -> void:
	var category := StringName(entry.get("category", ""))
	var key := StringName(entry.get("key", ""))
	var declared := (
		AssetTable.building(key, String(entry.get("color", "Blue")))
		if category == &"buildings"
		else AssetTable.sprite(category, key)
	)
	if declared.is_empty():
		return

	var node: Node2D = null
	if StringName(declared.get("kind", AssetTable.KIND_IMAGE)) == AssetTable.KIND_STRIP:
		var frames := SpriteFrameFactory.for_sprite(category, key)
		if frames == null:
			return
		var animated := AnimatedSprite2D.new()
		animated.sprite_frames = frames
		# CHACUN À SON PROPRE DÉCALAGE D'IMAGE. Deux moutons en phase se
		# voient comme un copier-coller ; décalés, ils sont deux moutons.
		# Un nombre de JSON arrive en FLOTTANT : sans la conversion, le
		# modulo échoue et le décor entier disparaît sans que la scène
		# cesse de tourner.
		animated.frame = (int(entry.get("cell", [0, 0])[0]) * 3) % maxi(
			frames.get_frame_count(&"default"), 1
		)
		animated.play(&"default")
		node = animated
	else:
		var path := String(declared.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			return
		var still := Sprite2D.new()
		still.texture = load(path)
		node = still

	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.scale = Vector2.ONE * float(entry.get("scale", 1.0))
	# Ancré par le BAS, comme les décors de terrain : un sprite du pack se
	# dessine les pieds au sol.
	node.set("centered", false)
	var size := _size_of(declared) * node.scale
	node.position = TitleSet.anchor_of(entry, tile) - Vector2(size.x * 0.5, size.y)
	add_child(node)

	var bob := float(entry.get("bob", 0.0))
	if bob > 0.0:
		_bobbers.append({"node": node, "base": node.position.y, "amplitude": bob})


func _add_actor(entry: Dictionary, tile: int) -> void:
	var unit_id := StringName(entry.get("unit", ""))
	var color := String(entry.get("color", "Blue"))
	var frames := SpriteFrameFactory.for_unit(unit_id, &"idle", color)
	if frames == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.frame = (int(entry.get("cell", [0, 0])[0]) * 2) % maxi(
		frames.get_frame_count(&"default"), 1
	)
	sprite.play(&"default")
	sprite.centered = true
	# Le cadre d'une unité fait 192 px pour une case de 64 : le personnage
	# occupe le tiers central, donc son SOL est au milieu du cadre décalé
	# d'un quart de hauteur. Même calcul que la vue de combat.
	var frame_height := 0.0
	var first := frames.get_frame_texture(&"default", 0)
	if first != null:
		frame_height = first.get_size().y
	sprite.position = TitleSet.anchor_of(entry, tile) - Vector2(0, frame_height * 0.25)
	add_child(sprite)


func _add_clouds(tile: int) -> void:
	var block := TitleSet.clouds()
	var keys: Array = block.get("keys", [])
	var speeds: Array = block.get("speeds_px", [])
	var rows: Array = block.get("rows", [])
	var scales: Array = block.get("scales", [])
	var alpha := float(block.get("alpha", 0.5))

	for i in keys.size():
		var entry := AssetTable.sprite(&"decorations", StringName(keys[i]))
		if entry.is_empty():
			continue
		var path := String(entry.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var cloud := Sprite2D.new()
		cloud.texture = load(path)
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.centered = false
		cloud.scale = Vector2.ONE * float(scales[i] if i < scales.size() else 1.0)
		cloud.modulate = Color(1, 1, 1, alpha)
		# Étalés à l'écart les uns des autres au départ : lâchés tous du
		# même bord, il faudrait attendre une minute pour que le ciel ait
		# l'air peuplé.
		cloud.position = Vector2(
			_span.x * float(i) / float(maxi(keys.size(), 1)) - _span.x * 0.15,
			float(rows[i] if i < rows.size() else 0.0) * float(tile)
		)
		add_child(cloud)
		_clouds.append(cloud)
		_cloud_speeds.append(float(speeds[i] if i < speeds.size() else 8.0))


func _process(delta: float) -> void:
	_clock += delta
	for i in _clouds.size():
		var cloud := _clouds[i]
		cloud.position.x += _cloud_speeds[i] * delta
		# Reparti du bord opposé dès qu'il a fini de traverser, largeur
		# comprise : le faire réapparaître au bord visible ferait clignoter
		# un nuage entier d'un coup.
		var width := cloud.texture.get_width() * cloud.scale.x if cloud.texture != null else 0.0
		if cloud.position.x > _span.x:
			cloud.position.x = -width

	for entry: Dictionary in _bobbers:
		var node: Node2D = entry["node"]
		if not is_instance_valid(node):
			continue
		# La barque monte et descend. Une barque parfaitement immobile sur
		# une eau qui bouge est ce qui trahit le décor collé.
		node.position.y = float(entry["base"]) + sin(_clock * 1.4) * float(entry["amplitude"])


func _size_of(entry: Dictionary) -> Vector2:
	if StringName(entry.get("kind", AssetTable.KIND_IMAGE)) == AssetTable.KIND_STRIP:
		return Vector2(float(entry.get("frame_w", 0)), float(entry.get("frame_h", 0)))
	return Vector2(float(entry.get("w", 0)), float(entry.get("h", 0)))
