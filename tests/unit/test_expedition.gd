extends GutTest

## T3.2 — l'expédition : la chaîne du § 28 et la décision du § 29.
##
## Ce que ces tests protègent, c'est la décision elle-même. Elle n'existe
## que si trois choses sont vraies en même temps : continuer rapporte plus,
## continuer coûte, échouer perd. Chacune a ses tests ici ; en casser une
## rendrait la réponse automatique, et la mécanique fondamentale du
## roguelite disparaîtrait sans qu'aucun autre test ne bronche.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()
	Loot.clear_cache()
	Region.clear_cache()
	ExpeditionRules.clear_cache()


func _company() -> Company:
	var company := Company.new()
	var rng := CombatRng.new(1234)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		company.recruit(class_id, rng)
	return company


func _run(seed_value: int = 7) -> Expedition:
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	return Expedition.depart(&"greenlands", ids, CombatRng.new(seed_value))


func _victory(downed: int = 4) -> Dictionary:
	return {"victory": true, "enemies_downed": downed, "finished": true}


func _defeat() -> Dictionary:
	return {"victory": false, "enemies_downed": 1, "finished": true}


# --- La chaîne du § 28 -----------------------------------------------------

func test_une_expedition_part_de_sa_region() -> void:
	var run := _run()
	assert_not_null(run)
	assert_eq(run.region_id, &"greenlands")
	assert_true(run.is_ongoing())
	assert_eq(run.depth(), 0)


func test_on_ne_part_pas_dans_une_region_verrouillee() -> void:
	assert_null(Expedition.depart(&"black_empire", [] as Array[int], CombatRng.new(1)))
	assert_push_error("Expedition : la région « black_empire » est verrouillée")


func test_on_ne_part_pas_dans_une_region_inexistante() -> void:
	assert_null(Expedition.depart(&"atlantide", [] as Array[int], CombatRng.new(1)))


func test_la_chaine_finit_toujours_par_son_boss() -> void:
	# Une expédition courte n'est pas une expédition tronquée : elle a moins
	# de corps, mais elle a sa fin.
	for seed_value in 25:
		var run := _run(seed_value)
		var tail := Region.chain_tail(&"greenlands")
		var last := run.steps.slice(run.length() - tail.size())
		for i in tail.size():
			assert_eq(StringName(last[i]["kind"]), tail[i], "graine %d" % seed_value)


func test_la_chaine_commence_par_un_combat() -> void:
	# Le § 28 ouvre sur « Départ → Combat ». Ouvrir sur un marchand ferait
	# d'une expédition une boutique.
	for seed_value in 20:
		assert_eq(_run(seed_value).step_kind(0), Expedition.KIND_COMBAT)


func test_chaque_etape_de_combat_a_une_carte_et_les_autres_non() -> void:
	var known := CombatMap.map_ids()
	for seed_value in 20:
		var run := _run(seed_value)
		for step: Dictionary in run.steps:
			var kind := StringName(step["kind"])
			var map_id := StringName(step["map"])
			var fights := kind in [
				Expedition.KIND_COMBAT, Expedition.KIND_MINIBOSS, Expedition.KIND_BOSS
			]
			assert_eq(not map_id.is_empty(), fights, String(kind))
			if fights:
				assert_true(known.has(map_id), String(map_id))


func test_la_meme_graine_donne_la_meme_route() -> void:
	# Sans ça, une expédition rechargée ne serait plus la même expédition.
	assert_eq(_run(555).steps, _run(555).steps)


func test_deux_graines_ne_donnent_pas_toujours_la_meme_route() -> void:
	var seen := {}
	for seed_value in 30:
		seen[str(_run(seed_value).steps)] = true
	assert_gt(seen.size(), 1, "la route ne varie pas du tout")


# --- Continuer rapporte plus (§ 29) ----------------------------------------

func test_la_profondeur_avance_avec_les_etapes() -> void:
	var run := _run()
	run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(1))
	assert_eq(run.depth(), 1)
	assert_eq(run.remaining(), run.length() - 1)


func test_le_butin_grossit_avec_la_profondeur() -> void:
	# C'est la moitié « tentante » de la question du § 29. Sans elle, on
	# rentrerait toujours après la première rencontre.
	var shallow := 0
	var deep := 0
	for seed_value in 60:
		var early := _run(seed_value)
		early.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(seed_value))
		shallow += early.satchel_gold

		var late := _run(seed_value)
		late.index = 5
		late.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(seed_value))
		deep += late.satchel_gold
	assert_gt(deep, shallow, "s'enfoncer ne rapporte pas plus")


# --- Continuer coûte -------------------------------------------------------

func test_les_pv_se_portent_d_une_etape_a_l_autre() -> void:
	# L'usure mesurée en T1.11 ne compte que si elle s'accumule.
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))

	var units := run.squad_units(company)
	assert_eq(units.size(), 3)
	var wounded := units[0]
	wounded.hit_points = wounded.max_hit_points / 2
	run.resolve_combat(_victory(), units, CombatRng.new(3))

	var next_units := run.squad_units(company)
	assert_eq(next_units[0].hit_points, wounded.max_hit_points / 2)
	assert_eq(next_units[1].hit_points, next_units[1].max_hit_points)


func test_un_heros_a_terre_se_releve_diminue_mais_se_releve() -> void:
	# § 25 : pas de mort définitive. § 41 : mourir reste une conséquence.
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))

	var units := run.squad_units(company)
	units[2].down()
	var outcome := run.resolve_combat(_victory(), units, CombatRng.new(3))
	assert_eq(outcome["downed"], [ids[2]] as Array[int])

	var next_units := run.squad_units(company)
	assert_gt(next_units[2].hit_points, 0, "le héros repart à terre")
	assert_lt(next_units[2].hit_points, next_units[2].max_hit_points)


