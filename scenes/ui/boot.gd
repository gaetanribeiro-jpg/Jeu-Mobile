extends Control

## Écran d'amorçage — et, pour l'instant, menu principal.
##
## LA BOUCLE PASSE PAR ICI, et elle est maintenant complète du côté du
## joueur : carte du monde → expédition → combat → butin → compagnie →
## sauvegarde. Il manque le royaume, qui est la Phase 4 et qui viendra se
## brancher au même endroit.
##
## LE BANC D'ESSAI RESTE. La liste des huit cartes lance un combat seul,
## hors expédition. Ce n'est pas un reliquat : je ne peux pas jouer au jeu,
## et pouvoir ouvrir une carte précise en deux clics est la seule façon de
## vérifier un combat sans traverser une sortie entière. Il est nommé pour
## ce qu'il est.
##
## PROVISOIRE quand même : le vrai menu principal viendra avec le royaume.

const COMBAT_SCENE := "res://scenes/combat/combat_scene.tscn"
const COMPANY_SCENE := "res://scenes/ui/company_screen.tscn"
const WORLD_SCENE := "res://scenes/world/world_map.tscn"
const KINGDOM_SCENE := "res://scenes/kingdom/kingdom_screen.tscn"
const OPTIONS_SCENE := "res://scenes/ui/options_screen.tscn"
const EXPEDITION_SCENE := "res://scenes/world/expedition_screen.tscn"

## Identifiants des héros emmenés au banc d'essai, dans l'ordre des
## emplacements. L'expédition tient sa propre équipe.
var _squad_ids: Array[int] = []

## Combats du banc d'essai déjà enchaînés. Nourrit la profondeur du butin
## hors expédition ; une vraie sortie utilise la sienne.
var _depth: int = 0

## Compte rendu du dernier cycle de production, montré à la prochaine
## ouverture du royaume.
var _last_cycle: Dictionary = {}

## Compte rendu du dernier assaut, montré au même endroit.
var _last_defence: Dictionary = {}

## Vrai entre l'annonce du retour et le lancement de la bataille. Sans ce
## drapeau, la fermeture de l'expédition résoudrait l'assaut par l'armée
## seule une fraction de seconde avant que le joueur n'arrive.
var _defending := false

var _company_screen: Control = null
var _kingdom_screen: Control = null
var _options_screen: Control = null
var _world_screen: Control = null
var _expedition_screen: Control = null

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _maps: VBoxContainer = %Maps
@onready var _squad: VBoxContainer = %Squad


func _ready() -> void:
	theme = UiSkin.theme
	_lay_backdrop()
	_title.add_theme_font_size_override("font_size", UiTheme.font_size(&"title"))
	_title.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	_subtitle.add_theme_color_override("font_color", UiTheme.color(&"ink_muted"))
	_title.text = tr("GAME_TITLE")
	_subtitle.text = tr("BOOT_TEMPORARY")
	GameState.load_saved()
	_ensure_company()
	_reset_squad()
	_build_squad_picker()
	_build_map_list()


## Une compagnie vide n'a rien à montrer et rien à envoyer au combat : on
## en recrute une au premier lancement, à la graine de la partie, pour
## qu'elle soit la même à chaque rechargement.
func _ensure_company() -> void:
	var company := GameState.company
	if company.size() > 0:
		return
	var rng := GameState.combat_rng(0)
	var classes := Unit.hero_class_ids()
	for i in CombatRules.team_size():
		company.recruit(classes[i % classes.size()], rng)
	# Le sac de départ (§ 44). Une potion qu'on ne peut pas obtenir n'est
	# pas une mécanique, c'est une déclaration : tant que le butin et le
	# marchand n'en distribuent pas, c'est d'ici qu'elles viennent.
	company.supplies = Consumable.starting_stock()
	GameState.save()


func _reset_squad() -> void:
	_squad_ids.clear()
	for hero: Hero in GameState.company.heroes:
		if _squad_ids.size() < CombatRules.team_size():
			_squad_ids.append(hero.id)


# --- Le haut de l'écran : l'expédition et la compagnie ---------------------

