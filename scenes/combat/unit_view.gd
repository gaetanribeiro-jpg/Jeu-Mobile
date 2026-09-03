extends Node2D

## Un combattant à l'écran : son ombre, son sprite animé, sa barre de vie.
##
## Le pack ne fournit AUCUNE animation de mort sauf pour le Troll (§ 13.4bis).
## D'où l'effet universel : flash blanc, fondu, poussière — et gerbe d'eau
## si la mort est une noyade. C'est plus lisible qu'une vraie animation de
## mort, et ça coûte une heure.

signal animation_finished

const ANIMATION := &"default"

var unit: Unit
var color: String = "Blue"

var _sprite: AnimatedSprite2D
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _frames_cache: Dictionary = {}
var _float_phase: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO
var _busy: bool = false
var _font: Font


func setup(combat_unit: Unit, faction_color: String) -> void:
	unit = combat_unit
	color = faction_color
	_build()
	play(&"idle")
	refresh()


func _build() -> void:
	# Police chargée une fois : `_draw()` s'exécute à chaque image, et y
	# charger une ressource serait un load par unité et par image.
	_font = ThemeDB.fallback_font
	var theme: Theme = load("res://assets/fonts/pixel_theme.tres")
	if theme != null and theme.default_font != null:
		_font = theme.default_font

	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	var width := ViewSettings.size_of(&"health_bar_width_px")
	var height := ViewSettings.size_of(&"health_bar_height_px")
	var offset := ViewSettings.size_of(&"health_bar_offset_px")

	_bar_back = ColorRect.new()
	_bar_back.color = ViewSettings.color(&"bar_back")
	_bar_back.size = Vector2(width, height)
	_bar_back.position = Vector2(-width * 0.5, offset)
	add_child(_bar_back)

	_bar_fill = ColorRect.new()
	_bar_fill.size = Vector2(width, height)
	_bar_fill.position = _bar_back.position
	add_child(_bar_fill)

	# Chaque unité démarre à une phase différente, sinon toute l'escouade
	# flotte au même rythme et l'effet se voit comme un artifice.
	_float_phase = float(unit.id) * 0.7


func _process(delta: float) -> void:
	if _busy or unit == null or unit.is_downed():
		return
	_float_phase += delta
	var amplitude := ViewSettings.number(&"idle_float", &"amplitude_px", 0.0)
	var period := maxf(ViewSettings.number(&"idle_float", &"period_seconds", 1.0), 0.01)
	_sprite.position.y = _base_offset.y + sin(_float_phase * TAU / period) * amplitude


