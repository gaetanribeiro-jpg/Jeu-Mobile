extends GutTest

## T2.7 — l'écran de compagnie.
##
## Sans lui, la Phase 2 entière est invisible : un niveau gagné, un objet
## trouvé, un choix à faire n'existent pour le joueur que s'il peut les
## voir et y toucher.
##
## Ces tests montent la vraie scène et pressent ses vrais boutons. Ils ne
## jugent pas le rendu — je le contrôle en capture — mais la mécanique,
## qui casse aussi silencieusement.


var _screen: Control
var _company: Company
var _changes := 0


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()

	_company = Company.new()
	var rng := CombatRng.new(31337)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		_company.recruit(class_id, rng)
	_company.collect({"gold": 400, "items": ["iron_sword", "plate", "longbow"]})

	_changes = 0
	var packed: PackedScene = load("res://scenes/ui/company_screen.tscn")
	_screen = packed.instantiate()
	_screen.configure(_company)
	add_child_autofree(_screen)
	_screen.changed.connect(func() -> void: _changes += 1)
	await wait_process_frames(2)


## Les boutons de la réserve, dans l'ordre affiché.
func _stash_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _screen._stash.get_children():
		if child is Button:
			out.append(child)
	return out


func _stash_button(item_id: StringName) -> Button:
	for button: Button in _stash_buttons():
		if button.text == tr(Equipment.name_key(item_id)):
			return button
	return null


func _sheet_buttons() -> Array[Button]:
	var out: Array[Button] = []
	_collect_buttons(_screen._sheet, out)
	return out


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_collect_buttons(child, out)


# --- La compagnie, à gauche ------------------------------------------------

func test_un_bouton_par_heros() -> void:
	assert_eq(_screen._roster.get_child_count(), _company.size())


func test_le_premier_heros_est_selectionne_d_office() -> void:
	# Une fiche vide au premier affichage donnerait l'impression d'un bogue.
	assert_not_null(_screen.selected_hero())
	assert_eq(_screen.selected_hero().id, _company.heroes[0].id)


func test_toucher_un_heros_change_la_fiche() -> void:
	var wanted: Hero = _company.heroes[2]
	_screen._roster.get_child(2).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_screen.selected_hero().id, wanted.id)


func test_un_heros_qui_attend_une_decision_est_signale() -> void:
	# C'est la seule chose de cet écran qui ne peut pas attendre.
	var before: int = _screen._roster.get_child(0).get_child(0).get_child_count()
	_company.heroes[0].add_experience(999999)
	_screen.refresh()
	await wait_process_frames(1)
	assert_gt(
		_screen._roster.get_child(0).get_child(0).get_child_count(), before,
		"le héros en attente ne porte aucune marque"
	)


# --- Le choix de niveau ----------------------------------------------------

func test_un_niveau_sans_choix_se_prend_d_un_bouton() -> void:
	var hero: Hero = _company.heroes[0]
	hero.add_experience(HeroProgression.experience_to_reach(2))
	_screen.refresh()
	await wait_process_frames(1)

	var pressed := false
	for button: Button in _sheet_buttons():
		if button.text == tr("COMPANY_LEVEL_UP") % 2:
			button.pressed.emit()
			pressed = true
			break
	assert_true(pressed, "aucun bouton pour monter de niveau")
	assert_eq(hero.level, 2)
	assert_eq(_changes, 1, "l'appelant doit être prévenu pour sauvegarder")


func test_l_arbre_dit_ce_que_chaque_noeud_donne() -> void:
	# « Fureur » ne dit rien ; « Fureur — Force +1 » dit tout, et le choix
	# est définitif.
	var hero: Hero = _company.heroes[0]
	hero.add_experience(999999)
	hero.level_up_free()
	_screen.refresh()
	await wait_process_frames(1)

	var seen := 0
	for button: Button in _sheet_buttons():
		for node_id: StringName in SkillTree.node_ids(hero.class_id):
			var name_ := tr(SkillTree.name_key(node_id))
			if button.text.begins_with(name_):
				seen += 1
				assert_gt(
					button.text.length(), name_.length() + 3,
					"le bouton ne dit pas ce que le nœud donne : %s" % button.text
				)
	assert_eq(seen, SkillTree.node_ids(hero.class_id).size(), "l'arbre n'est pas entier")


