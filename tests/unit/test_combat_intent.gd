extends GutTest

## Le télégraphe : ce qu'un ennemi annonce.
##
## La propriété que ces tests protègent : une intention retient un
## DÉCALAGE, pas une case. Déplacer l'attaquant déplace donc sa menace,
## et c'est ce qui fait de la poussée une réponse au télégraphe.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()


func _grid() -> Grid:
	return Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)


func test_une_intention_vide() -> void:
	var intent := CombatIntent.none(3)
	assert_eq(intent.attacker_id, 3)
	assert_false(intent.is_attack())
	assert_eq(intent.target_cells(Vector2i(2, 2), _grid()), [])
	assert_null(intent.ability())


func test_une_attaque_vise_une_case() -> void:
	var intent := CombatIntent.attack_cell(
		1, &"goblin_spear", Vector2i(2, 2), Vector2i(3, 2)
	)
	assert_true(intent.is_attack())
	assert_eq(intent.target_cell(Vector2i(2, 2)), Vector2i(3, 2))
	assert_eq(intent.target_cells(Vector2i(2, 2), _grid()), [Vector2i(3, 2)])


func test_l_intention_suit_l_attaquant_quand_on_le_pousse() -> void:
	# LA raison d'être des décalages. Si l'intention retenait une case
	# absolue, pousser l'attaquant laisserait son attaque frapper le vide à
	# l'endroit d'avant : illisible, et faux.
	var intent := CombatIntent.attack_cell(
		1, &"goblin_spear", Vector2i(2, 2), Vector2i(3, 2)
	)
	assert_eq(
		intent.target_cells(Vector2i(2, 3), _grid()), [Vector2i(3, 3)],
		"poussé d'une case vers le bas, il menace une case plus bas"
	)


func test_la_zone_vient_de_la_competence() -> void:
	# Le télégraphe d'une Boule de feu montre cinq cases sans que personne
	# n'ait eu à les écrire.
	var intent := CombatIntent.attack_cell(
		1, &"fireball", Vector2i(1, 3), Vector2i(4, 3)
	)
	var cells := intent.target_cells(Vector2i(1, 3), _grid())
	assert_eq(cells.size(), 5)
	assert_true(cells.has(Vector2i(4, 2)))


func test_une_attaque_en_ligne_garde_sa_forme() -> void:
	var intent := CombatIntent.attack_cell(
		1, &"troll_smash", Vector2i(2, 3), Vector2i(3, 3)
	)
	assert_eq(
		intent.target_cells(Vector2i(2, 3), _grid()),
		[Vector2i(3, 3), Vector2i(4, 3)]
	)


func test_la_zone_est_bornee_a_la_grille() -> void:
	var intent := CombatIntent.attack_cell(
		1, &"fireball", Vector2i(2, 0), Vector2i(0, 0)
	)
	for cell: Vector2i in intent.target_cells(Vector2i(2, 0), _grid()):
		assert_true(_grid().contains(cell), "case hors grille : %s" % cell)


func test_aller_retour_de_serialisation() -> void:
	var intent := CombatIntent.attack_cell(
		4, &"fireball", Vector2i(1, 1), Vector2i(3, 2)
	)
	var copy := CombatIntent.from_dictionary(intent.to_dictionary())
	assert_eq(copy.attacker_id, 4)
	assert_true(copy.is_attack())
	assert_eq(copy.ability_id, &"fireball")
	assert_eq(copy.target_offset, intent.target_offset)
	assert_eq(
		copy.target_cells(Vector2i(1, 1), _grid()),
		intent.target_cells(Vector2i(1, 1), _grid())
	)


func test_une_intention_vide_survit_a_la_serialisation() -> void:
	var copy := CombatIntent.from_dictionary(CombatIntent.none(9).to_dictionary())
	assert_eq(copy.attacker_id, 9)
	assert_false(copy.is_attack())
