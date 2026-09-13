extends GutTest

## T11.3 — le décor de l'écran de titre, et les crédits.
##
## CE QUI SE CASSE ICI NE PLANTE PAS. Un décor dont un sprite manque
## s'affiche sans lui : l'île garde son château et perd ses moutons, et
## personne ne s'en aperçoit avant de regarder une capture. D'où des tests
## qui vérifient que chaque entrée pointe sur quelque chose.


func before_each() -> void:
	TitleSet.clear_cache()
	CreditsTable.clear_cache()
	AssetTable.clear_cache()
	CombatRules.clear_cache()


func test_l_ile_est_un_vrai_plateau() -> void:
	# C'EST TOUT L'INTÉRÊT DU FORMAT : bâtie par `CombatBoard.from_rows`,
	# l'île hérite des rives du tileset, de l'écume et de la mer. Un décor
	# peint à la main aurait fallu les redessiner, et aurait divergé au
	# premier changement de terrain.
	var rows := TitleSet.island_rows()
	assert_gt(rows.size(), 4, "il faut de quoi faire une île")
	var board := CombatBoard.from_rows(rows)
	assert_not_null(board, "les rangées doivent former un plateau valide")
	assert_eq(Vector2i(board.grid.width, board.grid.height), TitleSet.reference_size())


func test_l_ile_a_de_la_terre_et_de_l_eau() -> void:
	# De la terre sans eau ne serait pas une île ; de l'eau sans terre
	# n'aurait rien à porter.
	var board := CombatBoard.from_rows(TitleSet.island_rows())
	var land := 0
	var water := 0
	for cell: Vector2i in board.grid.cells():
		var tile := board.tile_at(cell)
		if tile == null:
			continue
		if tile.is_swimmable() and not tile.is_walkable():
			water += 1
		else:
			land += 1
	assert_gt(land, 20, "il faut de quoi poser un château")
	assert_gt(water, land, "une île est entourée d'eau, pas l'inverse")


func test_chaque_decor_du_titre_existe() -> void:
	var seen := 0
	for entry: Variant in TitleSet.props():
		var block := entry as Dictionary
		var category := StringName(block.get("category", ""))
		var key := StringName(block.get("key", ""))
		var declared := (
			AssetTable.building(key, String(block.get("color", "Blue")))
			if category == &"buildings" else AssetTable.sprite(category, key)
		)
		assert_false(
			declared.is_empty(), "décor « %s/%s » absent de la table" % [category, key]
		)
		seen += 1
	assert_gt(seen, 5, "une île vide n'annonce rien")


func test_les_trois_classes_du_mvp_sont_sur_le_titre() -> void:
	# C'est la seule image du jeu où on les voit toutes les trois sans
	# lancer un combat — et l'endroit où juger si le Moine tient le rôle
	# du Mage à l'œil.
	var classes := {}
	for entry: Variant in TitleSet.actors():
		var block := entry as Dictionary
		classes[StringName(block.get("unit", ""))] = true
		assert_false(
			AssetTable.unit_animation(
				StringName(block.get("unit", "")), &"idle",
				String(block.get("color", "Blue"))
			).is_empty(),
			"« %s » n'a pas d'animation d'attente" % block.get("unit", "")
		)
	assert_eq(classes.size(), 3, "le MVP a trois classes")


func test_les_nuages_derivent_a_des_vitesses_differentes() -> void:
	# Tous à la même vitesse, ils restent en formation, et l'œil voit une
	# image qui glisse au lieu d'un ciel.
	var block := TitleSet.clouds()
	var keys: Array = block.get("keys", [])
	var speeds: Array = block.get("speeds_px", [])
	assert_gt(keys.size(), 1, "un seul nuage ne fait pas un ciel")
	assert_eq(speeds.size(), keys.size(), "chaque nuage a sa vitesse")
	var distinct := {}
	for speed: Variant in speeds:
		assert_gt(float(speed), 0.0, "un nuage immobile est un décor collé")
		distinct[speed] = true
	assert_gt(distinct.size(), 1, "deux vitesses au moins, sinon ils restent groupés")
	for key: Variant in keys:
		assert_false(AssetTable.sprite(&"decorations", StringName(key)).is_empty())


func test_un_decor_se_pose_par_le_bas_de_sa_case() -> void:
	# Un sprite du pack se dessine les pieds au sol, jamais centré sur la
	# case : centré, un arbre flotte à mi-hauteur de sa case.
	var anchor := TitleSet.anchor_of({"cell": [2, 3], "offset": [0, 0]}, 64)
	assert_eq(anchor, Vector2(160.0, 256.0))
	var shifted := TitleSet.anchor_of({"cell": [2, 3], "offset": [-8, 4]}, 64)
	assert_eq(shifted, Vector2(152.0, 260.0))


# --- Les crédits -----------------------------------------------------------

func test_l_attribution_obligatoire_est_a_l_ecran() -> void:
	# LA SEULE LIGNE DU JEU QUI NE SOIT PAS UNE POLITESSE. game-icons.net
	# est en CC BY 3.0 : l'attribution est une CONDITION de la licence. La
	# perdre au détour d'un remaniement d'écran serait une violation, pas
	# un défaut de style.
	var entries := CreditsTable.entries()
	assert_gt(entries.size(), 3, "il y a plus de trois sources")
	var attributed := false
	for entry: Variant in entries:
		var block := entry as Dictionary
		if String(block.get("licence_key", "")) != "CREDITS_LICENCE_CCBY":
			continue
		attributed = true
		var authors := String(block.get("author", ""))
		for name_: String in ["Lorc", "Delapouite", "Caro Asercion"]:
			assert_true(
				authors.contains(name_), "« %s » doit être nommé" % name_
			)
	assert_true(attributed, "l'entrée CC BY a disparu de l'écran des crédits")


func test_chaque_credit_dit_sa_licence() -> void:
	for entry: Variant in CreditsTable.entries():
		var block := entry as Dictionary
		assert_false(String(block.get("name", "")).is_empty())
		assert_false(String(block.get("author", "")).is_empty())
		assert_false(
			String(block.get("licence_key", "")).is_empty(),
			"« %s » ne dit pas sous quelle licence" % block.get("name", "")
		)
