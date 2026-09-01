extends GutTest

## T3.3 — les évènements du § 40.
##
## Le § 40 tient en une phrase : « les événements doivent créer des
## décisions ». Ces tests protègent donc deux choses. D'abord la table
## elle-même — chaque évènement offre au moins deux options qui s'excluent,
## et aucune n'est meilleure qu'une autre sur toute la ligne. Ensuite
## l'échange : ce qu'une option promet doit vraiment être prélevé ou versé,
## sur les PV, sur la bourse, sur la besace.


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
	ExpeditionEvent.clear_cache()


func _company() -> Company:
	var company := Company.new()
	var rng := CombatRng.new(1234)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		company.recruit(class_id, rng)
	return company


## Une expédition déjà en route, avec son équipe entamée : c'est l'état
## dans lequel un évènement se rencontre vraiment.
func _underway(company: Company, seed_value: int = 3) -> Expedition:
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(seed_value))
	var units := run.squad_units(company)
	run.resolve_combat(
		{"victory": true, "enemies_downed": 4}, units, CombatRng.new(seed_value)
	)
	# On se place sur la première étape hors plateau.
	while run.is_ongoing() and run.current_is_combat():
		run.index += 1
	return run


# --- La table tient la promesse du § 40 ------------------------------------

func test_les_cinq_evenements_du_paragraphe_40_sont_declares() -> void:
	assert_eq(ExpeditionEvent.ids().size(), 5)


func test_chaque_evenement_offre_au_moins_deux_options() -> void:
	# Une option unique n'est pas une décision, c'est une annonce.
	for event_id: StringName in ExpeditionEvent.ids():
		assert_gt(ExpeditionEvent.options(event_id).size(), 1, String(event_id))


func test_chaque_option_echange_quelque_chose() -> void:
	for event_id: StringName in ExpeditionEvent.ids():
		for index in ExpeditionEvent.options(event_id).size():
			var option := ExpeditionEvent.option(event_id, index)
			var success: Dictionary = option.get("success", {})
			assert_false(
				success.is_empty() and not option.has("chance"),
				"%s option %d ne fait rien" % [event_id, index]
			)


func test_un_evenement_inconnu_se_signale() -> void:
	ExpeditionEvent.entry(&"dragon_apprivoise")
	assert_push_error("ExpeditionEvent : évènement inconnu « dragon_apprivoise »")


func test_une_option_inexistante_se_signale() -> void:
	assert_eq(ExpeditionEvent.resolve(&"altar", 99, CombatRng.new(1)), {})
	assert_push_error("ExpeditionEvent : « altar » n'a pas d'option 99")


# --- Le tirage -------------------------------------------------------------

func test_le_tirage_se_rejoue_a_l_identique() -> void:
	assert_eq(
		ExpeditionEvent.draw(CombatRng.new(77)),
		ExpeditionEvent.draw(CombatRng.new(77))
	)


func test_le_tirage_evite_ce_qu_on_a_deja_vu() -> void:
	var seen: Array = ["altar", "village", "ruins", "ambush"]
	for seed_value in 20:
		assert_eq(ExpeditionEvent.draw(CombatRng.new(seed_value), seen), &"chest")


func test_le_tirage_rouvre_la_table_quand_tout_a_ete_vu() -> void:
	# Rendre une étape vide serait un trou dans la chaîne ; mieux vaut
	# resservir un évènement déjà croisé.
	var all: Array = []
	for event_id: StringName in ExpeditionEvent.ids():
		all.append(String(event_id))
	assert_true(ExpeditionEvent.exists(ExpeditionEvent.draw(CombatRng.new(5), all)))


func test_l_evenement_se_tire_a_l_arrivee_et_ne_change_plus() -> void:
	# Le § 40 les veut aléatoires : la route dit « un évènement », pas
	# lequel. Mais une partie rechargée doit retrouver le même.
	var run := _underway(_company())
	var first := run.reveal_event(CombatRng.new(9))
	assert_false(first.is_empty())
	assert_eq(run.reveal_event(CombatRng.new(12345)), first)

	var reloaded := Expedition.from_dictionary(run.to_dictionary())
	assert_eq(reloaded.reveal_event(CombatRng.new(999)), first)


func test_une_etape_de_combat_n_a_pas_d_evenement() -> void:
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))
	assert_true(run.current_is_combat())
	assert_eq(run.reveal_event(CombatRng.new(1)), &"")


# --- Le pari ---------------------------------------------------------------

func test_une_option_sans_pari_reussit_toujours() -> void:
	for seed_value in 15:
		var outcome := ExpeditionEvent.resolve(&"village", 0, CombatRng.new(seed_value))
		assert_true(bool(outcome["succeeded"]))
		assert_false(bool(outcome["gambled"]))


