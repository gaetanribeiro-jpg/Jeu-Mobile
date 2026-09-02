extends GutTest

## T11.7 — le bestiaire découpé par acte.
##
## `Unit.enemies()` FOND les fichiers d'acte en une seule table. C'est ce
## qui permet à une carte de convoquer n'importe quelle bête sans savoir
## de quel acte elle vient — un ennemi n'appartient à son acte que pour
## être ÉCRIT — et c'est aussi ce qui rend la collision d'identifiants
## dangereuse : elle se jouerait en silence.


func before_each() -> void:
	Unit.clear_cache()
	Ability.clear_cache()
	AssetTable.clear_cache()


func _ids_in(path: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for key: Variant in (parsed as Dictionary).keys():
		if not String(key).begins_with("_"):
			out.append(StringName(key))
	return out


func test_les_deux_actes_sont_fondus() -> void:
	var merged := Unit.enemy_ids()
	assert_gt(Unit.ENEMY_PATHS.size(), 1, "le bestiaire est découpé par acte")
	var total := 0
	for path: String in Unit.ENEMY_PATHS:
		var ids := _ids_in(path)
		assert_gt(ids.size(), 0, "%s est vide" % path)
		total += ids.size()
		for enemy_id: StringName in ids:
			assert_true(merged.has(enemy_id), "« %s » manque à la table" % enemy_id)
	assert_eq(merged.size(), total, "aucune bête ne doit se perdre à la fusion")


func test_aucun_identifiant_n_est_declare_deux_fois() -> void:
	# Deux actes qui déclarent le même identifiant se marcheraient dessus
	# EN SILENCE, et une carte de l'acte 1 changerait de bête sans qu'une
	# ligne de code ait bougé.
	var seen := {}
	for path: String in Unit.ENEMY_PATHS:
		for enemy_id: StringName in _ids_in(path):
			assert_false(
				seen.has(enemy_id),
				"« %s » est déclaré dans %s et dans %s" % [enemy_id, seen.get(enemy_id, ""), path]
			)
			seen[enemy_id] = path


func test_chaque_bete_sait_frapper() -> void:
	# Une entrée sans compétence rend un ennemi qui passe son tour : ça se
	# JOUE sans rien casser, et c'est exactement ce qui ne se voit pas.
	for enemy_id: StringName in Unit.enemy_ids():
		var abilities: Array = Unit.enemy_stats(enemy_id).get("abilities", [])
		assert_gt(abilities.size(), 0, "« %s » n'a aucune compétence" % enemy_id)
		for ability_id: Variant in abilities:
			assert_not_null(
				Ability.of(StringName(ability_id)),
				"« %s » veut la compétence inconnue « %s »" % [enemy_id, ability_id]
			)


func test_chaque_bete_pose_une_question() -> void:
	# LA QUESTION EST LE CRITÈRE D'ADMISSION, pas un commentaire : un
	# ennemi qui n'en pose pas de neuve n'ajoute que des points de vie à
	# tuer, et un acte 2 fait de ceux-là serait un acte 1 plus lent.
	for enemy_id: StringName in Unit.enemy_ids():
		assert_false(
			String(Unit.enemy_stats(enemy_id).get("question", "")).is_empty(),
			"« %s » ne dit pas ce qu'il demande au joueur" % enemy_id
		)


func test_l_acte_2_apporte_des_roles_que_l_acte_1_n_avait_pas() -> void:
	# Un acte 2 qui ne serait qu'un acte 1 aux chiffres gonflés n'apprend
	# rien. Le barrage — une bête qu'on a intérêt à IGNORER — est le rôle
	# que la première région ne posait nulle part.
	var first := {}
	for enemy_id: StringName in _ids_in(Unit.ENEMY_PATHS[0]):
		first[StringName(Unit.enemy_stats(enemy_id).get("role", ""))] = true
	var fresh := 0
	for enemy_id: StringName in _ids_in(Unit.ENEMY_PATHS[1]):
		if not first.has(StringName(Unit.enemy_stats(enemy_id).get("role", ""))):
			fresh += 1
	assert_gt(fresh, 0, "l'acte 2 n'apporte aucun rôle neuf")
