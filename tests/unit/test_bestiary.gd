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


## LE DESSIN N'EST PAS L'IDENTITÉ, et l'acte 1 le cachait.
##
## Pendant tout l'acte 1, chaque ennemi portait le nom de son sprite —
## `troll` se dessine avec `troll` —, si bien que les vues ont pris
## l'habitude d'aller chercher l'image avec `class_id`. Ça marchait par
## COÏNCIDENCE. L'acte 2 l'a rompue (`sand_serpent` se dessine avec
## `snake`) et sept bêtes se sont affichées en ombre nue, sans une seule
## erreur dans la console : `has_enemy_animation` répond « non » poliment
## et la vue retombe sur rien.
func test_une_unite_ennemie_porte_le_sprite_declare_en_donnees() -> void:
	var unit := Unit.from_enemy(1, &"sand_serpent", Vector2i.ZERO)
	assert_not_null(unit, "le serpent des sables doit se fabriquer")
	assert_eq(
		unit.sprite_id, &"snake",
		"le serpent des sables se dessine avec le sprite « snake »"
	)
	assert_ne(
		unit.sprite_id, unit.class_id,
		"c'est justement le cas où les deux diffèrent"
	)


## Chaque bête du jeu doit savoir se dessiner ET se montrer de face : la
## timeline affiche des visages depuis T11.8, et une bête sans avatar y
## retomberait sur son initiale, seule au milieu de portraits.
func test_chaque_ennemi_sait_se_dessiner_par_son_sprite() -> void:
	for enemy_id: StringName in Unit.enemy_ids():
		var unit := Unit.from_enemy(1, enemy_id, Vector2i.ZERO)
		assert_not_null(unit, "%s doit se fabriquer" % enemy_id)
		if unit == null:
			continue
		# UN ENNEMI HUMAIN SE CHERCHE PARMI LES UNITÉS (T12.1), pas parmi
		# les bêtes, et c'est `sprite_color` qui le dit. Le pack dessine
		# vingt-cinq sprites humains dont le jeu n'employait que le Bleu
		# des héros ; les Rougefer de l'acte 3 sont les premiers ennemis
		# à en porter.
		if not unit.sprite_color.is_empty():
			assert_true(
				AssetTable.has_unit_animation(unit.sprite_id, &"idle"),
				"%s : pas d'animation d'attente pour « %s »"
					% [enemy_id, unit.sprite_id]
			)
			assert_false(
				AssetTable.portrait(unit.sprite_id, unit.sprite_color).is_empty(),
				"%s : pas de portrait pour « %s » en %s"
					% [enemy_id, unit.sprite_id, unit.sprite_color]
			)
			continue
		assert_true(
			AssetTable.has_enemy_animation(unit.sprite_id, &"idle"),
			"%s : pas d'animation d'attente pour « %s »" % [enemy_id, unit.sprite_id]
		)
		assert_true(
			AssetTable.has_enemy_animation(unit.sprite_id, &"avatar"),
			"%s : pas de portrait pour « %s »" % [enemy_id, unit.sprite_id]
		)
		# DÉCLARÉ NE VEUT PAS DIRE DESSINABLE (T12.1). Le poisson-bombe
		# déclarait bien son attente, et la fabrique la REFUSAIT : c'est
		# une image fixe et pas une bande, elle poussait une erreur et
		# rendait null. La bête s'affichait en ombre nue avec sa barre de
		# vie — et ce test-ci, qui ne demandait que la déclaration,
		# passait. On va donc jusqu'à l'image.
		var frames := SpriteFrameFactory.for_enemy(unit.sprite_id, &"idle")
		assert_not_null(
			frames, "%s : « %s » ne se fabrique pas" % [enemy_id, unit.sprite_id]
		)
		if frames != null:
			assert_gt(
				frames.get_frame_count(&"default"), 0,
				"%s : « %s » se fabrique vide" % [enemy_id, unit.sprite_id]
			)


## Un héros n'a pas de champ `sprite` dans ses données : son sprite est sa
## classe. La retombée doit donc être l'identifiant, sinon plus rien ne se
## dessine du côté joueur.
func test_un_heros_se_dessine_avec_sa_classe() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_not_null(unit, "le guerrier doit se fabriquer")
	assert_eq(unit.sprite_id, unit.class_id, "un héros se dessine avec sa classe")


## Une sauvegarde d'AVANT ce champ n'a que sa classe — et c'était le
## sprite pour tout l'acte 1, donc la retombée est juste. Un combat repris
## ne doit pas perdre ses ennemis.
func test_une_sauvegarde_conserve_le_sprite() -> void:
	var unit := Unit.from_enemy(1, &"sand_serpent", Vector2i.ZERO)
	assert_eq(Unit.from_dictionary(unit.to_dictionary()).sprite_id, &"snake")

	var ancienne := unit.to_dictionary()
	ancienne.erase("sprite")
	assert_eq(
		Unit.from_dictionary(ancienne).sprite_id, &"sand_serpent",
		"faute de mieux, une vieille sauvegarde retombe sur la classe"
	)
