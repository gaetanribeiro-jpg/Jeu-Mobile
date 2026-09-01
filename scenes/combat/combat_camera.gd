extends Camera2D

## Caméra de combat : cadrage automatique, glissement et pincement (C1.17).
##
## Elle ne lit aucun évènement elle-même — c'est le contrôleur qui décide
## si un geste est un glissement de caméra ou un tap sur une case, et lui
## transmet. Deux nœuds qui écoutent le même doigt finissent toujours par
## se disputer.

var _bounds: Rect2 = Rect2()

## Tremblement en cours : amplitude restante en pixels, et son décompte.
##
## LE DÉCALAGE DU TREMBLEMENT EST TENU À PART DE `offset`, qui sert au
## cadrage sous le HUD. Les mélanger ferait dériver le cadrage à chaque
## coup — le tremblement s'ajoute au moment de dessiner et se retire tout
## seul.
var _shake_amplitude := 0.0
var _shake_left := 0.0
var _shake_total := 0.0
var _framing := Vector2.ZERO


## Cadre la grille dans la zone que le HUD laisse libre.
##
## `safe` est ce rectangle EN PIXELS D'ÉCRAN, position comprise, et
## `viewport` l'écran entier. La position est indispensable : une zone
## sûre n'est presque jamais centrée — le bandeau des compétences est plus
## haut que celui de l'objectif — et cadrer sur le centre de l'écran
## ferait passer les dernières rangées sous les boutons.
##
## PIÈGE DU SIGNE : `offset` déplace la CAMÉRA, donc le contenu va en sens
## inverse. Pour remonter le plateau de 50 pixels à l'écran, il faut
## descendre la caméra de 50. Et `offset` s'exprime en unités de monde :
## il se divise par le zoom.
func frame_board(
	grid: Grid, tile_size: int, safe: Rect2, viewport: Vector2 = Vector2.ZERO
) -> void:
	var span := Vector2(grid.width * tile_size, grid.height * tile_size)
	var margin := ViewSettings.number(&"camera", &"edge_margin_tiles", 1.0) * float(tile_size)
	_bounds = Rect2(-Vector2.ONE * margin, span + Vector2.ONE * margin * 2.0)

	position = span * 0.5
	if safe.size.x > 0.0 and safe.size.y > 0.0:
		var fit := minf(safe.size.x / span.x, safe.size.y / span.y)
		set_zoom_level(clampf(fit, _min_zoom(), _max_zoom()))
	else:
		set_zoom_level(ViewSettings.number(&"camera", &"zoom_default", 1.0))

	offset = Vector2.ZERO
	_framing = Vector2.ZERO
	if viewport.y > 0.0 and safe.size.y > 0.0:
		var safe_centre := safe.position.y + safe.size.y * 0.5
		offset.y = (viewport.y * 0.5 - safe_centre) / maxf(zoom.y, 0.001)
	_framing = offset
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


# --- Le tremblement --------------------------------------------------------
#
# Le § 12 met le hit stop et le tremblement en tête du rapport impact/coût,
# et les chiffres attendaient dans `view.json` depuis T1.9. Le réglage de
# confort les coupe : certains joueurs ne le supportent pas, et le § 48
# veut une interface lisible avant d'être spectaculaire.

## Secoue la caméra. `pixels` et `seconds` viennent de `view.json`.
func shake(pixels: float, seconds: float) -> void:
	if not Settings.flag(&"display", &"screen_shake", true):
		return
	if pixels <= 0.0 or seconds <= 0.0:
		return
	# Un coup pendant un tremblement ne l'additionne pas : il le remplace
	# s'il est plus fort. Sinon trois coups d'affilée décrochent l'écran.
	if pixels >= _shake_amplitude:
		_shake_amplitude = pixels
		_shake_total = seconds
		_shake_left = seconds
	set_process(true)


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		offset = _framing
		set_process(false)
		return
	_shake_left -= delta
	var strength := _shake_amplitude * maxf(_shake_left / maxf(_shake_total, 0.001), 0.0)
	# Alternance franche plutôt que bruit : à trois pixels et quinze
	# centièmes, un tirage aléatoire ne se distingue pas d'un tremblement
	# régulier, et un tremblement régulier se code en une ligne.
	var swing := strength * (1.0 if int(_shake_left * 60.0) % 2 == 0 else -1.0)
	offset = _framing + Vector2(swing, -swing * 0.5) / maxf(zoom.x, 0.001)
