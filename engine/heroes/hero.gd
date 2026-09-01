class_name Hero
extends RefCounted

## Un héros : ce qui persiste quand le combat s'arrête.
##
## LA DIFFÉRENCE AVEC `Unit`, et elle est structurante. Une `Unit` est
## jetable : elle vit le temps d'un combat, porte des PV entamés, des PA
## dépensés, une case. Un `Hero` porte ce qui traverse les combats — un
## nom, une classe, un niveau, une expérience, des choix faits, un
## équipement — et fabrique une `Unit` au moment d'entrer sur la grille.
##
## Le sens de la dépendance compte : `Hero` connaît `Unit`, jamais
## l'inverse. Le combat n'a pas à savoir qu'il existe une campagne autour,
## et c'est ce qui permet de le tester seul.
##
## Toutes les modifications sont donc appliquées ICI, une fois, dans
## `effective_stats()`. `Unit.from_stats` reçoit un bloc déjà calculé et ne
## recalcule jamais rien.

var id: int = 0
var given_name: String = ""

## Départage deux héros du même nom dans une même compagnie. Vide tant
## qu'il n'y a pas d'homonyme.
var epithet: String = ""

var class_id: StringName = &""

## Couleur de faction, parmi les cinq du pack. Décide du sprite et du
## portrait, pas des statistiques.
var color: String = "Blue"

var level: int = 1
var experience: int = 0

## Choix retenus aux niveaux qui en demandent : niveau → identifiant
## d'option. Définitifs.
## Nœuds d'arbre appris, dans l'ordre où ils l'ont été.
##
## REMPLACE LES ANCIENS `choices` (un choix imposé aux niveaux 3, 6 et 9).
## Les six options d'alors sont devenues des nœuds : rien n'a été perdu, et
## le joueur choisit maintenant dans quel ORDRE il les prend. Deux monnaies
## de progression pour le même acte auraient été la complexité que le § 31
## refuse.
var learned: Array[StringName] = []

## Emplacement d'équipement → identifiant d'objet. Un emplacement absent
## est un emplacement vide.
var equipment: Dictionary = {}


static func create(
	hero_id: int, class_to_use: StringName, name_: String, faction_color: String = "Blue"
) -> Hero:
	if Unit.hero_class(class_to_use).is_empty():
		return null
	var hero := Hero.new()
	hero.id = hero_id
	hero.class_id = class_to_use
	hero.given_name = name_
	hero.color = faction_color
	return hero


## Fabrique un héros nommé au hasard, en évitant les homonymes de la
## compagnie. S'il n'a pas pu éviter l'homonymie, il reçoit une épithète —
## c'est exactement ce à quoi elle sert.
##
## Le tirage passe par `CombatRng` : une compagnie doit se régénérer à
## l'identique à partir de sa graine.
static func recruit(
	hero_id: int, class_to_use: StringName, rng: CombatRng,
	company: Array[Hero] = [], faction_color: String = "Blue"
) -> Hero:
	var taken: Array[String] = []
	for other: Hero in company:
		taken.append(other.given_name)
	var name_ := HeroNames.given(rng, taken)
	var hero := Hero.create(hero_id, class_to_use, name_, faction_color)
	if hero == null:
		return null
	if taken.has(name_):
		hero.epithet = HeroNames.epithet(rng)
	return hero


## Nom affiché : le prénom, et l'épithète s'il en a une.
func display_name() -> String:
	return given_name if epithet.is_empty() else "%s %s" % [given_name, epithet]


## La statistique qui définit la classe. Les gains la nomment `primary`
## plutôt que `strength` : la table serait fausse pour deux classes sur
## trois si elle codait la réponse en dur.
func primary_stat() -> StringName:
	return StringName(Unit.hero_class(class_id).get("primary_stat", "strength"))


# --- Expérience et niveaux -------------------------------------------------

