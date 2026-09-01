extends GutTest

## La table d'assets est la seule source de chemins du projet. Si elle est
## incohérente, tout le rendu l'est. Ces tests portent sur la table elle-même,
## pas sur les fichiers : le pack n'est pas versionné, donc rien ici ne
## suppose qu'un PNG existe sur le disque. La vérification des fichiers
## réels est le travail de `tools/verify_assets.gd`.


func before_each() -> void:
	AssetTable.clear_cache()


func test_la_table_se_charge() -> void:
	assert_false(AssetTable.table().is_empty(), "data/assets.json doit se charger")


func test_les_constantes_du_pack() -> void:
	assert_eq(AssetTable.tile_size(), 64, "les tuiles Tiny Swords font 64 px")
	assert_eq(AssetTable.fps(), 10, "les animations du pack sont à 10 fps")
	assert_eq(AssetTable.colors().size(), 5, "cinq couleurs de faction")


func test_chemin_d_une_animation_d_unite() -> void:
	var entry := AssetTable.unit_animation(&"warrior", &"idle", "Blue")
	assert_eq(
		entry["path"],
		"res://assets/tiny_swords/free/Units/Blue Units/Warrior/Warrior_Idle.png"
	)
	assert_eq(entry["kind"], AssetTable.KIND_STRIP)
	assert_eq(entry["frames"], 8)
	assert_eq(entry["frame_w"], 192)
	assert_eq(entry["frame_h"], 192)


func test_le_dossier_de_classe_n_est_pas_duplique() -> void:
	# Le piège du fichier d'origine : path_template et le champ "file"
	# portaient tous les deux le dossier de la classe.
	for unit_id: String in AssetTable.table()["units"].keys():
		var animations: Dictionary = AssetTable.table()["units"][unit_id]["animations"]
		var first: String = animations.keys()[0]
		var path: String = AssetTable.unit_animation(unit_id, first, "Blue")["path"]
		var segments := path.split("/")
		for i in range(1, segments.size()):
			assert_ne(
				segments[i], segments[i - 1],
				"segment répété dans %s" % path
			)


func test_chemin_d_une_animation_d_ennemi() -> void:
	var entry := AssetTable.enemy_animation(&"troll", &"windup")
	assert_eq(entry["path"], "res://assets/tiny_swords/enemy/Troll/Troll_Windup.png")
	assert_eq(entry["kind"], AssetTable.KIND_STRIP)
	assert_eq(entry["frames"], 5)
	assert_eq(entry["frame_w"], 384)


func test_chemin_d_un_batiment() -> void:
	var entry := AssetTable.building(&"castle", "Red")
	assert_eq(
		entry["path"],
		"res://assets/tiny_swords/free/Buildings/Red Buildings/Castle.png"
	)
	assert_eq(entry["kind"], AssetTable.KIND_IMAGE)
	assert_eq(entry["w"], 320)
	assert_eq(entry["h"], 256)


func test_les_categories_simples() -> void:
	assert_eq(
		AssetTable.sprite(&"terrain", &"water_foam")["path"],
		"res://assets/tiny_swords/free/Terrain/Tileset/Water Foam.png"
	)
	# La catégorie "extra" vient du pack ennemi, pas du pack gratuit.
	assert_eq(
		AssetTable.sprite(&"extra", &"cave_cave_idle")["path"],
		"res://assets/tiny_swords/enemy/Extra/Cave/Cave_Idle.png"
	)


func test_une_unite_inconnue_ne_plante_pas() -> void:
	# On veut un dictionnaire vide ET une erreur nommée, jamais un crash :
	# le pack n'est pas versionné, une faute de frappe doit se voir tout de
	# suite dans la console au lieu de faire tomber la scène.
	assert_eq(AssetTable.unit_animation(&"dragon", &"idle", "Blue"), {})
	assert_push_error("unité inconnue")


