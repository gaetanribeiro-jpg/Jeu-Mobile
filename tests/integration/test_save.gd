extends GutTest

## T2.6 — la sauvegarde.
##
## Règle dure n° 5 : on sauvegarde après chaque action significative, parce
## que sur mobile l'application peut être tuée à tout moment sans prévenir.
## Ce que ces tests protègent : ce qu'on retrouve après un rechargement est
## exactement ce qu'on avait, y compris la graine — sans elle, une partie
## rechargée ne serait plus la même partie.
##
## Ces tests écrivent dans `user://`. Ils remettent en place ce qu'ils ont
## trouvé, pour ne pas effacer une partie en cours.


var _saved: Dictionary = {}
var _had_save := false


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	_saved = SaveManager.load_game() if _had_save else {}


func after_each() -> void:
	if _had_save:
		SaveManager.save_now(_saved)
	else:
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)
		DirAccess.remove_absolute(SaveManager.BACKUP_PATH)


func _peopled() -> Company:
	var company := Company.new()
	var rng := CombatRng.new(31337)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		company.recruit(class_id, rng)
	company.collect({"gold": 275, "items": ["plate", "swift_boots", "longbow"]})
	company.equip_from_stash(company.heroes[0].id, &"plate")
	company.heroes[1].add_experience(999999)
	company.heroes[1].level_up_free()
	return company


func test_une_partie_sauvegardee_se_retrouve_entiere() -> void:
	GameState.start_new_campaign(987654)
	GameState.company = _peopled()
	var before := GameState.to_save()
	assert_true(GameState.save())

	GameState.start_new_campaign(1)
	assert_eq(GameState.company.size(), 0, "la nouvelle partie est vide")

	assert_true(GameState.load_saved())
	assert_eq(GameState.campaign_seed, 987654, "la graine est revenue")
	assert_eq(GameState.to_save(), before)


func test_les_heros_reviennent_avec_leur_niveau_et_leur_equipement() -> void:
	GameState.start_new_campaign(4242)
	GameState.company = _peopled()
	var expected := {}
	for hero: Hero in GameState.company.heroes:
		expected[hero.id] = [hero.display_name(), hero.level, hero.effective_stats()]
	GameState.save()

	GameState.start_new_campaign(1)
	GameState.load_saved()
	for hero_id: int in expected.keys():
		var hero := GameState.company.hero_by_id(hero_id)
		assert_not_null(hero, "le héros %d a disparu" % hero_id)
		assert_eq(hero.display_name(), expected[hero_id][0])
		assert_eq(hero.level, expected[hero_id][1])
		assert_eq(hero.effective_stats(), expected[hero_id][2])


func test_l_or_et_la_reserve_reviennent() -> void:
	GameState.start_new_campaign(11)
	GameState.company = _peopled()
	var gold := GameState.company.gold
	var stash := GameState.company.stash.duplicate()
	GameState.save()

	GameState.start_new_campaign(1)
	GameState.load_saved()
	assert_eq(GameState.company.gold, gold)
	assert_eq(GameState.company.stash, stash)


func test_la_graine_rechargee_rejoue_les_memes_tirages() -> void:
	# Une partie qui se recharge doit rester la même partie : c'est la
	# règle 4, et tout le roguelite en dépend.
	GameState.start_new_campaign(555)
	var expected := GameState.combat_rng(3).int_between(1, 1000000, &"test")
	GameState.save()

	GameState.start_new_campaign(1)
	GameState.load_saved()
	assert_eq(GameState.combat_rng(3).int_between(1, 1000000, &"test"), expected)


func test_charger_sans_sauvegarde_ne_casse_rien() -> void:
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.BACKUP_PATH)
	GameState.start_new_campaign(77)
	GameState.company.recruit(&"warrior", CombatRng.new(1))
	assert_false(GameState.load_saved(), "il n'y a rien à charger")
	assert_eq(GameState.company.size(), 1, "la partie en cours est intacte")


func test_une_sauvegarde_est_versionnee() -> void:
	# Sans version, une migration future n'a rien à quoi se raccrocher.
	GameState.start_new_campaign(2)
	GameState.save()
	assert_eq(
		int(SaveManager.load_game().get("version", 0)), SaveManager.SAVE_VERSION
	)


func test_une_sauvegarde_illisible_ne_perd_pas_la_partie() -> void:
	# La copie de secours existe pour ce moment-là.
	GameState.start_new_campaign(31)
	GameState.company = _peopled()
	GameState.save()
	var gold := GameState.company.gold
	# Une seconde écriture pousse la première en copie de secours.
	GameState.save()

	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ ceci n'est pas du JSON")
	file.close()

	GameState.start_new_campaign(1)
	assert_true(GameState.load_saved(), "la copie de secours a pris le relais")
	assert_eq(GameState.company.gold, gold)
	# Lire un fichier abîmé DOIT se plaindre : c'est la seule trace qui
	# reste, une fois la partie sauvée par la copie de secours.
	assert_engine_error(2)
