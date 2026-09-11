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
## UN CONTROL QUI SE DESSINE LUI-MÊME, pas une nuée de nœuds. Les
## bâtiments, les gisements et les Pawns tiennent dans un `_draw` et une
## table de rectangles cliquables. Une trentaine de sprites ne justifient
## pas trente nœuds à tenir synchronisés avec un état qui change à chaque
## clic.
##
## LE SOL, LUI, EST UN VRAI PLATEAU (T12.11). Le reproche de Gaetan était
## exact : « c'est juste des bâtiments posés sur l'herbe ! Pas de
## décoration, pas de délimitations, pas d'animations ». `_draw_ground`
## carrelait UNE tuile d'herbe sur toute la surface — aucun rivage, aucun
## relief, aucune clôture, rien qui bouge.
##
## La réponse est celle de l'écran de titre (T11.3) : un `CombatBoard`
## bâti par `from_rows` et rendu par le MÊME `terrain_view` que les
## combats. Le royaume hérite gratuitement des rives du tileset, de
## l'écume animée, des rochers d'eau, de la mer et de son fondu, et il ne
## pourra jamais diverger du jeu. La clôture est le terrain `palisade`,
## que l'acte 4 employait déjà.

## Le joueur a désigné quelque chose : un bâtiment ou un chantier.
signal picked(kind: StringName, id: StringName)

const KIND_BUILDING := &"building"
const KIND_WORKSITE := &"worksite"

## Toile de référence. Les positions des données sont en pixels de
## celle-ci ; la vue la met à l'échelle de ce qu'on lui donne.
## La toile vient des DONNÉES (`Buildings.canvas`) : une constante ici ne
## pouvait être comparée par aucun outil, et la tour de guet est restée
## hors du terrain depuis sa création sans que rien ne s'en plaigne.

const TERRAIN_VIEW := "res://scenes/combat/terrain_view.gd"

const BUILDING_SCALE := 0.55
const PAWN_SCALE := 0.5
const COLOR := "Blue"

## La garde, dessinée en rangs de quatre sous son poste. Constantes de
## MISE EN PAGE, comme `PAWN_SCALE` : elles disent où poser une image, pas
## ce que vaut une mécanique.
const WATCH_PER_ROW := 4
const WATCH_SPACING := Vector2(30.0, 24.0)
const WATCH_OFFSET := Vector2(0.0, 46.0)

var kingdom: Kingdom
## Ce que le joueur a désigné. Le château au départ, jamais rien : un
## panneau vide au premier regard n'apprend pas qu'on peut toucher le
## terrain, il donne l'impression que l'écran ne fait rien.
var selected_kind: StringName = KIND_BUILDING
var selected_id: StringName = Buildings.KEYSTONE

var _terrain: Node2D
var _board: CombatBoard
var _frame := 0.0
## Horloge en SECONDES, à part de `_frame` qui compte des images. Un nuage
## dérive à une vitesse, pas à une cadence : le convertir depuis le
## numéro d'image le ferait changer de vitesse le jour où le pack
## passerait à autre chose que dix images par seconde.
var _clock := 0.0
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
	_build_terrain()
	resized.connect(_frame_terrain)
	set_process(not _blind)


## Le terrain du royaume, bâti une fois. Il ne change jamais : ce qui
## évolue, ce sont les bâtiments posés dessus.
func _build_terrain() -> void:
	var rows := KingdomGround.rows()
	if rows.is_empty():
		return
	_board = CombatBoard.from_rows(rows)
	if _board == null:
		return
	_terrain = Node2D.new()
	_terrain.set_script(load(TERRAIN_VIEW))
	# DERRIÈRE TOUT LE RESTE. Un `Node2D` enfant d'un `Control` se dessine
	# APRÈS le `_draw` du parent : sans `show_behind_parent`, la mer
	# recouvrait les bâtiments et l'écran paraissait vide.
	_terrain.show_behind_parent = true
	add_child(_terrain)
	_terrain.setup(_board)
	_frame_terrain()


## LE PLATEAU SE CADRE, IL NE S'ÉTIRE PLUS. Les positions s'étiraient sur
## les deux axes pour occuper tout l'espace — c'était la bonne réponse
## tant que le fond était un aplat d'herbe, parce qu'une bande noire au
## bord se lit comme un écran cassé. Avec une île, la bande n'existe
## plus : `terrain_view` peint la mer autour de la grille et l'éteint dans
## le fond (T9.9). Un tileset ne supporte pas l'étirement, et deux échelles
## différentes auraient décollé les bâtiments de leurs cases.
func _frame_terrain() -> void:
	if _terrain == null:
		return
	var factor := _scale()
	_terrain.scale = Vector2(factor, factor)
	_terrain.position = _origin()
	refresh()


