extends SceneTree

## Vérifie que le thème de l'interface tient debout.
##
##     godot --headless --path . -s tools/verify_ui.gd
##
## CE QUI SE CASSE ICI NE PLANTE PAS, ÇA S'AFFICHE EN MAGENTA — ou pire,
## ça s'affiche presque bien. Une couleur mal nommée rend du magenta au
## milieu d'un écran, une surface qui pointe sur un asset absent rend un
## rectangle plat qu'on peut prendre pour une intention, et un rôle de
## bouton oublié fait un menu où deux entrées se ressemblent.
##
## Il contrôle aussi la chose qui a coûté le plus de temps à voir : la
## GÉOMÉTRIE DES TRANCHES. Un bouton du pack est une grille 3×3 de
## morceaux séparés par du vide ; sans sa géométrie déclarée, on étire les
## trous avec le décor et le résultat est méconnaissable sans être vide.

## Éclaircissement minimal du fond par le motif, en luminance.
##
## Mesuré : à 0,03 les diagonales se lisent sans se remarquer, à 0,000
## elles n'existent pas. Le seuil est bas exprès — il refuse le motif
## ABSENT, pas le motif discret, qui est ce qu'on veut.
const MINIMUM_WEAVE_LIFT := 0.01

var _problems: Array[String] = []


func _init() -> void:
	print("Vérification du thème de l'interface…\n")
	_check_palette()
	_check_typography()
	_check_metrics()
	_check_surfaces()
	_check_button_roles()
	_check_bars()
	_check_widgets()
	_check_weave()
	_check_glyphs()
	_check_title()
	_check_credits()
	_check_accents()

	if _problems.is_empty():
		print("\nLe thème tient debout.")
		quit(0)
		return
	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	quit(1)


func _check_palette() -> void:
	var palette: Dictionary = UiTheme.section(&"palette")
	var named := 0
	for key: Variant in palette.keys():
		if AssetTable.is_note(String(key)):
			continue
		named += 1
		var raw: Variant = palette[key]
		if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
			_problems.append("couleur « %s » : il faut au moins [r, v, b]" % key)
			continue
		for channel: Variant in raw:
			# Une seule exception admise plus bas pour les flashs, qui
			# multiplient au lieu de peindre — mais pas dans un thème
			# d'interface, où une valeur hors bornes est une faute de
			# frappe.
			if float(channel) < 0.0 or float(channel) > 1.0:
				_problems.append("couleur « %s » : %s est hors de [0, 1]" % [key, channel])
	print("palette      : %d couleurs" % named)
	if named == 0:
		_problems.append("le thème n'a aucune couleur")


func _check_typography() -> void:
	var block: Dictionary = UiTheme.section(&"typography")
	var sizes := PackedStringArray()
	for key: Variant in block.keys():
		if AssetTable.is_note(String(key)):
			continue
		var size := int(block[key])
		if size <= 0:
			_problems.append("taille de police « %s » nulle ou négative" % key)
		# Silver est une police pixel : une taille impaire tombe entre deux
		# pixels et le texte bave. Ça ne plante pas, ça se lit mal.
		if size % 2 != 0:
			_problems.append("taille de police « %s » impaire (%d)" % [key, size])
		sizes.append("%s %d" % [key, size])
	print("typographie  : %s" % ", ".join(sizes))


func _check_metrics() -> void:
	var block: Dictionary = UiTheme.section(&"metrics")
	for key: Variant in block.keys():
		if AssetTable.is_note(String(key)):
			continue
		if int(block[key]) < 0:
			_problems.append("mesure « %s » négative" % key)
	print("mesures      : %d" % block.size())


func _check_surfaces() -> void:
	for role: StringName in UiTheme.surface_roles():
		var block := UiTheme.surface(role)
		var tint := StringName(block.get("tint", ""))
		if not tint.is_empty() and not UiTheme.has_color(tint):
			_problems.append("surface « %s » : teinte « %s » absente de la palette"
				% [role, tint])
		var scale := int(block.get("scale", 1))
		if scale < 1:
			_problems.append("surface « %s » : échelle %d, il en faut au moins 1"
				% [role, scale])
		for key: String in ["asset", "pressed_asset"]:
			if not block.has(key):
				continue
			_check_sliced(role, StringName(block[key]), scale)


