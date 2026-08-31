extends GutTest

## T2.4 — le butin.
##
## Trois propriétés à protéger : le butin se rejoue à l'identique à partir
## de sa graine, une défaite laisse quand même quelque chose (§ 41), et la
## profondeur enrichit (§ 29).


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Equipment.reload()
	Loot.reload()


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