func test_une_option_a_pari_echoue_parfois() -> void:
	var failures := 0
	for seed_value in 60:
		if not bool(ExpeditionEvent.resolve(&"ruins", 0, CombatRng.new(seed_value))["succeeded"]):
			failures += 1
	assert_gt(failures, 0, "le pari ne perd jamais")
	assert_lt(failures, 60, "le pari ne gagne jamais")


func test_le_de_est_jete_une_seule_fois_et_se_rejoue() -> void:
	# Un pari qu'on ne peut pas rejouer est un pari qu'on ne peut pas
	# déboguer.
	assert_eq(
		ExpeditionEvent.resolve(&"chest", 1, CombatRng.new(42)),
		ExpeditionEvent.resolve(&"chest", 1, CombatRng.new(42))
	)


# --- Ce que l'option coûte vraiment ----------------------------------------

func test_l_autel_prend_le_sang_qu_il_annonce() -> void:
	var company := _company()
	var run := _underway(company)
	var before: int = run.carried[run.squad_ids[0]]
	var maximum: int = run.squad_units(company)[0].max_hit_points

	var effects := ExpeditionEvent.resolve(&"altar", 0, CombatRng.new(4))
	run.resolve_event(effects, CombatRng.new(4), company)

	var expected := before + int(round(float(maximum) * float(effects["health"])))
	assert_eq(int(run.carried[run.squad_ids[0]]), expected)
	assert_lt(int(run.carried[run.squad_ids[0]]), before)


func test_un_evenement_ne_tue_jamais() -> void:
	# Mourir se fait sur un plateau, où le joueur peut agir. Pas dans un
	# menu, où il ne peut que regarder.
	var company := _company()
	var run := _underway(company)
	for hero_id: int in run.carried.keys():
		run.carried[hero_id] = 1
	run.resolve_event(ExpeditionEvent.resolve(&"altar", 0, CombatRng.new(4)), CombatRng.new(4), company)
	for hero_id: int in run.carried.keys():
		assert_gt(int(run.carried[hero_id]), 0, "un héros est mort dans un menu")


func test_le_forgeron_prend_l_or_de_la_compagnie() -> void:
	# Une expédition dépense l'or du royaume ; elle n'en a pas un second.
	var company := _company()
	company.gold = 500
	var run := _underway(company)
	var effects := ExpeditionEvent.resolve(&"village", 1, CombatRng.new(4))
	run.resolve_event(effects, CombatRng.new(4), company)
	assert_eq(company.gold, 500 + int(effects["gold"]))
	assert_lt(company.gold, 500)


func test_une_option_trop_chere_reste_proposee_mais_se_sait() -> void:
	# Savoir ce qu'on ne peut pas s'offrir fait partie de la décision.
	var cost := ExpeditionEvent.option_gold_cost(&"village", 1)
	assert_gt(cost, 0)
	assert_false(ExpeditionEvent.can_afford(&"village", 1, cost - 1))
	assert_true(ExpeditionEvent.can_afford(&"village", 1, cost))


func test_l_autel_donne_ce_qu_il_promet() -> void:
	var company := _company()
	var run := _underway(company)
	var report := run.resolve_event(
		ExpeditionEvent.resolve(&"altar", 0, CombatRng.new(4)), CombatRng.new(4), company
	)
	assert_eq((report["items"] as Array).size(), 1)
	assert_eq(run.satchel_items.size(), 1, "l'objet n'est pas dans la besace")


func test_fuir_coute_une_part_de_la_besace() -> void:
	var company := _company()
	var run := _underway(company)
	run.satchel_gold = 200
	var report := run.resolve_event(
		ExpeditionEvent.resolve(&"ambush", 1, CombatRng.new(4)), CombatRng.new(4), company
	)
	assert_lt(run.satchel_gold, 200)
	assert_gt(run.satchel_gold, 0, "fuir prend tout")
	assert_gt(int(report["lost_gold"]), 0)


func test_charger_intercale_une_rencontre() -> void:
	var company := _company()
	var run := _underway(company)
	var before := run.length()
	var report := run.resolve_event(
		ExpeditionEvent.resolve(&"ambush", 0, CombatRng.new(4)), CombatRng.new(4), company
	)
	assert_true(bool(report["combat"]))
	assert_eq(run.length(), before + 1, "l'embuscade n'a pas amené de combat")
	assert_true(run.current_is_combat())
	assert_true(run.is_ongoing())


func test_l_etape_de_recompense_tire_son_butin_toute_seule() -> void:
	var company := _company()
	var run := _underway(company)
	while run.is_ongoing() and run.current_kind() != Expedition.KIND_REWARD:
		run.index += 1
	run.resolve_event({}, CombatRng.new(4), company)
	assert_gt(run.satchel_gold, 0, "la récompense ne donne rien")
