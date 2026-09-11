extends GutTest

## T3.6 — la carte du monde.
##
## Le § 28 met les décisions AVANT le départ : destination, équipe. Une
## seule est réelle au MVP puisqu'une seule région est ouverte ; l'autre
## est là pour qu'on voie où l'on ira, ce qui est le § 27 en une ligne.
##
## Ce que ces tests protègent surtout : une région verrouillée se LIT mais
## ne se part pas. Une carte qui n'afficherait que les Terres Vertes ne
## serait pas une carte du monde, ce serait un bouton ; et une carte qui
## laisserait partir vers l'Empire Noir enverrait le joueur dans le vide.


var _screen: Control
var _company: Company
var _departures: Array[Dictionary] = []


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()
	Region.clear_cache()

	_company = Company.new()
	var rng := CombatRng.new(31337)
	for class_id: StringName in [&"warrior", &"archer", &"mage", &"warrior"]:
		_company.recruit(class_id, rng)

	_departures.clear()
	var packed: PackedScene = load("res://scenes/world/world_map.tscn")
	_screen = packed.instantiate()
	_screen.configure(_company)
	add_child_autofree(_screen)
	_screen.departed.connect(func(region_id: StringName, ids: Array) -> void:
		_departures.append({"region": region_id, "squad": ids}))
	await wait_process_frames(2)


## LA CARTE SE TOUCHE, ELLE NE SE CLIQUE PLUS PAR RANGÉE (T12.11). L'écran
## n'empile plus six boutons : `world_map_view` dessine la mer, les terres
## et la route, et rend un identifiant de région. Un test qui fixerait la
## forme d'un nœud d'habillage casserait au premier changement de style
## sans que rien ne soit faux — la leçon des deux tests d'expédition de
## T9.7, prise ici par avance.
func _pick(region_id: StringName) -> void:
	_screen._atlas.picked.emit(region_id)


