extends GutTest

## T3.5 — l'écran d'expédition.
##
## Sans lui, toute la Phase 3 est invisible : une chaîne de rencontres
## qu'on ne voit pas n'est pas une expédition, c'est une file d'attente.
##
## Ces tests montent la vraie scène et pressent ses vrais boutons. Ils ne
## jugent pas le rendu — je le contrôle en capture — mais la mécanique,
## qui casse aussi silencieusement. Et surtout ils protègent la propriété
## qui fait exister la décision du § 29 : la route, la besace et l'équipe
## sont à l'écran EN MÊME TEMPS.


var _screen: Control
var _company: Company
var _run: Expedition
var _changes := 0
var _ended := -1


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	HeroProgression.reload()
	HeroNames.reload()
	Equipment.reload()
	Loot.reload()
	Region.reload()
	ExpeditionRules.reload()
	ExpeditionEvent.reload()
	Merchant.reload()

	_company = Company.new()
	var rng := CombatRng.new(31337)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		_company.recruit(class_id, rng)
	_company.gold = 2000

	var ids: Array[int] = []
	for hero: Hero in _company.heroes:
		ids.append(hero.id)
	_run = Expedition.depart(&"greenlands", ids, CombatRng.new(7))

	_changes = 0
	_ended = -1
	await _mount()


func _mount() -> void:
	var packed: PackedScene = load("res://scenes/world/expedition_screen.tscn")
	_screen = packed.instantiate()
	_screen.configure(_run, _company, CombatRng.new(4242))
	add_child_autofree(_screen)
	_screen.changed.connect(func() -> void: _changes += 1)
	_screen.finished.connect(func(state: int) -> void: _ended = state)
	await wait_process_frames(2)


func _step_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _screen._step.get_children():
		if child is Button:
			out.append(child)
	return out


func _press(label: String) -> void:
	for button: Button in _step_buttons():
		if button.text.begins_with(label) and not button.disabled:
			button.pressed.emit()
			return
	fail_test("aucun bouton actif « %s » parmi %s" % [label, _labels()])


func _labels() -> PackedStringArray:
	var out := PackedStringArray()
	for button: Button in _step_buttons():
		out.append(button.text)
	return out


## Gagne le combat de l'étape en cours, comme le fera l'appelant.
func _win() -> void:
	var units := _run.squad_units(_company)
	_screen.resolve_combat({"victory": true, "enemies_downed": 4}, units)


## Avance jusqu'à une étape du genre voulu, en gagnant tout ce qui se
## présente. Renvoie faux si la chaîne n'en contient pas.
func _advance_to(kind: StringName) -> bool:
	for guard in 30:
		if _run.is_over():
			return false
		if _run.current_kind() == kind:
			_screen.refresh()
			return true
		if _run.current_is_combat():
			_win()
		else:
			_run.resolve_event({}, CombatRng.new(guard), _company)
			_screen.refresh()
	return false


# --- Les trois termes de la décision, ensemble -----------------------------

func test_la_route_la_besace_et_l_equipe_sont_a_l_ecran() -> void:
	# Les séparer reviendrait à demander au joueur d'en retenir deux
	# pendant qu'il regarde le troisième.
	assert_eq(_screen._route.get_child_count(), _run.length(), "la route")
	assert_string_contains(_screen._satchel.text, "0")
	assert_gt(_screen._squad.get_child_count(), 1, "l'équipe")


func test_la_route_montre_toutes_les_etapes_et_marque_celle_en_cours() -> void:
	_win()
	await wait_process_frames(1)
	var badges: Array[Node] = _screen._route.get_children()
	assert_eq(badges.size(), _run.length())
	# Le badge de l'étape en cours porte son numéro : c'est ce qui permet
	# de lire « il me reste trois combats » d'un coup d'œil.
	var here: Label = badges[_run.depth()].get_child(0)
	assert_string_contains(here.text, str(_run.depth() + 1))


func test_l_equipe_montre_les_pv_portes() -> void:
	# C'est le chiffre qui dit si continuer est encore raisonnable.
	var units := _run.squad_units(_company)
	units[0].hit_points = 7
	_screen.resolve_combat({"victory": true, "enemies_downed": 3}, units)
	await wait_process_frames(1)
	var found := false
	for row: Node in _screen._squad.get_children():
		for child: Node in row.get_children():
			if child is Label and String((child as Label).text).begins_with("7 /"):
				found = true
	assert_true(found, "les PV portés ne sont pas affichés")


# --- La décision du § 29 ---------------------------------------------------