func test_une_animation_inconnue_ne_plante_pas() -> void:
	assert_eq(AssetTable.unit_animation(&"warrior", &"voler", "Blue"), {})
	assert_push_error("animation")


func test_une_couleur_inconnue_ne_plante_pas() -> void:
	assert_eq(AssetTable.unit_animation(&"warrior", &"idle", "Vert"), {})
	assert_push_error("couleur inconnue")


func test_un_ennemi_inconnu_ne_plante_pas() -> void:
	assert_eq(AssetTable.enemy_animation(&"licorne", &"idle"), {})
	assert_push_error("ennemi inconnu")


func test_un_batiment_inconnu_ne_plante_pas() -> void:
	assert_eq(AssetTable.building(&"cathedrale", "Blue"), {})
	assert_push_error("bâtiment inconnu")


func test_une_cle_inconnue_ne_plante_pas() -> void:
	assert_eq(AssetTable.sprite(&"terrain", &"lave"), {})
	assert_push_error("lave")


func test_toutes_les_entrees_sont_coherentes() -> void:
	var entries := AssetTable.all_entries()
	assert_gt(entries.size(), 500, "la table doit couvrir tout le pack")
	var kinds := [AssetTable.KIND_IMAGE, AssetTable.KIND_STRIP, AssetTable.KIND_ATLAS]
	# LES RACINES SONT LUES DANS LA TABLE, pas écrites ici. Il y en a deux
	# depuis que les widgets Kenney (CC0, versionnés) complètent ce que
	# Tiny Swords ne dessine pas ; en coder une seule en dur revenait à
	# faire échouer le test à chaque nouvelle origine, ce qui n'est pas ce
	# qu'il vérifie.
	var roots := PackedStringArray()
	for key: String in AssetTable.meta().keys():
		if key.begins_with("root_"):
			roots.append("res://" + String(AssetTable.meta()[key]))
	assert_gt(roots.size(), 0, "aucune racine déclarée")

	for entry: Dictionary in entries:
		var inside := false
		for root: String in roots:
			if String(entry["path"]).begins_with(root):
				inside = true
				break
		assert_true(inside, "chemin hors des racines déclarées : %s" % entry["path"])
		assert_false(entry["path"].contains("{"), "gabarit non substitué : %s" % entry["path"])
		assert_true(kinds.has(entry["kind"]), "%s : kind inconnu « %s »" % [entry["id"], entry["kind"]])
		var size := AssetTable.pixel_size(entry)
		assert_gt(size.x, 0, "%s : largeur nulle" % entry["id"])
		assert_gt(size.y, 0, "%s : hauteur nulle" % entry["id"])


func test_les_cadres_ne_sont_pas_tous_carres() -> void:
	# Le piège qui a tenu jusqu'à ce que le pack soit sur le disque : la
	# table supposait des cadres carrés. La tour pirate sur l'eau est une
	# animation de 8 cadres de 128 × 192.
	var entry := AssetTable.sprite(&"extra", &"pirate_tower_pirate_tower_water")
	assert_eq(entry["kind"], AssetTable.KIND_STRIP)
	assert_eq(entry["frames"], 8)
	assert_eq(entry["frame_w"], 128)
	assert_eq(entry["frame_h"], 192)
	assert_eq(AssetTable.pixel_size(entry), Vector2i(1024, 192))


func test_les_tilesets_sont_des_atlas() -> void:
	# 5 variantes de couleur, 9 × 6 tuiles de 64 : les quatre saisons.
	for i in range(1, 6):
		var entry := AssetTable.sprite(&"terrain", StringName("tilemap_color%d" % i))
		assert_eq(entry["kind"], AssetTable.KIND_ATLAS, "tilemap_color%d" % i)
		assert_eq(entry["columns"], 9)
		assert_eq(entry["rows"], 6)
		assert_eq(entry["cell_w"], AssetTable.tile_size())
		assert_eq(entry["cell_h"], AssetTable.tile_size())


