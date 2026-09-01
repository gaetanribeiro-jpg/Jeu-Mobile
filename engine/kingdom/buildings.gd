class_name Buildings
extends RefCounted

## Les bâtiments du royaume, lus dans `data/kingdom/buildings.json`
## (§ 7, § 8).
##
## LA QUESTION QUE CHAQUE BÂTIMENT DOIT SAVOIR RÉPONDRE : « qu'est-ce que
## ça permet à mes héros ? » Aucun bâtiment décoratif — décision
## verrouillée. Un bâtiment qui n'accorde rien n'entre pas dans la table,
## même si le pack le dessine. C'est le cas de la TOUR : elle sert à la
## défense, les invasions sont la Phase 5, et une tour sans invasion ne
## répond à rien.
##
## LE CHÂTEAU PLAFONNE TOUT LE RESTE. Sans cette règle on monterait une
## caserne au niveau 5 dans un hameau, et la progression du royaume
## n'aurait plus de colonne vertébrale.
##
## LES COÛTS SONT ENGENDRÉS, LES GAINS SONT ÉCRITS. Vingt-cinq prix à la
## main auraient dérivé les uns des autres dès la première retouche ; les
## gains, eux, sont la conception et ne se déduisent d'aucune formule.

const PATH := "res://data/kingdom/buildings.json"

## Le bâtiment dont le niveau plafonne tous les autres.
const KEYSTONE := &"castle"

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
		push_error("Buildings : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Buildings : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Buildings : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("buildings", {})


## Les bâtiments, le château en tête : c'est l'ordre où l'écran les montre,
## et le château commande les autres.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in _table().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		if (a == KEYSTONE) != (b == KEYSTONE):
			return a == KEYSTONE
		return false)
	return out


static func exists(building_id: StringName) -> bool:
	return _table().has(String(building_id))


static func entry(building_id: StringName) -> Dictionary:
	var table := _table()
	if not table.has(String(building_id)):
		push_error("Buildings : bâtiment inconnu « %s »" % building_id)
		return {}
	return table[String(building_id)]


static func name_key(building_id: StringName) -> String:
	return String(entry(building_id).get("name_key", ""))


static func description_key(building_id: StringName) -> String:
	return String(entry(building_id).get("description_key", ""))


static func max_level(building_id: StringName) -> int:
	return int(entry(building_id).get("max_level", 0))


## Niveau auquel le bâtiment existe déjà au premier jour. Le château est
## là dès le début — le § 5 le dit : « un bâtiment principal rudimentaire ».
static func starts_at(building_id: StringName) -> int:
	return int(entry(building_id).get("starts_at", 0))


## La classe de héros que ce bâtiment sert, ou vide. C'est elle qui décide
## à qui ses gains s'appliquent, et qui il permet de recruter.
static func hero_class(building_id: StringName) -> StringName:
	return StringName(entry(building_id).get("hero_class", ""))


## L'image du bâtiment à ce niveau. Un bâtiment dont le pack sait montrer
## l'évolution déclare une liste ; les autres, une seule image.
static func asset_of(building_id: StringName, level: int) -> String:
	var built := entry(building_id)
	var evolving: Array = built.get("assets", [])
	if evolving.is_empty():
		return String(built.get("asset", ""))
	var index := clampi(level - 1, 0, evolving.size() - 1)
	return String(evolving[index])


## Le pied du bâtiment sur le terrain du royaume, en pixels d'une toile de
## 900 x 560. C'est de la mise en scène, et elle vit dans les données parce
## que le § 5 fait de l'évolution visuelle du royaume une exigence :
## déplacer une caserne doit se faire en changeant deux nombres.
static func spot_of(building_id: StringName) -> Vector2:
	var raw: Array = entry(building_id).get("spot", [])
	if raw.size() < 2:
		return Vector2.ZERO
	return Vector2(float(raw[0]), float(raw[1]))


# --- Ce qu'un niveau coûte -------------------------------------------------

## Prix pour ATTEINDRE ce niveau depuis le précédent. Zéro pour un niveau
## qu'on possède déjà au premier jour, et pour un niveau hors de portée.
static func cost_of(building_id: StringName, level: int) -> Dictionary:
	var out := {}
	if level <= starts_at(building_id) or level > max_level(building_id):
		return out
	var base: Dictionary = entry(building_id).get("base_cost", {})
	var growth := float(data().get("cost_growth", 1.0))
	var factor := pow(growth, float(level - 1))
	for key: Variant in base.keys():
		# Arrondi au multiple de cinq : un prix de 137 se lit moins bien
		# qu'un prix de 135, et personne ne compte à l'unité près.
		out[StringName(key)] = int(round(float(base[key]) * factor / 5.0)) * 5
	return out


## Ce que coûte le recrutement d'un héros dans ce bâtiment. Vide pour un
## bâtiment qui ne forme personne.
static func recruit_cost(building_id: StringName) -> Dictionary:
	var out := {}
	for key: Variant in (entry(building_id).get("recruit_cost", {}) as Dictionary).keys():
		out[StringName(key)] = int((entry(building_id)["recruit_cost"] as Dictionary)[key])
	return out


## Le bâtiment qui forme cette classe, ou rien.
static func trainer_of(class_id: StringName) -> StringName:
	for building_id: StringName in ids():
		if hero_class(building_id) == class_id:
			return building_id
	return &""


# --- Ce qu'un niveau accorde -----------------------------------------------

## Gains de CE niveau seul.
static func grants_at(building_id: StringName, level: int) -> Dictionary:
	var ladder: Array = entry(building_id).get("grants", [])
	if level < 1 or level > ladder.size():
		return {}
	return ladder[level - 1]


## Gains cumulés d'un bâtiment porté à ce niveau. Ils s'additionnent : un
## bâtiment de niveau 3 accorde la somme des trois premières lignes.
static func grants_up_to(building_id: StringName, level: int) -> Dictionary:
	var out := {}
	for step in range(1, mini(level, max_level(building_id)) + 1):
		for key: Variant in grants_at(building_id, step).keys():
			var current: Variant = out.get(key, 0)
			out[key] = sum_grant(current, grants_at(building_id, step)[key])
	return out


## Additionne deux gains, en flottant.
##
## PIÈGE : Godot analyse TOUT nombre JSON en flottant, y compris `6`.
## Choisir le mode d'addition sur le TYPE ne pouvait donc pas marcher —
## tout était flottant, et la distinction était une illusion. Les gains
## fractionnaires se reconnaissent à leur CLÉ (`is_fraction`), et c'est au
## lecteur de convertir : `int()` pour une statistique, `float()` pour un
## soin.
static func sum_grant(left: Variant, right: Variant) -> float:
	return float(left) + float(right)


## Les gains qui se lisent comme une fraction, pas comme un entier. Un
## seul aujourd'hui — le soin du monastère — mais l'affichage et les tests
## ont besoin de le savoir sans le deviner.
static func is_fraction(key: StringName) -> bool:
	return key == &"heal_between_steps"
