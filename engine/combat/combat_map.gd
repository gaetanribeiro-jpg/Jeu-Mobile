class_name CombatMap
extends RefCounted

## Charge une carte de combat écrite à la main (C1.26).
##
## Le terrain s'écrit en clair, une ligne par rangée, un caractère par
## case, avec les symboles de `terrain.json`. Une carte se relit d'un coup
## d'œil dans un éditeur de texte, et se corrige sans outil — ce qui vaut
## mieux qu'un éditeur graphique à écrire, à maintenir et à déboguer.
##
## Convention d'identifiants, pour que les objectifs puissent désigner
## leurs sujets sans ambiguïté :
##   1 à 99    les héros de l'escouade, posés par l'appelant
##   100 et +  les alliés fournis par la carte (le pion à escorter)
##   200 et +  les ennemis

const MAPS_DIR := "res://data/combat/maps/"

const ALLY_ID_BASE := 100
const ENEMY_ID_BASE := 200

var id: StringName = &""
var name_key: String = ""
var act: int = 1
var board: CombatBoard
var objective: CombatObjective

## Cases sur lesquelles le joueur PEUT poser ses héros. Il y en a plus que
## de héros : c'est ce qui fait du placement une décision plutôt qu'une
## formalité. La carte propose, le joueur dispose.
var deployment_cells: Array[Vector2i] = []


static func map_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open(MAPS_DIR)
	if dir == null:
		push_error("CombatMap : %s introuvable" % MAPS_DIR)
		return out
	var names := PackedStringArray()
	for name_ in dir.get_files():
		var clean: String = name_.trim_suffix(".remap")
		if clean.get_extension() == "json":
			names.append(clean.get_basename())
	# Tri sur des String : `Array[StringName].sort()` ne range pas dans
	# l'ordre alphabétique attendu, et les cartes sortaient à l'envers.
	names.sort()
	for name_: String in names:
		out.append(StringName(name_))
	return out


## Charge une carte. Renvoie null si elle est absente ou incohérente.
static func load_map(map_id: StringName, adjacency: String = "") -> CombatMap:
	var path := "%s%s.json" % [MAPS_DIR, map_id]
	if not FileAccess.file_exists(path):
		push_error("CombatMap : carte introuvable « %s »" % map_id)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CombatMap : « %s » n'est pas un objet JSON" % map_id)
		return null

	var data: Dictionary = parsed
	var rows := PackedStringArray()
	for row: Variant in data.get("rows", []):
		rows.append(String(row))
	var built := CombatBoard.from_rows(rows, adjacency)
	if built == null:
		return null

	var map := CombatMap.new()
	map.id = map_id
	map.name_key = String(data.get("name_key", ""))
	map.act = int(data.get("act", 1))
	map.board = built

	for pair: Variant in data.get("deployment_cells", []):
		map.deployment_cells.append(Vector2i(int(pair[0]), int(pair[1])))

	var next_ally := ALLY_ID_BASE
	for entry: Variant in data.get("allies", []):
		var ally := map._spawn(entry, next_ally, Unit.Side.HEROES)
		if ally == null:
			return null
		next_ally += 1

	var next_enemy := ENEMY_ID_BASE
	for entry: Variant in data.get("enemies", []):
		var enemy := map._spawn(entry, next_enemy, Unit.Side.ENEMIES)
		if enemy == null:
			return null
		next_enemy += 1

	map.objective = CombatObjective.from_dictionary(data.get("objective", {}))
	return map


## Moteur prêt à déployer. L'escouade n'est PAS posée : le combat s'ouvre
## sur la phase de placement, et c'est le joueur qui décide où chacun va.
func to_engine(squad: Array[Unit], rng: CombatRng = null) -> CombatEngine:
	var engine := CombatEngine.new(board, objective, rng)
	engine.set_deployment(deployment_cells, squad)
	return engine


func _spawn(entry: Variant, unit_id: int, side: int) -> Unit:
	var raw: Dictionary = entry
	var cell := Vector2i(int(raw["cell"][0]), int(raw["cell"][1]))
	var type_id := StringName(raw.get("type", ""))
	var unit: Unit = null
	if side == Unit.Side.ENEMIES:
		unit = Unit.from_enemy(unit_id, type_id, cell)
	else:
		unit = Unit.from_hero_class(unit_id, type_id, cell)
	if unit == null:
		return null
	if not board.place_unit(unit, cell):
		push_error("CombatMap : impossible de poser « %s » en %s" % [type_id, cell])
		return null
	return unit
