extends GutTest

## T7.1 — la sauvegarde en plein combat.
##
## POURQUOI ELLE EXISTE. Sur mobile, l'application meurt à tout moment.
## L'expédition survivait déjà à ça, le combat non : perdre sept rondes
## parce qu'un appel arrive est exactement la punition que le § 41 refuse.
##
## CE QUE CES TESTS PROTÈGENT, dans l'ordre de ce qu'on regretterait le
## plus : les PV et les positions, la timeline (qui a déjà joué), le
## TÉLÉGRAPHE (un ennemi qui avait annoncé son coup doit encore l'avoir
## annoncé), et le terrain abîmé.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


## Un combat déjà entamé : équipe posée, quelques activations passées.
func _underway(map_id: StringName = &"vallee_02", activations: int = 5) -> CombatEngine:
	var map := CombatMap.load_map(map_id, CombatRules.ADJACENCY_ORTHOGONAL)
	var squad: Array[Unit] = []
	var classes := Unit.hero_class_ids()
	for i in CombatRules.team_size():
		squad.append(Unit.from_hero_class(i + 1, classes[i % classes.size()], Vector2i.ZERO))
	var engine := map.to_engine(squad, CombatRng.new(4242))
	engine.start()
	engine.auto_deploy()
	engine.begin_combat()
	for i in activations:
		if engine.is_finished():
			break
		engine.end_activation()
	return engine


func _cells(engine: CombatEngine) -> Dictionary:
	var out := {}
	for unit: Unit in engine.board.units():
		out[unit.id] = [unit.cell, unit.hit_points, unit.state]
	return out


# --- Ce qu'on regretterait le plus -----------------------------------------

func test_les_unites_reviennent_ou_elles_etaient() -> void:
	var engine := _underway()
	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_not_null(copy)
	assert_eq(_cells(copy), _cells(engine))


func test_la_timeline_reprend_ou_elle_en_etait() -> void:
	# Refaire le tri au rechargement ne suffirait pas : l'ordre a pu être
	# amputé d'unités mises à terre, et la reprise ferait rejouer
	# quelqu'un qui a déjà agi.
	var engine := _underway()
	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_eq(copy.round_index(), engine.round_index())
	assert_eq(copy.order.current(), engine.order.current())
	assert_eq(copy.order.remaining(), engine.order.remaining())


func test_le_telegraphe_survit() -> void:
	# « Information parfaite, toujours » tomberait sur un rechargement : un
	# ennemi qui avait annoncé son coup frapperait sans l'avoir annoncé.
	var engine := _underway()
	var announced := 0
	for unit: Unit in engine.board.units():
		if engine.intent_of(unit.id) != null:
			announced += 1
	assert_gt(announced, 0, "aucune intention à sauver — le test ne prouve rien")

	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	for unit: Unit in engine.board.units():
		var before := engine.intent_of(unit.id)
		var after := copy.intent_of(unit.id)
		if before == null:
			assert_null(after, "intention inventée pour %d" % unit.id)
			continue
		assert_not_null(after, "intention perdue pour %d" % unit.id)
		assert_eq(after.to_dictionary(), before.to_dictionary())


func test_le_terrain_abime_reste_abime() -> void:
	# Un pont cassé qui se répare au rechargement rendrait un raccourci que
	# le joueur avait payé d'une activation entière.
	var engine := _underway()
	var broken := Vector2i(5, 4)
	var tile := engine.board.tile_at(broken)
	tile.set_terrain(&"water")

	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_eq(copy.board.tile_at(broken).terrain_id, &"water")


func test_l_objectif_et_son_etat_survivent() -> void:
	var engine := _underway(&"vallee_07")
	engine.objective.carried = true
	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_eq(copy.objective.kind, engine.objective.kind)
	assert_eq(copy.objective.subject_ids, engine.objective.subject_ids)
	assert_true(copy.objective.carried, "le colis ramassé est retombé au sol")


func test_la_graine_reprend_sa_position() -> void:
	# Règle 4 : un combat rechargé doit se dérouler comme s'il n'avait pas
	# été interrompu. Repartir du début de la graine rejouerait des
	# tirages déjà consommés.
	var engine := _underway()
	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_eq(copy.rng.position(), engine.rng.position())


# --- Reprendre et continuer ------------------------------------------------

func test_un_combat_repris_continue_pareil() -> void:
	# Le vrai test : la suite du combat doit être la même, coup pour coup.
	var engine := _underway()
	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	for i in 12:
		if engine.is_finished() or copy.is_finished():
			break
		engine.end_activation()
		copy.end_activation()
	assert_eq(_cells(copy), _cells(engine), "les deux combats ont divergé")
	assert_eq(copy.is_finished(), engine.is_finished())
	assert_eq(copy.is_victory(), engine.is_victory())


func test_on_peut_sauver_pendant_le_placement() -> void:
	var map := CombatMap.load_map(&"vallee_01", CombatRules.ADJACENCY_ORTHOGONAL)
	var squad: Array[Unit] = []
	for i in CombatRules.team_size():
		squad.append(Unit.from_hero_class(i + 1, &"warrior", Vector2i.ZERO))
	var engine := map.to_engine(squad, CombatRng.new(7))
	engine.start()
	assert_true(engine.is_deploying())

	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_true(copy.is_deploying(), "on ne reprend pas en placement")
	assert_eq(copy.pending_heroes().size(), engine.pending_heroes().size())
	assert_eq(copy.deployment_cells(), engine.deployment_cells())


func test_un_combat_fini_se_recharge_fini() -> void:
	var engine := _underway()
	engine.surrender()
	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_true(copy.is_finished())
	assert_false(copy.is_victory())


func test_une_sauvegarde_vide_ne_rend_rien() -> void:
	assert_null(CombatEngine.from_dictionary({}))


# --- La carte de défense, qui n'est dans aucun fichier ---------------------

func test_la_defense_du_royaume_se_sauve_aussi() -> void:
	# C'est le cas qui justifie de sauver le PLATEAU et pas seulement le
	# nom de la carte : celle-ci se fabrique et n'existe nulle part.
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()
	Invasion.clear_cache()
	var kingdom := Kingdom.create()
	for building_id: StringName in Buildings.ids():
		kingdom.levels[building_id] = 1
	var raid := Invasion.declare(CombatRng.new(3), kingdom.building_levels(), 0)
	var map := DefenceMap.build(kingdom, raid, CombatRng.new(3))

	var squad: Array[Unit] = []
	for i in CombatRules.team_size():
		squad.append(Unit.from_hero_class(i + 1, &"warrior", Vector2i.ZERO))
	var engine := map.to_engine(squad, CombatRng.new(3))
	engine.start()
	engine.auto_deploy()
	engine.begin_combat()
	engine.end_activation()

	var copy := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_not_null(copy)
	assert_eq(_cells(copy), _cells(engine))
	assert_eq(
		copy.board.tile_at(DefenceMap.SPOTS[&"castle"]).terrain_id, &"building_castle",
		"le royaume n'est plus sur le plateau"
	)
