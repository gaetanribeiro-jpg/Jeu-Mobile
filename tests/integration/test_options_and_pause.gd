extends GutTest

## T6.1 — les options, la pause et l'abandon.
##
## Ce que ces tests protègent : que les curseurs commandent quelque chose,
## et que la porte de sortie du combat existe.
##
## Un écran d'options dont les curseurs ne bougent rien est ce que le
## projet s'interdit ailleurs — du décoratif. Et un combat dont on ne peut
## pas sortir se quitte, sur mobile, par le bouton système : ce qui tue
## l'application et l'expédition avec elle.


var _screen: Control

## PIÈGE GDSCRIPT : une lambda capture une variable LOCALE par VALEUR. Un
## compteur local incrémenté dans un `connect` reste donc à zéro dans le
## test, et l'assertion échoue sans rien indiquer de faux dans le code
## qu'elle vise. Le compteur est donc un membre.
var _asked := 0


func before_each() -> void:
	_asked = 0
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	Settings.reset()

	var packed: PackedScene = load("res://scenes/ui/options_screen.tscn")
	_screen = packed.instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(2)


func after_all() -> void:
	Settings.reset()


func _sliders() -> Array[HSlider]:
	var out: Array[HSlider] = []
	for row: Node in _screen._body.get_children():
		for child: Node in row.get_children():
			if child is HSlider:
				out.append(child)
	return out


func _buttons(prefix: String) -> Button:
	for child: Node in _screen._body.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child
	return null


# --- Les réglages survivent à la partie -----------------------------------

func test_les_reglages_ne_vivent_pas_dans_la_sauvegarde_de_partie() -> void:
	# Commencer une nouvelle partie ne doit pas remettre le volume à zéro.
	Settings.set_value(&"audio", &"music_volume", 0.25)
	GameState.start_new_campaign(4242)
	assert_almost_eq(Settings.number(&"audio", &"music_volume", 1.0), 0.25, 0.001)


func test_un_reglage_absent_retombe_sur_son_defaut() -> void:
	Settings.reset()
	assert_gt(Settings.number(&"audio", &"master_volume", -1.0), 0.0)
	assert_true(Settings.flag(&"display", &"screen_shake", false))


func test_un_fichier_de_reglages_abime_ne_fait_pas_tomber_le_jeu() -> void:
	# Perdre son volume vaut mieux que perdre le démarrage.
	var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	file.store_string("ceci n'est pas du JSON")
	file.close()
	assert_eq(Settings._read(Settings.PATH), {})
	assert_push_error("Settings : %s ne se lit pas, on repart des défauts" % Settings.PATH)
	Settings.reset()


# --- Les curseurs commandent de vrais bus ---------------------------------

func test_les_trois_volumes_sont_reglables() -> void:
	assert_eq(_sliders().size(), 3)


func test_bouger_un_curseur_change_le_bus() -> void:
	var slider := _sliders()[1]
	slider.value = 0.3
	await wait_process_frames(1)
	assert_almost_eq(Settings.number(&"audio", &"music_volume", 1.0), 0.3, 0.001)
	assert_almost_eq(AudioManager.volume_of(AudioManager.BUS_MUSIC), 0.3, 0.05)


func test_le_volume_a_zero_coupe_franchement() -> void:
	# `linear_to_db(0)` rend -inf, et certains pilotes n'aiment pas ça.
	AudioManager.set_volume(AudioManager.BUS_SFX, 0.0)
	var index := AudioServer.get_bus_index(AudioManager.BUS_SFX)
	assert_true(AudioServer.is_bus_mute(index))
	AudioManager.set_volume(AudioManager.BUS_SFX, 1.0)
	assert_false(AudioServer.is_bus_mute(index))


func test_les_bus_existent() -> void:
	for bus_name: String in [AudioManager.BUS_MUSIC, AudioManager.BUS_SFX]:
		assert_gt(AudioServer.get_bus_index(bus_name), 0, bus_name)


# --- La partie neuve demande deux pressions -------------------------------

func test_la_partie_neuve_demande_confirmation() -> void:
	_screen.new_game_requested.connect(_count_ask)

	_buttons(tr("OPTIONS_NEW_GAME")).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_asked, 0, "une seule pression a suffi")

	_buttons(tr("OPTIONS_NEW_GAME_CONFIRM")).pressed.emit()
	assert_eq(_asked, 1)


func _count_ask() -> void:
	_asked += 1


func test_on_peut_revenir_en_arriere() -> void:
	_buttons(tr("OPTIONS_NEW_GAME")).pressed.emit()
	await wait_process_frames(1)
	_buttons(tr("OPTIONS_CANCEL")).pressed.emit()
	await wait_process_frames(1)
	assert_not_null(_buttons(tr("OPTIONS_NEW_GAME")))
	assert_null(_buttons(tr("OPTIONS_NEW_GAME_CONFIRM")))


# --- Abandonner est une vraie défaite -------------------------------------

func test_abandonner_termine_le_combat_en_defaite() -> void:
	var map := CombatMap.load_map(&"vallee_01")
	var squad: Array[Unit] = [Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)]
	var engine := map.to_engine(squad, CombatRng.new(7))
	engine.deploy(map.deployment_cells[0], squad[0])
	engine.begin_combat()

	assert_false(engine.is_finished())
	var log := engine.surrender()
	assert_true(engine.is_finished())
	assert_false(engine.is_victory())
	var events := PackedStringArray()
	for entry: Dictionary in log:
		events.append(String(entry.get("event", "")))
	assert_true(events.has("surrendered"))
	assert_true(events.has("combat_ended"))


func test_abandonner_deux_fois_ne_fait_rien() -> void:
	var map := CombatMap.load_map(&"vallee_01")
	var squad: Array[Unit] = [Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)]
	var engine := map.to_engine(squad, CombatRng.new(7))
	engine.deploy(map.deployment_cells[0], squad[0])
	engine.begin_combat()
	engine.surrender()
	assert_true(engine.surrender().is_empty())