func _texts_of(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child: Node in node.get_children():
		out.append_array(_texts_of(child))
	return out


# --- Le monde se voit en entier -------------------------------------------

func test_les_six_regions_sont_sur_la_carte() -> void:
	for region_id: StringName in Region.ids():
		assert_true(
			WorldAtlas.has_node(region_id),
			"« %s » n'est nulle part sur la carte" % region_id
		)
		_pick(region_id)
		await wait_process_frames(1)
		assert_eq(_screen.selected_region(), region_id)


## La carte reçoit ce qu'il lui faut pour se dessiner : ce qui est ouvert,
## et le crédit des voisines qui décide de leur couleur.
func test_la_carte_recoit_la_campagne_et_le_royaume() -> void:
	assert_not_null(_screen._atlas.campaign)
	assert_eq(_screen._atlas.selected, _screen.selected_region())


func test_une_region_verrouillee_se_lit() -> void:
	# Le verrou dit qu'il y a une suite, et c'est gratuit.
	_pick(&"black_empire")
	await wait_process_frames(1)
	var lines := PackedStringArray()
	for child: Node in _screen._brief.get_children():
		if child is Label:
			lines.append((child as Label).text)
	var joined := " ".join(lines)
	assert_string_contains(joined, tr(Region.name_key(&"black_empire")))
	assert_string_contains(joined, tr("WORLD_LOCKED_TEXT"))


func test_consulter_une_region_verrouillee_interdit_le_depart() -> void:
	_pick(&"black_empire")
	await wait_process_frames(1)
	assert_eq(_screen.selected_region(), &"black_empire")
	assert_true(_screen._depart.disabled, "on peut partir vers une région verrouillée")

	_screen._depart.pressed.emit()
	assert_true(_departures.is_empty())


func test_le_resume_dit_ce_qu_il_faut_savoir_avant_de_dire_oui() -> void:
	# La longueur de la sortie, sa fin, et que rien ne se soigne. Le reste
	# se découvre — c'est une expédition, pas un devis.
	var lines := PackedStringArray()
	for child: Node in _screen._brief.get_children():
		if child is Label:
			lines.append((child as Label).text)
	var joined := " ".join(lines)
	assert_string_contains(joined, tr(Region.name_key(&"greenlands")))
	assert_string_contains(joined, tr("WORLD_ENDS_ON_BOSS"))
	assert_string_contains(joined, tr("WORLD_NO_HEALING"))


# --- Partir ----------------------------------------------------------------

func test_partir_annonce_la_region_et_l_equipe() -> void:
	_screen._depart.pressed.emit()
	assert_eq(_departures.size(), 1)
	assert_eq(_departures[0]["region"], &"greenlands")
	assert_eq((_departures[0]["squad"] as Array).size(), CombatRules.team_size())


func test_l_equipe_ne_depasse_jamais_le_plafond() -> void:
	# La carte ne prévoit pas plus de cases de placement.
	for i in 6:
		_company.recruit(&"archer", CombatRng.new(i))
	_screen.configure(_company)
	_screen.refresh()
	await wait_process_frames(1)
	assert_eq(_screen.squad_ids().size(), CombatRules.team_size())


func test_un_emplacement_fait_defiler_les_heros_sans_doublon() -> void:
	_company.recruit(&"mage", CombatRng.new(9))
	_screen.configure(_company)
	_screen.refresh()
	await wait_process_frames(1)

	var before: Array[int] = _screen.squad_ids()
	var buttons: Array[Button] = []
	for child: Node in _screen._squad.get_children():
		if child is Button:
			buttons.append(child)
	buttons[0].pressed.emit()
	await wait_process_frames(1)

	var after: Array[int] = _screen.squad_ids()
	assert_ne(after[0], before[0], "l'emplacement n'a pas changé")
	var seen := {}
	for hero_id: int in after:
		assert_false(seen.has(hero_id), "un héros est dans deux emplacements")
		seen[hero_id] = true


## CE QUE LE ROYAUME ENVOIE SE LIT AU MOMENT DE PARTIR (§ 43, T12.9).
##
## « Le joueur n'est jamais uniquement un gestionnaire, uniquement un
## héros RPG, uniquement un commandant — il est les trois, et CHAQUE
## ACTIVITÉ INFLUENCE LES AUTRES. » Le royaume influençait déjà
## l'expédition — soin entre les étapes, modificateurs par classe — mais
## INVISIBLEMENT : les chiffres s'appliquaient dans le moteur sans jamais
## s'afficher. Une influence qu'on ne voit pas ne relie rien.
func test_la_fiche_dit_ce_que_le_royaume_envoie() -> void:
	var kingdom := Kingdom.create()
	kingdom.levels[&"monastery"] = Buildings.max_level(&"monastery")
	kingdom.levels[&"barracks"] = Buildings.max_level(&"barracks")
	_screen.configure(_company, null, kingdom)
	_screen.refresh()
	await wait_process_frames(1)

	var seen := " | ".join(_texts_of(_screen._brief))
	assert_string_contains(seen, tr("WORLD_GIFTS"))
	assert_string_contains(
		seen, tr("WORLD_GIFT_HEALING") % (kingdom.healing_between_steps() * 100.0),
		"le soin entre les étapes n'est pas annoncé"
	)


## ON NE MONTRE QUE LES CLASSES QUI PARTENT : lire le bonus d'un Mage
## resté au royaume donnerait un chiffre qu'on ne touchera pas.
func test_seules_les_classes_de_l_equipe_sont_annoncees() -> void:
	var kingdom := Kingdom.create()
	kingdom.levels[&"barracks"] = Buildings.max_level(&"barracks")
	kingdom.levels[&"archery"] = Buildings.max_level(&"archery")
	_screen.configure(_company, null, kingdom)
	# Une équipe de Guerriers seulement.
	_screen._squad_ids.clear()
	for hero: Hero in _company.heroes:
		if hero.class_id == &"warrior":
			_screen._squad_ids.append(hero.id)
	assert_gt(_screen._squad_ids.size(), 0, "aucun Guerrier dans la compagnie de test")
	_screen.refresh()
	await wait_process_frames(1)

	var seen := " | ".join(_texts_of(_screen._brief))
	assert_string_contains(seen, tr("CLASS_WARRIOR"))
	assert_false(
		seen.contains(tr("CLASS_ARCHER")),
		"le camp d'archers est annoncé alors qu'aucun Archer ne part"
	)


## Sans royaume bâti, l'écran le DIT plutôt que de laisser un blanc : un
## panneau vide se lit comme un bogue.
func test_un_royaume_nu_le_dit() -> void:
	_screen.configure(_company, null, Kingdom.create())
	_screen.refresh()
	await wait_process_frames(1)
	assert_string_contains(" | ".join(_texts_of(_screen._brief)), tr("WORLD_GIFT_NONE"))
