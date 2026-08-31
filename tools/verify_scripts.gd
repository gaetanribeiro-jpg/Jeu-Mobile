extends SceneTree

## Charge tous les scripts du projet et signale ceux qui ne compilent pas.
##
##     godot --headless --path . -s tools/verify_scripts.gd
##
## POURQUOI CET OUTIL EXISTE. `godot --headless --quit` n'analyse que ce
## que la scène principale atteint. Tout ce qui est chargé à l'exécution —
## un `set_script(load(...))`, un outil de `tools/`, un script de vue
## instancié à la volée — passe entre les mailles : le projet démarre
## proprement, et la faute n'apparaît qu'au moment précis où l'on ouvre
## l'écran concerné. Deux scripts sont partis cassés dans le dépôt pour
## cette raison exacte avant que cet outil n'existe.
##
## CE QU'IL NE COUVRE PAS, ET POURQUOI. `autoload/` est exclu : ces
## scripts se désignent entre eux par leur nom de singleton — SaveManager
## appelle `EventBus.game_saved` — et un singleton n'existe qu'une fois le
## jeu démarré. Les charger isolément échouerait toujours, pour une raison
## qui n'est pas un défaut. Ils sont couverts autrement, et mieux :
## `godot --headless --quit` les instancie tous au démarrage du projet.

const ROOTS: Array[String] = ["res://engine", "res://scenes", "res://tools"]

var _broken: Array[String] = []
var _checked := 0


func _init() -> void:
	print("Vérification des scripts du projet…\n")
	for root: String in ROOTS:
		_walk(root)

	print("Scripts analysés : %d (autoload/ exclu, voir l'en-tête)" % _checked)
	if _broken.is_empty():
		print("\nTous les scripts compilent.")
		quit(0)
		return
	print("Scripts en échec : %d" % _broken.size())
	for path: String in _broken:
		print("  %s" % path)
	quit(1)


func _walk(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [directory, entry]
		if dir.current_is_dir():
			_walk(path)
		elif entry.trim_suffix(".remap").get_extension() == "gd":
			_check(path.trim_suffix(".remap"))
		entry = dir.get_next()
	dir.list_dir_end()


func _check(path: String) -> void:
	_checked += 1
	# `load` renvoie null et pousse l'erreur d'analyse dans la console : on
	# ne peut pas l'intercepter, mais on peut compter les échecs et les
	# nommer, ce qui suffit à rendre l'outil utilisable.
	var script: Resource = load(path)
	if script == null or not (script is GDScript):
		_broken.append(path)