func _build_squad_picker() -> void:
	for child in _squad.get_children():
		child.queue_free()

	var centre := CenterContainer.new()
	_squad.add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	centre.add_child(row)

	# Une expédition en cours passe avant tout le reste : elle a la
	# priorité sur le disque comme à l'écran, sinon on la perdrait en
	# repartant de zéro sans s'en apercevoir.
	# UN COMBAT INTERROMPU PASSE AVANT TOUT. C'est l'état le plus fragile
	# de la partie et le plus coûteux à perdre : sept rondes de décisions.
	var go := _menu_button(&"primary", 400)
	if GameState.combat != null and not GameState.combat.is_finished():
		go.text = tr("BOOT_RESUME_COMBAT")
		go.pressed.connect(_resume_combat)
	elif GameState.expedition != null and GameState.expedition.is_ongoing():
		go.text = tr("BOOT_RESUME")
		go.pressed.connect(_resume_expedition)
	else:
		go.text = tr("BOOT_EXPEDITION")
		go.pressed.connect(_open_world)
	row.add_child(go)

	var kingdom := _menu_button(&"positive", 240)
	kingdom.text = tr("BOOT_KINGDOM")
	kingdom.pressed.connect(_open_kingdom)
	row.add_child(kingdom)

	var company := _menu_button(&"arcane", 240)
	company.text = tr("BOOT_COMPANY")
	company.pressed.connect(_open_company)
	row.add_child(company)

	var options := _menu_button(&"default", 200)
	options.text = tr("BOOT_OPTIONS")
	options.pressed.connect(_open_options)
	row.add_child(options)


func _open_company() -> void:
	_company_screen = _open(COMPANY_SCENE, func(screen: Node) -> void:
		screen.configure(GameState.company)
		screen.closed.connect(_close_company)
		screen.changed.connect(GameState.save))


func _close_company() -> void:
	_dismiss(_company_screen)
	_company_screen = null
	_reset_squad()
	_build_squad_picker()
	visible = true


# --- Les options -----------------------------------------------------------

func _open_options() -> void:
	_options_screen = _open(OPTIONS_SCENE, func(screen: Node) -> void:
		screen.closed.connect(_close_options)
		screen.new_game_requested.connect(_start_new_game))


func _close_options() -> void:
	_dismiss(_options_screen)
	_options_screen = null
	visible = true


## Une partie neuve efface tout : compagnie, royaume, expédition en cours.
## Les RÉGLAGES survivent — ils vivent dans leur propre fichier, et un
## joueur qui recommence ne veut pas re-régler son volume.
func _start_new_game() -> void:
	_close_options()
	GameState.start_new_campaign(GameState.new_seed())
	_ensure_company()
	_reset_squad()
	_last_cycle = {}
	_depth = 0
	GameState.save()
	_build_squad_picker()


