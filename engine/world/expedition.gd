class_name Expedition
extends RefCounted

## Une sortie : la chaîne de rencontres du § 28, et la décision du § 29.
##
## LA CHAÎNE EST TIRÉE EN ENTIER AU DÉPART, pas rencontre par rencontre.
## « Rentrer maintenant, ou continuer ? » n'est une question que si le
## joueur voit ce qui l'attend ; une route qui se découvre pas à pas ne
## demande rien, elle se subit. Le § 28 dessine d'ailleurs la chaîne comme
## une suite qu'on lit d'un bout à l'autre.
##
## TROIS CHOSES FONT LA DÉCISION, et il en faut trois :
##  1. continuer RAPPORTE plus — c'est `depth` passé à `Loot.roll` ;
##  2. continuer COÛTE — rien ne se soigne, l'usure de T1.11 s'accumule ;
##  3. échouer PERD — la besace ne rejoint la compagnie qu'au retour.
## Enlever l'une des trois rend la réponse automatique, et la mécanique
## fondamentale du roguelite avec elle.
##
## LA BESACE. Ce que l'expédition ramasse reste dedans jusqu'au retour. Une
## déroute n'en rend qu'une part (§ 41 : une conséquence, pas une punition
## absolue) — assez pour que la sortie ait servi, pas assez pour qu'on s'y
## jette.
##
## CLASSE PURE. Aucun nœud, aucune sauvegarde, aucun signal : elle décrit
## un état et le fait avancer. C'est l'appelant qui l'écrit sur le disque,
## et il a intérêt à le faire — sur mobile, l'application meurt en pleine
## expédition.

enum State {
	ONGOING,   ## en route
	RETURNED,  ## rentré par ses propres moyens, ou la chaîne finie
	LOST,      ## l'équipe est tombée
}

## Étapes possibles. Le combat, le mini-boss et le boss se jouent sur une
## carte ; les autres se résolvent hors du plateau.
const KIND_COMBAT := &"combat"
const KIND_MINIBOSS := &"miniboss"
const KIND_BOSS := &"boss"
const KIND_REWARD := &"reward"

var region_id: StringName = &""
var state: int = State.ONGOING

## La route, du départ à la fin : { kind, map }. `map` est vide pour une
## étape qui ne se joue pas sur un plateau.
var steps: Array[Dictionary] = []

## Étape en cours. C'est aussi le nombre d'étapes franchies, donc la
## profondeur du § 29.
var index: int = 0

## Les héros partis, dans l'ordre où ils prendront leurs numéros d'unité.
var squad_ids: Array[int] = []

## Ce que l'expédition a ramassé et n'a pas encore ramené.
var satchel_gold: int = 0
var satchel_items: Array[StringName] = []

## PV portés d'une étape à l'autre : { identifiant de héros → PV }. Un
## héros absent de cette table part avec ses PV pleins.
var carried: Dictionary = {}


## Prépare une sortie. La chaîne est tirée ici, une fois pour toutes.
static func depart(region: StringName, heroes: Array[int], rng: CombatRng) -> Expedition:
	if not Region.exists(region):
		return null
	if not Region.is_unlocked(region):
		push_error("Expedition : la région « %s » est verrouillée" % region)
		return null

	var run := Expedition.new()
	run.region_id = region
	run.squad_ids = heroes.duplicate()
	run.steps = _build_chain(region, rng)
	if run.steps.is_empty():
		return null
	return run


