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
## CE QU'IL NE COUVRE PAS, ET POURQUOI. Un script lancé par `-s` ne reçoit
## AUCUN autoload, et l'identifiant d'un singleton est résolu à la
## COMPILATION : tout script qui en nomme un échoue ici, pour une raison
## qui n'est pas un défaut du script. `autoload/` est donc exclu, et tout
## script qui cite un singleton l'est aussi — nommément, en le disant.
## Ceux-là sont couverts autrement, et mieux : `godot --headless --quit`
## démarre le projet avec ses singletons en place.
##
## LA LISTE DES SINGLETONS EST LUE DANS LES RÉGLAGES DU PROJET, jamais
## écrite ici : un autoload ajouté un jour et oublié dans cet outil
## rouvrirait le trou qu'il vient de boucher.
##
## L'ÉCHEC SE MESURE À `can_instantiate()`, PAS À `load() == null`. Un
## script qui ne compile pas revient quand même comme un GDScript valide,
## sa source chargée et son analyse en échec — et l'outil annonçait « tous
## les scripts compilent » juste après avoir affiché l'erreur. C'est le
## défaut que cet outil existait pour ne pas laisser passer.

const ROOTS: Array[String] = ["res://engine", "res://scenes", "res://tools"]

var _broken: Array[String] = []
var _skipped: Array[String] = []
var _singletons: Array[String] = []
var _checked := 0


func _init() -> void:
	print("Vérification des scripts du projet…\n")
	_singletons = _autoload_names()
	for root: String in ROOTS:
		_walk(root)

	print("Scripts analysés : %d" % _checked)
	if not _skipped.is_empty():
		# Les nommer, sinon le nombre rassurant du dessus cacherait une
		# zone d'ombre qui grandit sans qu'on la voie grandir.
		print("Non vérifiables hors du jeu (citent un singleton) : %d" % _skipped.size())
		for path: String in _skipped:
			print("  %s" % path)
	if _broken.is_empty():
		print("\nTous les scripts vérifiables compilent.")
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
	if _names_a_singleton(path):
		_skipped.append(path)
		return
	_checked += 1
	# L'erreur d'analyse part dans la console et on ne peut pas
	# l'intercepter ; mais un script qui ne compile pas ne s'instancie
	# pas, et ça, ça se lit.
	var script: Resource = load(path)
	if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
		_broken.append(path)


## Les noms de singleton déclarés dans le projet, lus dans les réglages.
func _autoload_names() -> Array[String]:
	var out: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var key := String(property.get("name", ""))
		if key.begins_with("autoload/"):
			out.append(key.trim_prefix("autoload/"))
	return out


## Vrai si le script nomme un singleton dans son CODE. Les commentaires ne
## comptent pas : trois fichiers en citent un pour expliquer qu'ils ne
## s'en servent pas, et les exclure pour ça reviendrait à ne plus vérifier
## les scripts les mieux documentés.
func _names_a_singleton(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var source := _without_comments(file.get_as_text())
	file.close()
	for name_: String in _singletons:
		var pattern := RegEx.create_from_string("\\b%s\\b" % name_)
		if pattern != null and pattern.search(source) != null:
			return true
	return false


## La source privée de ses commentaires. Un `#` entre guillemets reste un
## caractère de chaîne — les couleurs s'écrivent comme ça.
func _without_comments(source: String) -> String:
	var out := ""
	for line: String in source.split("\n"):
		var quoted := false
		var kept := ""
		for i in line.length():
			var glyph := line[i]
			if glyph == "\"":
				quoted = not quoted
			elif glyph == "#" and not quoted:
				break
			kept += glyph
		out += kept + "\n"
	return out
