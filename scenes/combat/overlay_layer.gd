extends Node2D

## Surbrillances (C1.16), télégraphe (C1.20) et prévisualisation (C1.18).
##
## Une seule couche qui dessine tout ce qui se superpose à la grille, dans
## un ordre fixe : objectif, déplacement, portée, zone d'effet, menace,
## sélection, fantôme. L'ordre compte — la menace doit rester lisible
## par-dessus les cases de déplacement, sinon le joueur perd l'information
## qui décide de son tour.
##
## Trois couches se ressemblent et ne disent pas la même chose (§ 17, § 18) :
##   move_cells    où je peux ALLER avec mes PM
##   attack_cells  où je peux VISER avec la compétence choisie
##   area_cells    ce que ce tir TOUCHERA vraiment, zone comprise
## Une Boule de feu a une portée de vingt cases visables et n'en touche que
## cinq : confondre les deux, c'est promettre au joueur ce qu'il n'aura pas.

var grid: Grid

var move_cells: Array[Vector2i] = []
var attack_cells: Array[Vector2i] = []
var objective_cells: Array[Vector2i] = []
var deployment_cells: Array[Vector2i] = []
## Cases que la compétence visée toucherait effectivement. Vide tant que le
## joueur n'a pas désigné de cible.
var area_cells: Array[Vector2i] = []
var selected_cell: Vector2i = Vector2i(-1, -1)
var ghost_cell: Vector2i = Vector2i(-1, -1)

## { cellule → dégâts annoncés }
var threat: Dictionary = {}

## { cellule → dégâts de l'attaque en cours de prévisualisation }
var preview_damage: Dictionary = {}

var _tile_size: int = 0
var _font: Font
var _pulse: float = 0.0


func setup(combat_grid: Grid) -> void:
	grid = combat_grid
	_tile_size = AssetTable.tile_size()
	_font = ThemeDB.fallback_font
	var theme: Theme = load("res://assets/fonts/pixel_theme.tres")
	if theme != null and theme.default_font != null:
		_font = theme.default_font
	queue_redraw()


func clear_selection() -> void:
	move_cells.clear()
	attack_cells.clear()
	area_cells.clear()
	selected_cell = Vector2i(-1, -1)
	ghost_cell = Vector2i(-1, -1)
	queue_redraw()


func _process(delta: float) -> void:
	if threat.is_empty():
		return
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	_fill(objective_cells, ViewSettings.color(&"objective"), Color.TRANSPARENT)
	_fill(
		deployment_cells,
		ViewSettings.color(&"deployment"), ViewSettings.color(&"deployment_border")
	)
	_fill(move_cells, ViewSettings.color(&"move"), ViewSettings.color(&"move_border"))
	_fill(attack_cells, ViewSettings.color(&"attack"), ViewSettings.color(&"attack_border"))
	_fill(area_cells, ViewSettings.color(&"area"), ViewSettings.color(&"area_border"))
	_draw_threat()

	if grid.contains(selected_cell):
		_outline(selected_cell, ViewSettings.color(&"selection"))
	if grid.contains(ghost_cell):
		_outline(ghost_cell, ViewSettings.color(&"ghost"))
	for cell: Vector2i in preview_damage.keys():
		_badge(cell, str(int(preview_damage[cell])), ViewSettings.color(&"attack_border"))


## La menace pulse doucement : c'est ce qui attire l'œil dessus en
## premier, avant même la lecture du chiffre.
func _draw_threat() -> void:
	if threat.is_empty():
		return
	var period := maxf(ViewSettings.duration(&"telegraph_pulse"), 0.01)
	var wave := 0.5 + 0.5 * sin(_pulse * TAU / period)
	var fill := ViewSettings.color(&"threat")
	fill.a *= 0.7 + 0.3 * wave
	var border := ViewSettings.color(&"threat_border")

	for cell: Vector2i in threat.keys():
		if not grid.contains(cell):
			continue
		_fill([cell] as Array[Vector2i], fill, border)

	# Le chiffre est L'information du jeu (§ 4.2). Posé à même le terrain il
	# se perd derrière un sprite ; il lui faut donc sa pastille, dessinée
	# par-dessus tout le reste, dans le coin de la case pour ne pas masquer
	# ce qui s'y trouve.
	var badge_border := ViewSettings.color(&"telegraph_badge_border")

	for cell: Vector2i in threat.keys():
		if not grid.contains(cell):
			continue
		_badge(cell, str(int(threat[cell])), badge_border)


## Pastille chiffrée dans le coin d'une case, dessinée par-dessus tout.
func _badge(cell: Vector2i, text: String, border: Color) -> void:
	if not grid.contains(cell):
		return
	var radius := ViewSettings.size_of(&"telegraph_badge_radius_px")
	var font_size := ViewSettings.integer(&"sizes", &"telegraph_font_size", 28)
	var centre := Vector2(
		cell.x * _tile_size + _tile_size - radius - 2.0,
		cell.y * _tile_size + radius + 2.0
	)
	draw_circle(centre, radius, ViewSettings.color(&"telegraph_badge"))
	draw_arc(centre, radius, 0.0, TAU, 24, border, 2.0)
	var span := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		_font, centre + Vector2(-span.x * 0.5, span.y * 0.34), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ViewSettings.color(&"damage_text")
	)


func _fill(cells: Array[Vector2i], fill: Color, border: Color) -> void:
	var inset := ViewSettings.size_of(&"highlight_inset_px")
	var width := ViewSettings.size_of(&"border_width_px")
	for cell: Vector2i in cells:
		var rect := Rect2(
			Vector2(cell.x * _tile_size + inset, cell.y * _tile_size + inset),
			Vector2(_tile_size - inset * 2.0, _tile_size - inset * 2.0)
		)
		if fill.a > 0.0:
			draw_rect(rect, fill)
		if border.a > 0.0:
			draw_rect(rect, border, false, width)


func _outline(cell: Vector2i, color: Color) -> void:
	var width := ViewSettings.size_of(&"border_width_px")
	draw_rect(
		Rect2(Vector2(cell.x * _tile_size, cell.y * _tile_size),
			Vector2(_tile_size, _tile_size)),
		color, false, width + 1.0
	)
