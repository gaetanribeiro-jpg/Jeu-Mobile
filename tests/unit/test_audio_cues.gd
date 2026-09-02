extends GutTest

## T11.2 — le son enfin branché.
##
## LE JEU ÉTAIT MUET, ET RIEN NE S'EN PLAIGNAIT. 473 fichiers dans le
## dépôt, `AudioManager` câblé sur trois bus, trente entrées déclarées —
## et **zéro appel** depuis le jeu. Un jeu silencieux se joue
## parfaitement ; il paraît simplement cassé.
##
## CE QUI EST TESTABLE ICI, c'est la TABLE : qu'un moment de jeu trouve
## son son. Qu'il soit AGRÉABLE demande des oreilles, et les affectations
## n'ont jamais été écoutées — raison de plus pour qu'elles vivent dans
## les données et pas dans le code.


func before_each() -> void:
	AudioTable.clear_cache()


func test_chaque_repere_pointe_sur_un_effet_declare() -> void:
	# UN REPÈRE CASSÉ NE FAIT PAS DE BRUIT ET NE SE PLAINT PAS : c'est le
	# pire des défauts sonores. Le jeu tourne, l'action se joue, et il
	# manque un son que personne ne cherchait.
	var declared := AudioTable.sfx_ids()
	var checked := 0
	for moment: StringName in AudioTable.cue_ids():
		var sound_id := AudioTable.cue(moment)
		if sound_id.is_empty():
			continue
		checked += 1
		assert_true(
			declared.has(sound_id),
			"le repère « %s » veut « %s », qui n'est pas un effet déclaré"
				% [moment, sound_id]
		)
	assert_gt(checked, 10, "il faut de quoi sonoriser une partie")


func test_les_moments_du_combat_ont_tous_une_voix() -> void:
	# CE SONT CEUX QU'ON ENTEND VINGT FOIS PAR COMBAT. En perdre un ne
	# casse rien : il rend une action muette au milieu d'actions qui ne le
	# sont pas, ce qui s'entend comme un défaut plutôt que comme un choix.
	for moment: StringName in [
		&"attack_melee", &"attack_ranged", &"attack_spell",
		&"hit", &"unit_downed", &"step", &"victory", &"defeat",
	]:
		assert_false(
			AudioTable.cue(moment).is_empty(),
			"le moment « %s » est muet" % moment
		)


func test_un_moment_inconnu_fait_silence_sans_se_plaindre() -> void:
	# Retirer un son doit coûter une ligne de données, pas une relecture
	# de code : un repère absent est une réponse valable.
	assert_true(AudioTable.cue(&"pas_un_moment").is_empty())


func test_l_interface_et_le_monde_ont_leur_voix() -> void:
	for moment: StringName in [&"ui_press", &"build", &"loot_gold", &"recruit"]:
		assert_false(AudioTable.cue(moment).is_empty(), "« %s » est muet" % moment)
