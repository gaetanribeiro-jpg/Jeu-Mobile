class_name Loot
extends RefCounted

## Ce qu'une rencontre laisse tomber (§ 30 et § 32).
##
## Deux fils, et ils ne servent pas à la même chose. L'OR est le fil sûr :
## il tombe toujours, proportionnellement à ce qu'on a abattu, et c'est lui
## qui alimentera le royaume. L'ÉQUIPEMENT est le fil incertain : il ne
## tombe pas à chaque fois, et sa rareté se tire aux poids déclarés. Un
## joueur qui perd repart quand même avec quelque chose — le § 41 refuse la
## punition absolue.
##
## LA PROFONDEUR est le levier du § 29. Plus le joueur enchaîne les
## rencontres sans rentrer, plus `depth` monte, et plus le butin grossit :
## c'est ce qui rend « je rentre ou je continue ? » une vraie question.
## `Expedition` la fait monter d'une étape à l'autre ; hors expédition elle
## vaut zéro et ne change rien.
##
## TOUT PASSE PAR LA GRAINE. Un butin qui ne se rejoue pas à l'identique
## interdit de reproduire un bogue, et le roguelite en dépend.

const PATH := "res://data/world/loot.json"

static var _data: Dictionary = {}


## Vide le cache de données, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé — « Cannot reload script while
## instances exist », 472 fois par exécution des tests. Le cache n'était
## donc jamais vidé, et la table de données que le test croyait relire
## était celle du test précédent.
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Loot : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Loot : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Loot : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func number(section: StringName, key: StringName, fallback: float) -> float:
	var block: Dictionary = data().get(String(section), {})
	if not block.has(String(key)):
		push_error("Loot : « %s.%s » absent de loot.json" % [section, key])
		return fallback
	return float(block[String(key)])


## Le butin d'une rencontre terminée.
##
## `summary` est ce que rend `CombatRewards.summarise`. `depth` est le
## nombre de rencontres déjà enchaînées dans l'expédition.
##
## `bonus` est un supplément de circonstance : { gold_multiplier,
## rarity_bonus }. La nuit du § 36 passe par là. `Loot` reste ignorant de
## l'heure qu'il est — il reçoit un bonus, pas une horloge — sinon la
## table du butin devrait connaître le calendrier des expéditions, et
## chaque nouvelle circonstance viendrait s'y ajouter.
##
## Renvoie { gold, items }.
static func roll(
	rng: CombatRng, summary: Dictionary, depth: int = 0, bonus: Dictionary = {}
) -> Dictionary:
	if rng == null or summary.is_empty():
		return {"gold": 0, "items": [] as Array[StringName]}
	var downed := int(summary.get("enemies_downed", 0))
	var victory := bool(summary.get("victory", false))
	var deeper := 1.0 + number(&"depth", &"gold_per_step", 0.0) * float(maxi(depth, 0))
	deeper *= maxf(float(bonus.get("gold_multiplier", 1.0)), 0.0)

	return {
		"gold": _roll_gold(rng, downed, victory, deeper),
		"items": _roll_items(rng, victory, depth, int(bonus.get("rarity_bonus", 0))),
	}


static func _roll_gold(rng: CombatRng, downed: int, victory: bool, deeper: float) -> int:
	var base := number(&"gold", &"per_enemy", 0.0) * float(downed)
	if victory:
		base += number(&"gold", &"victory_bonus", 0.0)
	base *= deeper
	# La variance ne sert pas à surprendre, elle sert à ce que deux combats
	# identiques ne rendent pas exactement la même chose : sans elle, le
	# joueur calcule son or au lieu de le gagner.
	var spread := number(&"gold", &"variance", 0.0)
	var swing := 1.0 + (rng.unit_float(&"loot_gold") * 2.0 - 1.0) * spread
	return maxi(int(round(base * swing)), 0)


## Tire un nombre voulu d'objets, sans passer par une rencontre. C'est ce
## dont un évènement ou un coffre a besoin : ils donnent un objet sans
## qu'aucun ennemi ne soit tombé. `rarity_bonus` relève le plancher de
## rareté — un autel paie mieux qu'un tas de gravats.
static func draw_items(rng: CombatRng, count: int, depth: int, rarity_bonus: int = 0) -> Array[StringName]:
	var out: Array[StringName] = []
	if rng == null:
		return out
	for i in maxi(count, 0):
		var item_id := _roll_item(rng, depth, rarity_bonus)
		if not item_id.is_empty():
			out.append(item_id)
	return out


static func _roll_items(
	rng: CombatRng, victory: bool, depth: int, rarity_bonus: int = 0
) -> Array[StringName]:
	var out: Array[StringName] = []
	var chance := number(&"drop", &"on_victory" if victory else &"on_defeat", 0.0)
	chance += number(&"depth", &"drop_per_step", 0.0) * float(maxi(depth, 0))
	var limit := int(number(&"drop", &"max_items", 1))

	for i in maxi(limit, 0):
		if not rng.chance(clampf(chance, 0.0, 1.0), &"loot_drop"):
			continue
		var item_id := _roll_item(rng, depth, rarity_bonus)
		if not item_id.is_empty():
			out.append(item_id)
	return out


## Tire une rareté aux poids déclarés, puis un objet de cette rareté.
##
## La profondeur décale le tirage d'un cran tous les `rarity_step` : au
## fond d'une expédition, le commun cesse de sortir. `rarity_bonus` décale
## en plus, pour une source qui paie mieux qu'une rencontre.
static func _roll_item(rng: CombatRng, depth: int, rarity_bonus: int = 0) -> StringName:
	var ladder := _rarity_ladder()
	if ladder.is_empty():
		return &""
	var step := int(number(&"depth", &"rarity_step", 0))
	var floor_index := maxi(rarity_bonus, 0)
	if step > 0:
		floor_index += int(maxi(depth, 0) / step)
	floor_index = mini(floor_index, ladder.size() - 1)

	var pool: Array[StringName] = ladder.slice(floor_index)
	var total := 0
	for rarity: StringName in pool:
		total += Equipment.rarity_weight(rarity)
	if total <= 0:
		return &""

	var draw := rng.int_between(1, total, &"loot_rarity")
	var chosen: StringName = pool[pool.size() - 1]
	for rarity: StringName in pool:
		draw -= Equipment.rarity_weight(rarity)
		if draw <= 0:
			chosen = rarity
			break

	var candidates: Array[StringName] = []
	for item_id: StringName in Equipment.ids():
		if Equipment.rarity_of(item_id) == chosen:
			candidates.append(item_id)
	if candidates.is_empty():
		return &""
	candidates.sort()
	return StringName(rng.pick(candidates, &"loot_item"))


## Les raretés du plus commun au plus rare. L'ordre vient des poids, pas
## d'une liste écrite à la main : ajouter une rareté ne demande donc rien
## d'autre que de lui donner un poids.
static func _rarity_ladder() -> Array[StringName]:
	var out := Equipment.rarities()
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		if Equipment.rarity_weight(a) != Equipment.rarity_weight(b):
			return Equipment.rarity_weight(a) > Equipment.rarity_weight(b)
		return a < b)
	return out
