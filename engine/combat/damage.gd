class_name Damage
extends RefCounted

## La formule de dégâts, et rien d'autre.
##
##     dégâts = base de la compétence
##            + statistique d'échelle du lanceur
##            − défense de la cible
##            ± modificateur de terrain
##            borné au plancher de `rules.json`
##
## Elle est isolée ici pour une raison : le télégraphe annonce un chiffre
## avant que le coup ne parte, et le chiffre appliqué doit être le même.
## Une seule fonction calcule, tout le monde l'appelle — la prévision
## comme la résolution. Un télégraphe qui ment est pire qu'une absence de
## télégraphe.
##
## Aucun nombre ici : la base et l'échelle viennent de la compétence, la
## défense de la cible, le plancher de `rules.json`.


## Dégâts d'une compétence, terrain compris.
##
## `attacker_tile` donne le bonus de tir en hauteur — la colline ne sert
## qu'aux compétences à distance, un guerrier perché ne frappe pas plus
## fort. `target_tile` donne l'abri de la forêt et l'exposition de la
## ruine.
static func compute(
	attacker: Unit, ability: Ability, target: Unit,
	attacker_tile: Tile = null, target_tile: Tile = null
) -> int:
	if attacker == null or ability == null or target == null:
		return 0
	if not ability.is_attack():
		return 0

	var total := ability.damage
	if not ability.scaling.is_empty():
		total += attacker.stat(ability.scaling)
	total -= target.defence

	if attacker_tile != null and ability.range_max > 1:
		total += attacker_tile.ranged_damage_bonus()
	if target_tile != null:
		total += target_tile.damage_taken_modifier()

	return maxi(total, CombatRules.damage_minimum())
