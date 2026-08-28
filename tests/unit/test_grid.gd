extends GutTest

## La grille est la géométrie de tout le combat. Une erreur d'un pas ici
## se retrouve dans le déplacement, la portée, la ligne de vue et la
## poussée à la fois.


func test_les_dimensions_de_combat_viennent_des_donnees() -> void:
	var grid := Grid.for_combat()
	assert_eq(grid.width, 8, "grille de combat 8 × 6 (§ 4.1)")
	assert_eq(grid.height, 6)
	assert_eq(grid.cell_count(), 48)


func test_les_dimensions_de_siege() -> void:
	var grid := Grid.for_siege()
	assert_eq(grid.width, 10, "grille de siège 10 × 8 (§ 8.1)")
	assert_eq(grid.height, 8)


func test_les_bords_sont_etanches() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	assert_true(grid.contains(Vector2i(0, 0)))
	assert_true(grid.contains(Vector2i(7, 5)))
	assert_false(grid.contains(Vector2i(-1, 0)))
	assert_false(grid.contains(Vector2i(0, -1)))
	assert_false(grid.contains(Vector2i(8, 0)))
	assert_false(grid.contains(Vector2i(0, 6)))


func test_le_balayage_couvre_toutes_les_cases_une_fois() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var cells := grid.cells()
	assert_eq(cells.size(), 48)
	var seen := {}
	for cell: Vector2i in cells:
		assert_false(seen.has(cell), "case %s vue deux fois" % cell)
		seen[cell] = true


func test_voisinage_orthogonal() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	assert_eq(grid.neighbors(Vector2i(3, 3)).size(), 4, "au centre : 4 voisins")
	assert_eq(grid.neighbors(Vector2i(0, 0)).size(), 2, "dans un coin : 2 voisins")
	assert_eq(grid.neighbors(Vector2i(0, 3)).size(), 3, "sur un bord : 3 voisins")


func test_voisinage_diagonal() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_DIAGONAL)
	assert_eq(grid.neighbors(Vector2i(3, 3)).size(), 8, "au centre : 8 voisins")
	assert_eq(grid.neighbors(Vector2i(0, 0)).size(), 3, "dans un coin : 3 voisins")
	assert_eq(grid.neighbors(Vector2i(0, 3)).size(), 5, "sur un bord : 5 voisins")


func test_distance_de_manhattan_en_orthogonal() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	assert_eq(grid.distance(Vector2i(0, 0), Vector2i(0, 0)), 0)
	assert_eq(grid.distance(Vector2i(0, 0), Vector2i(3, 0)), 3)
	assert_eq(grid.distance(Vector2i(0, 0), Vector2i(3, 4)), 7, "3 + 4")
	assert_eq(grid.distance(Vector2i(3, 4), Vector2i(0, 0)), 7, "symétrique")


func test_distance_de_chebyshev_en_diagonal() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_DIAGONAL)
	assert_eq(grid.distance(Vector2i(0, 0), Vector2i(3, 4)), 4, "max(3, 4)")
	assert_eq(grid.distance(Vector2i(0, 0), Vector2i(2, 2)), 2, "une diagonale coûte 1")


func test_la_portee_brute_respecte_ses_deux_bornes() -> void:
	# L'Archer tire à 2–4 : sa propre case et ses voisines sont hors portée.
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var center := Vector2i(4, 3)
	var cells := grid.cells_in_range(center, 2, 4)
	assert_false(cells.has(center), "sa propre case est hors portée")
	assert_false(cells.has(Vector2i(5, 3)), "une case adjacente est hors portée")
	assert_true(cells.has(Vector2i(6, 3)), "à 2 cases : en portée")
	assert_true(cells.has(Vector2i(4, 0)), "à 3 cases : en portée")
	for cell: Vector2i in cells:
		assert_between(grid.distance(center, cell), 2, 4)


func test_l_anneau_est_a_distance_exacte() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	for cell: Vector2i in grid.ring(Vector2i(4, 3), 2):
		assert_eq(grid.distance(Vector2i(4, 3), cell), 2)
	assert_eq(grid.ring(Vector2i(4, 3), 0), [Vector2i(4, 3)] as Array[Vector2i])


func test_la_direction_de_poussee_est_toujours_un_pas_legal() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	# En orthogonal, une poussée en biais suit l'axe dominant : jamais de
	# diagonale, sinon la cible atterrit sur une case qu'aucune règle de
	# déplacement n'autorise.
	assert_eq(grid.direction(Vector2i(2, 2), Vector2i(5, 3)), Vector2i(1, 0))
	assert_eq(grid.direction(Vector2i(2, 2), Vector2i(3, 5)), Vector2i(0, 1))
	assert_eq(grid.direction(Vector2i(5, 2), Vector2i(2, 2)), Vector2i(-1, 0))
	assert_eq(grid.direction(Vector2i(2, 5), Vector2i(2, 2)), Vector2i(0, -1))
	assert_eq(grid.direction(Vector2i(2, 2), Vector2i(2, 2)), Vector2i.ZERO)
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		assert_true(Grid.ORTHOGONAL_STEPS.has(step))


func test_la_direction_de_poussee_en_diagonal() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_DIAGONAL)
	assert_eq(grid.direction(Vector2i(2, 2), Vector2i(5, 5)), Vector2i(1, 1))
	assert_eq(grid.direction(Vector2i(5, 5), Vector2i(2, 2)), Vector2i(-1, -1))


func test_la_ligne_relie_les_deux_bouts_sans_trou() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var line := grid.line(Vector2i(1, 1), Vector2i(6, 4))
	assert_eq(line[0], Vector2i(1, 1), "la ligne part de l'origine")
	assert_eq(line[-1], Vector2i(6, 4), "la ligne arrive à la cible")
	for i in range(1, line.size()):
		var jump: Vector2i = (line[i] - line[i - 1]).abs()
		assert_lte(maxi(jump.x, jump.y), 1, "trou dans la ligne à l'index %d" % i)


func test_la_ligne_droite_est_droite() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	assert_eq(
		grid.line(Vector2i(2, 3), Vector2i(5, 3)),
		[Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)] as Array[Vector2i]
	)
	assert_eq(grid.line(Vector2i(2, 3), Vector2i(2, 3)), [Vector2i(2, 3)] as Array[Vector2i])


func test_conversion_grille_monde() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var size := AssetTable.tile_size()
	assert_eq(grid.to_world(Vector2i(2, 3), size), Vector2(128, 192))
	assert_eq(grid.to_world_center(Vector2i(0, 0), size), Vector2(32, 32))
	# Aller-retour : n'importe quel point d'une case retombe sur cette case.
	for cell: Vector2i in grid.cells():
		assert_eq(grid.to_cell(grid.to_world_center(cell, size), size), cell)
		assert_eq(grid.to_cell(grid.to_world(cell, size), size), cell)
