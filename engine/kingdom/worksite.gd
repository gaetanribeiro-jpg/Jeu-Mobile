class_name Worksite
extends RefCounted

## Les chantiers, lus dans `data/kingdom/worksites.json`.
##
## POURQUOI DES CHANTIERS ET PAS DES BÂTIMENTS. Le pack ne dessine ni
## ferme, ni scierie, ni mine — mais il dessine des arbres qu'on abat, un
## gisement d'or, des rochers, des moutons, et un Pawn avec quatre outils
## et une animation d'interaction pour chacun. C'est la production du
## royaume, déjà dessinée. Un bâtiment « Scierie » réclamerait un sprite
## qui n'existe pas ; un bûcheron devant un arbre montre en plus la
## POPULATION AU TRAVAIL, que le § 9 réclame et qu'un bâtiment fermé ne
## montre jamais.
##
## UN CHANTIER SANS PERSONNE NE PRODUIT RIEN. C'est ce qui fait de
## l'affectation une décision : il y a toujours moins de bras que de
## gisements.

const PATH := "res://data/kingdom/worksites.json"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Worksite : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Worksite : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Worksite : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("worksites", {})


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in _table().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(worksite_id: StringName) -> bool:
	return _table().has(String(worksite_id))


static func entry(worksite_id: StringName) -> Dictionary:
	var table := _table()
	if not table.has(String(worksite_id)):
		push_error("Worksite : chantier inconnu « %s »" % worksite_id)
		return {}
	return table[String(worksite_id)]


static func name_key(worksite_id: StringName) -> String:
	return String(entry(worksite_id).get("name_key", ""))


static func resource_of(worksite_id: StringName) -> StringName:
	return StringName(entry(worksite_id).get("resource", ""))


static func per_cycle(worksite_id: StringName) -> int:
	return int(entry(worksite_id).get("per_cycle", 0))


## L'outil que le Pawn tient — c'est lui qui choisit l'animation
## d'interaction, et donc ce que le joueur voit du travail.
static func tool_of(worksite_id: StringName) -> StringName:
	return StringName(entry(worksite_id).get("tool", ""))


static func asset_of(worksite_id: StringName) -> String:
	return String(entry(worksite_id).get("asset", ""))


## Bras qu'un gisement accepte. Il y a plus de places que d'habitants :
## affecter reste donc un arbitrage entre les ressources, jamais un simple
## remplissage.
static func slots_of(worksite_id: StringName) -> int:
	return int(entry(worksite_id).get("slots", 0))


## Facteur d'échelle du gisement. Les images du pack vont de 64 à 256
## pixels ; sans lui, la carrière est un caillou perdu au milieu du pré.
static func scale_of(worksite_id: StringName) -> float:
	return float(entry(worksite_id).get("scale", 1.0))


## Le pied du bâtiment sur le terrain du royaume, en pixels d'une toile de
## 900 x 560. C'est de la mise en scène, et elle vit dans les données parce
## que le § 5 fait de l'évolution visuelle du royaume une exigence :
## déplacer une caserne doit se faire en changeant deux nombres.
static func spot_of(worksite_id: StringName) -> Vector2:
	var raw: Array = entry(worksite_id).get("spot", [])
	if raw.size() < 2:
		return Vector2.ZERO
	return Vector2(float(raw[0]), float(raw[1]))


# --- Les chiffres du cycle -------------------------------------------------

static func number(section: StringName, key: StringName, fallback: float) -> float:
	var block: Dictionary = data().get(String(section), {})
	if not block.has(String(key)):
		push_error("Worksite : « %s.%s » absent de worksites.json" % [section, key])
		return fallback
	return float(block[String(key)])


## Ce qu'un habitant mange par cycle, qu'il travaille ou non. Sinon la
## population serait gratuite et son plafond ne voudrait rien dire.
static func food_per_pawn() -> int:
	return int(number(&"cycle", &"food_per_pawn", 0))


## Réserve de nourriture à accumuler pour qu'un habitant s'installe : la
## nourriture achète des bras, et les bras remplissent les chantiers.
static func arrival_food() -> int:
	return int(number(&"cycle", &"arrival_food", 0))


static func starting_population() -> int:
	return int(number(&"population", &"start", 0))


## Habitants que le royaume nourrit sans rien avoir bâti. Les maisons et le
## château l'augmentent.
static func base_population_cap() -> int:
	return int(number(&"population", &"base_cap", 0))
