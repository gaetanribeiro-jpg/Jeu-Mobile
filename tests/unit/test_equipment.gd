extends GutTest

## T2.3 — l'équipement.
##
## Deux propriétés à protéger. La première est le BUDGET : un objet vaut
## exactement ce que sa rareté autorise, et rien dans le jeu ne peut le
## mesurer autrement — on ne simule pas mille combats pour un anneau. La
## seconde est que l'équipement passe par `Hero.effective_stats()` comme
## tout le reste, et n'arrive au combat que sous forme de chiffres finis.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	Equipment.clear_cache()


func _hero(class_id: StringName = &"warrior") -> Hero:
	return Hero.create(1, class_id, "Aldric")


# --- La table --------------------------------------------------------------

func test_les_cinq_emplacements_du_paragraphe_30() -> void:
	var slots := Equipment.slots()
	assert_eq(slots.size(), 5)
	for wanted: StringName in [&"weapon", &"shield", &"helmet", &"armour", &"accessory"]:
		assert_true(slots.has(wanted), "emplacement manquant : %s" % wanted)


func test_les_cinq_raretes_du_paragraphe_31() -> void:
	var rarities := Equipment.rarities()
	assert_eq(rarities.size(), 5)
	for wanted: StringName in [
		&"common", &"uncommon", &"rare", &"epic", &"legendary"
	]:
		assert_true(rarities.has(wanted), "rareté manquante : %s" % wanted)


func test_une_rarete_plus_haute_vaut_plus_et_sort_moins() -> void:
	# C'est ce qui donne son prix au légendaire : sans les deux à la fois,
	# la rareté n'est qu'une couleur.
	var ordered: Array[StringName] = [
		&"common", &"uncommon", &"rare", &"epic", &"legendary"
	]
	for i in range(1, ordered.size()):
		assert_gt(
			Equipment.rarity_budget(ordered[i]), Equipment.rarity_budget(ordered[i - 1]),
			"%s doit valoir plus que %s" % [ordered[i], ordered[i - 1]]
		)
		assert_lt(
			Equipment.rarity_weight(ordered[i]), Equipment.rarity_weight(ordered[i - 1]),
			"%s doit sortir moins souvent que %s" % [ordered[i], ordered[i - 1]]
		)


func test_chaque_objet_vaut_exactement_son_budget() -> void:
	for item_id: StringName in Equipment.ids():
		assert_true(
			Equipment.is_within_budget(item_id),
			"%s vaut %.1f pour un budget de %.0f" % [
				item_id, Equipment.cost_of(item_id),
				Equipment.rarity_budget(Equipment.rarity_of(item_id))
			]
		)


func test_chaque_objet_a_un_emplacement_connu_et_accorde_quelque_chose() -> void:
	for item_id: StringName in Equipment.ids():
		assert_true(
			Equipment.is_slot(Equipment.slot_of(item_id)),
			"%s : emplacement inconnu" % item_id
		)
		assert_false(Equipment.grants(item_id).is_empty(), "%s n'accorde rien" % item_id)


func test_chaque_classe_peut_remplir_chacun_de_ses_emplacements() -> void:
	# Une fiche de héros avec un trou que rien ne comble est un défaut.
	for class_id: StringName in Unit.hero_class_ids():
		for slot: StringName in Equipment.slots():
			assert_false(
				Equipment.of_slot(slot, class_id).is_empty(),
				"un %s n'a rien à mettre en « %s »" % [class_id, slot]
			)


func test_un_objet_inconnu_ne_plante_pas() -> void:
	assert_false(Equipment.exists(&"excalibur"))
	assert_true(Equipment.grants(&"excalibur").is_empty())
	assert_push_error("objet inconnu")


# --- Porter un objet -------------------------------------------------------

func test_equiper_un_objet_change_les_statistiques() -> void:
	var hero := _hero()
	var before := int(hero.effective_stats()["strength"])
	hero.equip(&"iron_sword")
	assert_eq(
		int(hero.effective_stats()["strength"]),
		before + int(Equipment.grants(&"iron_sword")[&"strength"])
	)


func test_une_arme_est_reservee_a_sa_classe() -> void:
	# C'est ce qui rend les armes identitaires.
	var mage := _hero(&"mage")
	assert_false(mage.can_equip(&"iron_sword"))
	assert_eq(mage.equip(&"iron_sword"), &"")
	assert_push_error("ne peut pas être porté")
	assert_true(mage.equipment.is_empty())
	assert_true(mage.can_equip(&"oak_staff"))


