class_name Tile
extends RefCounted

## Une case de la grille : son terrain, son occupant, son état.
##
## Les propriétés du terrain ne sont pas recopiées ici — elles sont lues
## dans `data/combat/terrain.json` à chaque question. Une tuile ne stocke
## que ce qui lui est propre : son type, qui l'occupe, et les points de
## vie d'un décor destructible.

## Aucune unité n'occupe la case.
const NO_OCCUPANT := -1

var cell: Vector2i
var terrain_id: StringName
var occupant_id: int = NO_OCCUPANT

## Points de vie du décor destructible (un pont). -1 s'il n'y en a pas.
var structure_hp: int = -1


func _init(at: Vector2i, terrain: StringName) -> void:
	cell = at
	set_terrain(terrain)


## Change le terrain et remet à jour les points de vie du décor.
func set_terrain(terrain: StringName) -> void:
	terrain_id = terrain
	if is_destructible():
		structure_hp = int(CombatRules.terrain_property(terrain_id, &"hit_points", 0))
	else:
		structure_hp = -1


func is_occupied() -> bool:
	return occupant_id != NO_OCCUPANT


func clear_occupant() -> void:
	occupant_id = NO_OCCUPANT


## Le terrain se marche-t-il ? Ne dit rien de l'occupant : une case
## d'herbe occupée reste marchable, elle n'est simplement pas libre.
func is_walkable() -> bool:
	return bool(CombatRules.terrain_property(terrain_id, &"walkable", false))


## Les unités aquatiques y circulent.
func is_swimmable() -> bool:
	return bool(CombatRules.terrain_property(terrain_id, &"swimmable", false))


## Une unité terrestre poussée ici meurt. C'est l'eau, et c'est l'outil
## tactique le plus puissant du jeu.
func is_lethal() -> bool:
	return bool(CombatRules.terrain_property(terrain_id, &"lethal", false))


func blocks_sight() -> bool:
	return bool(CombatRules.terrain_property(terrain_id, &"blocks_sight", false))


func move_cost() -> int:
	return int(CombatRules.terrain_property(terrain_id, &"move_cost", 1))


## Modificateur de dégâts subis par l'occupant : négatif en forêt qui
## protège, positif en ruine qui expose.
func damage_taken_modifier() -> int:
	return int(CombatRules.terrain_property(terrain_id, &"damage_taken", 0))


## Bonus de portée pour une unité à distance postée ici (colline).
func ranged_range_bonus() -> int:
	return int(CombatRules.terrain_property(terrain_id, &"ranged_range_bonus", 0))


## Bonus de dégâts pour une unité à distance postée ici (colline).
func ranged_damage_bonus() -> int:
	return int(CombatRules.terrain_property(terrain_id, &"ranged_damage_bonus", 0))


func is_destructible() -> bool:
	return bool(CombatRules.terrain_property(terrain_id, &"destructible", false))


## Inflige des dégâts au décor. Renvoie true si le décor cède.
func damage_structure(amount: int) -> bool:
	if not is_destructible() or structure_hp <= 0:
		return false
	structure_hp -= amount
	if structure_hp > 0:
		return false
	var becomes := StringName(CombatRules.terrain_property(
		terrain_id, &"becomes_when_destroyed", &"grass"
	))
	set_terrain(becomes)
	return true


## État sérialisable, pour la sauvegarde et le rejeu d'un combat.
func to_dictionary() -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y,
		"terrain": String(terrain_id),
		"occupant": occupant_id,
		"structure_hp": structure_hp,
	}


static func from_dictionary(data: Dictionary) -> Tile:
	var tile := Tile.new(
		Vector2i(int(data.get("x", 0)), int(data.get("y", 0))),
		StringName(data.get("terrain", "grass"))
	)
	tile.occupant_id = int(data.get("occupant", NO_OCCUPANT))
	tile.structure_hp = int(data.get("structure_hp", -1))
	return tile