func test_la_palissade_est_un_atlas_de_tuiles_64() -> void:
	var entry := AssetTable.sprite(&"extra", &"wooden_fence_wooden_fence_64x64_tile")
	assert_eq(entry["kind"], AssetTable.KIND_ATLAS)
	assert_eq(entry["columns"], 4)
	assert_eq(entry["rows"], 3)
	assert_eq(entry["cell_w"], 64)


func test_les_planches_d_ui_sont_signalees_comme_telles() -> void:
	# Elles ne se découpent pas en grille régulière : leurs rectangles
	# seront relevés en P8.13. La table dit au moins qu'il faudra le faire.
	for key: StringName in [&"banner", &"woodtable", &"regularpaper", &"bigbluebutton_regular"]:
		assert_eq(AssetTable.sprite(&"ui", key).get("layout", ""), "nine_slice", String(key))
	for key: StringName in [&"bigribbons", &"smallribbons", &"swords"]:
		assert_eq(AssetTable.sprite(&"ui", key).get("layout", ""), "color_sheet", String(key))


func test_toutes_les_couleurs_produisent_un_chemin_distinct() -> void:
	var seen := {}
	for color: String in AssetTable.colors():
		var path: String = AssetTable.unit_animation(&"archer", &"shoot", color)["path"]
		assert_false(seen.has(path), "deux couleurs pointent sur %s" % path)
		seen[path] = true


func test_les_portraits_suivent_la_classe_et_la_couleur() -> void:
	# Vérifié à l'œil le 2026-08-29 en comparant chaque portrait à la
	# première image du sprite Idle correspondant : l'ordre des classes est
	# guerrier, lancier, archer, moine, pion.
	assert_eq(AssetTable.portrait(&"warrior", "Blue")["path"].get_file(), "Avatars_01.png")
	assert_eq(AssetTable.portrait(&"lancer", "Blue")["path"].get_file(), "Avatars_02.png")
	assert_eq(AssetTable.portrait(&"archer", "Blue")["path"].get_file(), "Avatars_03.png")
	assert_eq(AssetTable.portrait(&"monk", "Blue")["path"].get_file(), "Avatars_04.png")
	assert_eq(AssetTable.portrait(&"pawn", "Blue")["path"].get_file(), "Avatars_05.png")
	assert_eq(AssetTable.portrait(&"warrior", "Red")["path"].get_file(), "Avatars_06.png")
	assert_eq(AssetTable.portrait(&"pawn", "Black")["path"].get_file(), "Avatars_25.png")


func test_l_ordre_des_couleurs_des_portraits_n_est_pas_celui_du_pack() -> void:
	# Le piège : les portraits mettent Yellow avant Purple, l'inverse du
	# reste du pack. Confondre les deux donne un portrait violet à un héros
	# jaune, et personne ne le remarque avant très tard.
	assert_eq(AssetTable.portrait(&"warrior", "Yellow")["path"].get_file(), "Avatars_11.png")
	assert_eq(AssetTable.portrait(&"warrior", "Purple")["path"].get_file(), "Avatars_16.png")
	assert_ne(
		AssetTable.colors(), AssetTable.table()["portraits"]["color_order"],
		"si les deux ordres deviennent identiques, cette fonction n'a plus de raison d'être"
	)


func test_les_25_portraits_sont_tous_distincts() -> void:
	var seen := {}
	for color: String in AssetTable.table()["portraits"]["color_order"]:
		for class_id: String in AssetTable.table()["portraits"]["class_order"]:
			var path: String = AssetTable.portrait(class_id, color)["path"]
			assert_false(seen.has(path), "deux héros partagent %s" % path)
			seen[path] = true
	assert_eq(seen.size(), 25)


func test_un_portrait_introuvable_ne_plante_pas() -> void:
	assert_eq(AssetTable.portrait(&"paladin", "Blue"), {})
	assert_push_error("aucun portrait pour la classe")