func test_une_armure_est_ouverte_a_tous() -> void:
	# Sur-restreindre laisserait des emplacements morts sur deux classes.
	for class_id: StringName in Unit.hero_class_ids():
		assert_true(Hero.create(1, class_id, "X").can_equip(&"chainmail"))


func test_equiper_rend_ce_qui_occupait_l_emplacement() -> void:
	# Au roster de décider ce qu'il en fait — pas au héros de le jeter.
	var hero := _hero()
	assert_eq(hero.equip(&"rusty_sword"), &"", "l'emplacement était vide")
	assert_eq(hero.equip(&"iron_sword"), &"rusty_sword")
	assert_eq(hero.equipped(&"weapon"), &"iron_sword")


func test_retirer_un_objet_rend_les_statistiques_d_avant() -> void:
	var hero := _hero()
	var before := hero.effective_stats()
	hero.equip(&"kingmaker")
	assert_ne(hero.effective_stats(), before)
	assert_eq(hero.unequip(&"weapon"), &"kingmaker")
	assert_eq(hero.effective_stats(), before)


func test_retirer_un_emplacement_vide_ne_fait_rien() -> void:
	assert_eq(_hero().unequip(&"helmet"), &"")


func test_les_emplacements_s_additionnent() -> void:
	var hero := _hero()
	var bare := int(hero.effective_stats()["hit_points"])
	hero.equip(&"leather_cap")
	hero.equip(&"chainmail")
	assert_eq(
		int(hero.effective_stats()["hit_points"]),
		bare
			+ int(Equipment.grants(&"leather_cap")[&"hit_points"])
			+ int(Equipment.grants(&"chainmail")[&"hit_points"])
	)


func test_un_accessoire_peut_donner_un_pa() -> void:
	# Le seul objet du jeu qui touche aux PA : un tiers d'attaque de base
	# par activation, et c'est pour ça qu'il est légendaire.
	var hero := _hero()
	var before := int(hero.effective_stats()["action_points"])
	hero.equip(&"amulet_of_focus")
	assert_eq(int(hero.effective_stats()["action_points"]), before + 1)
	assert_eq(Equipment.rarity_of(&"amulet_of_focus"), &"legendary")


# --- Jusqu'au combat -------------------------------------------------------

func test_l_unite_de_combat_porte_l_equipement() -> void:
	var hero := _hero()
	var bare := hero.to_unit(1)
	hero.equip(&"kingmaker")
	hero.equip(&"dragonscale")
	var geared := hero.to_unit(2)
	assert_gt(geared.max_hit_points, bare.max_hit_points)
	assert_gt(geared.strength, bare.strength)
	assert_gt(geared.defence, bare.defence)


func test_l_equipement_change_vraiment_les_degats() -> void:
	# Un +5 de Force sur une Frappe de 20 est un quart de dégâts en plus :
	# c'est la granularité que l'échelle du § 47 devait offrir, et la
	# raison pour laquelle les statistiques restent des modificateurs.
	var board := CombatBoard.from_rows(PackedStringArray([
		"........", "........", "........",
	]), CombatRules.ADJACENCY_ORTHOGONAL)
	var hero := _hero()
	var goblin := Unit.from_enemy(90, &"spear_goblin", Vector2i(3, 1))
	board.place_unit(goblin, goblin.cell)

	var bare := hero.to_unit(1)
	board.place_unit(bare, Vector2i(2, 1))
	var without := board.predicted_damage(bare, Ability.of(&"strike"), goblin)

	board.remove_from_board(bare)
	hero.equip(&"kingmaker")
	var geared := hero.to_unit(2)
	board.place_unit(geared, Vector2i(2, 1))
	var with_sword := board.predicted_damage(geared, Ability.of(&"strike"), goblin)

	assert_gt(with_sword, without)
	assert_eq(with_sword - without, int(Equipment.grants(&"kingmaker")[&"strength"]))


func test_l_equipement_survit_a_la_sauvegarde() -> void:
	var hero := _hero(&"archer")
	hero.equip(&"longbow")
	hero.equip(&"swift_boots")
	var copy := Hero.from_dictionary(hero.to_dictionary())
	assert_eq(copy.equipped(&"weapon"), &"longbow")
	assert_eq(copy.equipped(&"accessory"), &"swift_boots")
	assert_eq(copy.effective_stats(), hero.effective_stats())


func test_un_objet_disparu_des_donnees_ne_plante_pas_un_heros() -> void:
	# Une sauvegarde peut porter un objet retiré depuis. Elle doit se
	# charger quand même : perdre un anneau vaut mieux que perdre la partie.
	var hero := _hero()
	hero.equipment["weapon"] = "excalibur"
	assert_true(hero.equipment_bonuses().is_empty())
	assert_false(hero.effective_stats().is_empty())
