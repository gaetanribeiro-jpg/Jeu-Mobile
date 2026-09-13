extends Node

## Bus de signaux global.
##
## Règle d'architecture : les systèmes ne se référencent jamais directement
## entre eux, ils passent par ici. Une scène de combat n'appelle pas
## `get_node("/root/City")` ; elle émet `combat_ended` et la ville écoute.
##
## Convention : les signaux sont nommés au passé (`unit_died`, pas `die_unit`).
## Ils décrivent un fait accompli, jamais un ordre.

# --- Combat ---
signal combat_started(seed_value: int)
signal combat_ended(victory: bool)
signal turn_started(side: int, turn_index: int)
signal turn_ended(side: int, turn_index: int)
signal unit_moved(unit_id: int, from: Vector2i, to: Vector2i)
signal unit_attacked(attacker_id: int, target_id: int, damage: int)
signal unit_pushed(unit_id: int, from: Vector2i, to: Vector2i)
signal unit_downed(unit_id: int)
signal telegraph_updated

# --- Héros et Ordre ---
signal hero_recruited(hero_id: int)
signal hero_wounded(hero_id: int, wound_count: int)
signal hero_died(hero_id: int)
signal hero_leveled_up(hero_id: int, level: int)
signal order_rank_reached(class_id: StringName, rank: int)

# --- Ville et économie ---
signal resources_changed
signal building_constructed(building_id: StringName, level: int)
signal season_ended(season_index: int)
signal threat_changed(value: int)

# --- Expédition ---
signal expedition_started(plot_id: StringName)
signal expedition_node_entered(node_index: int)
signal expedition_ended(abandoned: bool)

# --- Système ---
signal game_saved
signal game_loaded