func _process(delta: float) -> void:
	# Une seule horloge pour tout le monde. Les animations du pack sont à
	# 10 images par seconde, et rien ici ne demande mieux.
	var before := int(_frame)
	_frame += delta * float(AssetTable.fps())
	_clock += delta
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
func _scale() -> float:
	var canvas := Buildings.canvas()
	if size.x <= 0.0 or size.y <= 0.0 or canvas.x <= 0.0 or canvas.y <= 0.0:
		return 1.0
	return minf(size.x / canvas.x, size.y / canvas.y)


## Le coin haut-gauche de la grille, une fois centrée dans le contrôle.
func _origin() -> Vector2:
	return (size - Buildings.canvas() * _scale()) * 0.5


func _draw() -> void:
	_hits.clear()
	if kingdom == null:
		return
	var factor := _scale()
	_draw_props(factor)

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
			# La garde se dessine AVEC son poste, pour rester dans le tri
			# par profondeur : posée après tout le monde, elle passerait
			# devant un chantier situé plus bas qu'elle.
			if StringName(piece["id"]) == _watch_post():
				_draw_watch(factor)
		else:
			_draw_worksite(StringName(piece["id"]), factor)

	_draw_clouds(factor)


## Ce que le terrain ne dit pas et qui fait le village : les souches du
## bûcheron, les outils posés, les buissons (T12.11).
##
## UNE SOUCHE DIT CE QUI S'EST PASSÉ ICI. Trois arbres coupés à côté du
## chantier de bois racontent le travail mieux qu'un arbre de plus — et le
## pack en dessine quatre, inemployées jusqu'ici.
##
## Ils sont dessinés AVANT les bâtiments et les gisements, donc derrière :
## un décor ne passe jamais devant ce qu'on peut toucher.
func _draw_props(factor: float) -> void:
	_draw_fence(factor)
	for entry: Variant in KingdomGround.props():
		var prop: Dictionary = entry
		var texture := _texture("%s/%s" % [prop.get("category", ""), prop.get("key", "")])
		if texture == null:
			continue
		var cell: Array = prop.get("cell", [0, 0])
		var tile := float(KingdomGround.tile_size())
		var foot := Vector2(
			(float(cell[0]) + 0.5) * tile, (float(cell[1]) + 0.9) * tile
		)
		draw_texture_rect(
			texture,
			_place(foot, texture.get_size(), float(prop.get("scale", 1.0)) * factor),
			false
		)


## LA CLÔTURE, morceau par morceau, avec ses bouts et ses traverses.
##
## PAS LE TERRAIN `palisade` : il n'a qu'UNE tuile pour tout le jeu — la
## verticale —, et posée en rangée elle donnait des piquets isolés espacés
## de 64 px. Le pack dessine pourtant l'enceinte entière, coins compris.
## Changer la tuile du terrain aurait touché les cartes de l'acte 4, qui
## l'emploient à la verticale ; le royaume connaît ses coins, il peut donc
## demander le bon morceau.
func _draw_fence(factor: float) -> void:
	var key := KingdomGround.fence_atlas()
	if key.is_empty():
		return
	var declared := AssetTable.sprite(&"extra", key)
	if declared.is_empty():
		return
	var tile := float(KingdomGround.tile_size())
	for piece: Dictionary in KingdomGround.fence_pieces():
		var texture := _atlas(declared, KingdomGround.fence_part(StringName(piece["part"])))
		if texture == null:
			continue
		var cell: Vector2i = piece["cell"]
		# Posée PAR LE BAS de sa case, comme tout le reste : une clôture
		# dont le pied flotte au milieu de la case passe devant l'herbe
		# qu'elle devrait border.
		var foot := Vector2((float(cell.x) + 0.5) * tile, float(cell.y + 1) * tile)
		draw_texture_rect(
			texture, _place(foot, texture.get_size(), factor), false
		)


## Une cellule d'atlas. Le pack livre la clôture en une planche de 4 × 3.
func _atlas(declared: Dictionary, cell: Vector2i) -> Texture2D:
	if cell.x < 0 or cell.y < 0:
		return null
	var key := "atlas:%s:%d,%d" % [declared.get("path", ""), cell.x, cell.y]
	if _cache.has(key):
		return _cache[key]
	var source := load(String(declared.get("path", ""))) as Texture2D
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(
		cell.x * int(declared["cell_w"]), cell.y * int(declared["cell_h"]),
		int(declared["cell_w"]), int(declared["cell_h"])
	)
	atlas.filter_clip = true
	_cache[key] = atlas
	return atlas