## Le corps répété jusqu'à la longueur tirée, puis la fin, toujours la
## même. Une expédition courte n'est donc pas une expédition tronquée :
## elle a moins de corps, mais elle a son boss.
static func _build_chain(region: StringName, rng: CombatRng) -> Array[Dictionary]:
	var pattern := Region.chain_pattern(region)
	var tail := Region.chain_tail(region)
	if pattern.is_empty() and tail.is_empty():
		push_error("Expedition : la région « %s » n'a pas de chaîne" % region)
		return []

	var kinds: Array[StringName] = []
	var body := Region.body_length(region, rng)
	for i in body:
		if pattern.is_empty():
			break
		kinds.append(pattern[i % pattern.size()])
	kinds.append_array(tail)

	var out: Array[Dictionary] = []
	var previous: StringName = &""
	for depth in kinds.size():
		var kind := kinds[depth]
		var map_id := &""
		match kind:
			KIND_COMBAT:
				map_id = Region.draw_map(region, depth, rng, previous)
				previous = map_id
			KIND_MINIBOSS:
				map_id = Region.miniboss_map(region)
			KIND_BOSS:
				map_id = Region.boss_map(region)
		out.append({"kind": String(kind), "map": String(map_id)})
	return out


# --- Lire l'état -----------------------------------------------------------

func length() -> int:
	return steps.size()


## Étapes franchies. C'est la profondeur que `Loot.roll` fait grossir.
func depth() -> int:
	return index


func remaining() -> int:
	return maxi(steps.size() - index, 0)


func is_ongoing() -> bool:
	return state == State.ONGOING and index < steps.size()


func is_over() -> bool:
	return not is_ongoing()


func current() -> Dictionary:
	if not is_ongoing():
		return {}
	return steps[index]


func current_kind() -> StringName:
	return StringName(current().get("kind", ""))


func current_map() -> StringName:
	return StringName(current().get("map", ""))


## Vrai si l'étape en cours se joue sur un plateau.
func current_is_combat() -> bool:
	return not current_map().is_empty()


func step_kind(step_index: int) -> StringName:
	if step_index < 0 or step_index >= steps.size():
		return &""
	return StringName(steps[step_index].get("kind", ""))


## Le boss est la dernière étape : la battre est la seule façon de finir la
## chaîne, et c'est ce qui distingue une expédition menée à son terme d'une
## expédition dont on est rentré.
func is_complete() -> bool:
	return state == State.RETURNED and index >= steps.size()


func satchel() -> Dictionary:
	return {"gold": satchel_gold, "items": satchel_items.duplicate()}


# --- La décision du § 29 ---------------------------------------------------

## Rentrer n'est possible qu'une fois la première étape passée : partir
## pour faire demi-tour aussitôt n'est pas une décision.
func can_retreat() -> bool:
	return is_ongoing() and index >= ExpeditionRules.retreat_min_steps()


## Rentrer avec la besace intacte. Ce n'est pas un échec : c'est l'autre
## moitié de la question.
func retreat() -> bool:
	if not can_retreat():
		return false
	state = State.RETURNED
	return true


# --- Faire avancer la chaîne -----------------------------------------------

## Encaisse une rencontre terminée.
##
## `summary` vient de `CombatRewards.summarise`, `hero_units` sont les
## unités de l'équipe telles que le combat les laisse — c'est d'elles que
## viennent les PV portés à l'étape suivante.
##
## Renvoie ce qu'il faut montrer au joueur : { gold, items, downed, state }.
func resolve_combat(summary: Dictionary, hero_units: Array[Unit], rng: CombatRng) -> Dictionary:
	if not is_ongoing():
		return {}
	var downed := _absorb_health(hero_units)
	if not bool(summary.get("victory", false)):
		return _wipe(rng, downed)

	var gained := Loot.roll(rng, summary, depth())
	_gather(gained)
	_advance()
	return {
		"gold": int(gained.get("gold", 0)),
		"items": gained.get("items", [] as Array[StringName]),
		"downed": downed,
		"state": state,
	}


