class_name Grid
extends RefCounted

## Géométrie de la grille de combat. Rien d'autre.
##
## Cette classe ne connaît ni les tuiles, ni les unités, ni le terrain :
## elle répond uniquement aux questions « cette case existe-t-elle »,
## « quels sont ses voisins », « à quelle distance », « quelle ligne
## relie ces deux cases ». C'est le socle sur lequel CombatBoard pose
## le reste.
##
## Le mode d'adjacence vient de `data/combat/rules.json` :
##   orthogonal → 4 voisins, distance de Manhattan (référence Into the Breach)
##   diagonal   → 8 voisins, distance de Chebyshev
## Il n'est pas écrit en dur ici, parce que c'est encore une question
## ouverte : le Lancier et le Canon sont dessinés sur 8 directions.

const ORTHOGONAL_STEPS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]

const DIAGONAL_STEPS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]

var width: int
var height: int

var _adjacency: String


func _init(grid_width: int, grid_height: int, adjacency: String = "") -> void:
	width = grid_width
	height = grid_height
	_adjacency = adjacency if not adjacency.is_empty() else CombatRules.adjacency()


## Grille de combat standard, aux dimensions de `rules.json`.
static func for_combat() -> Grid:
	return Grid.new(
		int(CombatRules.rule(&"grid", &"combat_width", 0)),
		int(CombatRules.rule(&"grid", &"combat_height", 0))
	)


## Grille de siège, plus grande.
static func for_siege() -> Grid:
	return Grid.new(
		int(CombatRules.rule(&"grid", &"siege_width", 0)),
		int(CombatRules.rule(&"grid", &"siege_height", 0))
	)


func adjacency() -> String:
	return _adjacency


func is_diagonal() -> bool:
	return _adjacency == CombatRules.ADJACENCY_DIAGONAL


## Pas élémentaires autorisés, selon le mode d'adjacence.
func steps() -> Array[Vector2i]:
	return DIAGONAL_STEPS if is_diagonal() else ORTHOGONAL_STEPS


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func cell_count() -> int:
	return width * height


## Toutes les cases, en balayage ligne par ligne.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			out.append(Vector2i(x, y))
	return out


## Voisins immédiats présents sur la grille.
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step: Vector2i in steps():
		var candidate := cell + step
		if contains(candidate):
			out.append(candidate)
	return out


## Distance de jeu entre deux cases : Manhattan en orthogonal, Chebyshev
## en diagonal. C'est cette distance-là qui définit une portée « 2 à 4 ».
func distance(from: Vector2i, to: Vector2i) -> int:
	var delta := (to - from).abs()
	if is_diagonal():
		return maxi(delta.x, delta.y)
	return delta.x + delta.y


## Toutes les cases à exactement `radius` de distance.
func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius < 0:
		return out
	for cell: Vector2i in cells():
		if distance(center, cell) == radius:
			out.append(cell)
	return out


## Toutes les cases dont la distance tient dans [min_radius, max_radius].
## C'est la forme brute d'une portée, avant toute ligne de vue.
func cells_in_range(center: Vector2i, min_radius: int, max_radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells():
		var d := distance(center, cell)
		if d >= min_radius and d <= max_radius:
			out.append(cell)
	return out


## Pas unitaire de `from` vers `to`, pour une poussée ou une charge.
## Renvoie Vector2i.ZERO si les deux cases sont confondues.
func direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if is_diagonal():
		return Vector2i(signi(delta.x), signi(delta.y))
	# En orthogonal, on pousse selon l'axe dominant : une poussée doit
	# toujours produire un pas légal, jamais une diagonale.
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


## Cases traversées de `from` à `to`, bornes comprises (Bresenham).
## Sert à la ligne de vue et aux attaques en ligne.
func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var delta := (to - from).abs()
	var step := Vector2i(
		1 if to.x > from.x else -1,
		1 if to.y > from.y else -1
	)
	var current := from
	var error := delta.x - delta.y
	out.append(current)
	while current != to:
		var double_error := error * 2
		if double_error > -delta.y:
			error -= delta.y
			current.x += step.x
		if double_error < delta.x:
			error += delta.x
			current.y += step.y
		out.append(current)
	return out


## Conversion grille → monde : le coin haut-gauche de la case.
func to_world(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2(cell.x * tile_size, cell.y * tile_size)


## Conversion grille → monde : le centre de la case, là où se pose un sprite.
func to_world_center(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2(
		cell.x * tile_size + tile_size * 0.5,
		cell.y * tile_size + tile_size * 0.5
	)


## Conversion monde → grille. Ne vérifie pas que la case existe.
func to_cell(position: Vector2, tile_size: int) -> Vector2i:
	return Vector2i(
		int(floorf(position.x / float(tile_size))),
		int(floorf(position.y / float(tile_size)))
	)
