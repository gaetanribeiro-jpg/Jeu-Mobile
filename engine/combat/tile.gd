class_name Tile
extends RefCounted

## Une case de la grille : son terrain, son occupant, son état.
##
## Les propriétés du terrain ne sont pas recopiées ici — elles sont lues
## dans `data/combat/terrain.json` à chaque question. Une tuile ne stocke
## que ce qui lui est propre : son type, qui l'occupe, les points de vie
## d'un décor destructible, et le compte à rebours d'un terrain
## temporaire.
##
## LE TERRAIN TEMPORAIRE (§ 19). Le feu que laisse le Torch Goblin ne
## remplace pas l'herbe pour toujours : il la recouvre quelques rondes,
## puis s'éteint et la rend. C'est pour ça que la tuile retient le terrain
## d'AVANT — sans lui, un incendie transformerait durablement une forêt en
## prairie, et la carte ne serait plus celle que l'auteur a écrite.

## Aucune unité n'occupe la case.
const NO_OCCUPANT := -1

var cell: Vector2i
var terrain_id: StringName
var occupant_id: int = NO_OCCUPANT

## Points de vie du décor destructible (un pont). -1 s'il n'y en a pas.
var structure_hp: int = -1

## Rondes restantes avant que le terrain temporaire ne s'éteigne. 0 quand
## le terrain est permanent.
var terrain_turns_left: int = 0

## Terrain que le temporaire recouvre, et auquel la case reviendra.
var terrain_before: StringName = &""


func _init(at: Vector2i, terrain: StringName) -> void:
	cell = at
	set_terrain(terrain)


## Change le terrain et remet à jour les points de vie du décor.
func set_terrain(terrain: StringName) -> void:
	terrain_id = terrain
	terrain_turns_left = 0
	terrain_before = &""
	if is_destructible():
		structure_hp = int(CombatRules.terrain_property(terrain_id, &"hit_points", 0))
	else:
		structure_hp = -1


## Cette case peut-elle prendre feu ? Ni l'eau, ni la pierre.
func is_flammable() -> bool:
	return bool(CombatRules.terrain_property(terrain_id, &"flammable", false))


## Dégâts que subit celui qui commence son activation ici.
func damage_per_activation() -> int:
	return int(CombatRules.terrain_property(terrain_id, &"damage_per_activation", 0))


func is_temporary() -> bool:
	return terrain_turns_left > 0


## Recouvre la case d'un terrain qui s'éteindra. Refuse si la case ne peut
## pas le porter — on n'allume pas un feu sur l'eau.
##
## Recouvrir une case DÉJÀ recouverte ne fait que rallumer le compteur :
## sinon deux torches d'affilée feraient perdre le terrain d'origine, et
## la case resterait en cendres pour toujours.
func cover_with(terrain: StringName, duration: int = -1) -> bool:
	if duration == 0 or not is_flammable():
		return false
	var before := terrain_before if is_temporary() else terrain_id
	var turns := duration
	if turns < 0:
		turns = int(CombatRules.terrain_property(terrain, &"duration", 0))
	if turns <= 0:
		return false
	set_terrain(terrain)
	terrain_before = before
	terrain_turns_left = turns
	return true


## Fait passer une ronde au terrain temporaire. Renvoie true s'il s'éteint.
func tick_terrain() -> bool:
	if not is_temporary():
		return false
	terrain_turns_left -= 1
	if terrain_turns_left > 0:
		return false
	var back := terrain_before
	if back.is_empty():
		back = StringName(CombatRules.terrain_property(terrain_id, &"reverts_to", &"grass"))
	set_terrain(back)
	return true


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
		"terrain_turns_left": terrain_turns_left,
		"terrain_before": String(terrain_before),
	}


static func from_dictionary(data: Dictionary) -> Tile:
	var tile := Tile.new(
		Vector2i(int(data.get("x", 0)), int(data.get("y", 0))),
		StringName(data.get("terrain", "grass"))
	)
	tile.occupant_id = int(data.get("occupant", NO_OCCUPANT))
	tile.structure_hp = int(data.get("structure_hp", -1))
	tile.terrain_turns_left = int(data.get("terrain_turns_left", 0))
	tile.terrain_before = StringName(data.get("terrain_before", ""))
	return tile
