extends Node

## Construit l'apparence de l'interface à partir du pack (T9.1, T9.2, T9.3).
##
## POURQUOI CETTE CLASSE EXISTE. Un bouton du pack n'est PAS une image
## étirable : c'est une grille 3×3 de morceaux posés sur une toile, avec un
## espace vide de 64 px entre chacun. Donné tel quel à un
## `StyleBoxTexture`, il étirerait les trous en même temps que le décor.
## Il faut donc recomposer les neuf morceaux bord à bord — et c'est
## précisément ce qui manquait pour que ces 70 assets servent à quelque
## chose.
##
## RIEN N'EST ÉCRIT SUR LE DISQUE. Le pack n'est pas dans le dépôt
## (licence), et un dérivé du pack ne le serait pas davantage : il
## faudrait le régénérer à la main sur chaque poste, ce que personne ne
## ferait. La recomposition se fait en mémoire au démarrage — neuf copies
## de 64×64 par style, une fois.
##
## LA TEINTE EST CE QUI SORT DU BLEU ET DU ROUGE. Le pack ne livre que ces
## deux couleurs, une langue « confirmer / renoncer » qui ne suffit pas à
## un menu de sept entrées. La source est passée en NIVEAUX DE GRIS puis
## reteintée par rôle : six boutons de couleurs différentes sortent de la
## même image, et le rôle porte le sens plutôt que la couleur.
##
## PAS « Skin » : CE NOM EST DÉJÀ PRIS PAR GODOT (la peau d'un squelette).
## L'autoload se résolvait silencieusement sur la classe native, et le
## seul message était « Cannot find member "theme" in base "Skin" » — le
## même piège exactement que `reload()` contre `Script.reload()` en T7.4.
## Un nom d'autoload se vérifie avant de l'écrire.
##
## LE CODE NE DOIT JAMAIS PLANTER PARCE QU'UN ASSET MANQUE. Les assets
## Tiny Swords ne sont pas versionnés ; sans eux, `Skin` rend un thème
## plat aux couleurs du thème, et le jeu reste jouable.

## Rôle de surface → StyleBox construit. Rempli une fois au démarrage.
var _styles: Dictionary = {}

## Textures recomposées, par « clé d'asset + échelle + désaturation ».
## Deux rôles qui partagent une source ne la recomposent pas deux fois.
var _textures: Dictionary = {}

## Le thème Godot appliqué à la racine de chaque écran.
var theme: Theme = null


func _ready() -> void:
	rebuild()


## (Re)construit tout. Public pour les tests et le rechargement à chaud.
func rebuild() -> void:
	_styles.clear()
	_textures.clear()
	theme = Theme.new()
	_build_styles()
	_build_theme()


# --- Ce que les écrans demandent ------------------------------------------

## Le fond d'un panneau, prêt à poser sur un `Panel` ou un `PanelContainer`.
## `pad` impose les marges de contenu. SANS LUI, CHAQUE PANNEAU GONFLE DE
## 64 px : un `StyleBoxTexture` écarte son contenu de ses marges de
## tranches, et le papier du pack a des coins de 32 px à l'échelle 2. Quatre
## cartes de héros gagnaient 256 px de haut à elles seules et chassaient la
## barre d'action hors de l'écran — sans la moindre erreur, Godot rogne en
## silence.
func panel_style(role: StringName = &"panel", pad: int = -1) -> StyleBox:
	var base: StyleBox = _styles.get(role, null)
	if base == null:
		return _flat(UiTheme.color(&"backdrop"))
	if pad < 0:
		return base
	var key := StringName("%s|pad%d" % [role, pad])
	if _styles.has(key):
		return _styles[key]
	var tight: StyleBox = base.duplicate()
	for side: String in ["left", "right", "top", "bottom"]:
		tight.set("content_margin_%s" % side, float(pad))
	_styles[key] = tight
	return tight


## Un bouton de la couleur d'un RÔLE — « primary », « danger », « muted »…
## Jamais d'une couleur : c'est le thème qui décide à quoi ressemble un
## danger.
func button_style(role: StringName = &"default", pressed: bool = false) -> StyleBox:
	var key := StringName("button_%s_%s" % [role, "pressed" if pressed else "regular"])
	if _styles.has(key):
		return _styles[key]
	var built := _button_style(role, pressed)
	_styles[key] = built
	return built


## Habille un bouton d'un rôle, d'un coup : fond, survol, appui, et la
## couleur de texte qui va avec.
func dress_button(button: Button, role: StringName = &"default") -> void:
	# LE CADRE ORNÉ SOMBRE, ET LE RÔLE DANS LE LISERÉ. Les boutons du pack
	# — acier, or, prune — étaient justes tant que l'interface était
	# claire ; sur des panneaux sombres à liseré doré, ils faisaient deux
	# matières pour une seule interface. Le rôle porte toujours le sens,
	# mais il le porte maintenant dans la couleur du TRAIT.
	var pad := UiTheme.metric(&"button_pad")
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(
			state, framed_style(&"frame_card", &"panel_fill", role, pad)
		)
	button.add_theme_stylebox_override(
		"pressed", framed_style(&"frame_card", &"panel_deep", role, pad)
	)
	button.add_theme_stylebox_override(
		"disabled", framed_style(&"frame_card", &"panel_deep", &"stone", pad)
	)
	# TEXTE CLAIR SUR CERCLÉ DE SOMBRE. Les six teintes sont des tons
	# moyens : ni le clair ni le sombre ne passe sur toutes. Le contour
	# règle la question une fois pour toutes, et c'est ce que fait déjà le
	# HUD de combat pour les chiffres de dégâts.
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, UiTheme.color(&"ink_inverse"))
	button.add_theme_color_override(
		"font_disabled_color", UiTheme.color(&"ink_disabled")
	)
	# AUCUN CONTOUR. Sur un panneau sombre il ne sert à rien, et avec un
	# texte clair il est clair sur clair : les glyphes d'une police pixel
	# se rejoignent et le texte s'épaissit jusqu'à devenir illisible.
	button.add_theme_constant_override("outline_size", 0)

	# LE CLIC DE TOUS LES BOUTONS DU JEU TIENT ICI (T11.2). Chaque écran
	# passe déjà par `dress_button` : le brancher une fois donne sa voix à
	# l'interface entière, là où le faire écran par écran aurait garanti
	# qu'un bouton l'oublie. Un bouton DÉSACTIVÉ n'émet pas de `pressed`,
	# donc le silence du refus est gratuit.
	if not button.pressed.is_connected(_click):
		button.pressed.connect(_click)


func _click() -> void:
	AudioManager.play_cue(&"ui_press")