## Ajoute de l'expérience. Renvoie le nombre de niveaux DISPONIBLES gagnés,
## sans les appliquer : une montée peut demander un choix, et c'est au
## joueur de le faire.
func add_experience(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := reachable_level()
	experience += amount
	return reachable_level() - before


## Le niveau que l'expérience actuelle autorise, plafond compris.
func reachable_level() -> int:
	var reached := 1
	for candidate in range(2, HeroProgression.max_level() + 1):
		if experience >= HeroProgression.experience_to_reach(candidate):
			reached = candidate
		else:
			break
	return reached


func can_level_up() -> bool:
	return level < reachable_level()


## Expérience qu'il reste à gagner avant le niveau suivant. Zéro au plafond.
func experience_to_next_level() -> int:
	if level >= HeroProgression.max_level():
		return 0
	return maxi(HeroProgression.experience_to_reach(level + 1) - experience, 0)


## Monte d'un niveau. Rien à trancher au moment de monter : le niveau
## donne un point, et le point se dépense dans l'arbre quand le joueur
## veut. C'est ce qui permet d'encaisser une expédition entière sans
## ouvrir un menu au milieu d'un combat.
func level_up() -> bool:
	if not can_level_up():
		return false
	level += 1
	return true


## Monte tous les niveaux disponibles. Rien ne bloque plus : les décisions
## vivent dans l'arbre, pas dans la montée.
func level_up_free() -> int:
	var gained := 0
	while can_level_up():
		if not level_up():
			break
		gained += 1
	return gained


# --- L'arbre de compétences (§ 34) -----------------------------------------

## Points gagnés depuis le niveau 1. Le niveau 1 n'en donne pas : on ne
## récompense pas d'exister.
func skill_points_earned() -> int:
	return maxi(level - 1, 0) * SkillTree.points_per_level()


func skill_points_left() -> int:
	return maxi(skill_points_earned() - learned.size(), 0)


func has_learned(node_id: StringName) -> bool:
	return learned.has(node_id)


## Pourquoi ce nœud n'est pas apprenable : vide s'il l'est.
func cannot_learn_because(node_id: StringName) -> StringName:
	if not SkillTree.exists(node_id) or SkillTree.class_of(node_id) != class_id:
		return &"unknown"
	if has_learned(node_id):
		return &"learned"
	var parent := SkillTree.requires(node_id)
	if not parent.is_empty() and not has_learned(parent):
		return &"locked"
	if skill_points_left() <= 0:
		return &"points"
	return &""


func can_learn(node_id: StringName) -> bool:
	return cannot_learn_because(node_id).is_empty()


## Apprend un nœud. Définitif : le § 33 fait de la progression du héros une
## suite de décisions, et une décision qu'on peut défaire n'en est pas une.
func learn(node_id: StringName) -> bool:
	if not can_learn(node_id):
		return false
	learned.append(node_id)
	return true


## Les compétences que le héros emmène au combat : celles de sa classe,
## plus celles que l'arbre a débloquées.
##
## L'ORDRE COMPTE — c'est celui de la barre de compétences du HUD, et les
## compétences de départ restent en tête : un joueur ne doit pas voir ses
## boutons bouger parce qu'il a appris quelque chose.
func combat_abilities() -> Array[StringName]:
	var out: Array[StringName] = []
	for ability_id: Variant in Unit.hero_class(class_id).get("abilities", []):
		out.append(StringName(ability_id))
	for node_id: StringName in learned:
		var gained := SkillTree.ability_of(node_id)
		if not gained.is_empty() and not out.has(gained):
			out.append(gained)
	return out


# --- Statistiques ----------------------------------------------------------

## Le bloc de statistiques dont le combat a besoin, tout appliqué : base de
## classe, gains de niveau, choix retenus, équipement.
##
## `bonuses` permet d'ajouter des modificateurs de l'extérieur sans que
## cette classe ait à les connaître — un bâtiment du royaume, une bénédiction
## d'expédition. Les clés sont celles du bloc de statistiques.
func effective_stats(bonuses: Dictionary = {}) -> Dictionary:
	var stats := Unit.hero_class(class_id).duplicate(true)
	if stats.is_empty():
		return {}
	var primary := primary_stat()

	for gained in range(2, level + 1):
		_apply(stats, HeroProgression.per_level(), primary)
		if gained % 2 == 0:
			_apply(stats, HeroProgression.every_other_level(), primary)

	for node_id: StringName in learned:
		_apply(stats, SkillTree.grants(node_id), primary)

	_apply(stats, equipment_bonuses(), primary)
	_apply(stats, _clean(bonuses), primary)
	return stats


## Somme des modificateurs de tout l'équipement porté.
func equipment_bonuses() -> Dictionary:
	var out := {}
	for slot: Variant in equipment.keys():
		var item_id := StringName(equipment[slot])
		if not Equipment.exists(item_id):
			continue
		for key: Variant in Equipment.grants(item_id).keys():
			out[key] = int(out.get(key, 0)) + int(Equipment.grants(item_id)[key])
	return out


## Objet porté à cet emplacement, ou vide.
func equipped(slot: StringName) -> StringName:
	return StringName(equipment.get(String(slot), ""))


## Ce héros peut-il porter cet objet ? Trois raisons de refuser : l'objet
## n'existe pas, son emplacement n'existe pas, ou sa classe n'y a pas droit.
func can_equip(item_id: StringName) -> bool:
	if not Equipment.exists(item_id):
		return false
	if not Equipment.is_slot(Equipment.slot_of(item_id)):
		return false
	return Equipment.allows(item_id, class_id)


## Équipe un objet. Renvoie ce qui occupait l'emplacement, ou une chaîne
## vide — c'est au roster de décider ce qu'il en fait, pas au héros de le
## jeter dans son dos.
func equip(item_id: StringName) -> StringName:
	if not can_equip(item_id):
		push_error("Hero : « %s » ne peut pas être porté par un %s" % [item_id, class_id])
		return &""
	var slot := Equipment.slot_of(item_id)
	var replaced := equipped(slot)
	equipment[String(slot)] = String(item_id)
	return replaced


## Retire ce qui occupe l'emplacement, et le renvoie.
func unequip(slot: StringName) -> StringName:
	var removed := equipped(slot)
	equipment.erase(String(slot))
	return removed


## Ajoute un bloc de gains à un bloc de statistiques. `primary` y est
## traduit en la statistique de la classe.
func _apply(stats: Dictionary, grants: Dictionary, primary: StringName) -> void:
	for key: Variant in grants.keys():
		var field := StringName(key)
		if field == HeroProgression.PRIMARY:
			field = primary
		stats[String(field)] = int(stats.get(String(field), 0)) + int(grants[key])


func _clean(raw: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in raw.keys():
		if not String(key).begins_with("_"):
			out[StringName(key)] = int(raw[key])
	return out


# --- Entrée en combat ------------------------------------------------------

## Fabrique l'unité de combat de ce héros, toutes modifications appliquées.
func to_unit(unit_id: int, slot: int = 0, bonuses: Dictionary = {}) -> Unit:
	var stats := effective_stats(bonuses)
	if stats.is_empty():
		return null
	var unit := Unit.from_stats(unit_id, class_id, Unit.Side.HEROES, Vector2i.ZERO, stats)
	unit.slot = slot
	# Les compétences apprises dans l'arbre entrent au combat ici, et
	# nulle part ailleurs : `Unit` ne sait pas ce qu'est un arbre, comme il
	# ne sait pas ce qu'est un niveau.
	unit.abilities = combat_abilities()
	return unit


func _learned_as_strings() -> Array:
	var out: Array = []
	for node_id: StringName in learned:
		out.append(String(node_id))
	return out


# --- Sérialisation ---------------------------------------------------------

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": given_name,
		"epithet": epithet,
		"class": String(class_id),
		"color": color,
		"level": level,
		"experience": experience,
		"learned": _learned_as_strings(),
		"equipment": equipment.duplicate(),
	}


static func from_dictionary(data: Dictionary) -> Hero:
	var hero := Hero.new()
	hero.id = int(data.get("id", 0))
	hero.given_name = String(data.get("name", ""))
	hero.epithet = String(data.get("epithet", ""))
	hero.class_id = StringName(data.get("class", ""))
	hero.color = String(data.get("color", "Blue"))
	hero.level = int(data.get("level", 1))
	hero.experience = int(data.get("experience", 0))
	for node_id: Variant in data.get("learned", []):
		# Un nœud retiré des données depuis la sauvegarde disparaît de
		# l'arbre, sans emporter le héros avec lui.
		if SkillTree.exists(StringName(node_id)):
			hero.learned.append(StringName(node_id))
	hero.equipment = (data.get("equipment", {}) as Dictionary).duplicate()
	return hero
