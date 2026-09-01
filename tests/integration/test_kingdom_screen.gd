extends GutTest

## T4.3 — l'écran du royaume.
##
## Le § 5 fait de l'évolution visuelle une exigence, pas un bonus. Ces
## tests ne jugent pas le rendu — je le contrôle en capture — mais la
## mécanique des deux décisions que l'écran contient, et qui cassent aussi
## silencieusement :
##
##   bâtir      dépenser maintenant, ou garder pour la prochaine sortie
##   affecter   quelle ressource manque le plus, ce cycle-ci
##
## Elles se disputent la même bourse et les mêmes bras.


var _screen: Control
var _kingdom: Kingdom
var _company: Company
var _changes := 0


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()

	_company = Company.new()
	_company.gold = 5000
	_kingdom = Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			_kingdom.stores[resource_id] = 5000

	_changes = 0
	var packed: PackedScene = load("res://scenes/kingdom/kingdom_screen.tscn")
	_screen = packed.instantiate()
	_screen.configure(_kingdom, _company, CombatRng.new(4242))
	add_child_autofree(_screen)
	_screen.changed.connect(func() -> void: _changes += 1)
	await wait_process_frames(2)


func _panel_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in _screen._panel.get_children():
		if child is Button:
			out.append(child)
	return out


func _button(prefix: String) -> Button:
	for button: Button in _panel_buttons():
		if button.text.begins_with(prefix):
			return button
	return null


## Désigne un bâtiment ou un chantier. PAS de `await` ici : une fonction
## d'aide qui attend, appelée avec `await`, imbrique deux coroutines et
## GUT part en boucle jusqu'au signal 11. On attend sur place, à l'appel.
func _select(kind: StringName, id: StringName) -> void:
	_screen._on_picked(kind, id)


# --- Ce que l'écran montre -------------------------------------------------

func test_les_quatre_ressources_et_les_bras_sont_en_haut() -> void:
	# Un habitant au repos mange sans rien rendre : c'est la ressource la
	# plus facile à oublier, donc elle est à côté des autres.
	var seen := ""
	for child: Node in _screen._stores.get_children():
		if child is Label:
			seen += (child as Label).text + " | "
	for resource_id: StringName in ResourceTable.ids():
		assert_string_contains(seen, tr(ResourceTable.name_key(resource_id)))
	assert_string_contains(seen, tr("KINGDOM_IDLE"))


func test_le_chateau_est_designe_d_entree() -> void:
	# Un panneau vide au premier regard n'apprend pas qu'on peut toucher le
	# terrain, il donne l'impression que l'écran ne fait rien.
	assert_eq(_screen._view.selected_id, Buildings.KEYSTONE)
	assert_gt(_panel_buttons().size(), 0)


func test_le_panneau_dit_le_cout_ET_le_gain_du_niveau_suivant() -> void:
	# Un prix sans son gain ne demande pas de décider, il demande de payer.
	_select(_screen._view.KIND_BUILDING, &"houses")
	await wait_process_frames(1)
	var text := ""
	for child: Node in _screen._panel.get_children():
		if child is Label:
			text += (child as Label).text + " "
	assert_string_contains(text, tr(ResourceTable.name_key(&"wood")))
	assert_string_contains(text, tr("GRANT_POPULATION_CAP"))


# --- Bâtir -----------------------------------------------------------------

func test_batir_depense_et_monte_le_batiment() -> void:
	_select(_screen._view.KIND_BUILDING, &"houses")
	await wait_process_frames(1)
	var wood := _kingdom.amount(&"wood")
	_button(tr("KINGDOM_FOUND")).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_kingdom.level_of(&"houses"), 1)
	assert_lt(_kingdom.amount(&"wood"), wood)
	assert_gt(_changes, 0, "rien n'a demandé la sauvegarde")


func test_un_bouton_grise_dit_pourquoi() -> void:
	# Un bouton grisé qui ne dit pas pourquoi est une impasse.
	var company := Company.new()
	var poor := Kingdom.create()
	poor.stores[&"wood"] = 0
	_screen.configure(poor, company, CombatRng.new(1))
	_select(_screen._view.KIND_BUILDING, &"houses")
	await wait_process_frames(1)
	var button := _button(tr("KINGDOM_NEEDS_RESOURCES"))
	assert_not_null(button, "le bouton ne dit pas ce qui manque")
	assert_true(button.disabled)


func test_le_chateau_bloque_et_l_ecran_le_dit() -> void:
	_kingdom.build(&"barracks", _company)
	_select(_screen._view.KIND_BUILDING, &"barracks")
	await wait_process_frames(1)
	var button := _button(tr("KINGDOM_NEEDS_CASTLE"))
	assert_not_null(button, "l'écran ne dit pas que le château bloque")
	assert_true(button.disabled)


# --- Affecter --------------------------------------------------------------

func test_envoyer_et_rappeler_un_habitant() -> void:
	_select(_screen._view.KIND_WORKSITE, &"lumber_camp")
	await wait_process_frames(1)
	_button(tr("KINGDOM_ASSIGN")).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_kingdom.assigned_to(&"lumber_camp"), 1)

	_button(tr("KINGDOM_UNASSIGN")).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_kingdom.assigned_to(&"lumber_camp"), 0)


func test_on_ne_peut_pas_envoyer_un_habitant_qu_on_n_a_pas() -> void:
	for i in _kingdom.population:
		_kingdom.assign(&"lumber_camp")
	_select(_screen._view.KIND_WORKSITE, &"quarry")
	await wait_process_frames(1)
	assert_true(_button(tr("KINGDOM_ASSIGN")).disabled)


# --- Recruter --------------------------------------------------------------

func test_on_ne_recrute_pas_sans_le_batiment() -> void:
	# Sans caserne, pas de Guerrier.
	_select(_screen._view.KIND_BUILDING, &"barracks")
	await wait_process_frames(1)
	assert_null(_button("Recruter"))


func test_recruter_ajoute_un_heros_et_coute() -> void:
	_kingdom.build(&"barracks", _company)
	_select(_screen._view.KIND_BUILDING, &"barracks")
	await wait_process_frames(1)
	var gold := _company.gold
	var food := _kingdom.amount(&"food")

	var button := _button("Recruter")
	assert_not_null(button, "aucun bouton de recrutement")
	button.pressed.emit()
	await wait_process_frames(1)

	assert_eq(_company.size(), 1)
	assert_eq(_company.heroes[0].class_id, &"warrior")
	assert_lt(_company.gold, gold)
	assert_lt(_kingdom.amount(&"food"), food)


func test_recruter_ne_prend_personne_a_la_population() -> void:
	# Un royaume qui perdrait un bûcheron chaque fois qu'il forme un
	# Guerrier punirait le joueur d'avoir joué.
	_kingdom.build(&"barracks", _company)
	var people := _kingdom.population
	_kingdom.recruit(&"barracks", _company, CombatRng.new(3))
	assert_eq(_kingdom.population, people)


# --- Le compte rendu du cycle ---------------------------------------------

func test_le_compte_rendu_du_cycle_s_affiche() -> void:
	_kingdom.assign(&"lumber_camp")
	var report := _kingdom.run_cycle(_company)
	_screen.report_cycle(report)
	await wait_process_frames(1)
	assert_string_contains(_screen._journal.text, tr(ResourceTable.name_key(&"wood")))
	assert_string_contains(_screen._journal.text, "nourriture mangée")
