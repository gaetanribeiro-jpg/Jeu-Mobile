class_name CombatIntent
extends RefCounted

## Ce qu'un ennemi annonce faire à sa prochaine activation.
##
## LE télégraphe (vision § 39) : information parfaite, toujours. Le joueur
## voit les cases visées et les dégâts chiffrés avant d'agir, et son tour
## consiste à répondre à une question claire — comment j'empêche ça ?
## Trois réponses : sortir de la case, mettre l'ennemi à terre avant, ou
## le déplacer pour dévier son attaque.
##
## C'est la troisième réponse qui dicte la forme de cette classe. Une
## intention ne retient PAS une case absolue, elle retient un décalage par
## rapport à l'attaquant. Pousser un gobelin déplace donc sa zone de
## menace avec lui, et le télégraphe se recalcule tout seul pendant que le
## joueur essaie des coups. S'il retenait une case absolue, pousser
## l'attaquant laisserait son attaque frapper le vide à l'endroit d'avant :
## illisible, et faux.
##
## Corollaire : ni les dégâts ni la zone ne sont stockés. La zone se
## redéduit de la compétence, les dégâts du terrain de l'attaquant et de
## celui de la cible — qui changent tous les deux quand on pousse. Tout est
## relu au moment de l'affichage, ce qui garantit que le chiffre annoncé
## est le chiffre appliqué.

## LE SOUTIEN EST UNE TROISIÈME INFORMATION, pas une attaque négative.
##
## Le § 39 demande l'information parfaite : si un ennemi va rendre vingt
## points de vie à son voisin, le joueur doit le savoir AVANT de décider
## qui il frappe — c'est même la seule façon dont la question « qui tuer
## d'abord » se pose honnêtement. Un soin caché rendrait la mise à terre
## d'un blessé aléatoire du point de vue du joueur.
##
## POURQUOI PAS DES DÉGÂTS NÉGATIFS. `_resolve_heal` en rend, et c'est
## juste pour un JOURNAL qu'on rejoue. Mais le télégraphe se PEINT : une
## case de soin dans le rouge de la menace, ou pire, additionnée au total
## d'une case menacée, ferait lire un chiffre faux. Même raisonnement que
## la case d'arrivée d'une poussée en T12.1.
enum Kind { NONE, ATTACK, SUPPORT }

var attacker_id: int = -1
var kind: int = Kind.NONE

## Compétence annoncée. C'est elle qui donne la forme de la zone : le
## télégraphe d'une Boule de feu montre cinq cases sans que personne n'ait
## eu à les écrire.
var ability_id: StringName = &""

## Case visée, EN DÉCALAGE par rapport à la case de l'attaquant.
var target_offset: Vector2i = Vector2i.ZERO


static func none(unit_id: int) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = unit_id
	intent.kind = Kind.NONE
	return intent


## Attaque annoncée, exprimée depuis la position de l'attaquant.
static func attack(unit_id: int, ability_to_use: StringName, offset: Vector2i) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = unit_id
	intent.kind = Kind.ATTACK
	intent.ability_id = ability_to_use
	intent.target_offset = offset
	return intent


## Attaque sur une case, exprimée en cases absolues.
static func attack_cell(
	unit_id: int, ability_to_use: StringName, from: Vector2i, to: Vector2i
) -> CombatIntent:
	return attack(unit_id, ability_to_use, to - from)


## Soutien annoncé — un soin porté à un allié, exprimé depuis la position
## du lanceur, comme une attaque.
static func support(unit_id: int, ability_to_use: StringName, offset: Vector2i) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = unit_id
	intent.kind = Kind.SUPPORT
	intent.ability_id = ability_to_use
	intent.target_offset = offset
	return intent


## Soutien sur une case, exprimé en cases absolues.
static func support_cell(
	unit_id: int, ability_to_use: StringName, from: Vector2i, to: Vector2i
) -> CombatIntent:
	return support(unit_id, ability_to_use, to - from)


func is_attack() -> bool:
	return kind == Kind.ATTACK


func is_support() -> bool:
	return kind == Kind.SUPPORT


## Une intention annoncée, quelle qu'elle soit. C'est ce qui décide si
## l'activation a quelque chose à exécuter.
func is_declared() -> bool:
	return kind != Kind.NONE


func ability() -> Ability:
	return Ability.of(ability_id) if is_declared() else null


## Case visée, depuis la position actuelle de l'attaquant.
func target_cell(attacker_cell: Vector2i) -> Vector2i:
	return attacker_cell + target_offset


## Cases réellement menacées, zone de la compétence comprise, depuis la
## position actuelle de l'attaquant.
func target_cells(attacker_cell: Vector2i, grid: Grid) -> Array[Vector2i]:
	if not is_declared():
		return []
	var used := ability()
	if used == null:
		return []
	return used.area_cells(grid, attacker_cell, target_cell(attacker_cell))


func to_dictionary() -> Dictionary:
	return {
		"attacker_id": attacker_id,
		"kind": kind,
		"ability": String(ability_id),
		"offset": [target_offset.x, target_offset.y],
	}


static func from_dictionary(data: Dictionary) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = int(data.get("attacker_id", -1))
	intent.kind = int(data.get("kind", Kind.NONE))
	intent.ability_id = StringName(data.get("ability", ""))
	var pair: Array = data.get("offset", [0, 0])
	intent.target_offset = Vector2i(int(pair[0]), int(pair[1]))
	return intent