## L'évènement qui attend sur cette étape. Il se tire À L'ARRIVÉE, une
## seule fois, et se retient : la route dit « un évènement », pas lequel
## (§ 40 les appelle aléatoires), mais une partie rechargée doit retrouver
## celui qu'elle avait déjà découvert.
func reveal_event(rng: CombatRng) -> StringName:
	if not is_ongoing() or current_is_combat():
		return &""
	var step := steps[index]
	var known := StringName(step.get("event", ""))
	if not known.is_empty():
		return known

	var seen: Array = []
	for past: Dictionary in steps:
		var past_event := String(past.get("event", ""))
		if not past_event.is_empty():
			seen.append(past_event)
	var drawn := ExpeditionEvent.draw(rng, seen)
	step["event"] = String(drawn)
	return drawn


## Encaisse une étape qui ne se joue pas sur un plateau : évènement ou
## récompense.
##
## `effects` vient de `ExpeditionEvent.resolve`, donc des données — le dé
## y a déjà été jeté. L'étape de récompense du § 28 tire son butin toute
## seule si l'appelant ne lui donne rien.
##
## `purse` est la bourse de la compagnie, parce que le § 40 fait payer :
## une expédition dépense l'or du royaume, elle n'en a pas un second.
## Renvoie ce qu'il faut montrer, `gold` compris — négatif si l'étape a
## coûté.
func resolve_event(effects: Dictionary, rng: CombatRng, company: Company = null) -> Dictionary:
	if not is_ongoing():
		return {}
	var applied := effects.duplicate()
	if applied.is_empty() and current_kind() == KIND_REWARD:
		applied = Loot.roll(rng, {"victory": true, "enemies_downed": 0}, depth())

	# L'or d'un évènement passe par la bourse, pas par la besace : ce qu'on
	# dépense est déjà à soi, et ce qu'on gagne ici n'est pas un butin
	# qu'une déroute pourrait reprendre.
	var gold := int(applied.get("gold", 0))
	if company != null and gold != 0:
		company.gold = maxi(company.gold + gold, 0)
	elif gold > 0:
		satchel_gold += gold

	# `items` se lit de deux façons, et c'est voulu : un évènement déclare
	# COMBIEN d'objets il donne et les fait tirer ici, tandis qu'une étape
	# de récompense arrive avec la liste déjà tirée par `Loot.roll`.
	var found: Array[StringName] = []
	var wanted: Variant = applied.get("items", 0)
	if wanted is Array:
		found = _as_items(wanted)
	else:
		found = Loot.draw_items(
			rng, int(wanted), depth(), int(applied.get("rarity_bonus", 0))
		)
	_gather({"items": found})

	# Fuir coûte une part de la besace. C'est le même levier qu'une déroute,
	# à un tarif choisi par le joueur plutôt que subi.
	var kept := float(applied.get("satchel_kept", 1.0))
	var forfeited := {}
	if kept < 1.0:
		forfeited = _shed_satchel(kept, rng)

	var ambushed := bool(applied.get("combat", false))
	_advance(float(applied.get("health", 0.0)) + _reward_healing())
	if ambushed:
		_insert_combat(rng)

	var report := {
		"gold": gold,
		"items": found,
		"combat": ambushed,
		"state": state,
	}
	report.merge(forfeited)
	return report


func _reward_healing() -> float:
	if current_kind() != KIND_REWARD:
		return 0.0
	return ExpeditionRules.healing_on_reward_step()


## Intercale une rencontre ici. C'est ce que fait une embuscade : elle
## rallonge la route, ce qui est déjà un prix, et le combat qu'elle amène
## se tire comme les autres.
func _insert_combat(rng: CombatRng) -> void:
	var previous := &""
	if index > 0:
		previous = StringName(steps[index - 1].get("map", ""))
	var map_id := Region.draw_map(region_id, depth(), rng, previous)
	if map_id.is_empty():
		return
	steps.insert(index, {"kind": String(KIND_COMBAT), "map": String(map_id)})
	# La chaîne s'est rallongée : une expédition qu'on croyait finie ne
	# l'est plus.
	if state == State.RETURNED and index < steps.size():
		state = State.ONGOING