## Fabrique une jauge complète : l'auge de bois du pack, et dedans le
## remplissage teinté par ce qu'il mesure.
##
## C'EST UN ASSEMBLAGE, PAS UN `ProgressBar` HABILLÉ, et il a fallu se
## cogner au second pour comprendre pourquoi. Un `ProgressBar` dessine son
## remplissage sur TOUTE sa surface, embouts compris : la barre débordait
## de l'auge. Et ses marges de tranches s'appliquent aux quatre côtés,
## alors qu'une jauge ne se découpe qu'HORIZONTALEMENT — le bois se
## répétait deux fois en hauteur. Un panneau qui porte l'auge, une marge
## qui écarte des embouts, et une barre nue à l'intérieur : chaque morceau
## fait une seule chose.
##
## LE REMPLISSAGE EST DÉSATURÉ AVANT D'ÊTRE TEINTÉ, comme les boutons. Le
## pack le livre en rouge : tel quel, une barre de PV pleine serait rouge
## vif, c'est-à-dire exactement le signal qu'on réserve à une barre vide.
func build_bar(
	value: float, maximum: float, fill_color: Color, height: int = 0
) -> Control:
	var block := UiTheme.bars()
	var scale := int(block.get("scale", 1))
	var base := _sliced_texture(
		StringName(block.get("base_asset", "")), scale, false, 3
	)
	var fill := _plain_texture(
		StringName(block.get("fill_asset", "")), scale, true,
		bool(block.get("normalise_fill", false)), true
	)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(maximum, 1.0)
	bar.value = clampf(value, 0.0, bar.max_value)

	if base == null or fill == null:
		# Sans le pack, on retombe sur des rectangles pleins : moins joli,
		# toujours lisible, et le jeu démarre.
		bar.add_theme_stylebox_override("background", _flat(UiTheme.color(&"ink")))
		bar.add_theme_stylebox_override("fill", _flat(fill_color))
		bar.custom_minimum_size = Vector2(
			0, height if height > 0 else UiTheme.metric(&"bar_height")
		)
		return bar

	# LA RAINURE DÉCIDE DE LA HAUTEUR, et il faut la lui DONNER. Laisser
	# le conteneur étirer la jauge ne marche pas : sans hauteur minimale
	# elle tombe à un pixel, un trait vert sur le bord du creux. On calcule
	# donc le creux — hauteur du bois moins ses deux bords — et on la pose.

	var painted := StyleBoxTexture.new()
	painted.texture = fill
	painted.modulate_color = fill_color
	bar.add_theme_stylebox_override("fill", painted)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var groove: Dictionary = AssetTable.sprite(
		&"ui", StringName(block.get("base_asset", ""))
	).get("groove", {})
	var divisor := maxi(scale, 1)
	var edges := (int(groove.get("top", 0)) + int(groove.get("bottom", 0))) / divisor
	var box := height if height > 0 else UiTheme.metric(&"bar_height")
	bar.custom_minimum_size = Vector2(0, maxi(box - edges, 1))
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# L'ENCART VIENT DU STYLEBOX, PAS D'UN `MarginContainer`. Un
	# `StyleBoxTexture` écarte déjà son contenu de ses marges de tranches ;
	# en ajouter un second par-dessus faisait 64 px de chaque côté sur une
	# barre large de 110, et la jauge se retrouvait à zéro. On voyait
	# l'auge et jamais rien dedans — deux fois de suite, avant de penser à
	# mesurer la largeur restante plutôt que la couleur du remplissage.
	var trough := PanelContainer.new()
	# LA HAUTEUR EST IMPOSABLE PAR L'APPELANT. Une jauge de carte de héros
	# n'a pas la place d'une jauge d'écran d'expédition ; forcer la même
	# des deux côtés écrasait le bois au lieu de le réduire.
	trough.custom_minimum_size = Vector2(
		0, height if height > 0 else UiTheme.metric(&"bar_height")
	)
	# SANS CE DRAPEAU, LE PANNEAU RESTE À SA TAILLE MINIMALE et la jauge
	# lui déborde dessus : mesuré à la capture, 76 px de bois sous 105 px
	# de vert. Un `PanelContainer` ne s'étire pas de lui-même quand son
	# style porte des marges de tranches.
	trough.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wood := _boxed(base, UiTheme.color(&"wood"), false)
	# La rainure est déclarée dans la table des assets, en pixels de
	# l'image recomposée : c'est une propriété du dessin, pas un réglage.
	wood.content_margin_left = int(groove.get("left", 0)) / divisor
	wood.content_margin_right = int(groove.get("right", 0)) / divisor
	wood.content_margin_top = int(groove.get("top", 0)) / divisor
	wood.content_margin_bottom = int(groove.get("bottom", 0)) / divisor
	trough.add_theme_stylebox_override("panel", wood)
	trough.add_child(bar)
	return trough


## Le portrait encadré d'une classe, dans une couleur de faction.
##
## LES 25 AVATARS DU PACK SONT DÉJÀ ENCADRÉS — un heaume sur une plaque
## colorée — donc il n'y a rien à recomposer : on les charge tels quels.
## Ils dormaient dans la table depuis toujours, employés par le seul écran
## de compagnie, alors que c'est en COMBAT qu'un visage sert le plus : les
## trois jeux de référence en montrent partout, et sans eux la liste des
## héros est du texte sur du noir.
func portrait(class_id: StringName, color: String) -> Texture2D:
	var cache := StringName("portrait|%s|%s" % [class_id, color])
	if _textures.has(cache):
		return _textures[cache]
	var entry := AssetTable.portrait(class_id, color)
	if entry.is_empty():
		return null
	var path := String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	_textures[cache] = texture
	return texture


## Le visage d'un ennemi, par le nom de son SPRITE.
##
## LE PACK EN A VINGT ET UN, et le commentaire du HUD affirmait le
## contraire — « 25 avatars humains et rien d'autre ». L'inventaire de
## `CLAUDE.md` disait 46 portraits depuis toujours ; personne n'était allé
## voir. La timeline montrait donc une LETTRE là où il y avait un visage,
## et « G » ne distingue pas un gnoll d'un gnome.
##
## Chaque avatar est une image de 256 carrée, sans couleur de faction :
## rien à recomposer, rien à teinter. On demande le sprite et pas
## l'identifiant, pour la même raison que la vue de combat : `sand_serpent`
## a le visage d'un `snake`.
func enemy_portrait(sprite_id: StringName) -> Texture2D:
	var cache := StringName("enemy_portrait|%s" % sprite_id)
	if _textures.has(cache):
		return _textures[cache]
	if not AssetTable.has_enemy_animation(sprite_id, &"avatar"):
		return null
	var entry := AssetTable.enemy_animation(sprite_id, &"avatar")
	var path := String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	# UN AVATAR PEUT ÊTRE UNE BANDE, et il faut alors n'en prendre que la
	# PREMIÈRE IMAGE. Les vingt et un visages du pack sont des images
	# fixes ; les bêtes qui viennent d'`extra` — le canon, la tour,
	# l'atelier — n'ont pas de portrait dessiné, et leur avatar pointe donc
	# sur leur propre animation d'attente.
	#
	# SANS ÇA, LE BADGE MONTRE LA BANDE ENTIÈRE : un ruban de 3072 × 256
	# écrasé dans un carré de 50 px donne une ligne pointillée d'un pixel
	# de haut. Deux ennemis se sont affichés en badge VIDE, sans une seule
	# erreur — même famille de défaut que les sept ombres nues de T11.8.
	var frame_size := Vector2i(texture.get_width(), texture.get_height())
	if StringName(entry.get("kind", AssetTable.KIND_IMAGE)) == AssetTable.KIND_STRIP:
		frame_size = Vector2i(
			int(entry.get("frame_w", frame_size.x)), int(entry.get("frame_h", frame_size.y))
		)
	# ET ON RECADRE SUR LES PIXELS OPAQUES. Les vingt et un portraits du
	# pack sont des bustes SERRÉS ; une animation d'attente, non — un
	# cavalier occupe le tiers d'un cadre de 256, donc son badge le montrait
	# gros comme un pouce à côté des autres. La règle est uniforme et sans
	# seuil : on recadre tout le monde, et les portraits déjà serrés ne
	# bougent quasiment pas.
	var region := _opaque_region(texture, frame_size)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		_textures[cache] = texture
		return texture
	var portrait := AtlasTexture.new()
	portrait.atlas = texture
	portrait.region = region
	_textures[cache] = portrait
	return portrait