## Un asset découpé doit déclarer sa géométrie, et cette géométrie doit
## tomber juste dans l'image. Une tranche qui dépasse ne se voit qu'à
## l'écran, sous la forme d'un bord répété.
func _check_sliced(role: StringName, key: StringName, scale: int) -> void:
	var entry := AssetTable.sprite(&"ui", key)
	if entry.is_empty():
		_problems.append("surface « %s » : asset « %s » absent de la table"
			% [role, key])
		return
	var slice: Dictionary = entry.get("slice", {})
	if slice.is_empty():
		_problems.append("« %s » n'a pas de géométrie de tranches" % key)
		return
	var corner := int(slice.get("corner", 0))
	var middle := int(slice.get("middle", 0))
	var gap := int(slice.get("gap", 0))
	var span := corner * 2 + middle + gap * 2
	var width := int(entry.get("w", AssetTable.pixel_size(entry).x))
	if span != width:
		_problems.append(
			"« %s » : les tranches couvrent %d px pour une image de %d"
				% [key, span, width]
		)
	# Le coin réduit doit rester un nombre entier de pixels, sinon la
	# bordure tombe entre deux et bave — c'est tout l'intérêt d'imposer
	# une échelle entière.
	if corner % maxi(scale, 1) != 0:
		_problems.append("« %s » : coin de %d px indivisible par l'échelle %d"
			% [key, corner, scale])


func _check_button_roles() -> void:
	var roles := UiTheme.button_roles()
	var seen := {}
	var line := PackedStringArray()
	for role: StringName in roles:
		var tint := UiTheme.button_tint(role)
		# DEUX RÔLES DE MÊME COULEUR NE SONT PAS DEUX RÔLES. Le pack ne
		# livre que du bleu et du rouge ; tout l'intérêt de la teinte est
		# qu'un menu cesse de se lire uniquement au texte.
		var key := tint.to_html(false)
		if seen.has(key):
			_problems.append("les rôles « %s » et « %s » ont la même couleur"
				% [seen[key], role])
		seen[key] = role
		line.append("%s %s" % [role, key])
	print("boutons      : %s" % ", ".join(line))
	if roles.size() < 3:
		_problems.append("moins de trois rôles de bouton : la teinte ne sert à rien")


func _check_bars() -> void:
	var block := UiTheme.bars()
	if block.is_empty():
		_problems.append("aucune jauge déclarée")
		return
	var base := AssetTable.sprite(&"ui", StringName(block.get("base_asset", "")))
	if base.is_empty():
		_problems.append("jauge : l'auge est absente de la table")
		return
	var groove: Dictionary = base.get("groove", {})
	if groove.is_empty():
		_problems.append("jauge : l'auge n'a pas de rainure déclarée")
		return
	var scale := maxi(int(block.get("scale", 1)), 1)
	var height := int(base.get("frame_h", base.get("h", 0)))
	var edges := int(groove.get("top", 0)) + int(groove.get("bottom", 0))
	if edges >= height:
		_problems.append("jauge : la rainure ne laisse aucune place au remplissage")
	if AssetTable.sprite(&"ui", StringName(block.get("fill_asset", ""))).is_empty():
		_problems.append("jauge : le remplissage est absent de la table")
	print("jauges       : auge de %d px, rainure %d en haut %d en bas, échelle %d"
		% [height, int(groove.get("top", 0)), int(groove.get("bottom", 0)), scale])


