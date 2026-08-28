extends GutTest

## La table d'assets est la seule source de chemins du projet. Si elle est
## incohérente, tout le rendu l'est. Ces tests portent sur la table elle-même,
## pas sur les fichiers : le pack n'est pas versionné, donc rien ici ne
## suppose qu'un PNG existe sur le disque. La vérification des fichiers
## réels est le travail de `tools/verify_assets.gd`.


func before_each() -> void:
	AssetTable.reload()


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
	assert_eq(entry["frames"], 8)
	assert_eq(entry["frame"], 192)


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
	assert_eq(entry["frames"], 5)


func test_chemin_d_un_batiment() -> void:
	var entry := AssetTable.building(&"castle", "Red")
	assert_eq(
		entry["path"],
		"res://assets/tiny_swords/free/Buildings/Red Buildings/Castle.png"
	)
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
	for entry: Dictionary in entries:
		assert_true(
			entry["path"].begins_with("res://assets/tiny_swords/"),
			"chemin hors du pack : %s" % entry["path"]
		)
		assert_false(entry["path"].contains("{"), "gabarit non substitué : %s" % entry["path"])
		if entry.has("frames"):
			assert_gt(entry["frames"], 0, "%s : nombre d'images nul" % entry["id"])
			assert_gt(entry["frame"], 0, "%s : cadre de taille nulle" % entry["id"])


func test_toutes_les_couleurs_produisent_un_chemin_distinct() -> void:
	var seen := {}
	for color: String in AssetTable.colors():
		var path: String = AssetTable.unit_animation(&"archer", &"shoot", color)["path"]
		assert_false(seen.has(path), "deux couleurs pointent sur %s" % path)
		seen[path] = true
