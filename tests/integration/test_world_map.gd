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


func _region_button(region_id: StringName) -> Button:
	for child: Node in _screen._regions.get_children():
		if child is Button and (child as Button).text.begins_with(tr(Region.name_key(region_id))):
			return child
	return null


# --- Le monde se voit en entier -------------------------------------------

func test_les_six_regions_sont_affichees() -> void:
	assert_eq(_screen._regions.get_child_count(), Region.ids().size())


func test_une_region_verrouillee_se_lit() -> void:
	# Le verrou dit qu'il y a une suite, et c'est gratuit.
	var button := _region_button(&"black_empire")
	assert_not_null(button)
	assert_false(button.disabled, "on ne peut même pas la consulter")
	assert_string_contains(button.text, tr("WORLD_LOCKED"))


func test_consulter_une_region_verrouillee_interdit_le_depart() -> void:
	_region_button(&"black_empire").pressed.emit()
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