## Les widgets que Tiny Swords ne dessine pas, pris chez Kenney.
##
## Ils sont dans le dépôt (CC0), donc leur absence est un vrai défaut et
## pas un poste mal installé — contrairement à tout le reste des assets.
func _check_widgets() -> void:
	var block := UiTheme.widgets()
	if block.is_empty():
		_problems.append("aucun widget déclaré : les barres de défilement "
			+ "resteront celles de Godot")
		return

	var scrollbar := UiTheme.widget(&"scrollbar")
	if scrollbar.is_empty():
		_problems.append("pas de barre de défilement déclarée")
	else:
		var entry := AssetTable.sprite(
			&"widgets", StringName(scrollbar.get("asset", ""))
		)
		if entry.is_empty():
			_problems.append("barre de défilement : asset absent de la table")
		else:
			var slice: Dictionary = entry.get("slice", {})
			var span := (int(slice.get("corner", 0)) * 2 + int(slice.get("middle", 0))
				+ int(slice.get("gap", 0)) * 2)
			# Une barre de défilement se découpe EN HAUTEUR : c'est sa
			# hauteur que les tranches doivent couvrir, pas sa largeur.
			if span != int(entry.get("h", 0)):
				_problems.append(
					"barre de défilement : les tranches couvrent %d px pour une "
					% span + "hauteur de %d" % int(entry.get("h", 0))
				)
		var tint := StringName(scrollbar.get("tint", ""))
		if not tint.is_empty() and not UiTheme.has_color(tint):
			_problems.append("barre de défilement : teinte « %s » inconnue" % tint)

	var checkbox := UiTheme.widget(&"checkbox")
	if checkbox.is_empty():
		_problems.append("pas de case à cocher déclarée")
	else:
		for key: String in ["empty", "checked"]:
			var entry := AssetTable.sprite(
				&"widgets", StringName(checkbox.get(key, ""))
			)
			if entry.is_empty():
				_problems.append("case à cocher « %s » absente de la table" % key)

	# La largeur de la barre décide de son épaisseur à l'écran : sans
	# elle, Godot la réduit à zéro et la barre disparaît sans un mot.
	if UiTheme.metric(&"scrollbar_width") <= 0:
		_problems.append("largeur de barre de défilement nulle : elle sera invisible")

	print("widgets      : %d déclarés, largeur de barre %d"
		% [block.size() - 1, UiTheme.metric(&"scrollbar_width")])


## Le motif du fond (T9.8).
##
## DEUX FAÇONS DE LE RATER, ET J'AI TROUVÉ LES DEUX À L'ŒIL AVANT DE LES
## MESURER. Ni l'une ni l'autre ne pousse la moindre erreur : un fond mal
## réglé s'affiche, simplement il ne fait pas son travail.
##
## - **Trop discret, il n'existe pas.** Le motif de Kenney est noir — il
##   est fait pour ombrer du clair — et son alpha plafonne à 51/255 ;
##   teinté d'or sur un fond presque noir, il ne bougeait le fond que
##   d'UN niveau sur 255. `UiSkin` le repeint donc en blanc, et la teinte
##   du thème doit rester assez haute pour qu'on voie quelque chose.
## - **Trop marqué, il passe DEVANT.** À l'inverse, une crête plus claire
##   que le panneau le plus sombre inverse la hiérarchie : le fond
##   devient plus lumineux que ce qu'on pose dessus, et un nœud de
##   compétence désactivé s'y noie.
##
## Ce contrôle borne la teinte entre ces deux fautes, en calculant la
## crête réelle — l'alpha du fichier MULTIPLIÉ par celui du thème.
## Les couleurs de classe et de région (T11.6).
##
## « JE NE VEUX PAS DE MENUS MOCHES TOUS GRIS. » Six régions dans six
## boîtes identiques, quatre héros dans quatre lignes identiques : il faut
## LIRE pour savoir ce qu'on regarde. Une teinte par classe et par région
## rend la liste comptable d'un coup d'œil — et sur un téléphone, où l'on
## parcourt au pouce, ce n'est pas de la décoration.
##
## CE CONTRÔLE EXISTE PARCE QUE L'OUBLI EST MUET : une classe sans teinte
## déclarée retombe sur `stone`, et on obtient exactement la liste grise
## qu'on essayait d'éviter, sans qu'aucune erreur ne le dise.
func _check_accents() -> void:
	var seen := PackedStringArray()
	for class_id: StringName in Unit.hero_class_ids():
		var accent := Unit.class_accent(class_id)
		seen.append("%s→%s" % [class_id, accent])
		if not UiTheme.has_color(accent):
			_problems.append(
				"la classe « %s » veut la couleur « %s », absente de la palette"
				% [class_id, accent]
			)
	print("classes     : %s" % ", ".join(seen))

	# DEUX RÉGIONS DE LA MÊME COULEUR NE SE DISTINGUENT PAS, et c'est
	# précisément le défaut qu'on répare : la teinte doit être unique,
	# sinon autant ne pas en avoir.
	var taken := {}
	var listed := PackedStringArray()
	for region_id: StringName in Region.ids():
		var accent := Region.accent_of(region_id)
		listed.append("%s→%s" % [region_id, accent])
		if not UiTheme.has_color(accent):
			_problems.append(
				"la région « %s » veut la couleur « %s », absente de la palette"
				% [region_id, accent]
			)
			continue
		if taken.has(accent):
			_problems.append(
				"« %s » et « %s » portent la même couleur « %s »"
				% [taken[accent], region_id, accent]
			)
		taken[accent] = region_id
	print("régions     : %s" % ", ".join(listed))

	# LE SOL EST UNE AUTRE COULEUR QUE L'ACCENT (T11.8), et il a le droit
	# d'être vide : les Terres Vertes se jouent sur l'herbe que le pack a
	# dessinée. Ce qu'on refuse, c'est une couleur INVENTÉE — elle
	# retomberait sur du noir et le plateau deviendrait illisible, sans
	# qu'aucune erreur ne le dise.
	var grounds := PackedStringArray()
	for region_id: StringName in Region.ids():
		var ground := Region.ground_of(region_id)
		if ground.is_empty():
			continue
		grounds.append("%s→%s" % [region_id, ground])
		if not UiTheme.has_color(ground):
			_problems.append(
				"le sol de « %s » veut la couleur « %s », absente de la palette"
				% [region_id, ground]
			)
	print("sols        : %s" % (", ".join(grounds) if not grounds.is_empty() else "aucun"))


