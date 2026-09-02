extends GutTest

## Le thème de l'interface (T9.1).
##
## Ce que ces tests protègent : qu'un écran ne puisse plus décider d'une
## couleur tout seul. La règle 1 du projet — « aucune valeur chiffrée dans
## le code » — était violée dans sept fichiers d'écran, et rien ne le
## disait parce qu'une couleur en dur compile parfaitement.


func before_each() -> void:
	UiTheme.clear_cache()
	AssetTable.clear_cache()


func after_all() -> void:
	UiTheme.clear_cache()
	AssetTable.clear_cache()


func test_la_palette_rend_des_couleurs() -> void:
	var ink := UiTheme.color(&"ink")
	assert_ne(ink, UiTheme.MISSING, "« ink » doit exister")
	assert_between(ink.r, 0.0, 1.0)
	assert_between(ink.g, 0.0, 1.0)
	assert_between(ink.b, 0.0, 1.0)


func test_une_couleur_absente_se_signale_au_lieu_de_passer() -> void:
	# Le magenta se voit tout de suite ; un gris par défaut passerait pour
	# une intention, et le défaut vivrait des mois.
	var missing := UiTheme.color(&"cette_couleur_n_existe_pas")
	assert_eq(missing, UiTheme.MISSING)
	assert_push_error("couleur")


func test_les_tailles_de_police_sont_paires() -> void:
	# Silver est une police PIXEL : une taille impaire tombe entre deux
	# pixels et le texte bave. Ça ne plante pas, ça se lit mal — donc
	# personne ne le signalerait.
	for key: StringName in [&"title", &"heading", &"subheading", &"body",
			&"small", &"button", &"button_large"]:
		var size := UiTheme.font_size(key)
		assert_gt(size, 0, "« %s » doit avoir une taille" % key)
		assert_eq(size % 2, 0, "« %s » vaut %d, impair" % [key, size])


func test_chaque_surface_pointe_sur_un_asset_reel() -> void:
	for role: StringName in UiTheme.surface_roles():
		var block := UiTheme.surface(role)
		assert_false(block.is_empty(), "surface « %s » vide" % role)
		var entry := AssetTable.sprite(&"ui", StringName(block.get("asset", "")))
		assert_false(
			entry.is_empty(), "surface « %s » : asset inconnu" % role
		)


func test_chaque_surface_declare_sa_geometrie_de_tranches() -> void:
	# SANS ELLE ON ÉTIRE LES TROUS AVEC LE DÉCOR. Un bouton du pack est une
	# grille 3×3 de morceaux séparés par 64 px de vide : donné tel quel à
	# un StyleBoxTexture, il rend une bouillie — reconnaissable comme un
	# bouton, fausse dans le détail, et donc facile à ne pas voir.
	for role: StringName in UiTheme.surface_roles():
		var block := UiTheme.surface(role)
		var entry := AssetTable.sprite(&"ui", StringName(block.get("asset", "")))
		var slice: Dictionary = entry.get("slice", {})
		assert_false(slice.is_empty(), "surface « %s » sans tranches" % role)
		var span := (int(slice.get("corner", 0)) * 2 + int(slice.get("middle", 0))
			+ int(slice.get("gap", 0)) * 2)
		assert_eq(
			span, int(entry.get("w", 0)),
			"surface « %s » : les tranches ne couvrent pas l'image" % role
		)


func test_l_echelle_d_une_surface_est_un_entier_qui_divise_le_coin() -> void:
	# Le pack est du pixel art sur grille de 64, filtré en Nearest.
	# Diviser par 2 fait tomber quatre pixels sur un ; une division
	# fractionnaire en fait tomber deux et demi, et la bordure bave.
	for role: StringName in UiTheme.surface_roles():
		var block := UiTheme.surface(role)
		var scale := int(block.get("scale", 1))
		assert_gte(scale, 1, "surface « %s » : échelle inférieure à 1" % role)
		var entry := AssetTable.sprite(&"ui", StringName(block.get("asset", "")))
		var corner := int(entry.get("slice", {}).get("corner", 0))
		assert_eq(
			corner % scale, 0,
			"surface « %s » : coin %d indivisible par %d" % [role, corner, scale]
		)


func test_six_roles_de_bouton_de_six_couleurs() -> void:
	# LE POINT DE T9.3. Le pack ne livre que du bleu et du rouge, une
	# langue « confirmer / renoncer » qui ne dit rien sur « Royaume » ou
	# « Compagnie ». Deux rôles de même couleur ne sont pas deux rôles.
	var roles := UiTheme.button_roles()
	assert_gte(roles.size(), 3, "moins de trois rôles : la teinte ne sert à rien")
	var seen := {}
	for role: StringName in roles:
		var tint := UiTheme.button_tint(role)
		assert_ne(tint, UiTheme.MISSING, "rôle « %s » sans couleur" % role)
		var key := tint.to_html(false)
		assert_false(seen.has(key), "« %s » et « %s » ont la même couleur"
			% [seen.get(key, ""), role])
		seen[key] = role


