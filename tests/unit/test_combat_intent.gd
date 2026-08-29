extends GutTest

## Le télégraphe est la décision verrouillée du § 4.2. Ces tests portent
## sur la propriété qui la rend vraie : une intention suit son attaquant.


func test_une_intention_vide() -> void:
	var intent := CombatIntent.none(3)
	assert_eq(intent.attacker_id, 3)
	assert_false(intent.is_attack())
	assert_eq(intent.target_cells(Vector2i(2, 2)), [] as Array[Vector2i])


func test_une_attaque_vise_une_case() -> void:
	var intent := CombatIntent.attack_cell(1, Vector2i(3, 3), Vector2i(4, 3))
	assert_true(intent.is_attack())
	assert_eq(intent.target_cells(Vector2i(3, 3)), [Vector2i(4, 3)] as Array[Vector2i])


func test_l_intention_suit_l_attaquant_quand_on_le_pousse() -> void:
	# C'est la propriété qui fait exister la troisième réponse du § 4.2 —
	# « déplacer l'ennemi pour dévier son attaque ». Si l'intention retenait
	# des cases absolues, pousser l'attaquant laisserait son attaque frapper
	# le vide à l'endroit d'avant : illisible, et faux.
	var intent := CombatIntent.attack_cell(1, Vector2i(3, 3), Vector2i(4, 3))
	assert_eq(intent.target_cells(Vector2i(3, 3)), [Vector2i(4, 3)] as Array[Vector2i])
	# Le lancier repousse le gobelin d'une case vers la droite.
	assert_eq(intent.target_cells(Vector2i(4, 3)), [Vector2i(5, 3)] as Array[Vector2i])
	# Et d'une case vers le bas : la menace pivote avec lui.
	assert_eq(intent.target_cells(Vector2i(3, 4)), [Vector2i(4, 4)] as Array[Vector2i])


func test_une_attaque_en_ligne_garde_sa_forme() -> void:
	# Le Minotaure frappe en ligne (§ 4.4) : trois cases devant lui.
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var intent := CombatIntent.attack(2, offsets)
	assert_eq(
		intent.target_cells(Vector2i(0, 2)),
		[Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)] as Array[Vector2i]
	)
	assert_eq(
		intent.target_cells(Vector2i(2, 5)),
		[Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)] as Array[Vector2i]
	)


func test_les_decalages_ne_sont_pas_partages_avec_l_appelant() -> void:
	var offsets: Array[Vector2i] = [Vector2i(1, 0)]
	var intent := CombatIntent.attack(1, offsets)
	offsets.append(Vector2i(9, 9))
	assert_eq(intent.offsets.size(), 1, "l'intention garde sa propre copie")


func test_aller_retour_de_serialisation() -> void:
	var intent := CombatIntent.attack(7, [Vector2i(1, 0), Vector2i(0, -1)] as Array[Vector2i])
	var restored := CombatIntent.from_dictionary(intent.to_dictionary())
	assert_eq(restored.attacker_id, 7)
	assert_true(restored.is_attack())
	assert_eq(restored.offsets, intent.offsets)
