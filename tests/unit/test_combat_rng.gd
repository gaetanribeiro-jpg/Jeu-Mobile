extends GutTest

## Le tirage à graine est ce qui rend un bug de combat reproductible.
## S'il dérive, on perd le seul outil de diagnostic dont on dispose sur un
## jeu qu'on ne peut pas observer en train de tourner.

const SEED := 20260828


func test_deux_generateurs_de_meme_graine_donnent_la_meme_suite() -> void:
	var a := CombatRng.new(SEED)
	var b := CombatRng.new(SEED)
	for i in 50:
		assert_eq(
			a.int_between(1, 100, &"test"),
			b.int_between(1, 100, &"test"),
			"tirage %d divergent" % i
		)


func test_deux_graines_differentes_divergent() -> void:
	var a := CombatRng.new(SEED)
	var b := CombatRng.new(SEED + 1)
	var same := 0
	for i in 50:
		if a.int_between(1, 1000, &"test") == b.int_between(1, 1000, &"test"):
			same += 1
	assert_lt(same, 10, "deux graines différentes ne doivent pas se suivre")


func test_la_remise_a_zero_rejoue_la_meme_suite() -> void:
	var rng := CombatRng.new(SEED)
	var first: Array[int] = []
	for i in 20:
		first.append(rng.int_between(0, 999, &"test"))

	rng.reset(SEED)
	for i in 20:
		assert_eq(rng.int_between(0, 999, &"test"), first[i], "rejeu divergent au tirage %d" % i)


func test_les_bornes_sont_comprises() -> void:
	var rng := CombatRng.new(SEED)
	var seen_low := false
	var seen_high := false
	for i in 200:
		var value := rng.int_between(1, 3, &"test")
		assert_between(value, 1, 3)
		seen_low = seen_low or value == 1
		seen_high = seen_high or value == 3
	assert_true(seen_low and seen_high, "les deux bornes doivent sortir")


func test_le_journal_retient_la_raison_de_chaque_tirage() -> void:
	var rng := CombatRng.new(SEED)
	rng.int_between(1, 6, &"degats_variables")
	rng.chance(0.5, &"embuscade")
	var entries := rng.log_entries()
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["reason"], "degats_variables")
	assert_eq(entries[1]["reason"], "embuscade")
	assert_eq(rng.draw_count(), 2)


func test_le_melange_est_reproductible_et_ne_perd_rien() -> void:
	var source := [1, 2, 3, 4, 5, 6, 7, 8]
	var a := CombatRng.new(SEED).shuffled(source, &"ordre_des_ennemis")
	var b := CombatRng.new(SEED).shuffled(source, &"ordre_des_ennemis")
	assert_eq(a, b, "même graine, même mélange")
	assert_eq(source, [1, 2, 3, 4, 5, 6, 7, 8], "le tableau d'origine n'est pas touché")
	var sorted_copy := a.duplicate()
	sorted_copy.sort()
	assert_eq(sorted_copy, source, "aucun élément perdu ni dupliqué")


func test_le_tirage_dans_un_tableau_vide_ne_plante_pas() -> void:
	assert_null(CombatRng.new(SEED).pick([], &"vide"))
	assert_push_error("tableau vide")


func test_un_generateur_derive_est_independant() -> void:
	# Deux dérivations de sels différents ne doivent pas se suivre, mais
	# chacune doit rester reproductible.
	var parent := CombatRng.new(SEED)
	var first := parent.derive(1)
	var second := parent.derive(2)
	var again := CombatRng.new(SEED).derive(1)

	var same := 0
	for i in 30:
		if first.int_between(0, 999, &"test") == second.int_between(0, 999, &"test"):
			same += 1
	assert_lt(same, 6, "deux sels différents doivent diverger")

	first.reset(first.seed_value)
	for i in 30:
		assert_eq(
			first.int_between(0, 999, &"test"),
			again.int_between(0, 999, &"test"),
			"la dérivation doit être reproductible"
		)


func test_la_probabilite_est_respectee() -> void:
	var rng := CombatRng.new(SEED)
	var hits := 0
	for i in 2000:
		if rng.chance(0.25, &"test"):
			hits += 1
	# 25 % sur 2000 tirages : large marge, on teste l'ordre de grandeur.
	assert_between(hits, 420, 580, "environ un quart de 2000")
