class_name CombatIntent
extends RefCounted

## Ce qu'un ennemi annonce faire au tour suivant.
##
## LA décision centrale du jeu (§ 4.2) : information parfaite, toujours.
## Le joueur voit les cases visées et les dégâts chiffrés avant d'agir, et
## son tour consiste à répondre à une question claire — comment j'empêche
## ça ? Trois réponses : sortir de la case, tuer l'ennemi avant, ou
## déplacer l'ennemi pour dévier son attaque.
##
## C'est la troisième réponse qui dicte la forme de cette classe. Une
## intention ne retient PAS des cases absolues, elle retient des décalages
## par rapport à l'attaquant. Pousser un gobelin déplace donc sa zone de
## menace avec lui, et le télégraphe se recalcule tout seul pendant que le
## joueur essaie des coups. S'il retenait des cases absolues, pousser
## l'attaquant laisserait son attaque frapper le vide à l'endroit d'avant :
## illisible, et faux.
##
## Corollaire : les dégâts ne sont pas stockés non plus. Ils dépendent du
## terrain de l'attaquant et de celui de la cible, qui changent tous les
## deux quand on pousse. Ils sont relus dans `CombatBoard.predicted_damage`
## au moment de l'affichage, ce qui garantit que le chiffre annoncé est le
## chiffre appliqué.

enum Kind { NONE, ATTACK }

var attacker_id: int = -1
var kind: int = Kind.NONE

## Cases visées, EN DÉCALAGE par rapport à la case de l'attaquant.
var offsets: Array[Vector2i] = []


static func none(unit_id: int) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = unit_id
	intent.kind = Kind.NONE
	return intent


static func attack(unit_id: int, target_offsets: Array[Vector2i]) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = unit_id
	intent.kind = Kind.ATTACK
	intent.offsets = target_offsets.duplicate()
	return intent


## Attaque sur une case unique, exprimée depuis la position de l'attaquant.
static func attack_cell(unit_id: int, from: Vector2i, to: Vector2i) -> CombatIntent:
	return attack(unit_id, [to - from] as Array[Vector2i])


func is_attack() -> bool:
	return kind == Kind.ATTACK


## Cases réellement visées, depuis la position actuelle de l'attaquant.
func target_cells(attacker_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset: Vector2i in offsets:
		out.append(attacker_cell + offset)
	return out


func to_dictionary() -> Dictionary:
	var raw: Array = []
	for offset: Vector2i in offsets:
		raw.append([offset.x, offset.y])
	return {"attacker_id": attacker_id, "kind": kind, "offsets": raw}


static func from_dictionary(data: Dictionary) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.attacker_id = int(data.get("attacker_id", -1))
	intent.kind = int(data.get("kind", Kind.NONE))
	var out: Array[Vector2i] = []
	for pair: Variant in data.get("offsets", []):
		out.append(Vector2i(int(pair[0]), int(pair[1])))
	intent.offsets = out
	return intent