func test_la_couleur_de_vie_suit_ce_qu_il_reste() -> void:
	var full := UiTheme.health_color(1.0)
	var half := UiTheme.health_color(0.45)
	var dying := UiTheme.health_color(0.05)
	assert_ne(full, half)
	assert_ne(half, dying)
	# Verte en haut, rouge en bas : l'ordre compte plus que les teintes.
	assert_gt(full.g, full.r, "pleine vie doit tirer vers le vert")
	assert_gt(dying.r, dying.g, "à l'agonie doit tirer vers le rouge")


func test_la_jauge_declare_sa_rainure() -> void:
	var block := UiTheme.bars()
	assert_false(block.is_empty(), "aucune jauge déclarée")
	var base := AssetTable.sprite(&"ui", StringName(block.get("base_asset", "")))
	assert_false(base.is_empty(), "l'auge est absente de la table")
	var groove: Dictionary = base.get("groove", {})
	assert_false(groove.is_empty(), "l'auge n'a pas de rainure")
	# Sans rainure déclarée, le remplissage se dessine par-dessus les
	# embouts de bois et déborde de son auge.
	var height := int(base.get("frame_h", base.get("h", 0)))
	assert_lt(
		int(groove.get("top", 0)) + int(groove.get("bottom", 0)), height,
		"la rainure ne laisse aucune place au remplissage"
	)


func test_les_widgets_manquants_du_pack_sont_declares() -> void:
	# CE QUE TINY SWORDS NE DESSINE PAS. Dix `ScrollContainer` sur six
	# écrans rendaient la barre grise par défaut de Godot au milieu d'une
	# interface en bois. Ce n'est pas un oubli : le pack n'a ni barre de
	# défilement, ni case à cocher, ni poignée.
	var scrollbar := UiTheme.widget(&"scrollbar")
	assert_false(scrollbar.is_empty(), "pas de barre de défilement")
	var entry := AssetTable.sprite(
		&"widgets", StringName(scrollbar.get("asset", ""))
	)
	assert_false(entry.is_empty(), "l'asset de la barre est absent de la table")

	# Elle se découpe EN HAUTEUR — c'est une pastille verticale dont seuls
	# les bouts sont arrondis. L'inverse exact d'une jauge, et le même
	# piège si on ne le dit pas.
	var slice: Dictionary = entry.get("slice", {})
	assert_false(slice.is_empty(), "la barre n'a pas de tranches")
	var span := (int(slice.get("corner", 0)) * 2 + int(slice.get("middle", 0))
		+ int(slice.get("gap", 0)) * 2)
	assert_eq(span, int(entry.get("h", 0)), "les tranches couvrent la HAUTEUR")

	var checkbox := UiTheme.widget(&"checkbox")
	assert_false(checkbox.is_empty(), "pas de case à cocher")
	for key: String in ["empty", "checked"]:
		assert_false(
			AssetTable.sprite(&"widgets", StringName(checkbox.get(key, ""))).is_empty(),
			"case à cocher « %s » absente" % key
		)

	# Sans largeur, Godot réduit la barre à zéro et elle disparaît sans un
	# mot — vu à la capture, 68 de luminosité avant, 16 après.
	assert_gt(UiTheme.metric(&"scrollbar_width"), 0)


func test_les_widgets_kenney_sont_dans_le_depot() -> void:
	# LA DIFFÉRENCE AVEC TINY SWORDS EST LA LICENCE. Kenney est en CC0,
	# donc `assets/kenney/` est versionné : ces fichiers-là DOIVENT être
	# présents, et leur absence est un vrai défaut, pas un poste mal
	# installé. C'est le seul endroit du jeu où on peut l'affirmer.
	for key: StringName in [&"scrollbar", &"checkbox_empty", &"checkbox_checked"]:
		var entry := AssetTable.sprite(&"widgets", key)
		assert_false(entry.is_empty(), "« %s » absent de la table" % key)
		assert_true(
			FileAccess.file_exists(String(entry.get("path", ""))),
			"« %s » : fichier manquant dans le dépôt" % key
		)