func _as_items(raw: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for item_id: Variant in raw:
		out.append(StringName(item_id))
	return out


func _gather(gained: Dictionary) -> void:
	satchel_gold += maxi(int(gained.get("gold", 0)), 0)
	for item_id: Variant in gained.get("items", []):
		var wanted := StringName(item_id)
		# Un objet retiré des données depuis le tirage disparaît de la
		# besace, sans emporter l'expédition avec lui.
		if Equipment.exists(wanted):
			satchel_items.append(wanted)


func _advance(health_change: float = 0.0) -> void:
	index += 1
	_change_health(ExpeditionRules.healing_between_steps() + health_change)
	if index >= steps.size():
		state = State.RETURNED


## L'équipe est tombée. Une part de la besace revient quand même.
func _wipe(rng: CombatRng, downed: Array[int]) -> Dictionary:
	state = State.LOST
	var kept := clampf(ExpeditionRules.satchel_kept_on_wipe(), 0.0, 1.0)
	var lost_gold := satchel_gold - int(floor(float(satchel_gold) * kept))
	satchel_gold -= lost_gold

	var lost_items := _shed_items(kept, rng)

	return {
		"gold": 0,
		"items": [] as Array[StringName],
		"downed": downed,
		"lost_gold": lost_gold,
		"lost_items": lost_items,
		"state": state,
	}


## Abandonne une part de la besace, or et objets. C'est le prix d'une
## déroute, et aussi celui d'une fuite : le même levier, subi dans un cas,
## choisi dans l'autre.
func _shed_satchel(kept: float, rng: CombatRng) -> Dictionary:
	var safe := clampf(kept, 0.0, 1.0)
	var lost_gold := satchel_gold - int(floor(float(satchel_gold) * safe))
	satchel_gold -= lost_gold
	return {"lost_gold": lost_gold, "lost_items": _shed_items(safe, rng)}


func _shed_items(kept: float, rng: CombatRng) -> Array[StringName]:
	var keep_count := int(floor(float(satchel_items.size()) * clampf(kept, 0.0, 1.0)))
	var lost_items: Array[StringName] = []
	if keep_count >= satchel_items.size():
		return lost_items
	# Le tirage décide de ce qui reste, pas la valeur : garder les meilleurs
	# annulerait la perte, garder les pires la doublerait.
	var order: Array = satchel_items
	if rng != null:
		order = rng.shuffled(satchel_items, &"shed_satchel")
	var survivors: Array[StringName] = []
	for i in order.size():
		if i < keep_count:
			survivors.append(StringName(order[i]))
		else:
			lost_items.append(StringName(order[i]))
	satchel_items = survivors
	return lost_items


# --- Les PV que l'équipe traîne derrière elle ------------------------------

## Relève les PV laissés par le combat. Renvoie les héros mis à terre.
##
## Un héros à terre n'est pas perdu (§ 25) et ne repart pas intact (§ 41) :
## il se relève à une fraction déclarée de ses PV. À zéro, il repartirait à
## terre au combat suivant — une mort définitive déguisée.
func _absorb_health(hero_units: Array[Unit]) -> Array[int]:
	var downed: Array[int] = []
	var recovery := ExpeditionRules.downed_recovery()
	for unit: Unit in hero_units:
		var hero_id := hero_id_of_unit(unit)
		if hero_id <= 0:
			continue
		var left := unit.hit_points
		if unit.is_downed():
			downed.append(hero_id)
			left = maxi(int(round(float(unit.max_hit_points) * recovery)), 1)
		carried[hero_id] = left
	return downed


## Rend ou retire une fraction des PV maximums à toute l'équipe.
##
## LE PLANCHER EST À UN PV, JAMAIS ZÉRO. Un autel du § 40 fait payer en
## sang ; il ne tue pas. Mourir dans le jeu se fait sur un plateau, où le
## joueur peut agir — pas dans un menu, où il ne peut que regarder.
func _change_health(fraction: float) -> void:
	if is_zero_approx(fraction) or carried.is_empty():
		return
	for hero_id: int in carried.keys():
		var maximum := int(_max_health.get(hero_id, 0))
		if maximum <= 0:
			continue
		var delta := int(round(float(maximum) * fraction))
		carried[hero_id] = clampi(int(carried[hero_id]) + delta, 1, maximum)


## PV maximums relevés au dernier passage : soigner une fraction demande de
## savoir de quoi. Ils viennent des unités, donc de `Hero.effective_stats`,
## donc de l'équipement porté au moment du combat.
var _max_health: Dictionary = {}


# --- L'équipe qui part -----------------------------------------------------

## Les unités de l'équipe, PV portés compris.
##
## LA NUMÉROTATION VIT ICI ET NULLE PART AILLEURS. `Company.to_units`
## numérote de 1 à n dans l'ordre de l'équipe ; c'est la seule façon de
## remonter d'une unité à son héros, et si les deux bouts de la règle
## étaient dans deux classes différentes, une équipe amputée d'un héros
## décalerait la table sans que rien ne le dise.
func squad_units(company: Company) -> Array[Unit]:
	if company == null:
		return []
	var heroes := company.squad(squad_ids)
	squad_ids.clear()
	for hero: Hero in heroes:
		squad_ids.append(hero.id)

	var units := company.to_units(heroes)
	for unit: Unit in units:
		var hero_id := hero_id_of_unit(unit)
		_max_health[hero_id] = unit.max_hit_points
		if carried.has(hero_id):
			unit.hit_points = clampi(int(carried[hero_id]), 0, unit.max_hit_points)
		else:
			# Un héros croisé pour la première fois part au complet, et il
			# entre dans la table tout de suite : sans ça, un évènement
			# rencontré avant son premier combat ne lui coûterait rien.
			carried[hero_id] = unit.hit_points
	return units


## Le héros derrière une unité de l'équipe. Zéro si l'unité n'en est pas.
func hero_id_of_unit(unit: Unit) -> int:
	if unit == null or unit.id < 1 or unit.id > squad_ids.size():
		return 0
	return squad_ids[unit.id - 1]


## Verse la besace à la compagnie et clôt l'expédition. Renvoie ce qui a
## été versé.
func bank(company: Company) -> Dictionary:
	if company == null or is_ongoing():
		return {}
	var payload := satchel()
	company.collect(payload)
	satchel_gold = 0
	satchel_items.clear()
	return payload


# --- Sérialisation ---------------------------------------------------------
#
# Une expédition perdue parce que le téléphone a tué l'application serait
# la pire des punitions, et le § 41 la refuse déjà pour la mort.

func to_dictionary() -> Dictionary:
	var items: Array = []
	for item_id: StringName in satchel_items:
		items.append(String(item_id))
	return {
		"region": String(region_id),
		"state": state,
		"index": index,
		"steps": steps.duplicate(true),
		"squad": squad_ids.duplicate(),
		"gold": satchel_gold,
		"items": items,
		"carried": carried.duplicate(),
		"max_health": _max_health.duplicate(),
	}


static func from_dictionary(data: Dictionary) -> Expedition:
	if data.is_empty():
		return null
	var run := Expedition.new()
	run.region_id = StringName(data.get("region", ""))
	run.state = int(data.get("state", State.ONGOING))
	run.index = int(data.get("index", 0))
	for step: Variant in data.get("steps", []):
		run.steps.append(step)
	for hero_id: Variant in data.get("squad", []):
		run.squad_ids.append(int(hero_id))
	run.satchel_gold = int(data.get("gold", 0))
	for item_id: Variant in data.get("items", []):
		if Equipment.exists(StringName(item_id)):
			run.satchel_items.append(StringName(item_id))
	for key: Variant in (data.get("carried", {}) as Dictionary):
		run.carried[int(key)] = int((data["carried"] as Dictionary)[key])
	for key: Variant in (data.get("max_health", {}) as Dictionary):
		run._max_health[int(key)] = int((data["max_health"] as Dictionary)[key])
	return run
