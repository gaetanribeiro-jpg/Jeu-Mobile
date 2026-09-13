extends GutTest

## Le découpage des feuilles est testé sur des textures fabriquées ici même :
## le pack n'est pas versionné, et de toute façon ce qu'on veut vérifier
## c'est l'arithmétique du découpage, pas le contenu des PNG de Pixel Frog.

const FPS := 10


func before_each() -> void:
	SpriteFrameFactory.clear_cache()


## Fabrique une feuille horizontale de `frames` cadres carrés de `size` px,
## chaque cadre rempli d'une couleur différente pour pouvoir vérifier que
## le bon morceau est découpé au bon endroit.
func _make_sheet(frames: int, size: int) -> ImageTexture:
	var image := Image.create(frames * size, size, false, Image.FORMAT_RGBA8)
	for i in frames:
		image.fill_rect(
			Rect2i(i * size, 0, size, size),
			Color(float(i) / float(frames), 0.0, 0.0, 1.0)
		)
	return ImageTexture.create_from_image(image)


func test_le_nombre_d_images_suit_la_table() -> void:
	# Warrior_Idle : 8 images de 192 px, soit une feuille de 1536 px.
	var sheet := _make_sheet(8, 192)
	var resource := SpriteFrameFactory.slice(sheet, 8, 192, 192, FPS)
	assert_eq(resource.get_frame_count(&"default"), 8)


func test_les_cadres_sont_carres_et_alignes() -> void:
	var sheet := _make_sheet(6, 64)
	var resource := SpriteFrameFactory.slice(sheet, 6, 64, 64, FPS)
	for i in 6:
		var atlas: AtlasTexture = resource.get_frame_texture(&"default", i)
		assert_eq(atlas.region, Rect2(i * 64, 0, 64, 64), "cadre %d mal placé" % i)
		assert_true(atlas.filter_clip, "filter_clip évite la bave d'un pixel sur les bords")


func test_une_feuille_a_une_seule_image() -> void:
	# Cas fréquent dans la table : les rochers, les icônes, les boutons.
	var resource := SpriteFrameFactory.slice(_make_sheet(1, 64), 1, 64, 64, FPS)
	assert_eq(resource.get_frame_count(&"default"), 1)
	assert_eq(resource.get_frame_texture(&"default", 0).region, Rect2(0, 0, 64, 64))


func test_un_cadre_rectangulaire() -> void:
	# Pirate Tower_Water : 8 cadres de 128 × 192. Le modèle « cadres carrés »
	# tenait jusqu'à ce que le pack arrive sur le disque.
	var image := Image.create(8 * 128, 192, false, Image.FORMAT_RGBA8)
	var sheet := ImageTexture.create_from_image(image)
	var resource := SpriteFrameFactory.slice(sheet, 8, 128, 192, FPS)
	assert_eq(resource.get_frame_count(&"default"), 8)
	assert_eq(
		resource.get_frame_texture(&"default", 7).region,
		Rect2(7 * 128, 0, 128, 192)
	)


func test_les_grandes_feuilles() -> void:
	# Minotaur_Idle : 16 images de 320 px, soit 5120 px de large — la plus
	# grande feuille du pack.
	var resource := SpriteFrameFactory.slice(_make_sheet(16, 320), 16, 320, 320, FPS)
	assert_eq(resource.get_frame_count(&"default"), 16)
	assert_eq(
		resource.get_frame_texture(&"default", 15).region,
		Rect2(15 * 320, 0, 320, 320)
	)


func test_la_cadence_du_pack_est_appliquee() -> void:
	var resource := SpriteFrameFactory.slice(_make_sheet(4, 64), 4, 64, 64, FPS)
	assert_eq(resource.get_animation_speed(&"default"), 10.0, "le pack est à 10 fps")
	assert_true(resource.get_animation_loop(&"default"))


func test_un_decoupage_absurde_ne_plante_pas() -> void:
	var resource := SpriteFrameFactory.slice(_make_sheet(4, 64), 0, 64, 64, FPS)
	assert_eq(resource.get_frame_count(&"default"), 0)
	assert_push_error("découpage impossible")


func test_une_texture_nulle_ne_plante_pas() -> void:
	var resource := SpriteFrameFactory.slice(null, 4, 64, 64, FPS)
	assert_eq(resource.get_frame_count(&"default"), 0)
	assert_push_error("découpage impossible")


## UNE IMAGE FIXE EST UNE ANIMATION D'UNE SEULE IMAGE (T12.1), et c'est un
## RENVERSEMENT de contrat assumé.
##
## La fabrique refusait tout ce qui n'était pas une bande, en poussant une
## erreur. Le poisson-bombe de l'acte 3 est le premier ennemi du pack dont
## l'attente soit une image fixe : la vue n'obtenait aucune image et la
## bête s'affichait en OMBRE NUE, avec sa barre de vie et rien dessous.
## Refuser une image fixe n'a jamais protégé de rien — ça a seulement fait
## disparaître un ennemi.
func test_une_image_fixe_donne_une_animation_d_une_seule_image() -> void:
	var resource := SpriteFrameFactory.for_enemy(&"bomb_fish", &"idle")
	assert_not_null(resource, "une image fixe doit se fabriquer")
	if resource != null:
		assert_eq(
			resource.get_frame_count(&"default"), 1,
			"une image fixe fait UNE image, pas zéro et pas plusieurs"
		)


func test_un_asset_absent_renvoie_null_sans_planter() -> void:
	# Le pack n'est pas versionné : demander une unité alors qu'il n'est pas
	# installé doit donner null et une erreur lisible, pas un crash.
	assert_null(SpriteFrameFactory.for_unit(&"dragon", &"idle", "Blue"))
	assert_push_error("unité inconnue")
