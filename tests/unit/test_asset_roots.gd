extends GutTest

## Une bête peut venir d'ailleurs que du pack, et son dossier se versionne.
##
## Tiny Swords interdit la redistribution : ses deux dossiers sont dans le
## `.gitignore`, et chaque poste recopie le pack à la main. Un dessin qui
## n'en vient pas n'a aucune raison de partager ce sort — sans le champ
## `root`, la seule façon d'ajouter une bête aurait été de la poser dans un
## dossier ignoré, donc de la perdre au prochain clone.
##
## C'est le quatrième régime d'assets du projet, après Tiny Swords
## (interdit de redistribuer), Kenney (CC0) et game-icons (CC BY).


func before_each() -> void:
	AssetTable.clear_cache()


## Sans le champ, rien ne bouge : les vingt et une bêtes du pack continuent
## de se résoudre sous `root_enemy`. C'est la moitié qu'une régression
## casserait en silence.
func test_une_bete_sans_root_reste_dans_le_pack() -> void:
	var found := AssetTable.enemy_animation(&"skull", &"idle")
	assert_false(found.is_empty(), "le crâne doit se résoudre")
	assert_string_contains(
		String(found.get("path", "")), AssetTable.root_of(&"enemies"),
		"une bête sans « root » vit dans le dossier du pack"
	)


func test_une_bete_avec_root_sort_du_pack() -> void:
	var found := AssetTable.enemy_animation(&"vampire", &"idle")
	assert_false(found.is_empty(), "le vampire doit se résoudre")
	var path := String(found.get("path", ""))
	assert_string_contains(
		path, AssetTable.root_of(&"pixellab"),
		"le vampire vit hors du pack"
	)
	assert_false(
		path.contains(AssetTable.root_of(&"enemies")),
		"et surtout pas dedans : ce dossier n'est pas versionné"
	)


## LE FICHIER EXISTE VRAIMENT, ce qu'aucune assertion de chemin ne dit.
## Un dossier versionné se distingue justement en ceci qu'un fichier
## manquant y est un défaut, pas une installation à faire.
func test_les_feuilles_du_vampire_sont_dans_le_depot() -> void:
	for animation: StringName in [&"idle", &"run", &"attack", &"avatar"]:
		var found := AssetTable.enemy_animation(&"vampire", animation)
		assert_false(found.is_empty(), "vampire : « %s » déclarée" % animation)
		assert_file_exists(String(found.get("path", "")))


## ET ELLE SE FABRIQUE. La leçon de T12.1 : le test ne demandait que la
## DÉCLARATION, et sept bêtes se sont affichées en ombre nue sans qu'une
## seule erreur soit poussée. On va donc jusqu'à la fabrique.
func test_le_vampire_se_fabrique() -> void:
	for animation: StringName in [&"idle", &"run", &"attack"]:
		var frames := SpriteFrameFactory.for_enemy(&"vampire", animation)
		assert_not_null(frames, "vampire : « %s » ne se fabrique pas" % animation)
		if frames != null:
			assert_eq(
				frames.get_frame_count(&"default"), 6,
				"vampire : « %s » doit rendre ses six images" % animation
			)