## LES NUAGES SONT L'ANIMATION LA MOINS CHÈRE DU JEU, et celle qui se voit
## le plus longtemps : un mouton et un bûcheron bougent SUR PLACE, un
## nuage traverse. Huit dorment dans le pack et seul l'écran de titre les
## avait employés.
##
## Ils passent PAR-DESSUS tout le reste, comme une ombre de nuage — sous
## le halo de sélection, qui doit rester lisible.
func _draw_clouds(factor: float) -> void:
	var canvas := Buildings.canvas()
	var tile := float(KingdomGround.tile_size())
	for entry: Variant in KingdomGround.clouds():
		var cloud: Dictionary = entry
		var texture := _texture("decorations/%s" % cloud.get("key", ""))
		if texture == null:
			continue
		var span := texture.get_size() * float(cloud.get("scale", 1.0))
		# Une boucle qui commence HORS de l'île des deux côtés : un nuage
		# qui apparaît ou disparaît au bord se remarque, un nuage qui
		# entre par la mer non.
		var travel := canvas.x + span.x * 2.0
		var drift := float(cloud.get("start", 0.0)) * tile
		drift += _clock * float(cloud.get("speed", 0.0)) * tile
		var at := Vector2(
			fposmod(drift, travel) - span.x,
			float(cloud.get("y", 0.0)) * tile
		)
		draw_texture_rect(
			texture,
			Rect2(_origin() + at * factor, span * factor),
			false,
			Color(1.0, 1.0, 1.0, float(cloud.get("alpha", 1.0)))
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
	var at := _origin() + spot * _scale()
	return Rect2(Vector2(at.x - span.x * 0.5, at.y - span.y), span)


func _draw_halo(rect: Rect2) -> void:
	draw_rect(rect.grow(4.0), UiTheme.color(&"ink_gold"), false, 3.0)


func _draw_pip(anchor: Vector2, text: String, factor: float) -> void:
	var radius := 13.0 * maxf(factor, 0.6)
	var centre := anchor + Vector2(0.0, radius)
	draw_circle(centre, radius, ViewSettings.color(&"badge_back"))
	draw_circle(centre, radius, UiTheme.color(&"ink_gold"), false, 2.0)
	var font := ThemeDB.fallback_font
	var size := int(radius * 1.3)
	var span := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(
		font, centre + Vector2(-span.x * 0.5, span.y * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiTheme.color(&"ink_inverse")
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


## Où se tient la garde : à la tour de guet si elle est bâtie, au château
## sinon. On ne poste pas des sentinelles devant une maison.
func _watch_post() -> StringName:
	if kingdom.level_of(&"tower") > 0:
		return &"tower"
	return Buildings.KEYSTONE


## LA GARDE SE VOIT SUR LE TERRAIN, et le § 5 l'exige : « cette évolution
## visuelle est extrêmement importante ». Depuis que les bras qu'on ne met
## pas sur un chantier montent la garde, retirer un ouvrier est une
## décision — et une décision dont le résultat ne se voit nulle part est
## une case à cocher.
##
## HACHE EN MAIN, PAS D'OUTIL DE TRAVAIL. Le pack ne dessine pas de garde ;
## un Pawn à la hache, DEBOUT plutôt qu'en train de frapper, est ce qui
## s'en approche le plus — et il se distingue d'un coup d'œil du bûcheron,
## qui lui est en pleine animation d'interaction.
func _draw_watch(factor: float) -> void:
	var posted := kingdom.garrison()
	if posted <= 0:
		return
	var pawn := _watch_texture()
	if pawn == null:
		return
	var spot := Buildings.spot_of(_watch_post()) + WATCH_OFFSET
	for i in posted:
		var column := float(i % WATCH_PER_ROW)
		var row := float(i / WATCH_PER_ROW)
		var offset := Vector2(
			(column - float(WATCH_PER_ROW - 1) * 0.5) * WATCH_SPACING.x,
			row * WATCH_SPACING.y
		)
		draw_texture_rect(
			pawn, _place(spot + offset, pawn.get_size(), PAWN_SCALE * factor), false
		)


func _watch_texture() -> Texture2D:
	if not AssetTable.has_unit_animation(&"pawn", &"idle_axe"):
		return null
	return _animated("watch", SpriteFrameFactory.for_unit(&"pawn", &"idle_axe", COLOR))


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