func test_un_noeud_hors_de_portee_est_grise_et_dit_pourquoi() -> void:
	var hero: Hero = _company.heroes[0]
	hero.add_experience(999999)
	hero.level_up_free()
	_screen.refresh()
	await wait_process_frames(1)

	var root: StringName = SkillTree.roots_of(hero.class_id)[0]
	var child: StringName = SkillTree.children_of(root)[0]
	for button: Button in _sheet_buttons():
		if button.text.begins_with(tr(SkillTree.name_key(child))):
			assert_true(button.disabled)
			assert_string_contains(button.text, tr(SkillTree.name_key(root)))
			return
	fail_test("le nœud enfant n'est pas affiché")


func test_apprendre_un_noeud_l_applique() -> void:
	var hero: Hero = _company.heroes[0]
	hero.add_experience(999999)
	hero.level_up_free()
	_screen.refresh()
	await wait_process_frames(1)

	var root: StringName = SkillTree.roots_of(hero.class_id)[0]
	var before := hero.skill_points_left()
	for button: Button in _sheet_buttons():
		if button.text.begins_with(tr(SkillTree.name_key(root))):
			button.pressed.emit()
			break
	assert_true(hero.has_learned(root))
	assert_eq(hero.skill_points_left(), before - 1)
	assert_gt(_changes, 0)


# --- La réserve ------------------------------------------------------------

func test_la_reserve_montre_tout_ce_qu_on_possede() -> void:
	assert_eq(_stash_buttons().size(), _company.stash.size())


func test_toucher_un_objet_l_equipe_sur_le_heros_choisi() -> void:
	var hero: Hero = _company.heroes[0]
	assert_eq(hero.class_id, &"warrior")
	_stash_button(&"iron_sword").pressed.emit()
	await wait_process_frames(1)
	assert_eq(hero.equipped(&"weapon"), &"iron_sword")
	assert_false(_company.stash.has(&"iron_sword"))
	assert_gt(_changes, 0)


func test_un_objet_que_le_heros_ne_peut_pas_porter_est_grise() -> void:
	# Grisé plutôt qu'absent : le joueur doit voir qu'il POSSÈDE l'arc, et
	# comprendre que c'est son Guerrier qui ne peut pas s'en servir.
	assert_eq(_screen.selected_hero().class_id, &"warrior")
	var bow := _stash_button(&"longbow")
	assert_not_null(bow, "l'arc doit être visible")
	assert_true(bow.disabled)

	# Sur l'Archer, le même arc devient disponible.
	_screen._roster.get_child(1).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_screen.selected_hero().class_id, &"archer")
	assert_false(_stash_button(&"longbow").disabled)


func test_toucher_un_emplacement_rend_l_objet_a_la_reserve() -> void:
	var hero: Hero = _company.heroes[0]
	_stash_button(&"plate").pressed.emit()
	await wait_process_frames(1)
	assert_eq(hero.equipped(&"armour"), &"plate")

	var returned := false
	for button: Button in _sheet_buttons():
		if button.text == tr(Equipment.name_key(&"plate")):
			button.pressed.emit()
			returned = true
			break
	assert_true(returned, "l'emplacement porté n'est pas touchable")
	assert_eq(hero.equipped(&"armour"), &"")
	assert_true(_company.stash.has(&"plate"), "rien ne se perd")


func test_l_ecran_ne_sauvegarde_pas_lui_meme() -> void:
	# Il ne connaît ni GameState ni le disque : il signale, l'appelant
	# décide. Sans cette séparation, l'écran serait intestable hors d'une
	# partie chargée.
	_stash_button(&"iron_sword").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_changes, 1, "un signal, et un seul, par modification")


func test_le_bouton_retour_annonce_la_fermeture() -> void:
	var closed := [false]
	_screen.closed.connect(func() -> void: closed[0] = true)
	_screen._back.pressed.emit()
	assert_true(closed[0])


func test_une_compagnie_vide_ne_plante_pas() -> void:
	var empty := Company.new()
	var packed: PackedScene = load("res://scenes/ui/company_screen.tscn")
	var screen: Control = packed.instantiate()
	screen.configure(empty)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_null(screen.selected_hero())
	assert_eq(screen._roster.get_child_count(), 0)