## L'écran de titre (T11.3) et son décor.
##
## IL A ANNONCÉ « ÉCRAN DE TEST PROVISOIRE » PENDANT TROIS MOIS, et rien
## ne s'en plaignait : un écran de titre raté n'échoue aucun test, il
## accueille simplement mal. Ce contrôle vérifie ce qu'un test unitaire ne
## dit pas — que le décor a de quoi vivre.
func _check_title() -> void:
	var rows := TitleSet.island_rows()
	if rows.is_empty():
		_problems.append("l'écran de titre n'a pas d'île")
		return
	var board := CombatBoard.from_rows(rows)
	if board == null:
		_problems.append("l'île du titre n'est pas un plateau valide")
		return

	var props := TitleSet.props().size()
	var actors := TitleSet.actors().size()
	var clouds: Array = TitleSet.clouds().get("keys", [])
	print("écran de titre: île %d × %d · %d décors · %d personnages · %d nuages"
		% [board.grid.width, board.grid.height, props, actors, clouds.size()])

	# UN DÉCOR IMMOBILE N'EST PAS UN ÉCRAN DE TITRE. C'est la seule chose
	# que Gaetan a demandée en toutes lettres — « un véritable écran titre
	# DYNAMIQUE » — et c'est celle qu'un test de données ne saurait pas
	# juger : ce qui bouge ici, ce sont les nuages et les personnages.
	if clouds.size() < 2:
		_problems.append("moins de deux nuages : le ciel ne bougera pas")
	if actors <= 0:
		_problems.append("aucun personnage sur le titre")
	if props <= 0:
		_problems.append("une île nue : ni château ni arbre")


## Les crédits, et la seule obligation juridique du projet.
##
## CC BY 3.0 EXIGE L'ATTRIBUTION. Ce n'est ni une politesse ni un style :
## c'est la condition à laquelle les dix-huit icônes de compétences
## peuvent être utilisées. La perdre au détour d'un remaniement d'écran
## serait une violation de licence, et rien d'autre ne le dirait.
func _check_credits() -> void:
	var entries := CreditsTable.entries()
	if entries.is_empty():
		_problems.append("aucun crédit déclaré : l'attribution CC BY manque")
		return

	var attributed := false
	for entry: Variant in entries:
		var block := entry as Dictionary
		for field: String in ["name", "author", "licence_key"]:
			if String(block.get(field, "")).is_empty():
				_problems.append(
					"crédit « %s » : « %s » manque" % [block.get("name", "?"), field]
				)
		var licence := String(block.get("licence_key", ""))
		if not licence.is_empty() and TranslationServer.translate(licence) == licence:
			_problems.append("crédits : la clé « %s » n'est pas traduite" % licence)
		if licence == "CREDITS_LICENCE_CCBY":
			attributed = true
			for author: String in ["Lorc", "Delapouite", "Caro Asercion"]:
				if not String(block.get("author", "")).contains(author):
					_problems.append("crédits : « %s » n'est plus nommé" % author)

	for section: Variant in CreditsTable.sections():
		var key := String((section as Dictionary).get("title_key", ""))
		if not key.is_empty() and TranslationServer.translate(key) == key:
			_problems.append("crédits : la clé « %s » n'est pas traduite" % key)

	if not attributed:
		_problems.append("crédits : l'entrée CC BY a disparu — c'est une obligation")
	print("crédits     : %d entrées, attribution CC BY %s"
		% [entries.size(), "présente" if attributed else "ABSENTE"])