func test_chaque_competence_du_joueur_a_son_glyphe() -> void:
	# UNE SEULE QUI MANQUE ET LA BARRE MÉLANGE ICÔNES ET TEXTE NU, ce qui
	# se lit plus mal que du texte partout. C'est aussi l'invariant qui
	# rattrapera l'oubli le jour où une classe gagne une compétence.
	assert_false(UiTheme.glyphs().is_empty(), "aucun glyphe déclaré")
	for ability_id: StringName in Ability.ids():
		var ability := Ability.of(ability_id)
		if ability == null:
			continue
		var mine := Unit.hero_class_ids().has(ability.class_id)
		if not mine and not ability.is_carried():
			continue
		assert_true(
			AssetTable.has(&"glyphs", ability_id),
			"« %s » n'a pas de glyphe" % ability_id
		)


func test_le_seuil_d_alpha_est_strictement_entre_zero_et_un() -> void:
	# C'EST LUI SEUL QUI REND LE MÉLANGE SUPPORTABLE. À zéro le glyphe
	# reste lisse et jure avec le pixel art ; à un il disparaît. Les deux
	# se voient à l'écran sans rien casser ailleurs, donc sans test.
	var threshold := float(UiTheme.glyphs().get("alpha_threshold", -1.0))
	assert_gt(threshold, 0.0)
	assert_lt(threshold, 1.0)
	assert_gt(int(UiTheme.glyphs().get("size", 0)), 0)


func test_les_glyphes_sont_dans_le_depot() -> void:
	# game-icons.net est en CC BY 3.0 : redistribuable, donc versionné —
	# et leur absence est un vrai défaut, pas un poste mal installé.
	var seen := 0
	for ability_id: StringName in Ability.ids():
		if not AssetTable.has(&"glyphs", ability_id):
			continue
		var entry := AssetTable.sprite(&"glyphs", ability_id)
		assert_true(
			FileAccess.file_exists(String(entry.get("path", ""))),
			"« %s » : fichier manquant" % ability_id
		)
		seen += 1
	assert_gt(seen, 10, "les glyphes doivent être là")


func test_une_categorie_sait_dire_qu_elle_ne_connait_pas_une_cle() -> void:
	# `has` est distinct de `sprite` : ici l'absence est une RÉPONSE, pas
	# une erreur. C'est ce qui permet à une compétence sans glyphe de
	# rester en texte au lieu de pousser une erreur à chaque image.
	assert_true(AssetTable.has(&"glyphs", &"fireball"))
	assert_false(AssetTable.has(&"glyphs", &"gore"), "un ennemi n'a pas de glyphe")
	assert_false(AssetTable.has(&"glyphs", &"_note"))
	assert_false(AssetTable.has(&"pas_une_categorie", &"fireball"))


func test_les_cles_de_commentaire_ne_sont_pas_des_entrees() -> void:
	# Tous les fichiers de données du projet portent des `_note`. La table
	# des assets n'y échappait que parce qu'elle n'en avait pas : en
	# ajouter une a suffi à faire tomber `all_entries()`, qui la lisait
	# comme une entrée et recevait une chaîne au lieu d'un objet.
	assert_true(AssetTable.is_note("_note"))
	assert_false(AssetTable.is_note("banner"))
	assert_true(AssetTable.sprite(&"ui", &"_slice_note").is_empty())
	for role: StringName in UiTheme.surface_roles():
		assert_false(AssetTable.is_note(String(role)), "rôle « %s »" % role)


func test_le_motif_du_fond_reste_sous_les_panneaux() -> void:
	# LA HIÉRARCHIE DU FOND, ET ELLE SE CASSE DANS LES DEUX SENS. Le
	# motif de Kenney est NOIR et son alpha plafonne à 51/255 : teinté
	# d'or sur un fond presque noir, il ne bougeait rien du tout. Monté
	# trop haut, sa crête passait AU-DESSUS du panneau le plus sombre, et
	# un nœud de compétence désactivé se noyait dans le fond.
	var entry := AssetTable.sprite(&"widgets", &"weave")
	assert_false(entry.is_empty(), "le motif de fond doit être déclaré")
	var texture: Texture2D = load(String(entry.get("path", "")))
	assert_not_null(texture, "le motif de fond est dans le dépôt (CC0)")
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var peak := 0.0
	for y in image.get_height():
		for x in image.get_width():
			peak = maxf(peak, image.get_pixel(x, y).a)
	assert_gt(peak, 0.0, "un motif entièrement transparent n'existe pas")

	# LES DEUX ALPHAS SE MULTIPLIENT : celui du fichier et celui du thème.
	var tint := UiTheme.color(&"weave")
	var ground := UiTheme.color(&"backdrop")
	var crest := ground.lerp(Color(tint.r, tint.g, tint.b), peak * tint.a)
	assert_gt(
		crest.get_luminance() - ground.get_luminance(), 0.01,
		"le motif doit se voir"
	)
	for role: StringName in [&"panel_fill", &"panel_deep"]:
		assert_lt(
			crest.get_luminance(), UiTheme.color(role).get_luminance(),
			"la crête du motif doit rester sous « %s »" % role
		)
