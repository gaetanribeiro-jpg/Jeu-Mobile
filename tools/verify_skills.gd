extends SceneTree

## Vérifie les arbres de compétences du § 34.
##
##     godot --headless --path . -s tools/verify_skills.gd
##
## POURQUOI. Un arbre est une structure, et une structure se casse en
## silence : un nœud dont le parent n'existe pas ne se voit pas, une
## branche qu'on ne peut jamais atteindre non plus, et un arbre qui boucle
## sur lui-même fait tourner l'écran sans fin.
##
## MAIS L'ESSENTIEL EST AILLEURS. Le § 35 promet des BUILDS — Guerrier Tank
## contre Guerrier Berserker. Deux branches ne sont un choix que si elles
## se valent : une branche qui donne deux fois plus que l'autre n'est pas
## une voie, c'est la bonne réponse et une erreur. Cet outil les PÈSE, au
## barème de l'équipement — les nœuds accordent les mêmes statistiques que
## les objets, et deux barèmes divergeraient dès la première retouche.

## Écart toléré entre deux branches, en part de la plus grosse.
const BRANCH_TOLERANCE := 0.25

var _problems: Array[String] = []


func _init() -> void:
	print("Vérification des arbres de compétences…\n")
	for class_id: StringName in Unit.hero_class_ids():
		_check_tree(class_id)

	if _problems.is_empty():
		print("\nLes arbres tiennent debout.")
		quit(0)
		return
	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	quit(1)


func _check_tree(class_id: StringName) -> void:
	if not SkillTree.has_tree(class_id):
		# Le § 34 en promet un par classe : une classe sans arbre ne
		# progresse plus au-delà de ses gains automatiques.
		_problems.append("%s : aucun arbre" % class_id)
		return

	var nodes := SkillTree.node_ids(class_id)
	var points := (HeroProgression.max_level() - 1) * SkillTree.points_per_level()
	print("%s — %d nœuds pour %d points" % [class_id, nodes.size(), points])

	if nodes.size() <= points:
		# Un arbre qu'on finit n'est plus un arbre, c'est une liste, et
		# deux Guerriers se ressembleraient.
		_problems.append("%s : l'arbre se termine (%d nœuds, %d points)"
			% [class_id, nodes.size(), points])

	var roots := SkillTree.roots_of(class_id)
	if roots.size() != 1:
		# Un joueur ne doit pas avoir à chercher par où commencer.
		_problems.append("%s : %d racines, il en faut une" % [class_id, roots.size()])

	for node_id: StringName in nodes:
		_check_node(class_id, node_id)

	_check_branches(class_id, roots)
	print("")


func _check_node(class_id: StringName, node_id: StringName) -> void:
	_check_translation(node_id, SkillTree.name_key(node_id))
	_check_translation(node_id, SkillTree.description_key(node_id))

	var parent := SkillTree.requires(node_id)
	if not parent.is_empty():
		if not SkillTree.exists(parent):
			_problems.append("%s : parent inconnu « %s »" % [node_id, parent])
		elif SkillTree.class_of(parent) != class_id:
			_problems.append("%s : son parent est d'une autre classe" % node_id)
		elif SkillTree.depth_of(node_id) >= 64:
			# Le garde-fou de `depth_of` s'est déclenché : l'arbre boucle.
			_problems.append("%s : l'arbre boucle sur lui-même" % node_id)

	var ability_id := SkillTree.ability_of(node_id)
	var gained := SkillTree.grants(node_id)
	if ability_id.is_empty() and gained.is_empty():
		_problems.append("%s : n'accorde rien" % node_id)
	if not ability_id.is_empty() and not gained.is_empty():
		# Comparer deux nœuds demanderait de comparer des choses qui ne se
		# comparent pas.
		_problems.append("%s : accorde à la fois une compétence et des statistiques" % node_id)

	if ability_id.is_empty():
		print("  %-14s %-4s %s" % [node_id, "·".repeat(SkillTree.depth_of(node_id)), _grants(gained)])
		return

	var ability := Ability.of(ability_id)
	if ability == null:
		_problems.append("%s : compétence inconnue « %s »" % [node_id, ability_id])
		return
	if ability.class_id != class_id:
		_problems.append("%s : la compétence « %s » est celle des %s"
			% [node_id, ability_id, ability.class_id])
	if Unit.hero_class(class_id).get("abilities", []).has(String(ability_id)):
		# Un nœud qui débloque une compétence qu'on a déjà fait payer un
		# point pour rien.
		_problems.append("%s : « %s » est déjà une compétence de départ" % [node_id, ability_id])
	print("  %-14s %-4s compétence %s" % [
		node_id, "·".repeat(SkillTree.depth_of(node_id)), ability_id
	])


## Le § 35 promet des builds. Deux branches ne sont un choix que si elles
## se valent : on les pèse au barème de l'équipement.
func _check_branches(class_id: StringName, roots: Array[StringName]) -> void:
	if roots.is_empty():
		return
	var fork := _first_fork(roots[0])
	if fork.is_empty():
		_problems.append("%s : l'arbre n'a aucune bifurcation — c'est une liste" % class_id)
		return

	var branches := SkillTree.children_of(fork)
	var weights: Array[float] = []
	var names := PackedStringArray()
	for branch: StringName in branches:
		var weight := _weigh(branch)
		weights.append(weight)
		names.append("%s %.1f" % [branch, weight])
	print("  bifurcation à %s : %s" % [fork, ", ".join(names)])

	var heaviest := 0.0
	var lightest := 0.0
	for weight: float in weights:
		heaviest = maxf(heaviest, weight)
		lightest = minf(lightest, weight) if lightest > 0.0 else weight
	if heaviest <= 0.0:
		return
	if (heaviest - lightest) / heaviest > BRANCH_TOLERANCE:
		_problems.append(
			"%s : une branche vaut %.1f et l'autre %.1f — ce n'est pas un choix"
			% [class_id, heaviest, lightest])


## Le premier nœud qui a plus d'un enfant, en descendant depuis la racine.
func _first_fork(node_id: StringName) -> StringName:
	var children := SkillTree.children_of(node_id)
	if children.size() > 1:
		return node_id
	if children.is_empty():
		return &""
	return _first_fork(children[0])


## Ce que vaut une branche entière, nœud de départ compris. Une compétence
## ne se pèse pas au barème des statistiques : on la compte pour ce qu'un
## point de compétence vaut, faute de mieux, et on le dit.
func _weigh(node_id: StringName) -> float:
	var total := Equipment.price_of_grants(SkillTree.grants(node_id))
	if SkillTree.is_ability_node(node_id):
		total += ability_weight()
	for child: StringName in SkillTree.children_of(node_id):
		total += _weigh(child)
	return total


## Ce qu'on compte pour un nœud de compétence. Une compétence ne se pèse
## pas au barème des statistiques — elle change ce qu'on PEUT faire, pas
## de combien. On l'aligne sur un point d'action, le gain le plus fort du
## barème, et c'est une convention assumée plutôt qu'une mesure.
func ability_weight() -> float:
	return Equipment.price_of_grants({&"action_points": 1})


func _grants(gained: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in gained.keys():
		pieces.append("%s %+d" % [key, int(gained[key])])
	return ", ".join(pieces)


func _check_translation(owner_id: StringName, key: String) -> void:
	if key.is_empty():
		_problems.append("%s : pas de clé de texte" % owner_id)
	elif TranslationServer.translate(key) == key:
		_problems.append("%s : la clé « %s » n'est pas traduite" % [owner_id, key])
