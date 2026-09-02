extends GutTest

## T2.4 — le butin.
##
## Trois propriétés à protéger : le butin se rejoue à l'identique à partir
## de sa graine, une défaite laisse quand même quelque chose (§ 41), et la
## profondeur enrichit (§ 29).


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Equipment.clear_cache()
	Loot.clear_cache()


func _encounter(downed: int, victory: bool) -> Dictionary:
	return {"enemies_downed": downed, "victory": victory}


## Moyenne sur beaucoup de graines : un tirage isolé ne dit rien.
func _average_gold(downed: int, victory: bool, depth: int, runs: int = 200) -> float:
	var total := 0.0
	for i in runs:
		total += float(Loot.roll(CombatRng.new(i * 7919), _encounter(downed, victory), depth)["gold"])
	return total / float(runs)


func _drop_rate(victory: bool, depth: int, runs: int = 400) -> float:
	var drops := 0
	for i in runs:
		var items: Array = Loot.roll(
			CombatRng.new(i * 104729), _encounter(4, victory), depth
		)["items"]
		if not items.is_empty():
			drops += 1
	return float(drops) / float(runs)


# --- Reproductibilité ------------------------------------------------------

func test_la_meme_graine_rend_le_meme_butin() -> void:
	# Sans ça, on ne peut pas reproduire un bogue, et le roguelite en dépend.
	var first := Loot.roll(CombatRng.new(4242), _encounter(5, true))
	var second := Loot.roll(CombatRng.new(4242), _encounter(5, true))
	assert_eq(first, second)


func test_deux_graines_ne_rendent_pas_toujours_la_meme_chose() -> void:
	var seen := {}
	for i in 40:
		seen[Loot.roll(CombatRng.new(i * 31), _encounter(5, true))["gold"]] = true
	assert_gt(seen.size(), 1, "l'or ne varie pas du tout")


func test_un_moteur_sans_resume_ne_plante_pas() -> void:
	var empty := Loot.roll(null, {})
	assert_eq(int(empty["gold"]), 0)
	assert_true((empty["items"] as Array).is_empty())


# --- L'or ------------------------------------------------------------------

func test_plus_on_abat_plus_on_ramasse() -> void:
	assert_gt(_average_gold(6, true, 0), _average_gold(2, true, 0))


func test_la_victoire_paie_une_prime() -> void:
	assert_gt(_average_gold(4, true, 0), _average_gold(4, false, 0))


func test_une_defaite_rapporte_quand_meme_ce_qu_on_a_abattu() -> void:
	# Le § 41 : mourir est une conséquence, pas une punition absolue.
	assert_gt(_average_gold(3, false, 0), 0.0)


func test_l_or_n_est_jamais_negatif() -> void:
	for i in 100:
		assert_gte(int(Loot.roll(CombatRng.new(i), _encounter(0, false))["gold"]), 0)


func test_deux_combats_identiques_ne_paient_pas_exactement_pareil() -> void:
	# La variance ne sert pas à surprendre : elle empêche le joueur de
	# calculer son or au lieu de le gagner.
	var seen := {}
	for i in 60:
		seen[Loot.roll(CombatRng.new(i * 977), _encounter(4, true))["gold"]] = true
	assert_gt(seen.size(), 3)


# --- Les objets ------------------------------------------------------------

func test_un_objet_qui_tombe_existe_vraiment() -> void:
	for i in 200:
		for item_id: StringName in Loot.roll(
			CombatRng.new(i * 6151), _encounter(5, true)
		)["items"] as Array:
			assert_true(Equipment.exists(item_id), "objet inventé : %s" % item_id)


func test_une_victoire_fait_tomber_plus_souvent_qu_une_defaite() -> void:
	assert_gt(_drop_rate(true, 0), _drop_rate(false, 0))


func test_une_defaite_peut_quand_meme_faire_tomber_quelque_chose() -> void:
	assert_gt(_drop_rate(false, 0), 0.0)


func test_le_commun_tombe_plus_souvent_que_le_legendaire() -> void:
	# Sinon la rareté n'est qu'une couleur.
	var counts := {}
	for i in 600:
		for item_id: StringName in Loot.roll(
			CombatRng.new(i * 3571), _encounter(5, true)
		)["items"] as Array:
			var rarity := Equipment.rarity_of(item_id)
			counts[rarity] = int(counts.get(rarity, 0)) + 1
	assert_gt(int(counts.get(&"common", 0)), int(counts.get(&"legendary", 0)))


# --- La profondeur, levier du § 29 -----------------------------------------

