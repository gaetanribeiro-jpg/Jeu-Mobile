extends GutTest

## Éprouve la chaîne complète sur les VRAIS fichiers du pack : table →
## chemin → texture chargée → SpriteFrames découpé.
##
## Les tests unitaires travaillent sur des images fabriquées en mémoire,
## parce que le pack n'est pas versionné. Ceux-ci ont besoin du pack sur
## le disque, et se déclarent ignorés proprement s'il est absent — un
## poste sans le pack ne doit pas voir une suite rouge, il doit voir que
## ces tests-là n'ont pas tourné.


func _pack_present() -> bool:
	return FileAccess.file_exists(
		AssetTable.unit_animation(&"warrior", &"idle", "Blue").get("path", "")
	)


func before_each() -> void:
	SpriteFrameFactory.clear_cache()


func test_le_pack_est_installe() -> void:
	if not _pack_present():
		pending("Pack Tiny Swords absent — copier le pack dans assets/tiny_swords/")
		return
	assert_true(true)


func test_toutes_les_animations_de_heros_se_decoupent() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	# Les 4 classes jouables, dans les 5 couleurs, toutes animations.
	for class_id: StringName in [&"warrior", &"archer", &"lancer", &"monk"]:
		var animations: Dictionary = AssetTable.table()["units"][String(class_id)]["animations"]
		for animation: String in animations.keys():
			for color: String in AssetTable.colors():
				var entry := AssetTable.unit_animation(class_id, animation, color)
				var frames := SpriteFrameFactory.for_unit(class_id, animation, color)
				assert_not_null(frames, "%s.%s.%s" % [class_id, animation, color])
				if frames != null:
					assert_eq(
						frames.get_frame_count(&"default"), entry["frames"],
						"%s.%s.%s : nombre d'images" % [class_id, animation, color]
					)


func test_le_troll_a_bien_ses_trois_temps() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	# Windup → Attack → Recovery, plus sa mort : le seul ennemi construit
	# comme un boss sur trois tours (§ 4.4). S'il manque un morceau, tout
	# le dessin du gardien tombe.
	for animation: StringName in [&"windup", &"attack", &"recovery", &"idle", &"walk"]:
		var frames := SpriteFrameFactory.for_enemy(&"troll", animation)
		assert_not_null(frames, "troll.%s" % animation)
		if frames != null:
			assert_gt(frames.get_frame_count(&"default"), 0)
	# La seule vraie animation de mort du pack.
	assert_not_null(SpriteFrameFactory.for_sprite(&"extra", &"troll_dead_troll_dead"))


func test_les_poses_de_garde_qui_dessinent_le_telegraphe() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	# § 4.2 : le télégraphe est une posture avant d'être une icône.
	for key: StringName in [
		&"minotaur_guard_minotaur_guard", &"panda_guard_panda_guard",
		&"skull_guard_skull_guard", &"turtle_guard_turtle_guard_in",
		&"turtle_guard_turtle_guard_out",
	]:
		assert_not_null(SpriteFrameFactory.for_sprite(&"extra", key), String(key))
	assert_not_null(SpriteFrameFactory.for_unit(&"warrior", &"guard", "Blue"))


func test_les_cinq_saisons_du_tileset() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	# Les 5 variantes de couleur donnent les 4 saisons gratuitement (§ 12).
	for i in range(1, 6):
		var entry := AssetTable.sprite(&"terrain", StringName("tilemap_color%d" % i))
		var texture: Texture2D = load(entry["path"])
		assert_not_null(texture, "tilemap_color%d" % i)
		if texture != null:
			assert_eq(texture.get_size(), Vector2(576, 384), "9 × 6 tuiles de 64")


func test_les_25_portraits_se_chargent() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	for color: String in AssetTable.table()["portraits"]["color_order"]:
		for class_id: String in AssetTable.table()["portraits"]["class_order"]:
			var entry := AssetTable.portrait(class_id, color)
			var texture: Texture2D = load(entry["path"])
			assert_not_null(texture, "portrait %s %s" % [class_id, color])
			if texture != null:
				assert_eq(texture.get_size(), Vector2(256, 256))


func test_la_tour_pirate_sur_l_eau_est_bien_une_animation() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	# Le cas qui a fait tomber le modèle « cadres carrés ».
	var frames := SpriteFrameFactory.for_sprite(&"extra", &"pirate_tower_pirate_tower_water")
	assert_not_null(frames)
	if frames != null:
		assert_eq(frames.get_frame_count(&"default"), 8)
		assert_eq(frames.get_frame_texture(&"default", 0).region, Rect2(0, 0, 128, 192))


func test_les_particules_du_pack() -> void:
	if not _pack_present():
		pending("Pack absent")
		return
	# 2 poussières, 3 feux, 2 explosions, 1 gerbe d'eau — l'effet de mort
	# universel du § 13.4bis repose entièrement dessus.
	for key: StringName in [
		&"dust_01", &"dust_02", &"fire_01", &"fire_02", &"fire_03",
		&"explosion_01", &"explosion_02", &"water_splash",
	]:
		var frames := SpriteFrameFactory.for_sprite(&"fx", key)
		assert_not_null(frames, String(key))
		if frames != null:
			assert_gt(frames.get_frame_count(&"default"), 1, "%s doit être animé" % key)
