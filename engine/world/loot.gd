class_name Loot
extends RefCounted

## Ce qu'une rencontre laisse tomber (§ 30 et § 32).
##
## Trois fils, et ils ne servent pas à la même chose. L'OR est le fil sûr :
## il tombe toujours, proportionnellement à ce qu'on a abattu, et c'est lui
## qui alimentera le royaume. L'ÉQUIPEMENT est le fil incertain : il ne
## tombe pas à chaque fois, et sa rareté se tire aux poids déclarés. Un
## joueur qui perd repart quand même avec quelque chose — le § 41 refuse la
## punition absolue. LES POTIONS sont un troisième fil, tiré à part : une
## consommable n'a pas à prendre la place d'un objet qu'on garde, et le
## § 29 a besoin qu'elles arrivent en flux plutôt qu'en trouvaille.
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
## Renvoie { gold, items, supplies }.
static func roll(
	rng: CombatRng, summary: Dictionary, depth: int = 0, bonus: Dictionary = {}
) -> Dictionary:
	if rng == null or summary.is_empty():
		return {
			"gold": 0,
			"items": [] as Array[StringName],
			"supplies": [] as Array[StringName],
		}
	var downed := int(summary.get("enemies_downed", 0))
	var victory := bool(summary.get("victory", false))
	var deeper := 1.0 + number(&"depth", &"gold_per_step", 0.0) * float(maxi(depth, 0))
	deeper *= maxf(float(bonus.get("gold_multiplier", 1.0)), 0.0)

	return {
		"gold": _roll_gold(rng, downed, victory, deeper),
		"items": _roll_items(rng, victory, depth, int(bonus.get("rarity_bonus", 0))),
		"supplies": _roll_supplies(rng, victory, depth, int(bonus.get("rarity_bonus", 0))),
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


## Tire un nombre voulu de potions, sans passer par une rencontre.
##
## LES POTIONS SONT UN SECOND FIL, PAS UNE PART DU PREMIER. Mêlées au sac
## de l'équipement, elles auraient pris sa place : l'économie de
## l'équipement est mesurée au point de rareté, et une potion qui se boit
## n'est pas un remplacement acceptable pour un objet qu'on garde. Le
## joueur qui voit une fiole là où il espérait une épée se sent volé.
## `distinct` interdit de tirer deux fois la même. C'est ce dont un ÉTAL
## a besoin : deux fioles identiques côte à côte, c'est un rang perdu et
## un choix en moins. Un butin, lui, peut très bien rendre deux fois la
## même potion — c'est un stock, pas une vitrine.
static func draw_supplies(
	rng: CombatRng, count: int, depth: int, rarity_bonus: int = 0,
	distinct: bool = false
) -> Array[StringName]:
	var out: Array[StringName] = []
	if rng == null:
		return out
	for i in maxi(count, 0):
		var item_id := _roll_supply(rng, depth, rarity_bonus, out if distinct else [])
		if not item_id.is_empty():
			out.append(item_id)
	return out


static func _roll_supplies(
	rng: CombatRng, victory: bool, depth: int, rarity_bonus: int = 0
) -> Array[StringName]:
	var out: Array[StringName] = []
	var chance := number(
		&"supplies", &"on_victory" if victory else &"on_defeat", 0.0
	)
	chance += number(&"supplies", &"per_step", 0.0) * float(maxi(depth, 0))
	var limit := int(number(&"supplies", &"max_items", 1))

	for i in maxi(limit, 0):
		if not rng.chance(clampf(chance, 0.0, 1.0), &"loot_supply_drop"):
			continue
		var item_id := _roll_supply(rng, depth, rarity_bonus)
		if not item_id.is_empty():
			out.append(item_id)
	return out


## Une potion, tirée à la même échelle de rareté que l'équipement.
##
## LA MÊME ÉCHELLE, PAS UNE SECONDE. Les raretés et leurs poids vivent
## dans `equipment.json` et servent déjà à `verify_items` ; en écrire une
## seconde pour les potions garantirait que les deux divergent au premier
## ajout. Une potion déclare simplement à laquelle elle appartient.
static func _roll_supply(
	rng: CombatRng, depth: int, rarity_bonus: int = 0, taken: Array = []
) -> StringName:
	# L'ÉCHELLE EST RÉDUITE À CE QUI EXISTE, et sans ça le fil se tarit.
	# Il n'y a de potions que dans deux raretés sur cinq : au troisième
	# palier de profondeur, le plancher passait au-dessus de la meilleure
	# et le tirage ne trouvait plus rien. Filtrer AVANT de trancher fait
	# que « plus profond » veut dire « la meilleure qui existe » au lieu
	# de « plus rien ».
	var stocked: Array[StringName] = []
	for rarity: StringName in _rarity_ladder():
		for item_id: StringName in Consumable.ids():
			if Consumable.rarity_of(item_id) == rarity:
				stocked.append(rarity)
				break
	var chosen := _draw_rarity(
		rng, depth, rarity_bonus, &"loot_supply_rarity", stocked
	)
	if chosen.is_empty():
		return &""
	var candidates: Array[StringName] = []
	for item_id: StringName in Consumable.ids():
		if Consumable.rarity_of(item_id) == chosen and not taken.has(item_id):
			candidates.append(item_id)
	# LA RARETÉ CÈDE AVANT L'UNICITÉ : si tout ce qu'elle contient est déjà
	# pris, on élargit à ce qui reste plutôt que de rendre un rang vide.
	if candidates.is_empty():
		for item_id: StringName in Consumable.ids():
			if not taken.has(item_id):
				candidates.append(item_id)
	if candidates.is_empty():
		return &""
	candidates.sort()
	return StringName(rng.pick(candidates, &"loot_supply"))


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
	var chosen := _draw_rarity(rng, depth, rarity_bonus, &"loot_rarity")
	if chosen.is_empty():
		return &""

	var candidates: Array[StringName] = []
	for item_id: StringName in Equipment.ids():
		if Equipment.rarity_of(item_id) == chosen:
			candidates.append(item_id)
	if candidates.is_empty():
		return &""
	candidates.sort()
	return StringName(rng.pick(candidates, &"loot_item"))


## Tire une rareté aux poids déclarés, plancher relevé par la profondeur.
##
## La profondeur décale le tirage d'un cran tous les `rarity_step` : au
## fond d'une expédition, le commun cesse de sortir. `rarity_bonus`
## décale en plus, pour une source qui paie mieux qu'une rencontre.
##
## `reason` sépare les journaux du butin et des potions. La graine reste
## une seule suite — c'est une étiquette, pas un flux —, mais un journal
## où les deux tirages portent le même nom ne se relit pas.
##
## `ladder_override` réduit l'échelle à ce qu'une famille possède
## vraiment. Sans lui, une famille qui n'occupe que deux raretés sur cinq
## voit son plancher passer au-dessus de sa meilleure dès le troisième
## palier de profondeur, et ne tire plus rien.
static func _draw_rarity(
	rng: CombatRng, depth: int, rarity_bonus: int, reason: StringName,
	ladder_override: Array[StringName] = []
) -> StringName:
	var ladder := ladder_override if not ladder_override.is_empty() else _rarity_ladder()
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

	var draw := rng.int_between(1, total, reason)
	for rarity: StringName in pool:
		draw -= Equipment.rarity_weight(rarity)
		if draw <= 0:
			return rarity
	return pool[pool.size() - 1]


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