func test_on_ne_peut_pas_rentrer_avant_d_etre_parti() -> void:
	assert_true(_screen._retreat.disabled)
	_win()
	await wait_process_frames(1)
	assert_false(_screen._retreat.disabled)


func test_rentrer_verse_la_besace_a_la_compagnie() -> void:
	_win()
	await wait_process_frames(1)
	var carried := _run.satchel_gold
	assert_gt(carried, 0)
	var before := _company.gold

	_screen._retreat.pressed.emit()
	await wait_process_frames(1)
	assert_eq(_company.gold, before + carried)
	assert_eq(_ended, Expedition.State.RETURNED)
	assert_gt(_changes, 0, "rien n'a demandé la sauvegarde")


# --- Les étapes ------------------------------------------------------------

func test_une_etape_de_combat_demande_un_plateau() -> void:
	var asked: Array[StringName] = []
	_screen.combat_requested.connect(func(map_id: StringName) -> void: asked.append(map_id))
	_press(tr("EXPEDITION_FIGHT"))
	assert_eq(asked, [_run.current_map()] as Array[StringName])


func test_un_evenement_propose_ses_options() -> void:
	assert_true(_advance_to(&"event"), "la chaîne n'a pas d'évènement")
	await wait_process_frames(1)
	var event_id := _run.reveal_event(CombatRng.new(4242))
	assert_false(event_id.is_empty())
	assert_eq(_step_buttons().size(), ExpeditionEvent.options(event_id).size())


func test_choisir_une_option_fait_avancer_la_chaine() -> void:
	assert_true(_advance_to(&"event"))
	await wait_process_frames(1)
	var before := _run.depth()
	_step_buttons()[0].pressed.emit()
	await wait_process_frames(1)
	assert_eq(_run.depth(), before + 1)


func test_le_pari_est_annonce_avant_d_etre_couru() -> void:
	# Le télégraphe du combat dit les dégâts avant de frapper ; un
	# évènement doit dire sa chance avant qu'on la coure.
	assert_true(_advance_to(&"event"))
	await wait_process_frames(1)
	var event_id := _run.reveal_event(CombatRng.new(4242))
	for index in ExpeditionEvent.options(event_id).size():
		if not ExpeditionEvent.option_gambles(event_id, index):
			continue
		var percent := int(round(ExpeditionEvent.option_chance(event_id, index) * 100.0))
		assert_string_contains(_step_buttons()[index].text, "%d %%" % percent)


func test_une_option_trop_chere_est_grisee_mais_montree() -> void:
	assert_true(_advance_to(&"event"))
	await wait_process_frames(1)
	var event_id := _run.reveal_event(CombatRng.new(4242))
	var costly := -1
	for index in ExpeditionEvent.options(event_id).size():
		if ExpeditionEvent.option_gold_cost(event_id, index) > 0:
			costly = index
	if costly < 0:
		pass_test("cet évènement ne fait rien payer")
		return
	_company.gold = 0
	_screen.refresh()
	await wait_process_frames(1)
	assert_true(_step_buttons()[costly].disabled)
	assert_eq(_step_buttons().size(), ExpeditionEvent.options(event_id).size())


func test_le_marchand_vend_et_l_objet_est_a_l_abri() -> void:
	if not _advance_to(&"merchant"):
		pass_test("cette chaîne n'a pas de marchand")
		return
	await wait_process_frames(1)
	var stock := _run.reveal_stock(CombatRng.new(4242))
	assert_false(stock.is_empty())
	var before := _company.gold

	_step_buttons()[0].pressed.emit()
	await wait_process_frames(1)
	assert_lt(_company.gold, before)
	assert_true(_company.stash.has(stock[0]), "l'achat n'est pas dans la réserve")
	assert_true(_step_buttons()[0].disabled, "l'étalage se réapprovisionne")


# --- La fin ----------------------------------------------------------------

func test_une_deroute_termine_l_expedition() -> void:
	_screen.resolve_combat({"victory": false, "enemies_downed": 0}, [] as Array[Unit])
	await wait_process_frames(1)
	assert_eq(_ended, Expedition.State.LOST)
	assert_string_contains(_screen._step.get_child(0).text, tr("EXPEDITION_LOST"))


func test_l_ecran_ne_sauvegarde_pas_lui_meme() -> void:
	# Même frontière que l'écran de compagnie : il émet, l'appelant décide.
	assert_eq(_changes, 0)
	_win()
	await wait_process_frames(1)
	assert_gt(_changes, 0)