## La boîte des pixels opaques de la PREMIÈRE image d'une texture.
## Rendue en coordonnées de la texture entière, prête pour un AtlasTexture.
func _opaque_region(texture: Texture2D, frame: Vector2i) -> Rect2:
	var image := texture.get_image()
	if image == null:
		return Rect2()
	var used := image.get_used_rect()
	# `get_used_rect` couvre la BANDE entière ; on la borne au premier cadre.
	var right := mini(used.position.x + used.size.x, frame.x)
	var bottom := mini(used.position.y + used.size.y, frame.y)
	var left := mini(used.position.x, frame.x)
	var top := mini(used.position.y, frame.y)
	return Rect2(left, top, maxi(right - left, 0), maxi(bottom - top, 0))


## Le fond de l'écran : un aplat sombre, et un motif carrelé par-dessus.
##
## UN APLAT NOIR EST FADE, et c'est le mot qu'a employé Gaetan. Rien n'y
## accroche la lumière, et les panneaux flottent sur du vide. Le motif est
## en diagonales à peine visibles : assez pour que le fond ait une
## matière, pas assez pour concurrencer ce qui est posé dessus — un fond
## qu'on remarque est un fond raté.
##
## DEUX PIÈGES, TOUS DEUX SILENCIEUX, et il a fallu deux mesures pour les
## voir :
## - **Le motif du pack est NOIR**, pas blanc : Kenney le livre comme une
##   ombre à poser sur du clair. Multiplié par une teinte dorée, du noir
##   reste du noir, et sur un fond déjà presque noir il ne fait rien —
##   mesuré, le fond passait de (14,12,10) à (12,11,9). On le REPEINT
##   donc en blanc en gardant son alpha, exactement comme le
##   remplissage d'une jauge et comme un glyphe : une source ne se teinte
##   que si elle est claire.
## - **Deux alphas se multiplient.** Le motif plafonne à 51/255, et la
##   teinte `weave` vient PAR-DESSUS. Réglée à 0,16 comme les autres
##   voiles, l'opacité vraie tombait à 0,03.
##
## LA RÈGLE QUI FIXE LA TEINTE : la CRÊTE du motif reste SOUS le panneau
## le plus sombre. Montée trop haut, elle passait à 32 quand `panel_deep`
## vaut 18 : le fond devenait plus clair que ce qu'on pose dessus, et un
## nœud de compétence désactivé s'y noyait.
##
## Rendu par `add_child` en PREMIER, donc derrière tout le reste — mais
## passer par `lay_backdrop` plutôt que par `add_child` : six écrans
## portent DÉJÀ leur propre `Background`, qui le recouvrait.
func backdrop(air: StringName = &"") -> Control:
	var ground := ColorRect.new()
	ground.color = UiTheme.air_ground(air)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var entry := AssetTable.sprite(&"widgets", &"weave")
	if entry.is_empty():
		return ground
	var path := String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return ground
	var image := _load_image(path)
	if image == null:
		return ground
	_whiten(image)
	var weave := TextureRect.new()
	weave.texture = ImageTexture.create_from_image(image)
	weave.stretch_mode = TextureRect.STRETCH_TILE
	weave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# STRETCH_TILE ne carrelle que si la répétition est autorisée sur le
	# nœud : une `ImageTexture` n'en décide pas elle-même.
	weave.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	weave.modulate = UiTheme.air_weave(air)
	weave.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.add_child(weave)
	return ground


## Efface la barre de défilement quand il n'y a rien à faire défiler.
##
## POURQUOI PAS SIMPLEMENT LA MASQUER PAR SON MODE. Un `ScrollContainer`
## dont la barre APPARAÎT selon la hauteur du contenu oscille : la barre
## prend de la largeur, le texte se replie autrement, la hauteur change,
## la barre disparaît, et le moteur empile un redessin par tour jusqu'au
## signal 11. Le projet s'est payé trois heures là-dessus.
##
## D'OÙ CE DÉTOUR : le mode reste « toujours visible », donc la LARGEUR ne
## bouge jamais et rien ne peut osciller ; on ne touche qu'à l'opacité.
## Un rail plein hauteur sur un panneau vide n'est pas faux — c'est ce que
## Godot dessine quand tout tient — mais il se lit comme un défaut, et sur
## l'écran d'expédition il traversait un panneau vide de haut en bas.
## Applique le traitement à TOUS les `ScrollContainer` d'un écran, pour la
## même raison que le clic des boutons vit dans `dress_button` : le faire
## un par un garantit qu'on en oublie un, et on en oublie toujours un.
func dress_scrolls(root: Node) -> void:
	if root is ScrollContainer:
		dress_scroll(root as ScrollContainer)
	for child: Node in root.get_children():
		dress_scrolls(child)


func dress_scroll(container: ScrollContainer) -> void:
	var bar := container.get_v_scroll_bar()
	if bar == null:
		return
	var refresh := func() -> void:
		# `page` est ce qu'on voit, `max_value` ce qu'il y a. Égaux, tout
		# tient à l'écran et la barre n'a rien à dire.
		bar.modulate.a = 0.0 if bar.page >= bar.max_value else 1.0
	refresh.call()
	if not bar.changed.is_connected(refresh):
		bar.changed.connect(refresh)


## Pose le fond sous un écran, en tenant compte de ce qu'il a déjà.
##
## SIX ÉCRANS PORTENT UN `Background` DESSINÉ DANS LEUR `.tscn`, et le
## premier réglage l'ignorait : le motif était bien inséré à l'indice 0,
## donc DERRIÈRE cet aplat, qui le recouvrait entièrement. L'écran de
## titre est resté noir uni sans qu'aucune erreur ne le dise — un nœud
## qui en cache un autre ne se plaint pas.
##
## D'où la règle : si l'écran a déjà un fond, on le REPEINT et on lui
## accroche le motif ; sinon seulement on en insère un.
##
## `root` est un `Node` et pas un `Control` : la scène de combat est un
## `Node2D`, et son fond doit rester SOUS le monde. Posé sur le
## `CanvasLayer` du HUD il passait devant le plateau et le cachait — un
## calque d'interface se dessine par-dessus le monde, c'est sa raison
## d'être.
## `air` est le nom d'une couleur de palette — en pratique l'`accent` de la
## région où l'on se trouve. Appeler à nouveau avec un autre air RETEINTE
## le fond en place : la carte du monde le fait à chaque région survolée.
func lay_backdrop(root: Node, air: StringName = &"") -> void:
	_air = air
	var existing := root.get_node_or_null(^"Background")
	if existing is ColorRect:
		var ground := existing as ColorRect
		ground.color = UiTheme.air_ground(air)
		if ground.get_child_count() == 0:
			var weave := backdrop(air)
			# On ne garde que le motif : l'aplat est déjà là.
			for child in weave.get_children():
				weave.remove_child(child)
				ground.add_child(child)
			weave.queue_free()
		else:
			for child in ground.get_children():
				if child is CanvasItem:
					(child as CanvasItem).modulate = UiTheme.air_weave(air)
		return
	var fresh := backdrop(air)
	root.add_child(fresh)
	root.move_child(fresh, 0)