func _draw() -> void:
	if unit == null or unit.is_downed():
		return
	# Ombre portée : une ellipse noire à 30 %, l'effet le moins cher du § 12.
	draw_set_transform(Vector2(0, ViewSettings.size_of(&"shadow_offset_px")), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, ViewSettings.size_of(&"shadow_radius_x_px"),
		ViewSettings.color(&"shadow"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_slot()


## Numéro d'emplacement, sur les héros seulement.
##
## Les doublons de classe sont autorisés — deux Guerriers, trois Lanciers —
## et toute la compagnie est de la même couleur. Sans ce numéro, deux
## Guerriers sont littéralement le même sprite au même endroit du roster,
## et le joueur ne sait pas lequel il vient de déplacer. PROVISOIRE : il
## cédera la place à l'initiale du nom du héros quand les noms existeront
## (H2.2), qui dit la même chose en plus incarné.
func _draw_slot() -> void:
	if not unit.is_hero() or unit.slot <= 0 or _font == null:
		return
	var radius := ViewSettings.size_of(&"slot_badge_radius_px")
	# Au-dessus de la barre de vie et centré sur l'unité : posé sur le côté,
	# il sortait de la case pour un héros de la colonne de gauche.
	var centre := Vector2(0.0, ViewSettings.size_of(&"slot_badge_offset_px"))
	draw_circle(centre, radius, ViewSettings.color(&"slot_badge"))
	draw_arc(centre, radius, 0.0, TAU, 20, ViewSettings.color(&"slot_badge_border"), 2.0)
	var size := ViewSettings.integer(&"sizes", &"slot_font_size", 22)
	var text := str(unit.slot)
	var span := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(
		_font, centre + Vector2(-span.x * 0.5, span.y * 0.33), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, ViewSettings.color(&"slot_text")
	)


## Remet la barre de vie et la visibilité en accord avec l'état de l'unité.
func refresh() -> void:
	if unit == null:
		return
	var ratio := 0.0
	if unit.max_hit_points > 0:
		ratio = clampf(float(unit.hit_points) / float(unit.max_hit_points), 0.0, 1.0)
	var width := ViewSettings.size_of(&"health_bar_width_px")
	_bar_fill.size.x = width * ratio
	_bar_fill.color = ViewSettings.color(
		&"hero_bar" if unit.is_hero() else &"enemy_bar"
	)
	var alive := not unit.is_downed()
	_bar_back.visible = alive
	_bar_fill.visible = alive
	queue_redraw()


## Joue une animation du pack. Retombe sur « idle » si elle n'existe pas :
## toutes les unités n'ont pas les mêmes, et un sprite manquant ne doit
## jamais faire disparaître un combattant.
func play(animation: StringName) -> void:
	var frames := _frames_for(animation)
	if frames == null:
		frames = _frames_for(&"idle")
	if frames == null:
		return
	_sprite.sprite_frames = frames
	_sprite.animation = ANIMATION
	_sprite.play()


func face(direction: Vector2i) -> void:
	if direction.x != 0:
		_sprite.flip_h = direction.x < 0


## Glisse jusqu'à une position, à la vitesse réglée dans view.json.
func move_along(points: Array[Vector2]) -> void:
	if points.is_empty():
		return
	_busy = true
	play(&"run")
	var per_tile := ViewSettings.duration(&"move_per_tile")
	var tween := create_tween()
	var previous := position
	for point: Vector2 in points:
		face(Vector2i(signi(int(point.x - previous.x)), 0))
		tween.tween_property(self, "position", point, per_tile)
		previous = point
	await _tween_done(tween)
	if not is_inside_tree():
		return
	_busy = false
	play(&"idle")
	animation_finished.emit()


## Animation d'attaque, sans appliquer de dégâts : le moteur a déjà tranché.
func play_attack(toward: Vector2i) -> void:
	face(toward)
	_busy = true
	play(_attack_animation())
	await get_tree().create_timer(
		ViewSettings.duration(&"attack_windup") + ViewSettings.duration(&"attack_strike")
	).timeout
	if not is_inside_tree():
		return
	_busy = false
	play(&"idle")
	animation_finished.emit()


## Encaisse un coup : teinte blanche brève, puis retour.
func play_hit() -> void:
	var flash := ViewSettings.duration(&"death_flash")
	_sprite.modulate = ViewSettings.color(&"hit_flash")
	await get_tree().create_timer(flash).timeout
	if not is_inside_tree():
		return
	_sprite.modulate = Color.WHITE
	refresh()


## Mise hors de combat. Effet universel du § 13.4bis, faute d'animation de
## mort dans le pack : flash blanc, fondu, et poussière par-dessus.
func play_downed(drowned: bool = false) -> void:
	_busy = true
	refresh()
	_sprite.modulate = ViewSettings.color(&"hit_flash")
	await get_tree().create_timer(ViewSettings.duration(&"death_flash")).timeout
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, ViewSettings.duration(&"death_fade"))
	tween.tween_property(self, "scale", Vector2(0.85, 0.85), ViewSettings.duration(&"death_fade"))
	await _tween_done(tween)
	if not is_inside_tree():
		return
	visible = false
	_busy = false
	animation_finished.emit()
	if drowned:
		pass


## Attend la fin d'un Tween SANS rester suspendu si le nœud disparaît.
##
## `await tween.finished` paraît naturel, et c'est un piège : un Tween créé
## par un nœud est TUÉ avec lui, et un Tween tué n'émet jamais `finished`.
## La coroutine reste alors suspendue pour toujours et retient tout ce
## qu'elle capture — le sprite, l'unité, le chemin parcouru. Quitter un
## combat pendant qu'une unité se déplace suffisait à laisser tout cela
## derrière soi, une fois par combat, sur une campagne entière.
##
## Ici on avance image par image : dès que le nœud sort de l'arbre, on
## rend la main. L'attente se termine toujours.
func _tween_done(tween: Tween) -> void:
	while is_instance_valid(tween) and tween.is_valid() and tween.is_running():
		if not is_inside_tree():
			tween.kill()
			return
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame


func _attack_animation() -> StringName:
	for candidate: StringName in [&"attack", &"attack1", &"shoot", &"throw", &"heal"]:
		if _frames_for(candidate) != null:
			return candidate
	return &"idle"


func _frames_for(animation: StringName) -> SpriteFrames:
	var key := String(animation)
	if _frames_cache.has(key):
		return _frames_cache[key]
	# ON DEMANDE LE DESSIN, PAS L'IDENTITÉ. `sand_serpent` se dessine avec
	# `snake` : demander l'image à `class_id` rendait sept bêtes de l'acte 2
	# en ombre nue, sans une seule erreur dans la console.
	#
	# ET C'EST `sprite_color` QUI DIT DANS QUELLE TABLE REGARDER : un
	# ennemi HUMAIN porte une couleur de faction et se cherche parmi les
	# unités, une bête n'en a pas et se cherche parmi les ennemis. Deviner
	# d'après le nom marcherait jusqu'au jour où une bête s'appellerait
	# comme une classe.
	var frames: SpriteFrames = null
	var tint := color if unit.is_hero() else unit.sprite_color
	if unit.is_hero() or not unit.sprite_color.is_empty():
		if AssetTable.has_unit_animation(unit.sprite_id, animation):
			frames = SpriteFrameFactory.for_unit(unit.sprite_id, animation, tint)
	elif AssetTable.has_enemy_animation(unit.sprite_id, animation):
		frames = SpriteFrameFactory.for_enemy(unit.sprite_id, animation)
	_frames_cache[key] = frames
	return frames