## Un bouton du menu principal : sa largeur, et le RÔLE qui lui donne sa
## couleur. Six rôles sortent de la même image du pack — sans quoi le menu
## serait bleu et rouge, une langue « confirmer / renoncer » qui ne veut
## rien dire sur « Royaume » ou « Compagnie ».
func _menu_button(role: StringName, width: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(
		width, UiTheme.metric(&"button_height")
	)
	button.add_theme_font_size_override("font_size", UiTheme.font_size(&"button_large"))
	UiSkin.dress_button(button, role)
	return button


# --- Le royaume ------------------------------------------------------------

func _open_kingdom() -> void:
	_kingdom_screen = _open(KINGDOM_SCENE, func(screen: Node) -> void:
		screen.configure(
			GameState.kingdom, GameState.company,
			GameState.combat_rng(GameState.kingdom.cycles + GameState.company.size())
		)
		screen.closed.connect(_close_kingdom)
		screen.changed.connect(GameState.save))
	# Le compte rendu du dernier cycle attend ici : le joueur revient
	# d'expédition sur l'écran de titre, et c'est en ouvrant son royaume
	# qu'il veut savoir ce qu'il a produit pendant son absence.
	if is_instance_valid(_kingdom_screen):
		if not _last_defence.is_empty():
			_kingdom_screen.report_defence(_last_defence)
			_last_defence = {}
		elif not _last_cycle.is_empty():
			_kingdom_screen.report_cycle(_last_cycle)


func _close_kingdom() -> void:
	_dismiss(_kingdom_screen)
	_kingdom_screen = null
	_reset_squad()
	_build_squad_picker()
	visible = true


# --- La carte du monde -----------------------------------------------------

func _open_world() -> void:
	_world_screen = _open(WORLD_SCENE, func(screen: Node) -> void:
		screen.configure(GameState.company)
		screen.closed.connect(_close_world)
		screen.departed.connect(_depart))


func _close_world() -> void:
	_dismiss(_world_screen)
	_world_screen = null
	_build_squad_picker()
	visible = true


func _depart(region_id: StringName, hero_ids: Array) -> void:
	var ids: Array[int] = []
	for hero_id: Variant in hero_ids:
		ids.append(int(hero_id))
	# La graine de la sortie sort de la graine de la partie : deux
	# expéditions successives ne se ressemblent pas, et la même partie
	# rejouée les retrouve toutes les deux.
	var run := Expedition.depart(
		region_id, ids, GameState.combat_rng(GameState.company.gold + ids.size())
	)
	if run == null:
		return
	GameState.expedition = run
	GameState.save()
	_dismiss(_world_screen)
	_world_screen = null
	_open_expedition()


# --- L'expédition ----------------------------------------------------------

func _resume_expedition() -> void:
	if GameState.expedition == null:
		return
	_open_expedition()


func _open_expedition() -> void:
	# Ce que le royaume apporte à cette sortie se pose ICI, à chaque
	# ouverture, plutôt que d'être figé au départ : le joueur a pu bâtir
	# entre deux, et une valeur dérivée qu'on garde finit par mentir.
	_apply_kingdom_to(GameState.expedition)
	_expedition_screen = _open(EXPEDITION_SCENE, func(screen: Node) -> void:
		screen.configure(GameState.expedition, GameState.company, GameState.kingdom)
		screen.changed.connect(GameState.save)
		screen.combat_requested.connect(_start_expedition_combat)
		screen.defence_requested.connect(_defend_kingdom)
		screen.finished.connect(_close_expedition))


func _close_expedition(_state: int) -> void:
	_dismiss(_expedition_screen)
	_expedition_screen = null
	# Une expédition finie ne doit pas rester dans la sauvegarde : au
	# prochain lancement, « Reprendre » proposerait une sortie déjà close.
	if GameState.expedition != null and GameState.expedition.is_over():
		GameState.expedition = null
		# UNE SORTIE CONCLUE = UN CYCLE DE PRODUCTION. C'est la couture des
		# deux moitiés de la boucle du § 3, et elle tient en une ligne :
		# une sortie courte rapporte plus de cycles, une longue plus de
		# butin. Une déroute compte aussi — les bûcherons ont travaillé
		# pendant que les héros tombaient.
		_last_cycle = GameState.kingdom.run_cycle(GameState.company)
		# Un assaut que le joueur n'est pas rentré défendre se résout tout
		# seul : le § 37 dit que l'armée peut défendre seule, pas que
		# l'assaut attend indéfiniment.
		# Un assaut que le joueur n'est pas rentré défendre se résout tout
		# seul. S'il rentre, la bataille tranche à la place.
		if (not _defending and GameState.kingdom.invasion != null
				and GameState.kingdom.invasion.is_imminent()):
			_resolve_invasion(0)
	GameState.save()
	_build_squad_picker()
	visible = true
	if _defending:
		_start_defence()


## Le royaume ne parle pas à l'expédition : c'est l'écran de titre qui les
## relie. `Expedition` ignore qu'un royaume existe, et c'est ce qui permet
## de jouer une sortie dans un test ou dans le simulateur sans en bâtir un.
func _apply_kingdom_to(run: Expedition) -> void:
	if run == null:
		return
	var bonuses := {}
	for class_id: StringName in Unit.hero_class_ids():
		bonuses[class_id] = GameState.kingdom.hero_bonuses(class_id)
	run.kingdom_bonuses = bonuses
	run.kingdom_healing = GameState.kingdom.healing_between_steps()


## Le joueur est rentré défendre (§ 37, § 38).
##
## LA BATAILLE A LIEU. Résoudre l'assaut par une comparaison de nombres
## alors que le joueur est rentré exprès reviendrait à lui dire qu'il a
## gagné pour de faux — et « le terrain du royaume devient une carte de
## combat » est une phrase du § 38, pas une image.
func _defend_kingdom() -> void:
	# La sortie n'est pas encore refermée : on note l'intention, et la
	# bataille se lance une fois l'écran d'expédition rendu.
	_defending = true


func _start_defence() -> void:
	_defending = false
	var raid: Invasion = GameState.kingdom.invasion
	if raid == null:
		return
	var run: Expedition = GameState.expedition
	var seed_value := run.seed_value if run != null else GameState.campaign_seed
	var rng := CombatRng.new(hash([seed_value, "defence", raid.strength]))
	var map := DefenceMap.build(GameState.kingdom, raid, rng)
	var squad := GameState.company.squad(_squad_ids_for_defence())
	if map == null or squad.is_empty():
		# On ne laisse pas le royaume avec un assaut en suspens : l'armée
		# défend seule, comme si le joueur n'était pas rentré.
		_resolve_invasion(0)
		GameState.save()
		return

	var units := GameState.company.to_units(squad, _kingdom_bonuses())
	_launch_with_map(map, units, rng, _on_defence_finished)


## L'équipe qui défend : celle qui rentre, ou la compagnie entière si
## aucune sortie n'est en cours.
func _squad_ids_for_defence() -> Array:
	var run: Expedition = GameState.expedition
	if run != null and not run.squad_ids.is_empty():
		return run.squad_ids
	return _squad_ids


func _kingdom_bonuses() -> Dictionary:
	var bonuses := {}
	for class_id: StringName in Unit.hero_class_ids():
		bonuses[class_id] = GameState.kingdom.hero_bonuses(class_id)
	return bonuses


func _on_defence_finished(scene: Node) -> void:
	if not is_instance_valid(scene) or GameState.kingdom.invasion == null:
		return
	var won := (scene.engine as CombatEngine).is_victory()
	_last_defence = GameState.kingdom.settle_invasion(
		GameState.company, won, GameState.kingdom.defence_strength(_squad_levels())
	)
	_last_defence["alone"] = false
	_last_defence["fought"] = true
	GameState.save()
	_build_squad_picker()
	visible = true


## Résout l'assaut en cours, s'il y en a un. `hero_levels` vaut zéro quand
## l'armée défend seule.
func _resolve_invasion(hero_levels: int) -> void:
	if GameState.kingdom.invasion == null:
		return
	_last_defence = GameState.kingdom.resolve_invasion(GameState.company, hero_levels)
	_last_defence["alone"] = hero_levels <= 0


## Somme des niveaux des héros partis. C'est ce que le retour du joueur
## ajoute à la défense.
func _squad_levels() -> int:
	var run: Expedition = GameState.expedition
	if run == null:
		return 0
	var total := 0
	for hero: Hero in GameState.company.squad(run.squad_ids):
		total += hero.level
	return total


func _start_expedition_combat(map_id: StringName) -> void:
	var run: Expedition = GameState.expedition
	if run == null:
		return
	var units := run.squad_units(GameState.company)
	if units.is_empty():
		return
	var rng := CombatRng.new(hash([run.seed_value, run.index]))
	var map := CombatMap.load_map(map_id)
	if map == null:
		return
	# LA NUIT AJOUTE SES BÊTES AVANT LE PLACEMENT, jamais après. Le § 39
	# veut l'information parfaite : le joueur doit pouvoir compter ses
	# adversaires pendant qu'il décide où poser son équipe. Un renfort qui
	# arriverait en cours de combat serait une embuscade, et une embuscade
	# est le contraire d'un télégraphe.
	DayNight.reinforce(
		map.board, run.moment(), run.night_roster(), map.deployment_cells, rng,
		map.objective
	)
	_launch_with_map(map, units, rng, _on_expedition_combat_finished, run.moment())


func _on_expedition_combat_finished(scene: Node) -> void:
	var run: Expedition = GameState.expedition
	if run == null or not is_instance_valid(scene):
		return
	var engine: CombatEngine = scene.engine
	var summary := CombatRewards.summarise(engine)
	# L'expérience va à la compagnie, le butin à la besace : la première
	# est acquise, le second reste en jeu jusqu'au retour.
	CombatRewards.award_to(
		GameState.company.squad(run.squad_ids), int(summary.get("experience", 0))
	)
	var heroes: Array[Unit] = []
	for unit: Unit in engine.board.units():
		if unit.is_hero():
			heroes.append(unit)
	if is_instance_valid(_expedition_screen):
		_expedition_screen.resolve_combat(summary, heroes)
		_expedition_screen.visible = true
	# Une étape de plus loin du royaume, donc une menace de plus (§ 37).
	# L'expédition ne sait pas qu'un royaume existe : c'est ici qu'ils se
	# parlent, comme pour les modificateurs.
	GameState.kingdom.raise_threat(
		CombatRng.new(hash([run.seed_value, run.index, "threat"])), run.depth()
	)
	GameState.save()


# --- Le banc d'essai : un combat seul, hors expédition ---------------------

## La carte que le bouton « de nuit » ouvre. Le § 36 veut qu'une
## rencontre de nuit soit vérifiable sans gagner cinq combats d'abord.
const NIGHT_TESTBENCH_MAP := &"vallee_02"


func _build_map_list() -> void:
	for child in _maps.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = tr("BOOT_TESTBENCH")
	header.add_theme_font_size_override("font_size", UiTheme.font_size(&"subheading"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", UiTheme.color(&"ink_muted"))
	_maps.add_child(header)

	# Un GridContainer prend sa taille minimale et se cale à gauche : sans
	# CenterContainer autour, la première colonne sort de l'écran.
	var centre := CenterContainer.new()
	_maps.add_child(centre)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	centre.add_child(grid)

	for map_id: StringName in CombatMap.map_ids():
		var map := CombatMap.load_map(map_id)
		var button := Button.new()
		button.text = tr(map.name_key) if map != null else String(map_id)
		button.custom_minimum_size = Vector2(250, UiTheme.metric(&"button_height_small"))
		button.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
		UiSkin.dress_button(button, &"muted")
		button.pressed.connect(_start_test_combat.bind(map_id))
		grid.add_child(button)

	# UNE CARTE DE NUIT AU BANC D'ESSAI (§ 36). La nuit ne tombe qu'au fond
	# d'une expédition : sans ce bouton, vérifier une rencontre de nuit
	# demande de gagner cinq combats d'abord, et personne ne le fera —
	# c'est exactement le raisonnement qui a fait exister ce banc.
	#
	# LE LIBELLÉ SORT DE LA CARTE, pas d'une chaîne écrite à la main : il
	# annonçait « La route basse » et ouvrait `vallee_02`, qui est le gué
	# de Cendre. Un banc d'essai qui ment sur ce qu'il ouvre fait perdre
	# plus de temps qu'il n'en fait gagner.
	var night_map := CombatMap.load_map(NIGHT_TESTBENCH_MAP)
	var night := Button.new()
	night.text = tr("BOOT_TESTBENCH_NIGHT") % [
		tr(night_map.name_key) if night_map != null else String(NIGHT_TESTBENCH_MAP)
	]
	night.custom_minimum_size = Vector2(250, UiTheme.metric(&"button_height_small"))
	night.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	UiSkin.dress_button(night, &"muted")
	night.pressed.connect(_start_test_combat.bind(NIGHT_TESTBENCH_MAP, &"night"))
	grid.add_child(night)


func _start_test_combat(
	map_id: StringName, moment: StringName = DayNight.DEFAULT_MOMENT
) -> void:
	var squad := GameState.company.squad(_squad_ids)
	if squad.is_empty():
		return
	var map := CombatMap.load_map(map_id)
	if map == null:
		return
	var rng := GameState.combat_rng(_depth)
	DayNight.reinforce(
		map.board, moment, Region.night_roster(&"greenlands"),
		map.deployment_cells, rng, map.objective
	)
	_launch_with_map(
		map, GameState.company.to_units(squad), rng,
		_on_test_combat_finished, moment
	)


func _on_test_combat_finished(scene: Node) -> void:
	if not is_instance_valid(scene):
		return
	var summary := CombatRewards.summarise(scene.engine)
	if summary.is_empty():
		return
	CombatRewards.award_to(GameState.company.squad(_squad_ids), int(summary["experience"]))
	GameState.company.collect(Loot.roll(GameState.combat_rng(_depth + 1), summary, _depth))
	_depth += 1
	GameState.save()
	_build_squad_picker()
	visible = true


# --- Quitter et reprendre un combat ---------------------------------------

## Le joueur sauvegarde et rend la main depuis la pause. Le combat reste
## dans la sauvegarde ; l'écran de titre proposera de le reprendre.
func _save_and_leave_combat(scene: Node) -> void:
	GameState.save()
	if is_instance_valid(scene):
		scene.queue_free()
	_build_squad_picker()
	visible = true


## Rouvre le combat sauvegardé, exactement où il en était.
##
## LE MOTEUR EST DÉJÀ VIVANT : il a été reconstruit au chargement de la
## partie. La scène le reprend tel quel plutôt que de recharger une carte
## et de tout replacer — ce qui, pour la défense du royaume, serait
## d'ailleurs impossible : sa carte n'est dans aucun fichier.
func _resume_combat() -> void:
	if GameState.combat == null or GameState.combat.is_finished():
		GameState.clear_combat()
		return
	var packed: PackedScene = load(COMBAT_SCENE)
	if packed == null:
		return
	var scene: Node2D = packed.instantiate()
	scene.moment = GameState.combat_moment
	scene.adopt(GameState.combat, GameState.combat_map_id)
	scene.state_changed.connect(GameState.save)
	scene.save_and_quit_requested.connect(_save_and_leave_combat.bind(scene))
	# On reprend le chemin de fin qui correspond au combat repris : une
	# défense de royaume et une rencontre d'expédition ne se concluent pas
	# de la même façon.
	var on_done := _on_expedition_combat_finished
	if GameState.combat_map_id == DefenceMap.MAP_ID:
		on_done = _on_defence_finished
	elif GameState.expedition == null:
		on_done = _on_test_combat_finished
	scene.combat_finished.connect(func(_victory: bool) -> void:
		await get_tree().create_timer(2.5).timeout
		GameState.clear_combat()
		on_done.call(scene)
		if is_instance_valid(scene):
			scene.queue_free())
	get_tree().root.add_child(scene)
	visible = false


# --- Plomberie commune -----------------------------------------------------

func _launch(map_id: StringName, units: Array[Unit], rng: CombatRng, on_done: Callable) -> void:
	var map := CombatMap.load_map(map_id)
	if map != null:
		_launch_with_map(map, units, rng, on_done)


## Lance un combat sur une carte déjà construite. La défense du royaume
## (§ 38) en fabrique une qui n'est dans aucun fichier ; tout le reste du
## chemin est identique.
func _launch_with_map(
	map: CombatMap, units: Array[Unit], rng: CombatRng, on_done: Callable,
	moment: StringName = DayNight.DEFAULT_MOMENT
) -> void:
	var packed: PackedScene = load(COMBAT_SCENE)
	if packed == null:
		return
	var scene: Node2D = packed.instantiate()
	scene.moment = moment
	scene.configure_with_map(map, units, rng)
	# LE MOTEUR VIT DANS `GameState` DÈS SA CRÉATION. Sur mobile
	# l'application meurt à tout moment, y compris à la première
	# activation : attendre un « moment sûr » pour l'y mettre reviendrait
	# à choisir la fenêtre pendant laquelle on accepte de tout perdre.
	# LE SAC ENTRE EN COMBAT ET EN RESSORT. Il vit dans le moteur le temps
	# de la bataille — c'est l'annulation qui l'exige — et revient à la
	# compagnie une fois la dernière activation jouée.
	scene.engine.supplies = GameState.company.supplies.duplicate()
	GameState.combat = scene.engine
	GameState.combat_map_id = map.id
	GameState.combat_moment = moment
	scene.state_changed.connect(GameState.save)
	scene.save_and_quit_requested.connect(_save_and_leave_combat.bind(scene))
	GameState.save()
	scene.combat_finished.connect(func(_victory: bool) -> void:
		# On laisse la bannière de résultat à l'écran, puis on rend la main.
		await get_tree().create_timer(2.5).timeout
		# Ce qui reste dans le sac revient à la compagnie : les potions
		# bues sont bues, et elles manqueront au combat suivant. C'est
		# tout l'intérêt d'une réserve finie (§ 29).
		GameState.company.supplies = scene.engine.supplies.duplicate()
		# Le combat est fini : il n'a plus rien à faire dans la sauvegarde,
		# sinon « Reprendre » rouvrirait une bataille déjà jouée.
		GameState.clear_combat()
		on_done.call(scene)
		if is_instance_valid(scene):
			scene.queue_free())
	get_tree().root.add_child(scene)
	visible = false
	if is_instance_valid(_expedition_screen):
		_expedition_screen.visible = false


func _open(path: String, setup: Callable) -> Control:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var screen: Control = packed.instantiate()
	setup.call(screen)
	get_tree().root.add_child(screen)
	visible = false
	return screen


func _dismiss(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.queue_free()


## Le motif de fond, posé DERRIÈRE tout le reste. Un aplat noir est fade :
## rien n'y accroche la lumière et les panneaux flottent sur du vide.
func _lay_backdrop() -> void:
	UiSkin.lay_backdrop(self)