## L'AIR DE L'ÉCRAN COURANT : le nom d'une couleur de palette, en pratique
## l'`accent` de la région où l'on se trouve (T11.9). Vide sur les écrans
## qui n'appartiennent à aucune région — titre, options, crédits, royaume.
##
## C'est un état d'ambiance et il vit donc dans la peau, pas dans un
## paramètre traîné d'appel en appel : `framed_style` est appelée depuis
## une trentaine d'endroits, et lui ajouter un argument aurait obligé
## chaque écran à savoir où il se trouve pour dessiner une bordure.
## `lay_backdrop` le pose, et tous les écrans l'appellent déjà en premier.
var _air: StringName = &""


## Les deux teintes de FOND vivent dans `UiTheme`, pas ici : c'est un
## CALCUL sur des couleurs, et `verify_ui` doit pouvoir le refaire. Un
## script lancé par `-s` ne reçoit aucun autoload.


## La carte d'un personnage : portrait encadré, nom, jauge de vie.
##
## PARTAGÉE PAR TROIS ÉCRANS — combat, expédition, compagnie. C'est la
## même information partout, et trois dessins pour une même chose est
## exactement ce qui donnait à l'ensemble son air de brouillon : chaque
## écran avait inventé sa façon d'afficher un héros.
## `accent` teinte le liseré à la couleur de la CLASSE du héros.
##
## QUATRE HÉROS EN RANG DANS QUATRE BOÎTES IDENTIQUES ne se distinguent
## que par leur nom, qu'il faut lire. Teintés, ils se comptent d'un coup
## d'œil. Le liseré, jamais le fond : c'est la règle de T9.7 — un fond
## coloré ferait deux matières pour une interface.
##
## Le héros qui joue garde la priorité sur sa classe : mis en avant, il
## reprend l'or, parce que « c'est à lui » est plus urgent à lire que
## « c'est un archer ».
func hero_card(
	face: Texture2D, title: String, hit_points: int, maximum: int,
	highlighted: bool = false, note: String = "", accent: StringName = &""
) -> Control:
	var edge := &"panel_edge" if highlighted else &"panel_edge_soft"
	if not highlighted and not accent.is_empty() and UiTheme.has_color(accent):
		edge = accent
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", framed_style(
		&"frame_card", &"panel_fill", edge, UiTheme.metric(&"card_margin")
	))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.metric(&"card_margin"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	if face != null:
		var side := UiTheme.metric(&"portrait_card")
		var rect := TextureRect.new()
		rect.texture = face
		rect.custom_minimum_size = Vector2(side, side)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var name_ := Label.new()
	name_.text = title
	name_.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	name_.add_theme_color_override(
		"font_color",
		UiTheme.color(&"ink_gold") if highlighted else UiTheme.color(&"ink")
	)
	name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(name_)

	var points := Label.new()
	points.text = note if not note.is_empty() else "%d/%d" % [hit_points, maximum]
	points.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	points.add_theme_color_override("font_color", UiTheme.color(&"ink_soft"))
	points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(points)

	if maximum > 0:
		column.add_child(build_bar(
			float(hit_points), float(maximum),
			UiTheme.health_color(float(hit_points) / maxf(float(maximum), 1.0)),
			UiTheme.metric(&"bar_height_card")
		))
	return card


## Un carré de terre du tileset, teinté à la couleur d'une région.
##
## SIX RÉGIONS, CINQ VARIANTES DE VERT. Le pack livre bien cinq tilesets
## de couleur, mais ce sont cinq nuances de la MÊME herbe : aucune ne fait
## un désert ni une banquise. Désaturée puis reteintée, la même tuile
## donne du sable, du gel et de la cendre — sans qu'un pixel ait été
## redessiné.
##
## C'EST LE PROCÉDÉ DES SIX BOUTONS DE T9.3, appliqué au terrain : on ne
## teinte proprement que ce qu'on a d'abord passé en gris, sinon le vert
## de l'herbe se mêle à la teinte et rend du vert sale.
##
## La tuile prise est le CENTRE du bloc de terre — celle qui n'a aucun
## bord — parce qu'une tuile de rive porterait un morceau d'écume, et
## qu'un carré d'échantillon n'a pas de rivage.
func terrain_swatch(tint: Color, side: int) -> Texture2D:
	var cache := StringName("swatch|%s|%d" % [tint.to_html(false), side])
	if _textures.has(cache):
		return _textures[cache]

	var entry := AssetTable.sprite(&"terrain", &"tilemap_color1")
	if entry.is_empty():
		return null
	var source := _load_image(String(entry.get("path", "")))
	if source == null:
		return null

	var tile := AssetTable.tile_size()
	var block: Array = ViewSettings.section(&"terrain_blocks").get("land", [0, 0])
	# [colonne, rangée] désigne le coin du bloc 4 × 4 ; la tuile sans
	# aucun bord est à (1, 1) dedans.
	var region := Rect2i(
		(int(block[0]) + 1) * tile, (int(block[1]) + 1) * tile, tile, tile
	)
	var cut := Image.create_empty(tile, tile, false, source.get_format())
	cut.blit_rect(source, region, Vector2i.ZERO)
	if cut.is_compressed():
		cut.decompress()
	cut.convert(Image.FORMAT_RGBA8)
	_desaturate(cut, true)
	for y in cut.get_height():
		for x in cut.get_width():
			var pixel := cut.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			cut.set_pixel(x, y, Color(
				pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, pixel.a
			))
	# Agrandi en NEAREST et par un facteur ENTIER quand c'est possible :
	# du pixel art redimensionné autrement bave, et c'est la règle que le
	# projet applique déjà à tous ses assets.
	if side != tile:
		cut.resize(side, side, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(cut)
	_textures[cache] = texture
	return texture


## LE TERRAIN DE COMBAT PORTE LA COULEUR DE SA RÉGION (T11.8).
##
## Le pack livre cinq nuances de tileset, et elles sont TOUTES VERTES —
## jaune-vert, vert clair, vert, kaki, sarcelle. Aucune ne fait du sable.
## Les Dunes Ardentes se jouaient donc sur l'herbe des Terres Vertes, et
## l'acte 2 ressemblait à l'acte 1 avant même le premier tour.
##
## C'est la règle de T11.6, appliquée à une image entière au lieu d'un
## carré de 48 : on DÉSATURE puis on reteinte. Cinquième emploi de « une
## source ne se teinte que si elle est claire ». La cohérence est un
## bonus qu'on n'avait pas cherché : le carré de terre montré sur la carte
## du monde et le sol du combat sortent maintenant de la même opération,
## donc ils ne peuvent pas diverger.
##
## `ground` vide rend le tileset TEL QUEL. Les Terres Vertes sont vertes
## parce que le pack les a dessinées vertes ; les désaturer pour les
## reteinter en vert ne ferait que perdre des nuances.
func tinted_tileset(ground: StringName) -> Texture2D:
	var entry := AssetTable.sprite(&"terrain", &"tilemap_color1")
	if entry.is_empty():
		return null
	var path := String(entry.get("path", ""))
	if ground.is_empty():
		return load(path) as Texture2D if ResourceLoader.exists(path) else null

	var cache := StringName("tileset|%s" % ground)
	if _textures.has(cache):
		return _textures[cache]
	var source := _load_image(path)
	if source == null:
		return null
	var tint := UiTheme.color(ground)
	_desaturate(source, true)
	for y in source.get_height():
		for x in source.get_width():
			var pixel := source.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			source.set_pixel(x, y, Color(
				pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, pixel.a
			))
	var texture := ImageTexture.create_from_image(source)
	_textures[cache] = texture
	return texture


## L'icône d'une ressource, par la référence « catégorie/clé » que ses
## données déclarent.
##
## LES QUATRE RÉFÉRENCES ÉTAIENT ÉCRITES ET VÉRIFIÉES DEPUIS TOUJOURS —
## `verify_kingdom` refuse une ressource dont l'asset n'existe pas —, et
## AUCUN écran ne les dessinait. Troisième fois que le projet trouve une
## donnée cataloguée que personne n'affiche, après les 70 entrées `ui` de
## T9.1 et les 21 visages d'ennemis de T11.8.
##
## Les tas du monde sont des images fixes de 64 : rien à recomposer. Le
## réglage à ne pas rater est l'ÉCHELLE — un tas de bois dessiné pour une
## case de plateau, réduit à la hauteur d'une ligne de texte, doit rester
## en Nearest et sur un diviseur qui ne fasse pas baver le contour.
func resource_icon(reference: String, side: int) -> Texture2D:
	if reference.is_empty():
		return null
	var parts := reference.split("/", false)
	if parts.size() != 2:
		return null
	var cache := StringName("res_icon|%s|%d" % [reference, side])
	if _textures.has(cache):
		return _textures[cache]
	var entry := AssetTable.sprite(StringName(parts[0]), StringName(parts[1]))
	if entry.is_empty():
		return null
	var image := _load_image(String(entry.get("path", "")))
	if image == null:
		return null
	# Une feuille d'animation rendrait toutes ses images côte à côte : on
	# n'en garde que la première, qui est la pose au repos.
	if StringName(entry.get("kind", "")) == AssetTable.KIND_STRIP:
		var frame_w := int(entry.get("frame_w", image.get_width()))
		var frame_h := int(entry.get("frame_h", image.get_height()))
		var cut := Image.create_empty(frame_w, frame_h, false, image.get_format())
		cut.blit_rect(image, Rect2i(0, 0, frame_w, frame_h), Vector2i.ZERO)
		image = cut
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)

	# ON RECADRE SUR LE DESSIN, PAS SUR LE FICHIER. `gold_resource` est une
	# image de 128 dont la pièce n'occupe que 24 px au centre : réduite
	# telle quelle à la hauteur d'une ligne, elle rendait un POINT de cinq
	# pixels à côté de trois tas qui remplissaient leur case. Le pack ne
	# cadre pas ses tas de la même façon, et rien ne l'y oblige.
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var drawing := Image.create_empty(used.size.x, used.size.y, false, image.get_format())
	drawing.blit_rect(image, used, Vector2i.ZERO)

	# Puis on l'inscrit dans un carré SANS le déformer : un tas de bois est
	# large et bas, une pièce est ronde, et les étirer pour remplir la même
	# boîte se verrait tout de suite.
	var span := maxi(used.size.x, used.size.y)
	var fitted := Vector2i(
		maxi(1, used.size.x * side / span), maxi(1, used.size.y * side / span)
	)
	drawing.resize(fitted.x, fitted.y, Image.INTERPOLATE_NEAREST)
	var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0.0, 0.0, 0.0, 0.0))
	square.blit_rect(
		drawing, Rect2i(Vector2i.ZERO, fitted),
		Vector2i((side - fitted.x) / 2, (side - fitted.y) / 2)
	)
	var texture := ImageTexture.create_from_image(square)
	_textures[cache] = texture
	return texture