func _check_weave() -> void:
	var entry := AssetTable.sprite(&"widgets", &"weave")
	if entry.is_empty():
		_problems.append("pas de motif de fond déclaré : l'interface restera "
			+ "sur un aplat noir")
		return
	var path := String(entry.get("path", ""))
	if not ResourceLoader.exists(path):
		_problems.append("motif de fond : %s absent du dépôt" % path)
		return
	var texture: Texture2D = load(path)
	var image := texture.get_image() if texture != null else null
	if image == null:
		_problems.append("motif de fond : %s illisible" % path)
		return
	if image.is_compressed():
		image.decompress()

	var peak := 0.0
	for y in image.get_height():
		for x in image.get_width():
			peak = maxf(peak, image.get_pixel(x, y).a)
	if peak <= 0.0:
		_problems.append("motif de fond : entièrement transparent")
		return

	var tint := UiTheme.color(&"weave")
	var ground := UiTheme.color(&"backdrop")
	var opacity := peak * tint.a
	var crest := ground.lerp(Color(tint.r, tint.g, tint.b), opacity)
	var lift := crest.get_luminance() - ground.get_luminance()
	if lift < MINIMUM_WEAVE_LIFT:
		_problems.append(
			"motif de fond : il n'éclaircit le fond que de %.3f — invisible. "
			% lift + "L'alpha du fichier (%.2f) et celui du thème (%.2f) se "
			% [peak, tint.a] + "MULTIPLIENT."
		)
	var floor_ := minf(
		UiTheme.color(&"panel_fill").get_luminance(),
		UiTheme.color(&"panel_deep").get_luminance()
	)
	if crest.get_luminance() >= floor_:
		_problems.append(
			"motif de fond : sa crête (%.3f) atteint le panneau le plus sombre "
			% crest.get_luminance() + "(%.3f). Le fond passerait devant." % floor_
		)
	print("motif de fond: crête %.3f, plancher des panneaux %.3f"
		% [crest.get_luminance(), floor_])


## Les glyphes de compétences (§ 48).
##
## LE SEUL MÉLANGE VECTORIEL / PIXEL DU JEU, et il ne tient qu'au seuil
## d'alpha : sans lui la silhouette reste lisse et jure avec le pack. Un
## seuil à zéro ou à un rendrait le glyphe respectivement flou ou vide,
## et les deux se voient à l'écran sans rien casser ailleurs.
func _check_glyphs() -> void:
	var block := UiTheme.glyphs()
	if block.is_empty():
		_problems.append("aucun glyphe déclaré : la barre d'action restera en texte")
		return

	var threshold := float(block.get("alpha_threshold", -1.0))
	if threshold <= 0.0 or threshold >= 1.0:
		_problems.append("seuil d'alpha à %.2f : il doit être strictement entre 0 et 1"
			% threshold)
	if int(block.get("size", 0)) <= 0:
		_problems.append("taille de glyphe nulle")

	# CHAQUE COMPÉTENCE DU JOUEUR DOIT AVOIR SON GLYPHE. Une seule qui
	# manque et la barre mélange icônes et texte nu, ce qui se lit plus
	# mal que du texte partout.
	var missing := PackedStringArray()
	var covered := 0
	for ability_id: StringName in Ability.ids():
		var ability := Ability.of(ability_id)
		if ability == null:
			continue
		if not Unit.hero_class_ids().has(ability.class_id) and not ability.is_carried():
			continue
		if AssetTable.has(&"glyphs", ability_id):
			covered += 1
		else:
			missing.append(String(ability_id))
	for id: String in missing:
		_problems.append("« %s » n'a pas de glyphe" % id)

	print("glyphes      : %d compétences couvertes, %d px, seuil %.2f"
		% [covered, int(block.get("size", 0)), threshold])
