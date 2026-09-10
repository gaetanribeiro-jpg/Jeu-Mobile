extends GutTest

## LE FEU ENNEMI ATTEND LA FIN DE LA SALVE (T12.5).
##
## LE DÉFAUT, EN UNE PHRASE : le sol d'une case entre dans le chiffre
## annoncé — une ruine ajoute un point de dégâts reçus — et une ruine est
## INFLAMMABLE. Un ennemi qui brûlait la ruine sous un héros faisait donc
## mentir de un point l'annonce de tous les ennemis qui n'avaient pas
## encore frappé. Le joueur avait décidé sur l'ancien chiffre : il ne
## pouvait pas savoir, et le § 39 promet l'information parfaite.
##
## IL DORMAIT DEPUIS LE GOBELIN TORCHE DE L'ACTE 2. Il a fallu un brûleur
## et une ruine sur la même carte pour le réveiller, et c'est le test qui
## parcourt une partie ENTIÈRE qui l'a vu — aucun test unitaire ne le
## disait, parce que chaque moitié était juste séparément.
##
## LE FEU DU JOUEUR, LUI, PREND TOUT DE SUITE : l'écran recalcule le
## télégraphe après chaque action de héros, donc le chiffre est à jour
## avant la décision suivante.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func test_une_ruine_est_inflammable_et_change_les_degats_recus() -> void:
	# Les deux moitiés du piège, énoncées : sans l'une ou l'autre, le
	# défaut n'existerait pas.
	assert_ne(
		int(CombatRules.terrain_property(&"ruin", &"damage_taken", 0)), 0,
		"une ruine qui ne change pas les dégâts ne pourrait pas faire mentir une annonce"
	)
	var board := _board(["rrr", "rrr", "rrr"])
	var tile := board.tile_at(Vector2i(1, 1))
	assert_true(tile.is_flammable(), "une ruine qui ne brûle pas ne poserait pas le problème")


func test_le_plateau_peut_relever_une_case_sans_l_enflammer() -> void:
	var board := _board(["rrr", "rrr", "rrr"])
	var tile := board.tile_at(Vector2i(1, 1))
	var before := tile.terrain_id
	assert_true(tile.can_cover_with(&"fire"), "la case devrait pouvoir prendre feu")
	assert_eq(tile.terrain_id, before, "la relever ne doit rien changer")
	assert_true(tile.cover_with(&"fire"), "et l'allumer doit marcher")
	assert_eq(tile.terrain_id, &"fire")


func test_une_case_qui_ne_brule_pas_se_releve_comme_telle() -> void:
	var board := _board(["...", ".~.", "..."])
	var tile := board.tile_at(Vector2i(1, 1))
	assert_false(tile.can_cover_with(&"fire"), "l'eau ne prend pas feu")
	assert_false(tile.cover_with(&"fire"))