## Le glyphe d'une compétence, ou null si elle n'en a pas.
##
## LE SEUL ENDROIT DU JEU OÙ L'ON MÊLE DU VECTORIEL AU PIXEL ART, et
## c'était ça ou rien : ni Tiny Swords ni les packs Kenney n'ont d'icône
## de sort. Le premier en a douze, toutes de ressources et de chrome ; le
## second est thématique jeu de plateau et n'offre que l'épée, l'arc, le
## feu et le bouclier. game-icons.net les avait toutes les quinze.
##
## LE SEUIL D'ALPHA EST CE QUI REND LE MÉLANGE SUPPORTABLE. Une silhouette
## vectorielle est lisse ; posée à côté d'un sprite de 64 px en filtrage
## Nearest, ça se voit immédiatement. En jetant le dégradé de bord, le
## glyphe redevient un masque franc — du pixel, comme le reste. On réduit
## d'abord en Lanczos pour garder la forme, PUIS on seuille : l'inverse
## (réduire en Nearest) hacherait le trait.
func glyph(ability_id: StringName) -> Texture2D:
	var block := UiTheme.glyphs()
	if block.is_empty() or ability_id.is_empty():
		return null
	var cache := StringName("glyph|%s" % ability_id)
	if _textures.has(cache):
		return _textures[cache]
	if not AssetTable.has(&"glyphs", ability_id):
		return null

	var entry := AssetTable.sprite(&"glyphs", ability_id)
	if entry.is_empty():
		return null
	var image := _load_image(String(entry.get("path", "")))
	if image == null:
		return null

	var side := maxi(int(block.get("size", 48)), 1)
	image.resize(side, side, Image.INTERPOLATE_LANCZOS)
	_threshold(image, float(block.get("alpha_threshold", 0.5)))
	var texture := ImageTexture.create_from_image(image)
	_textures[cache] = texture
	return texture


## Rend l'alpha binaire : un bord franc au lieu d'un dégradé.
func _threshold(image: Image, level: float) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < level:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				# Le glyphe est blanc à la source ; on le REPEINT en blanc
				# franc, sinon les pixels à demi couverts gardent leur
				# gris et le seuil ne sert à rien.
				image.set_pixel(x, y, Color(1, 1, 1, 1))


