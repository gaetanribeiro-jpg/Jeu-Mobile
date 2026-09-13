extends GutTest

## LA CARTE DU MONDE ET LE SOL DU ROYAUME (T12.11).
##
## Les deux fichiers décrivent un DÉCOR, et un décor casse en silence : un
## contour de moins de trois points ne se dessine pas et ne se plaint pas,
## un emplacement à l'eau se dessine très bien. Ce que ces tests tiennent,
## c'est la lecture — les vérificateurs tiennent la cohérence.


func before_each() -> void:
	CombatRules.clear_cache()
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()
	Neighbour.clear_cache()
	WorldAtlas.clear_cache()
	KingdomGround.clear_cache()


# --- La carte du monde -----------------------------------------------------

func test_chaque_region_a_un_contour_fermé() -> void:
	for region_id: StringName in WorldAtlas.ids():
		var shape := WorldAtlas.shape_of(region_id)
		assert_gt(shape.size(), 2, "« %s » n'a pas de contour" % region_id)
		assert_true(
			Geometry2D.is_point_in_polygon(WorldAtlas.anchor_of(region_id), shape),
			"le centre de « %s » tombe hors de sa terre" % region_id
		)


func test_l_ile_du_royaume_porte_le_chateau_et_les_voisines() -> void:
	var home := WorldAtlas.shape_of(WorldAtlas.HOME)
	assert_gt(home.size(), 2)
	assert_true(Geometry2D.is_point_in_polygon(WorldAtlas.castle(), home))
	for town_id: StringName in WorldAtlas.towns():
		assert_true(
			Geometry2D.is_point_in_polygon(WorldAtlas.town_at(town_id), home),
			"« %s » est au large" % town_id
		)


## LA ROUTE REND L'ORDRE LISIBLE : sans elle, six terres posées sur une mer
## sont six terres.
func test_la_route_part_du_royaume_et_suit_les_actes() -> void:
	var roads := WorldAtlas.roads()
	assert_gt(roads.size(), 0)
	assert_eq(StringName(roads[0][0]), WorldAtlas.HOME)
	var previous := 0
	for road: Array in roads:
		var act := Region.act_of(road[1])
		assert_gt(act, previous, "la route remonte le temps vers « %s »" % road[1])
		previous = act


func test_une_terre_inconnue_ne_fait_pas_tomber_la_lecture() -> void:
	assert_false(WorldAtlas.has_node(&"terra_incognita"))
	assert_eq(WorldAtlas.shape_of(&"terra_incognita").size(), 0)
	assert_eq(WorldAtlas.anchor_of(&"terra_incognita"), Vector2.ZERO)


## LA COULEUR D'UNE VILLE DIT SON CRÉDIT, et chaque cran en a une.
func test_chaque_cran_de_credit_a_une_teinte_de_la_palette() -> void:
	for value in range(Neighbour.minimum(), Neighbour.maximum() + 1):
		var tint := Neighbour.standing_tint(value)
		assert_false(tint.is_empty(), "le crédit %+d n'a pas de teinte" % value)
		assert_true(UiTheme.has_color(tint), "« %s » n'est pas dans la palette" % tint)


# --- Le sol du royaume -----------------------------------------------------

func test_le_terrain_du_royaume_est_rectangulaire() -> void:
	var rows := KingdomGround.rows()
	assert_gt(rows.size(), 0)
	for row: String in rows:
		assert_eq(row.length(), KingdomGround.width(), "le terrain n'est pas rectangulaire")


## LA GRILLE EST LA TOILE. Une constante recopiée finirait par ne plus dire
## la même chose, et un bâtiment se retrouverait hors du terrain sans que
## rien ne le dise — ce qui est EXACTEMENT arrivé à la tour de guet (T12.8).
func test_la_toile_des_batiments_est_la_grille_du_terrain() -> void:
	assert_eq(Buildings.canvas(), KingdomGround.canvas())


func test_on_ne_batit_ni_a_l_eau_ni_dans_un_rocher() -> void:
	for building_id: StringName in Buildings.ids():
		assert_true(
			KingdomGround.can_stand_at(Buildings.spot_of(building_id)),
			"« %s » est posé sur du « %s »" % [
				building_id,
				KingdomGround.terrain_at(
					KingdomGround.cell_of(Buildings.spot_of(building_id))
				),
			]
		)
	for worksite_id: StringName in Worksite.ids():
		assert_true(
			KingdomGround.can_stand_at(Worksite.spot_of(worksite_id)),
			"« %s » est posé à l'eau" % worksite_id
		)


func test_le_terrain_se_lit_case_par_case() -> void:
	assert_eq(KingdomGround.terrain_at(Vector2i(-1, 0)), &"")
	assert_eq(
		KingdomGround.terrain_at(Vector2i(KingdomGround.width(), 0)), &"",
		"une case hors grille a un terrain"
	)
	assert_eq(KingdomGround.cell_of(Vector2i(0, 0)), Vector2i(0, 0))


## LA CLÔTURE EST UNE DÉLIMITATION, PAS UNE FRISE : elle a des bouts, des
## traverses, et une ouverture.
func test_la_cloture_a_des_bouts_et_une_ouverture() -> void:
	var pieces := KingdomGround.fence_pieces()
	assert_gt(pieces.size(), 3)
	var parts := {}
	for piece: Dictionary in pieces:
		parts[piece["part"]] = true
		assert_ne(
			KingdomGround.fence_part(StringName(piece["part"])), Vector2i(-1, -1),
			"le morceau « %s » n'est pas déclaré" % piece["part"]
		)
	assert_true(parts.has(&"start"), "la clôture n'a pas de bout")
	assert_true(parts.has(&"end"), "la clôture n'a pas de bout")
	# Une enceinte fermée enfermerait le village : le pack ne dessine pas de
	# portail, un trou dans la ligne se lit comme une entrée.
	var columns := {}
	for piece: Dictionary in pieces:
		columns[(piece["cell"] as Vector2i).x] = true
	assert_lt(columns.size(), KingdomGround.width(), "la clôture fait tout le tour")