func test_l_etape_de_recompense_est_la_seule_respiration() -> void:
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))

	var units := run.squad_units(company)
	for unit: Unit in units:
		unit.hit_points = 1
	run.resolve_combat(_victory(), units, CombatRng.new(3))
	var after_fight: int = run.carried[ids[0]]

	# On se place sur l'étape de récompense de la fin de chaîne.
	while run.current_kind() != Expedition.KIND_REWARD and run.is_ongoing():
		run.index += 1
	run.resolve_event({}, CombatRng.new(3))
	assert_gt(int(run.carried[ids[0]]), after_fight, "la récompense ne soigne pas")


# --- Échouer perd ----------------------------------------------------------

func test_une_defaite_perd_l_expedition() -> void:
	var run := _run()
	run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(1))
	var outcome := run.resolve_combat(_defeat(), [] as Array[Unit], CombatRng.new(1))
	assert_eq(int(outcome["state"]), Expedition.State.LOST)
	assert_true(run.is_over())
	assert_false(run.is_complete())


func test_une_deroute_ne_prend_pas_tout() -> void:
	# § 41 : mourir est une conséquence, pas une punition absolue.
	var run := _run()
	run.satchel_gold = 100
	var kept := ExpeditionRules.satchel_kept_on_wipe()
	run.resolve_combat(_defeat(), [] as Array[Unit], CombatRng.new(1))
	assert_eq(run.satchel_gold, int(floor(100.0 * kept)))
	assert_gt(run.satchel_gold, 0)
	assert_lt(run.satchel_gold, 100)


func test_une_deroute_perd_des_objets_sans_tout_perdre() -> void:
	var run := _run()
	for i in 5:
		run.satchel_items.append(Equipment.ids()[i])
	run.resolve_combat(_defeat(), [] as Array[Unit], CombatRng.new(1))
	var kept := ExpeditionRules.satchel_kept_on_wipe()
	assert_eq(run.satchel_items.size(), int(floor(5.0 * kept)))


func test_ce_qui_reste_apres_une_deroute_se_rejoue_a_l_identique() -> void:
	var first := _run()
	var second := _run()
	for run: Expedition in [first, second]:
		for i in 5:
			run.satchel_items.append(Equipment.ids()[i])
		run.resolve_combat(_defeat(), [] as Array[Unit], CombatRng.new(88))
	assert_eq(first.satchel_items, second.satchel_items)


# --- La besace et le retour ------------------------------------------------

func test_la_besace_ne_rejoint_la_compagnie_qu_au_retour() -> void:
	# C'est ce qui met le butin en jeu. Sans ça, continuer ne risquerait
	# rien.
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))
	run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(3))

	assert_gt(run.satchel_gold, 0)
	assert_eq(company.gold, 0, "l'or est arrivé trop tôt")
	assert_eq(run.bank(company), {}, "on a pu vider la besace en route")

	run.retreat()
	var banked := run.bank(company)
	assert_gt(company.gold, 0)
	assert_eq(company.gold, int(banked["gold"]))
	assert_eq(run.satchel_gold, 0)


func test_on_ne_rentre_pas_avant_d_etre_parti() -> void:
	# Partir pour faire demi-tour aussitôt n'est pas une décision.
	var run := _run()
	assert_false(run.can_retreat())
	assert_false(run.retreat())
	assert_true(run.is_ongoing())

	run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(1))
	assert_true(run.can_retreat())
	assert_true(run.retreat())
	assert_true(run.is_over())


func test_battre_le_boss_termine_la_chaine() -> void:
	var run := _run()
	var guard := 0
	while run.is_ongoing() and guard < 40:
		if run.current_is_combat():
			run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(guard))
		else:
			run.resolve_event({}, CombatRng.new(guard))
		guard += 1
	assert_true(run.is_complete(), "la chaîne ne se termine pas")
	assert_eq(run.state, Expedition.State.RETURNED)
	assert_eq(run.depth(), run.length())


func test_une_expedition_finie_n_avance_plus() -> void:
	var run := _run()
	run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(1))
	run.retreat()
	var before := run.depth()
	assert_eq(run.resolve_combat(_victory(), [] as Array[Unit], CombatRng.new(1)), {})
	assert_eq(run.resolve_event({}, CombatRng.new(1)), {})
	assert_eq(run.depth(), before)


# --- La sauvegarde ---------------------------------------------------------

func test_une_expedition_survit_a_un_rechargement() -> void:
	# Sur mobile, l'application meurt en pleine expédition. La perdre serait
	# la pire des punitions.
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))
	var units := run.squad_units(company)
	units[0].hit_points = 11
	run.resolve_combat(_victory(), units, CombatRng.new(3))

	var reloaded := Expedition.from_dictionary(run.to_dictionary())
	assert_eq(reloaded.region_id, run.region_id)
	assert_eq(reloaded.index, run.index)
	assert_eq(reloaded.steps, run.steps)
	assert_eq(reloaded.squad_ids, run.squad_ids)
	assert_eq(reloaded.satchel_gold, run.satchel_gold)
	assert_eq(reloaded.satchel_items, run.satchel_items)
	assert_eq(reloaded.squad_units(company)[0].hit_points, 11)


func test_un_objet_disparu_des_donnees_ne_fait_pas_tomber_la_partie() -> void:
	var run := _run()
	var saved := run.to_dictionary()
	saved["items"] = ["anneau_de_l_oubli"]
	assert_true(Expedition.from_dictionary(saved).satchel_items.is_empty())
