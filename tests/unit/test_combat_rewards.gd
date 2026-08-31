extends GutTest

## T2.2 — ce qu'une rencontre rapporte.
##
## La couture entre le combat et la campagne. Ce que ces tests protègent :
## le combat n'apprend RIEN de la campagne au passage, et les niveaux sont
## ouverts sans être pris.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	HeroProgression.reload()


func _board() -> CombatBoard:
	return CombatBoard.from_rows(PackedStringArray([
		"..........", "..........", "..........",
		"..........", "..........", "..........",
	]), CombatRules.ADJACENCY_ORTHOGONAL)


func _engine(board: CombatBoard) -> CombatEngine:
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(5)
	)
	engine.start()
	return engine


func _hero(board: CombatBoard, at: Vector2i, id: int = 1) -> Unit:
	var unit := Unit.from_hero_class(id, &"warrior", at)
	unit.initiative = 99
	board.place_unit(unit, at)
	return unit


func _enemy(board: CombatBoard, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_enemy(id, &"gnome", at)
	unit.initiative = 1
	board.place_unit(unit, at)
	return unit


func _company() -> Array[Hero]:
	return [
		Hero.create(1, &"warrior", "Aldric"),
		Hero.create(2, &"archer", "Lyra"),
	] as Array[Hero]


func test_une_rencontre_gagnee_rapporte_ses_mises_a_terre_et_sa_victoire() -> void:
	var board := _board()
	var warrior := _hero(board, Vector2i(2, 2))
	var goblin := _enemy(board, Vector2i(3, 2), 90)
	var engine := _engine(board)

	while goblin.is_active() and engine.can_use(warrior, &"strike"):
		engine.use_ability(warrior, &"strike", goblin.cell)
	engine.end_activation()
	assert_true(engine.is_victory())

	var summary := CombatRewards.summarise(engine)
	assert_eq(summary["enemies_downed"], 1)
	assert_eq(summary["experience"],
		HeroProgression.award(&"enemy_downed")
		+ HeroProgression.award(&"combat_won")
		+ HeroProgression.award(&"objective_completed"))


func test_une_rencontre_perdue_ne_rapporte_que_les_mises_a_terre() -> void:
	var board := _board()
	var warrior := _hero(board, Vector2i(2, 2))
	var first := _enemy(board, Vector2i(3, 2), 90)
	_enemy(board, Vector2i(8, 5), 91)
	var engine := _engine(board)

	while first.is_active() and engine.can_use(warrior, &"strike"):
		engine.use_ability(warrior, &"strike", first.cell)
	warrior.down()
	board.remove_from_board(warrior)
	engine.end_activation()

	assert_false(engine.is_victory())
	var summary := CombatRewards.summarise(engine)
	assert_eq(summary["enemies_downed"], 1)
	assert_eq(summary["experience"], HeroProgression.award(&"enemy_downed"))


func test_un_moteur_absent_ne_plante_pas() -> void:
	assert_true(CombatRewards.summarise(null).is_empty())


func test_l_experience_va_a_toute_la_compagnie() -> void:
	# Pas au tueur : récompenser celui qui porte le coup pousserait le
	# joueur à voler les mises à terre à son propre Guerrier.
	var company := _company()
	CombatRewards.award_to(company, 40)
	for hero: Hero in company:
		assert_eq(hero.experience, 40)


func test_le_versement_rend_les_niveaux_ouverts_par_heros() -> void:
	var company := _company()
	var opened := CombatRewards.award_to(
		company, HeroProgression.experience_to_reach(3)
	)
	assert_eq(opened.size(), company.size())
	for hero: Hero in company:
		assert_eq(int(opened[hero.id]), 2)
		assert_eq(hero.level, 1, "les niveaux sont OUVERTS, pas pris")


func test_un_versement_nul_ne_rend_rien() -> void:
	var company := _company()
	assert_true(CombatRewards.award_to(company, 0).is_empty())
	assert_eq(company[0].experience, 0)


func test_un_heros_absent_de_la_compagnie_ne_plante_pas() -> void:
	var company: Array[Hero] = [null, Hero.create(1, &"mage", "Enguerrand")]
	var opened := CombatRewards.award_to(company, 999999)
	assert_eq(opened.size(), 1)
