extends GutTest

## T11.8 — le passage de l'acte 1 à l'acte 2, de bout en bout.
##
## C'EST LE CHEMIN LE MOINS ÉPROUVÉ DU JEU ET LE PIRE ENDROIT POUR UN
## BUG : il se déclenche une seule fois par partie, au moment qui doit
## être le plus satisfaisant. Les pièces sont testées séparément —
## `Campaign` en unitaire, la région en données — mais rien ne vérifiait
## qu'une sortie menée à son terme ouvre VRAIMENT une terre jouable.


func before_each() -> void:
	Region.clear_cache()
	Unit.clear_cache()
	CombatRules.clear_cache()


func _company() -> Company:
	var company := Company.new()
	var rng := CombatRng.new(31337)
	for class_id: StringName in [&"warrior", &"archer", &"mage", &"warrior"]:
		company.recruit(class_id, rng)
	return company


func _hero_ids(company: Company) -> Array[int]:
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	return ids


func test_conclure_l_acte_1_ouvre_une_terre_JOUABLE() -> void:
	# « Ouverte » ne suffit pas : une région ouverte mais sans carte est
	# un cul-de-sac, et c'est exactement l'état où les cinq régions
	# verrouillées se trouvaient avant l'acte 2.
	var campaign := Campaign.new()
	var first := &"greenlands"
	var opened := campaign.clear_region(first)
	assert_eq(opened, &"burning_dunes", "l'acte 2 doit s'ouvrir")
	assert_true(campaign.is_open(opened))

	var maps := Region.encounter_maps(opened)
	assert_gt(maps.size(), 3, "une région sans cartes est un cul-de-sac")
	for map_id: StringName in maps:
		assert_not_null(CombatMap.load_map(map_id), "%s ne se charge pas" % map_id)
	assert_not_null(CombatMap.load_map(Region.boss_map(opened)), "pas de boss")
	assert_not_null(CombatMap.load_map(Region.miniboss_map(opened)), "pas de mini-boss")


func test_une_sortie_dans_l_acte_2_se_monte_entierement() -> void:
	# La chaîne du § 28 doit se bâtir : combats, évènement, marchand,
	# mini-boss, récompense, boss. Une région dont la chaîne ne se monte
	# pas se déclare parfaitement et ne se joue pas.
	var company := _company()
	# LA CAMPAGNE DÉCIDE, PAS LE FICHIER DE DONNÉES. `regions.json` ne dit
	# que l'état d'une partie neuve ; sans ce paramètre, `depart` refusait
	# une région que la carte du monde proposait pourtant.
	var campaign := Campaign.new()
	campaign.clear_region(&"greenlands")
	var run := Expedition.depart(
		&"burning_dunes", _hero_ids(company), CombatRng.new(4242), campaign
	)
	assert_not_null(run, "l'expédition doit partir")
	assert_true(run.is_ongoing())
	assert_gt(run.length(), 5, "une chaîne trop courte n'est pas une sortie")

	var kinds := {}
	for step: Dictionary in run.steps:
		kinds[String(step.get("kind", ""))] = true
	for expected: String in ["combat", "event", "merchant", "boss"]:
		assert_true(kinds.has(expected), "la chaîne n'a pas d'étape « %s »" % expected)


func test_les_dunes_paient_mieux_que_les_terres_vertes() -> void:
	# UNE RÉGION PLUS DURE QUI PAIE PAREIL N'A AUCUNE RAISON D'ÊTRE
	# CHOISIE. Rien ne le disait et rien ne cassait : à profondeur égale,
	# l'acte 2 rendait exactement le même butin que l'acte 1.
	var green := Region.reward_bonus(&"greenlands")
	var dunes := Region.reward_bonus(&"burning_dunes")
	assert_gt(
		float(dunes["gold_multiplier"]), float(green["gold_multiplier"]),
		"les Dunes doivent payer plus d'or"
	)
	assert_gt(
		int(dunes["rarity_bonus"]), int(green["rarity_bonus"]),
		"les Dunes doivent rendre de meilleurs objets"
	)


func test_les_betes_de_l_acte_2_se_fabriquent_vraiment() -> void:
	# Une entrée de bestiaire qui ne sait pas se fabriquer en `Unit` se
	# déclare parfaitement et fait tomber le combat au premier tirage.
	for map_id: StringName in Region.encounter_maps(&"burning_dunes"):
		var map := CombatMap.load_map(map_id)
		assert_not_null(map)
		if map == null:
			continue
		var enemies := map.board.active_units(Unit.Side.ENEMIES)
		assert_gt(enemies.size(), 2, "%s : trop peu d'ennemis" % map_id)
		for unit: Unit in enemies:
			assert_gt(unit.max_hit_points, 0, "%s : une bête sans PV" % map_id)
			assert_gt(unit.abilities.size(), 0, "%s : une bête sans coup" % map_id)


func test_partir_sans_avoir_ouvert_la_region_reste_refuse() -> void:
	# La garde ne disparaît pas, elle change d'autorité : une région
	# qu'aucune conclusion n'a ouverte reste fermée.
	var company := _company()
	assert_null(
		Expedition.depart(
			&"burning_dunes", _hero_ids(company), CombatRng.new(9), Campaign.new()
		),
		"on est parti vers une région verrouillée"
	)
	assert_push_error("verrouillée")