## Repeint chaque pixel en blanc, en gardant son alpha.
##
## Une source SOMBRE ne se teinte pas : `modulate` multiplie, et tout ce
## qui multiplie du noir rend du noir. C'est la même raison que
## `_desaturate(normalise)` pour les jauges — sauf qu'ici le motif n'a
## aucun relief à préserver, seulement une forme.
func _whiten(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			image.set_pixel(x, y, Color(1, 1, 1, pixel.a))


## Les deux textures d'une jauge : { base, fill }. Vides si le pack
## manque — l'appelant retombe alors sur un rectangle plein.
func bar_textures() -> Dictionary:
	var block := UiTheme.bars()
	if block.is_empty():
		return {}
	var scale := int(block.get("scale", 1))
	var base := _sliced_texture(
		StringName(block.get("base_asset", "")), scale, false, 3
	)
	var fill := _plain_texture(
		StringName(block.get("fill_asset", "")), scale, true,
		bool(block.get("normalise_fill", false)), true
	)
	if base == null or fill == null:
		return {}
	return {"base": base, "fill": fill}


func has_pack() -> bool:
	return not _textures.is_empty()


## Un panneau SOMBRE À LISERÉ ORNÉ : le style demandé par le modèle.
##
## LE CADRE ET LE FOND SONT COMPOSÉS EN UNE SEULE IMAGE, parce qu'un
## `StyleBox` ne s'empile pas. Les cadres de Kenney sont monochromes — un
## tracé BLANC OPAQUE sur un centre à demi transparent — donc on ne garde
## que les pixels pleinement opaques, on les repeint en or, et on pose le
## tout sur un aplat sombre. Le centre reste uniforme, ce qui est la
## condition pour qu'un 9-tranches s'étire proprement.
##
## POURQUOI PAS LE PAPIER DU PACK : le modèle est sombre à liseré doré, et
## un parchemin clair teinté en sombre devient une tache boueuse. Tiny
## Swords ne dessine pas de cadre ; la règle tient — on ne mélange que là
## où le premier pack ne dessine rien.
func framed_style(
	frame: StringName = &"frame_panel", fill: StringName = &"panel_fill",
	edge: StringName = &"panel_edge", pad: int = -1
) -> StyleBox:
	# LE TRAIT DOUX PORTE L'AIR DE LA RÉGION (T11.9), donc la clé de cache
	# doit le contenir : sans ça le premier écran teinté imposerait sa
	# couleur à tous les suivants.
	var key := StringName("framed|%s|%s|%s|%d|%s" % [frame, fill, edge, pad, _air])
	if _styles.has(key):
		return _styles[key]

	# Le trait accepte une couleur de la palette OU un rôle de bouton : un
	# écran demande « danger », pas « rouge ».
	var line: StringName = edge
	if not UiTheme.has_color(line):
		line = StringName(UiTheme.section(&"button_tints").get(String(edge), "panel_edge"))
	# Seul le trait DOUX vire : le vif dit « c'est à lui » et ne se
	# négocie pas, un rôle de bouton dit « danger » et encore moins.
	var stroke := UiTheme.color(line)
	if line == &"panel_edge_soft":
		stroke = UiTheme.air_edge(_air)
	var built: StyleBox = null
	var texture := _frame_texture(frame, fill, stroke, String(key))
	if texture == null:
		built = _flat(UiTheme.color(fill))
		(built as StyleBoxFlat).border_color = stroke
		(built as StyleBoxFlat).set_border_width_all(2)
	else:
		var box := StyleBoxTexture.new()
		box.texture = texture
		var corner: int = _textures.get(_corner_key(texture), 0)
		for side: String in ["left", "right", "top", "bottom"]:
			box.set("texture_margin_%s" % side, float(corner))
		built = box
	if pad >= 0:
		for side: String in ["left", "right", "top", "bottom"]:
			built.set("content_margin_%s" % side, float(pad))
	_styles[key] = built
	return built


func _frame_texture(
	frame: StringName, fill: StringName, line: Color, tag: String
) -> Texture2D:
	var cache := StringName("frametex|%s" % tag)
	if _textures.has(cache):
		return _textures[cache]
	var entry := AssetTable.sprite(&"widgets", frame)
	if entry.is_empty():
		return null
	var source := _load_image(String(entry.get("path", "")))
	if source == null:
		return null

	var ground := UiTheme.color(fill)
	var painted := Image.create_empty(
		source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8
	)
	painted.fill(ground)
	for y in source.get_height():
		for x in source.get_width():
			# SEUIL HAUT VOLONTAIRE : le centre de ces cadres est du blanc
			# à demi transparent, pas du vide. Le prendre pour du tracé
			# remplirait le panneau d'or.
			if source.get_pixel(x, y).a > 0.9:
				painted.set_pixel(x, y, line)
	var texture := ImageTexture.create_from_image(painted)
	_textures[cache] = texture
	_textures[_corner_key(texture)] = int(entry.get("slice", {}).get("corner", 16))
	return texture


# --- Construction ----------------------------------------------------------

func _build_styles() -> void:
	for role: StringName in UiTheme.surface_roles():
		var built := _surface_style(role)
		if built != null:
			_styles[role] = built


## Le thème global : tailles de police et couleurs par défaut. Ce qui est
## ici n'a plus besoin d'être répété écran par écran — c'est la moitié des
## `add_theme_*_override` qui disparaît.
func _build_theme() -> void:
	var body := UiTheme.font_size(&"body")
	for type_name: String in ["Label", "Button", "CheckBox", "OptionButton"]:
		theme.set_font_size("font_size", type_name, body)
	theme.set_font_size("font_size", "Button", UiTheme.font_size(&"button"))
	theme.set_color("font_color", "Label", UiTheme.color(&"ink_inverse"))
	theme.set_color("font_color", "Button", UiTheme.color(&"ink_inverse"))
	# LE THÈME GLOBAL DOIT PORTER LA COULEUR DÉSACTIVÉE, pas seulement
	# `dress_button` : les boutons qui ne passent pas par lui — l'arbre de
	# compétences en a une trentaine — gardaient le gris par défaut de
	# Godot sur le fond gris du rôle « muted », et l'arbre devenait
	# illisible dès qu'un nœud n'était pas achetable, c'est-à-dire
	# presque toujours.
	theme.set_color("font_disabled_color", "Button", UiTheme.color(&"ink_disabled"))
	theme.set_color("font_hover_color", "Button", UiTheme.color(&"ink_inverse"))
	theme.set_color("font_pressed_color", "Button", UiTheme.color(&"ink_inverse"))
	theme.set_constant("outline_size", "Button", 0)
	theme.set_constant("outline_size", "Label", 0)

	var pad := UiTheme.metric(&"button_pad")
	for state: String in ["normal", "hover", "focus"]:
		theme.set_stylebox(
			state, "Button", framed_style(&"frame_card", &"panel_fill", &"default", pad)
		)
	theme.set_stylebox(
		"pressed", "Button", framed_style(&"frame_card", &"panel_deep", &"default", pad)
	)
	theme.set_stylebox(
		"disabled", "Button", framed_style(&"frame_card", &"panel_deep", &"stone", pad)
	)
	theme.set_stylebox("panel", "PanelContainer", framed_style(
		&"frame_panel", &"panel_fill", &"panel_edge", UiTheme.metric(&"panel_margin")
	))

	_build_widgets()


## Les widgets que Tiny Swords ne dessine pas, pris chez Kenney (CC0).
##
## DIX `ScrollContainer` SUR SIX ÉCRANS rendaient la barre grise par
## défaut de Godot au milieu d'une interface en bois, et le curseur de
## volume des options avec. Ce n'est pas un oubli : le pack n'a ni barre
## de défilement, ni case à cocher, ni poignée.
##
## MÉLANGER DEUX PACKS SUR UN BOUTON SE VERRAIT ; sur un widget que le
## premier n'a jamais dessiné, il n'y a rien à trahir. C'est la seule
## raison qui autorise ce mélange, et elle ne s'étend pas aux boutons ni
## aux panneaux, qui restent en Tiny Swords.
func _build_widgets() -> void:
	var block := UiTheme.widget(&"scrollbar")
	if not block.is_empty():
		var pill := _sliced_texture(
			StringName(block.get("asset", "")), int(block.get("scale", 1)),
			false, 3, &"widgets", true
		)
		if pill != null:
			var grabber := _boxed(
				pill, UiTheme.color(StringName(block.get("tint", "wood_light"))), true
			)
			# LA PISTE DOIT PORTER LA LARGEUR DE LA BARRE. Godot déduit
			# l'épaisseur d'un `ScrollBar` de la taille minimale de son
			# style ; un `StyleBoxFlat` nu en a une nulle, et la barre
			# disparaissait purement et simplement — mesuré à la capture,
			# 68 de luminosité avant, 16 après, c'est-à-dire le fond.
			var track := _flat(UiTheme.color(&"scroll_track"))
			var half := UiTheme.metric(&"scrollbar_width") / 2
			track.content_margin_left = half
			track.content_margin_right = half
			track.content_margin_top = half
			track.content_margin_bottom = half
			for bar_type: String in ["VScrollBar", "HScrollBar"]:
				for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
					theme.set_stylebox(state, bar_type, grabber)
				theme.set_stylebox("scroll", bar_type, track)
	# LE CURSEUR DE VOLUME REPREND L'AUGE DES JAUGES. C'est le même objet —
	# une valeur dans une gouttière — et lui donner un deuxième dessin
	# reviendrait à dire qu'il s'agit d'autre chose. Un rectangle sombre
	# sur un fond sombre, lui, ne se voyait simplement pas.
	var bars := UiTheme.bars()
	var trough := _sliced_texture(
		StringName(bars.get("base_asset", "")), int(bars.get("scale", 1)),
		false, 3
	)
	if trough != null:
		var groove := _boxed(trough, UiTheme.color(&"wood"), false)
		# GODOT DESSINE LE RAIL À LA HAUTEUR MINIMALE DU STYLE, et sans
		# marges verticales cette hauteur est nulle : le bois était bien
		# posé, sur zéro pixel de haut. Les marges de contenu la lui
		# donnent.
		var half := UiTheme.metric(&"bar_height") / 2
		groove.content_margin_top = half
		groove.content_margin_bottom = half
		theme.set_stylebox("slider", "HSlider", groove)
		# La part remplie du rail : sans elle Godot pose un gris qui ne
		# veut rien dire, alors que c'est justement la valeur qu'on règle.
		var filled := _flat(UiTheme.color(&"slider_filled"))
		theme.set_stylebox("grabber_area", "HSlider", filled)
		theme.set_stylebox("grabber_area_highlight", "HSlider", filled)

	var boxes := UiTheme.widget(&"checkbox")
	if boxes.is_empty():
		return
	var empty := _plain_texture(
		StringName(boxes.get("empty", "")), int(boxes.get("scale", 1)),
		false, false, false, &"widgets"
	)
	var checked := _plain_texture(
		StringName(boxes.get("checked", "")), int(boxes.get("scale", 1)),
		false, false, false, &"widgets"
	)
	if empty == null or checked == null:
		return
	# La poignée du curseur est la MÊME pastille ronde que la case à
	# cocher : deux dessins pour deux gestes voisins se remarquent, un
	# seul se lit.
	theme.set_icon("grabber", "HSlider", checked)
	theme.set_icon("grabber_highlight", "HSlider", checked)
	theme.set_icon("grabber_disabled", "HSlider", empty)
	for widget_type: String in ["CheckBox", "CheckButton"]:
		theme.set_icon("unchecked", widget_type, empty)
		theme.set_icon("checked", widget_type, checked)
		theme.set_icon("unchecked_disabled", widget_type, empty)
		theme.set_icon("checked_disabled", widget_type, checked)
		theme.set_color("font_color", widget_type, UiTheme.color(&"ink_inverse"))
	# `CheckButton` a ses propres noms d'icônes : un interrupteur, pas une
	# case. Sans ça, l'option « tremblement d'écran » gardait le dessin de
	# Godot au milieu de tout le reste.
	theme.set_icon("unchecked", "CheckButton", empty)
	theme.set_icon("checked", "CheckButton", checked)
	theme.set_icon("off", "CheckButton", empty)
	theme.set_icon("on", "CheckButton", checked)
	theme.set_icon("off_disabled", "CheckButton", empty)
	theme.set_icon("on_disabled", "CheckButton", checked)


func _surface_style(role: StringName) -> StyleBox:
	var block := UiTheme.surface(role)
	if block.is_empty():
		return null
	var texture := _sliced_texture(
		StringName(block.get("asset", "")), int(block.get("scale", 1)),
		bool(block.get("desaturate", false)), 3
	)
	if texture == null:
		return _flat(UiTheme.color(StringName(block.get("tint", "backdrop"))))
	return _boxed(texture, UiTheme.color(StringName(block.get("tint", "parchment"))))


func _button_style(role: StringName, pressed: bool) -> StyleBox:
	var block := UiTheme.surface(&"button")
	if block.is_empty():
		return _flat(UiTheme.button_tint(role))
	var key := "pressed_asset" if pressed else "asset"
	var texture := _sliced_texture(
		StringName(block.get(key, block.get("asset", ""))),
		int(block.get("scale", 1)), bool(block.get("desaturate", false)), 3
	)
	if texture == null:
		return _flat(UiTheme.button_tint(role))
	return _boxed(texture, UiTheme.button_tint(role))


## Un `StyleBoxTexture` dont les marges valent le coin de la texture
## recomposée. Comme la recomposition met les trois morceaux bord à bord,
## le coin fait exactement le tiers... non : il fait ce que la table dit,
## divisé par l'échelle. On le relit sur la texture plutôt que de le
## recalculer, pour qu'il n'y ait qu'un seul endroit qui décide.
func _boxed(
	texture: Texture2D, tint: Color, vertical: bool = true
) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	var corner: int = _textures.get(_corner_key(texture), 0)
	box.texture_margin_left = corner
	box.texture_margin_right = corner
	# UNE JAUGE NE SE DÉCOUPE QU'EN LARGEUR. Lui donner des marges hautes
	# et basses répétait le bois deux fois dans une barre de 22 px : les
	# coins, qui font 32, ne tenaient pas dans la hauteur qu'on leur
	# donnait.
	box.texture_margin_top = corner if vertical else 0
	box.texture_margin_bottom = corner if vertical else 0
	box.modulate_color = tint
	return box


func _flat(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(UiTheme.metric(&"row_spacing"))
	return box


func _corner_key(texture: Texture2D) -> StringName:
	return StringName("corner:%d" % texture.get_instance_id())


# --- Recomposition ---------------------------------------------------------

## Recompose les morceaux d'un asset découpé et rend la texture, ou null
## si le fichier manque.
##
## `pieces` vaut 3 pour une jauge (trois morceaux en ligne) et 3 aussi
## pour une grille 3×3 — c'est le nombre de morceaux par axe. Une jauge
## n'a qu'une rangée, ce que la table dit par son `layout`.
func _sliced_texture(
	key: StringName, scale: int, desaturate: bool, pieces: int,
	category: StringName = &"ui", vertical_only: bool = false
) -> Texture2D:
	if key.is_empty():
		return null
	var cache := StringName(
		"%s|%s|%d|%s|%d|%s" % [category, key, scale, desaturate, pieces, vertical_only]
	)
	if _textures.has(cache):
		return _textures[cache]

	var entry := AssetTable.sprite(category, key)
	if entry.is_empty():
		return null
	var source := _load_image(String(entry.get("path", "")))
	if source == null:
		return null

	var slice: Dictionary = entry.get("slice", {})
	if slice.is_empty():
		push_error("Skin : « %s » n'a pas de géométrie de tranches" % key)
		return null
	var corner := int(slice.get("corner", 0))
	var middle := int(slice.get("middle", 0))
	var gap := int(slice.get("gap", 0))
	# UNE BARRE DE DÉFILEMENT SE DÉCOUPE EN HAUTEUR, pas en largeur : c'est
	# une pastille verticale dont seuls les bouts sont arrondis. L'inverse
	# exact d'une jauge, et le même piège si on ne le dit pas.
	var horizontal := _spans(corner, middle, gap)
	var vertical: Array = horizontal
	if vertical_only:
		vertical = _spans(corner, middle, gap)
		horizontal = [[0, 0, source.get_width()]]
	elif not (pieces > 1 and source.get_height() > corner * 2):
		vertical = [[0, 0, source.get_height()]]

	var width: int = horizontal[horizontal.size() - 1][1] + horizontal[horizontal.size() - 1][2]
	var height: int = vertical[vertical.size() - 1][1] + vertical[vertical.size() - 1][2]
	var packed := Image.create_empty(width, height, false, source.get_format())
	for row: Array in vertical:
		for column: Array in horizontal:
			packed.blit_rect(
				source,
				Rect2i(int(column[0]), int(row[0]), int(column[2]), int(row[2])),
				Vector2i(int(column[1]), int(row[1]))
			)

	if desaturate:
		_desaturate(packed)
	if scale > 1:
		# Nearest, et une division ENTIÈRE : le pack est du pixel art sur
		# grille de 64. Diviser par 2 fait tomber quatre pixels sur un ;
		# une division fractionnaire ferait baver la bordure.
		packed.resize(
			maxi(width / scale, 1), maxi(height / scale, 1), Image.INTERPOLATE_NEAREST
		)

	var texture := ImageTexture.create_from_image(packed)
	_textures[cache] = texture
	_textures[_corner_key(texture)] = maxi(corner / maxi(scale, 1), 1)
	return texture


## Les trois tranches d'un axe : { départ dans la source, départ dans la
## sortie, longueur }.
func _spans(corner: int, middle: int, gap: int) -> Array:
	return [
		[0, 0, corner],
		[corner + gap, corner, middle],
		[corner + gap + middle + gap, corner + middle, corner],
	]


## Un asset qui n'est pas découpé — le remplissage d'une jauge.
func _plain_texture(
	key: StringName, scale: int, desaturate: bool = false,
	normalise: bool = false, crop: bool = false, category: StringName = &"ui"
) -> Texture2D:
	if key.is_empty():
		return null
	var cache := StringName(
		"plain|%s|%s|%d|%s|%s|%s" % [category, key, scale, desaturate, normalise, crop]
	)
	if _textures.has(cache):
		return _textures[cache]
	var entry := AssetTable.sprite(category, key)
	if entry.is_empty():
		return null
	var image := _load_image(String(entry.get("path", "")))
	if image == null:
		return null
	if crop:
		image = _cropped(image)
	if desaturate:
		_desaturate(image, normalise)
	if scale > 1:
		image.resize(
			maxi(image.get_width() / scale, 1), maxi(image.get_height() / scale, 1),
			Image.INTERPOLATE_NEAREST
		)
	var texture := ImageTexture.create_from_image(image)
	_textures[cache] = texture
	return texture


## Réduit l'image à ce qu'elle dessine vraiment.
##
## LE REMPLISSAGE D'UNE JAUGE EST UNE BANDE DANS UNE TOILE VIDE : 64×64 de
## fichier pour 24 px de peinture, le reste transparent. Étirée telle
## quelle dans un creux de 13 px, la bande n'en occupait que 4 — un trait
## vert au milieu du bois. Recadrée, elle remplit ce qu'on lui donne.
func _cropped(image: Image) -> Image:
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return image
	return image.get_region(used)


## Charge une image du pack. Rend null SANS PLANTER si elle manque : les
## assets ne sont pas dans le dépôt, et un poste qui ne les a pas encore
## copiés doit quand même pouvoir lancer le jeu.
func _load_image(path: String) -> Image:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	# `blit_rect` refuse une image compressée, et l'importateur peut en
	# rendre une selon les réglages du projet.
	if image.is_compressed():
		image.decompress()
	return image


## Passe l'image en niveaux de gris, en gardant l'alpha.
##
## C'EST CE QUI SORT DU BLEU ET DU ROUGE. Multiplier un bouton bleu par de
## l'or donne du vert sale ; passé en gris, il prend n'importe quelle
## teinte proprement. Les six rôles de bouton sortent de cette ligne-là.
func _desaturate(image: Image, normalise: bool = false) -> void:
	# `normalise` remonte le plus clair à blanc.
	#
	# SANS ÇA, LE REMPLISSAGE D'UNE JAUGE EST INVISIBLE. Le pack le livre
	# en rouge sombre : mesuré, sa luminance plafonne à 0,71 et vaut 0,37
	# en moyenne. Passé en gris puis multiplié par un vert de PV, il
	# tombait sous 0,3 — du brun foncé dans une auge brun foncé. On voyait
	# le bois, jamais la vie.
	var ceiling := 1.0
	if normalise:
		ceiling = 0.0
		for y in image.get_height():
			for x in image.get_width():
				var sample := image.get_pixel(x, y)
				if sample.a > 0.0:
					ceiling = maxf(ceiling, sample.get_luminance())
		if ceiling <= 0.0:
			ceiling = 1.0

	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			# Luminance perçue : un bleu et un rouge de même intensité ne
			# donnent pas le même gris, et prendre la moyenne écraserait
			# le relief que le pack a dessiné.
			var grey := clampf(pixel.get_luminance() / ceiling, 0.0, 1.0)
			image.set_pixel(x, y, Color(grey, grey, grey, pixel.a))
