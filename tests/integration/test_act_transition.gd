extends GutTest

## T11.8 — le passage d'un acte au suivant, de bout en bout.
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


## LES RÉGIONS JOUABLES, DANS L'ORDRE DE LEUR ACTE. C'est sur cette liste
## que tournent les tests génériques : le jour où l'acte 4 reçoit ses
## cartes, il entre tout seul dans la couverture, sans qu'on touche à un
## test. Une coquille vide n'est pas un défaut — elle attend son contenu.
func _playable() -> Array[StringName]:
	var out: Array[StringName] = []
	for region_id: StringName in Region.ids():
		if not Region.encounter_maps(region_id).is_empty():
			out.append(region_id)
	return out


## CHAQUE FRONTIÈRE D'ACTE SE PARCOURT, PAS SEULEMENT LA PREMIÈRE.
##
## Le test d'origine ne connaissait que « Terres Vertes → Dunes ». La
## machinerie de `Campaign` est pourtant générique — l'acte n + 1 s'ouvre
## quand une région d'acte n est conclue — et c'est exactement le genre de
## généricité qu'on croit acquise jusqu'à ce qu'un acte de plus la
## démente. Celui-ci les parcourt TOUTES.
func test_chaque_acte_conclu_ouvre_le_suivant() -> void:
	var playable := _playable()
	assert_gt(playable.size(), 1, "il faut au moins deux actes pour un passage")
	var campaign := Campaign.new()
	for i in playable.size() - 1:
		var here: StringName = playable[i]
		var next: StringName = playable[i + 1]
		assert_false(
			campaign.is_open(next),
			"%s ne doit pas être ouverte avant que %s soit conclue" % [next, here]
		)
		var opened := campaign.clear_region(here)
		assert_eq(opened, next, "conclure %s doit ouvrir %s" % [here, next])
		assert_true(campaign.is_open(next))


## Une région ouverte mais sans carte est un cul-de-sac, et c'est l'état
## où les cinq régions verrouillées se trouvaient avant l'acte 2.
func test_chaque_acte_ouvert_est_reellement_jouable() -> void:
	for region_id: StringName in _playable():
		var maps := Region.encounter_maps(region_id)
		assert_gt(maps.size(), 3, "%s : une région sans cartes est un cul-de-sac" % region_id)
		for map_id: StringName in maps:
			assert_not_null(CombatMap.load_map(map_id), "%s ne se charge pas" % map_id)
		assert_not_null(
			CombatMap.load_map(Region.boss_map(region_id)), "%s : pas de boss" % region_id
		)
		assert_not_null(
			CombatMap.load_map(Region.miniboss_map(region_id)),
			"%s : pas de mini-boss" % region_id
		)


## LA CHAÎNE SE MONTE POUR CHAQUE ACTE, et c'est le chemin qui avait caché
## le bug de T11.8 : `depart()` demandait le FICHIER quand la carte du
## monde demandait la PARTIE, et chaque moitié répondait juste à sa
## question. Le test le rejoue maintenant à chaque frontière.
func test_une_sortie_se_monte_dans_chaque_acte() -> void:
	var company := _company()
	var campaign := Campaign.new()
	var playable := _playable()
	for i in playable.size():
		var region_id: StringName = playable[i]
		var run := Expedition.depart(
			region_id, _hero_ids(company), CombatRng.new(4242 + i), campaign
		)
		assert_not_null(run, "%s : l'expédition doit partir" % region_id)
		if run == null:
			continue
		assert_gt(run.length(), 5, "%s : chaîne trop courte" % region_id)
		var kinds := {}
		for step: Dictionary in run.steps:
			kinds[String(step.get("kind", ""))] = true
		for expected: String in ["combat", "event", "merchant", "boss"]:
			assert_true(
				kinds.has(expected),
				"%s : la chaîne n'a pas d'étape « %s »" % [region_id, expected]
			)
		campaign.clear_region(region_id)


## UN ACTE TARDIF DOIT PAYER PLUS, à chaque frontière et pas seulement à
## la première. Une région plus dure qui paie pareil n'a aucune raison
## d'être choisie.
func test_chaque_acte_paie_mieux_que_le_precedent() -> void:
	var playable := _playable()
	for i in playable.size() - 1:
		var here := Region.reward_bonus(playable[i])
		var next := Region.reward_bonus(playable[i + 1])
		assert_gt(
			float(next["gold_multiplier"]), float(here["gold_multiplier"]),
			"%s doit payer plus que %s" % [playable[i + 1], playable[i]]
		)


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
