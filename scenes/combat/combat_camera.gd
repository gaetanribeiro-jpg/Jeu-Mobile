extends Camera2D

## Caméra de combat : cadrage automatique, glissement et pincement (C1.17).
##
## Elle ne lit aucun évènement elle-même — c'est le contrôleur qui décide
## si un geste est un glissement de caméra ou un tap sur une case, et lui
## transmet. Deux nœuds qui écoutent le même doigt finissent toujours par
## se disputer.

var _bounds: Rect2 = Rect2()


## Cadre la grille entière et fixe les limites de déplacement.
func frame_board(grid: Grid, tile_size: int, viewport_size: Vector2) -> void:
	var span := Vector2(grid.width * tile_size, grid.height * tile_size)
	var margin := ViewSettings.number(&"camera", &"edge_margin_tiles", 1.0) * float(tile_size)
	_bounds = Rect2(-Vector2.ONE * margin, span + Vector2.ONE * margin * 2.0)

	position = span * 0.5
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var fit := minf(viewport_size.x / span.x, viewport_size.y / span.y)
		set_zoom_level(clampf(fit, _min_zoom(), _max_zoom()))
	else:
		set_zoom_level(ViewSettings.number(&"camera", &"zoom_default", 1.0))
	_clamp_position()


func set_zoom_level(level: float) -> void:
	var clamped := clampf(level, _min_zoom(), _max_zoom())
	zoom = Vector2(clamped, clamped)


func zoom_level() -> float:
	return zoom.x


## Glissement : on déplace en unités de monde, pour que la caméra suive le
## doigt exactement quel que soit le zoom.
func pan(screen_delta: Vector2) -> void:
	position -= screen_delta / maxf(zoom.x, 0.001)
	_clamp_position()


## Pincement, autour du point tenu.
func pinch(factor: float, focus: Vector2) -> void:
	var before := get_global_mouse_position() if focus == Vector2.INF else focus
	set_zoom_level(zoom.x * factor)
	if focus != Vector2.INF:
		position += (before - focus) * 0.0
	_clamp_position()


## Recentre doucement sur une case — utilisé pendant le tour ennemi, pour
## que le joueur voie ce qui se passe même hors écran (C1.22).
func focus_on(world_position: Vector2, delta: float) -> void:
	var speed := ViewSettings.number(&"camera", &"follow_speed", 8.0)
	position = position.lerp(world_position, clampf(speed * delta, 0.0, 1.0))
	_clamp_position()


func _min_zoom() -> float:
	return ViewSettings.number(&"camera", &"zoom_min", 0.5)


func _max_zoom() -> float:
	return ViewSettings.number(&"camera", &"zoom_max", 3.0)


func _clamp_position() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	position.x = clampf(position.x, _bounds.position.x, _bounds.end.x)
	position.y = clampf(position.y, _bounds.position.y, _bounds.end.y)
