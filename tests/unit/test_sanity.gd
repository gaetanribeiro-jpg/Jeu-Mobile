extends GutTest

## Test de fumée : vérifie que la chaîne de test tourne réellement.
## S'il échoue, ce n'est pas le jeu qui est cassé, c'est l'outillage.


func test_gut_est_branche() -> void:
	assert_true(true, "GUT exécute bien les tests")


func test_le_projet_est_en_paysage() -> void:
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_gt(width, height, "la résolution de référence doit être en paysage")


func test_le_filtrage_est_nearest() -> void:
	# 0 = Nearest. Un pixel art filtré en linéaire devient une bouillie.
	var filter: int = ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"
	)
	assert_eq(filter, 0, "le filtrage de texture par défaut doit être Nearest")


func test_les_autoloads_existent() -> void:
	for name_ in ["EventBus", "GameState", "SaveManager", "AudioManager"]:
		assert_true(
			ProjectSettings.has_setting("autoload/%s" % name_),
			"l'autoload %s doit être déclaré" % name_
		)
