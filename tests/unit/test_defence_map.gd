extends GutTest

## T5.3 — la bataille de défense du § 38.
##
## « Le terrain du royaume devient une carte de combat. » Ce que ces tests
## protègent, c'est précisément ça : la carte doit DÉPENDRE de ce qui a été
## bâti. Une carte de défense identique quel que soit le royaume ne
## relierait rien — ce serait une neuvième carte de vallée avec un autre
## nom.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	HeroProgression.reload()
	HeroNames.reload()
	Equipment.reload()
	ResourceTable.reload()
	Worksite.reload()
	Buildings.reload()
	Invasion.reload()


func _kingdom(built: bool = false) -> Kingdom:
	var kingdom := Kingdom.create()
	if not built:
		return kingdom
	var company := Company.new()
	company.gold = 100000
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 100000
	for i in 3:
		kingdom.build(Buildings.KEYSTONE, company)
	for building_id: StringName in [&"houses", &"barracks", &"archery", &"monastery"]:
		kingdom.build(building_id, company)
	return kingdom


func _raid(strength: int = 60) -> Invasion:
	var raid := Invasion.new()
	raid.strength = strength
	return raid


func _terrain_count(map: CombatMap, terrain_id: StringName) -> int:
	var total := 0
	for row in map.board.grid.height:
		for column in map.board.grid.width:
			if map.board.tile_at(Vector2i(column, row)).terrain_id == terrain_id:
				total += 1
	return total


## Cases occupées par un bâtiment, quel qu'il soit. Il y a un terrain par
## bâtiment — un terrain ne porte qu'un décor, et un type unique les
## dessinait tous en château.
func _building_count(map: CombatMap) -> int:
	var total := 0
	for building_id: StringName in DefenceMap.SPOTS.keys():
		total += _terrain_count(map, StringName("building_%s" % building_id))
	return total


# --- Le terrain du royaume ------------------------------------------------

func test_la_carte_se_fabrique_sans_fichier() -> void:
	var map := DefenceMap.build(_kingdom(), _raid(), CombatRng.new(1))
	assert_not_null(map)
	assert_eq(map.id, DefenceMap.MAP_ID)
	assert_false(CombatMap.map_ids().has(DefenceMap.MAP_ID), "elle traîne dans data/")


func test_un_royaume_bati_pose_plus_de_murs() -> void:
	# C'est TOUT le § 38 : le même assaut ne se joue pas de la même façon
	# selon ce qu'on a construit.
	var bare := DefenceMap.build(_kingdom(), _raid(), CombatRng.new(1))
	var grown := DefenceMap.build(_kingdom(true), _raid(), CombatRng.new(1))
	assert_gt(
		_building_count(grown), _building_count(bare),
		"la carte ne dépend pas de ce qui est bâti"
	)


func test_le_chateau_est_toujours_la() -> void:
	# § 5 : le bâtiment principal existe dès le premier jour. Une carte de
	# défense sans château ne serait pas un royaume.
	var map := DefenceMap.build(_kingdom(), _raid(), CombatRng.new(1))
	assert_eq(map.board.tile_at(DefenceMap.SPOTS[&"castle"]).terrain_id, &"building_castle")


func test_la_palissade_laisse_une_porte() -> void:
	# Une palissade sans porte ferait un siège ; le § 38 veut une bataille.
	var map := DefenceMap.build(_kingdom(true), _raid(), CombatRng.new(1))
	for row: int in DefenceMap.GATE_ROWS:
		assert_ne(
			map.board.tile_at(Vector2i(DefenceMap.FENCE_COLUMN, row)).terrain_id,
			&"palisade", "la porte est murée à la rangée %d" % row
		)
	assert_gt(_terrain_count(map, &"palisade"), 0, "aucune palissade")


func test_la_palissade_se_casse_et_pas_les_batiments() -> void:
	# Le § 41 refuse la punition absolue : regarder son monastère tomber
	# pendant qu'on le défend serait exactement ça.
	assert_true(bool(CombatRules.terrain_property(&"palisade", &"destructible", false)))
	assert_false(bool(CombatRules.terrain_property(&"building_castle", &"destructible", false)))


func test_on_ne_traverse_ni_l_un_ni_l_autre() -> void:
	assert_false(bool(CombatRules.terrain_property(&"palisade", &"walkable", true)))
	assert_false(bool(CombatRules.terrain_property(&"building_castle", &"walkable", true)))


# --- L'objectif ------------------------------------------------------------