func test_s_enfoncer_rapporte_plus_d_or() -> void:
	assert_gt(_average_gold(4, true, 6), _average_gold(4, true, 0))


func test_s_enfoncer_fait_tomber_plus_souvent() -> void:
	assert_gt(_drop_rate(true, 5), _drop_rate(true, 0))


func test_au_fond_le_commun_cesse_de_sortir() -> void:
	# C'est ce qui rend « je continue » tentant plutôt que seulement risqué.
	var deep := {}
	for i in 300:
		for item_id: StringName in Loot.roll(
			CombatRng.new(i * 2087), _encounter(5, true), 12
		)["items"] as Array:
			deep[Equipment.rarity_of(item_id)] = true
	assert_false(deep.has(&"common"), "un commun est tombé au fond d'une expédition")
	assert_gt(deep.size(), 0, "il faut bien que quelque chose soit tombé")


# --- Les potions, troisième fil (T10.2) ------------------------------------

func _supply_rate(victory: bool, depth: int, runs: int = 400) -> float:
	var drops := 0
	for i in runs:
		var found: Array = Loot.roll(
			CombatRng.new(i * 15485863), _encounter(4, victory), depth
		)["supplies"]
		if not found.is_empty():
			drops += 1
	return float(drops) / float(runs)


func test_une_potion_qui_tombe_existe_vraiment() -> void:
	var seen := 0
	for i in 200:
		for item_id: StringName in Loot.roll(
			CombatRng.new(i * 6151), _encounter(4, true)
		)["supplies"] as Array:
			assert_true(Consumable.exists(item_id), "« %s » n'existe pas" % item_id)
			seen += 1
	assert_gt(seen, 0, "sans ça, le sac ne se renouvelle jamais")


func test_les_potions_ne_prennent_pas_la_place_de_l_equipement() -> void:
	# TIRAGE SÉPARÉ, ET C'EST TOUT L'INTÉRÊT. L'économie de l'équipement
	# est mesurée au point de rareté ; une consommable n'est pas un
	# remplacement acceptable pour un objet qu'on garde, et le joueur qui
	# voit une fiole là où il espérait une épée se sent volé.
	var with_potions := _drop_rate(true, 0)
	assert_almost_eq(
		with_potions, Loot.number(&"drop", &"on_victory", 0.0), 0.08,
		"le taux d'équipement doit rester celui qui est déclaré"
	)


func test_une_defaite_ne_rend_pas_de_potion() -> void:
	# Le § 41 refuse la punition absolue, et c'est pour ça que
	# l'équipement tombe quand même. Mais une équipe qui vient de perdre a
	# déjà vidé son sac : lui rendre une fiole effacerait la dépense.
	assert_eq(_supply_rate(false, 0), 0.0)
	assert_gt(_supply_rate(true, 0), 0.0)


func test_s_enfoncer_rend_les_potions_plus_frequentes() -> void:
	assert_gt(_supply_rate(true, 6), _supply_rate(true, 0))


func test_une_potion_tombe_plus_souvent_qu_une_piece_d_equipement() -> void:
	# Une potion se boit et disparaît : il en faut un FLUX, pas une
	# trouvaille. Sinon la réserve n'est qu'un compte à rebours.
	assert_gt(_supply_rate(true, 4), _drop_rate(true, 4) * 0.5)


func test_au_fond_les_potions_ne_se_tarissent_pas() -> void:
	# L'ÉCHELLE EST RÉDUITE À CE QUI EXISTE. Il n'y a de potions que dans
	# deux raretés sur cinq : sans ce garde-fou, au troisième palier de
	# profondeur le plancher passait au-dessus de la meilleure et le fil
	# s'arrêtait — plus on s'enfonce, moins on se ravitaille, exactement
	# l'inverse du § 29.
	var deep := 0
	for i in 120:
		deep += (Loot.roll(
			CombatRng.new(i * 3571), _encounter(5, true), 12
		)["supplies"] as Array).size()
	assert_gt(deep, 0, "au fond d'une expédition, plus aucune potion ne tombait")


func test_un_etal_ne_propose_pas_deux_fois_la_meme_fiole() -> void:
	# Deux fioles identiques côte à côte, c'est un rang perdu et un choix
	# en moins. Un butin, lui, peut répéter : c'est un stock, pas une
	# vitrine.
	for i in 40:
		var listed := Loot.draw_supplies(CombatRng.new(i * 8191), 2, 3, 0, true)
		if listed.size() < 2:
			continue
		assert_ne(listed[0], listed[1], "graine %d : l'étal se répète" % i)
