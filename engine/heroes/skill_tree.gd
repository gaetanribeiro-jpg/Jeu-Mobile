class_name SkillTree
extends RefCounted

## Les arbres de compétences du § 34, lus dans
## `data/heroes/skill_trees.json`.
##
## IL REMPLACE LES CHOIX DE NIVEAU, il ne s'ajoute pas à eux. Deux monnaies
## de progression pour le même acte — monter d'un niveau — auraient été la
## complexité que le § 31 refuse. Les six anciennes options n'ont rien
## perdu : elles sont devenues des nœuds, et le joueur choisit maintenant
## dans quel ORDRE il les prend, pas seulement laquelle.
##
## UN TRONC, DEUX BRANCHES. Le tronc est l'identité de la classe ; les
## branches sont les builds du § 35. Onze nœuds pour neuf points : on ne
## prend pas tout, et c'est ce qui fait qu'un Guerrier ne ressemble pas à
## un autre Guerrier.
##
## LA CLASSE GARDE SES TROIS COMPÉTENCES DE DÉPART. L'arbre en ajoute, il
## n'en reprend aucune : un héros de niveau 1 doit pouvoir jouer, et
## l'équilibrage mesuré en T1.11 et T1.14 suppose ces trois-là.

const PATH := "res://data/heroes/skill_trees.json"

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
		push_error("SkillTree : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("SkillTree : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SkillTree : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func points_per_level() -> int:
	return int(data().get("points_per_level", 0))


static func _tree_of(class_id: StringName) -> Dictionary:
	return (data().get("trees", {}) as Dictionary).get(String(class_id), {})


static func has_tree(class_id: StringName) -> bool:
	return not _tree_of(class_id).is_empty()


## Les nœuds d'une classe, dans l'ordre du fichier — qui est l'ordre de
## lecture de l'arbre, du tronc vers les branches.
static func node_ids(class_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in _tree_of(class_id).keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


## La classe à laquelle appartient un nœud, ou rien.
static func class_of(node_id: StringName) -> StringName:
	for key: String in (data().get("trees", {}) as Dictionary).keys():
		if (data()["trees"][key] as Dictionary).has(String(node_id)):
			return StringName(key)
	return &""


static func exists(node_id: StringName) -> bool:
	return not class_of(node_id).is_empty()


static func node(node_id: StringName) -> Dictionary:
	var class_id := class_of(node_id)
	if class_id.is_empty():
		push_error("SkillTree : nœud inconnu « %s »" % node_id)
		return {}
	return _tree_of(class_id)[String(node_id)]


static func name_key(node_id: StringName) -> String:
	return String(node(node_id).get("name_key", ""))


static func description_key(node_id: StringName) -> String:
	return String(node(node_id).get("description_key", ""))


## Le nœud parent, ou rien pour une racine.
static func requires(node_id: StringName) -> StringName:
	return StringName(node(node_id).get("requires", ""))


## Ce que le nœud ajoute aux statistiques. Vide pour un nœud de compétence.
##
## Les clés de commentaire sont retirées : un `_note` compté comme une
## statistique donnerait un héros avec une caractéristique fantôme, et le
## bogue serait très difficile à voir.
static func grants(node_id: StringName) -> Dictionary:
	var out := {}
	for key: String in (node(node_id).get("grants", {}) as Dictionary).keys():
		if not key.begins_with("_"):
			out[StringName(key)] = int(node(node_id)["grants"][key])
	return out


## La compétence que le nœud débloque, ou rien.
static func ability_of(node_id: StringName) -> StringName:
	return StringName(node(node_id).get("ability", ""))


static func is_ability_node(node_id: StringName) -> bool:
	return not ability_of(node_id).is_empty()


## Les nœuds qui dépendent directement de celui-ci. Sert à dessiner
## l'arbre, et à refuser d'oublier une branche.
static func children_of(node_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var class_id := class_of(node_id)
	if class_id.is_empty():
		return out
	for candidate: StringName in node_ids(class_id):
		if requires(candidate) == node_id:
			out.append(candidate)
	return out


## Les racines d'un arbre. Il ne doit y en avoir qu'une : un joueur ne doit
## pas avoir à chercher par où commencer.
static func roots_of(class_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for node_id: StringName in node_ids(class_id):
		if requires(node_id).is_empty():
			out.append(node_id)
	return out


## Profondeur d'un nœud dans son arbre, la racine à zéro. Sert à l'écran,
## qui décale chaque rangée pour que l'arbre se lise comme un arbre.
static func depth_of(node_id: StringName) -> int:
	var depth := 0
	var current := requires(node_id)
	# Garde-fou : une donnée qui boucle sur elle-même ferait tourner
	# l'écran sans fin, et `verify_skills` la refuse — mais un fichier
	# retouché à la main peut arriver ici avant l'outil.
	while not current.is_empty() and depth < 64:
		depth += 1
		current = requires(current)
	return depth