func test_on_protege_l_intendant_et_pas_un_batiment() -> void:
	# L'IA ne vise que des unités : un objectif « protéger une structure »
	# ne pourrait jamais échouer, et une carte dont l'objectif ne peut pas
	# être perdu n'est pas une carte.
	var map := DefenceMap.build(_kingdom(), _raid(), CombatRng.new(1))
	assert_eq(map.objective.kind, CombatObjective.Kind.PROTECT)
	var steward := map.board.unit_by_id(CombatMap.ALLY_ID_BASE)
	assert_not_null(steward, "aucun intendant")
	assert_true(steward.is_hero(), "l'intendant n'est pas du bon camp")
	assert_eq(steward.cell, DefenceMap.STEWARD_CELL)


func test_l_intendant_est_derriere_tout_le_monde() -> void:
	var map := DefenceMap.build(_kingdom(true), _raid(), CombatRng.new(1))
	for unit: Unit in map.board.units():
		if unit.is_enemy():
			assert_gt(unit.cell.x, DefenceMap.STEWARD_CELL.x, String(unit.class_id))


# --- Les assaillants -------------------------------------------------------

func test_un_assaut_plus_fort_amene_plus_de_monde() -> void:
	# Le même chiffre décide si l'armée s'en sort seule : les deux issues
	# parlent de la même invasion.
	var weak := DefenceMap.build(_kingdom(), _raid(20), CombatRng.new(1))
	var strong := DefenceMap.build(_kingdom(), _raid(200), CombatRng.new(1))
	assert_gt(
		strong.board.active_units(Unit.Side.ENEMIES).size(),
		weak.board.active_units(Unit.Side.ENEMIES).size()
	)


func test_le_nombre_d_assaillants_reste_dans_ses_bornes() -> void:
	var floor_ := int(Invasion.number(&"assault", &"min_enemies", 0.0))
	var ceiling := int(Invasion.number(&"assault", &"max_enemies", 0.0))
	for strength in [1, 40, 200, 5000]:
		var map := DefenceMap.build(_kingdom(), _raid(strength), CombatRng.new(strength))
		var count := map.board.active_units(Unit.Side.ENEMIES).size()
		assert_between(count, floor_, ceiling, "force %d" % strength)


func test_la_meme_graine_donne_le_meme_assaut() -> void:
	var first := DefenceMap.build(_kingdom(), _raid(), CombatRng.new(99))
	var second := DefenceMap.build(_kingdom(), _raid(), CombatRng.new(99))
	var cells_first: Array[Vector2i] = []
	var cells_second: Array[Vector2i] = []
	for unit: Unit in first.board.active_units(Unit.Side.ENEMIES):
		cells_first.append(unit.cell)
	for unit: Unit in second.board.active_units(Unit.Side.ENEMIES):
		cells_second.append(unit.cell)
	assert_eq(cells_first, cells_second)


# --- Le placement ----------------------------------------------------------

func test_on_se_place_a_l_interieur() -> void:
	var map := DefenceMap.build(_kingdom(true), _raid(), CombatRng.new(1))
	assert_false(map.deployment_cells.is_empty())
	for cell: Vector2i in map.deployment_cells:
		assert_lt(cell.x, DefenceMap.FENCE_COLUMN, "case de placement hors les murs")
		assert_true(map.board.tile_at(cell).is_walkable(), "case de placement murée")


func test_il_y_a_plus_de_cases_que_de_heros() -> void:
	# Le placement est une décision : la carte doit proposer plus que le
	# nécessaire.
	var map := DefenceMap.build(_kingdom(true), _raid(), CombatRng.new(1))
	assert_gt(map.deployment_cells.size(), CombatRules.team_size())


func test_la_carte_se_joue_jusqu_a_une_conclusion() -> void:
	var map := DefenceMap.build(_kingdom(true), _raid(), CombatRng.new(4))
	var squad: Array[Unit] = []
	var classes := Unit.hero_class_ids()
	for i in CombatRules.team_size():
		squad.append(Unit.from_hero_class(i + 1, classes[i % classes.size()], Vector2i.ZERO))
	var engine := map.to_engine(squad, CombatRng.new(4))
	engine.start()
	engine.auto_deploy()
	engine.begin_combat()

	# Politique triviale : personne n'agit, tout le monde passe. Ce qu'on
	# vérifie n'est pas qu'on gagne, c'est que la carte SE CONCLUT — une
	# carte qui tourne sans fin est une carte qu'on ne peut pas jouer.
	var activations := 0
	while not engine.is_finished() and activations < 400:
		engine.end_activation()
		activations += 1
	assert_true(engine.is_finished(), "la défense ne se conclut pas")
