class_name HeroProgression
extends RefCounted

## Accès aux chiffres de la montée en niveau, tous dans
## `data/heroes/progression.json`.
##
## RÈGLE DURE : aucun nombre de gameplay dans un `.gd`. Cette classe est le
## seul chemin entre le fichier et le moteur, comme `CombatRules` l'est
## pour le combat.
##
## LES CHOIX DE NIVEAU ONT ÉTÉ RETIRÉS D'ICI : ils vivent maintenant dans
## l'arbre de compétences (`SkillTree`, § 34). Les six options d'alors sont
## devenues des nœuds ; rien n'a été perdu, et le joueur choisit maintenant
## dans quel ORDRE il les prend. Deux monnaies de progression pour le même
## acte auraient été la complexité que le § 31 refuse.

const PATH := "res://data/heroes/progression.json"

## Dans un bloc de gains, ce mot désigne la statistique qui définit la
## classe. Écrire « strength » à la place rendrait la table fausse pour
## deux classes sur trois.
const PRIMARY := &"primary"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("HeroProgression : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("HeroProgression : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeroProgression : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func max_level() -> int:
	return int(data().get("max_level", 1))


## Expérience totale exigée pour atteindre ce niveau. Zéro au niveau 1.
static func experience_to_reach(level: int) -> int:
	if level <= 1:
		return 0
	var table: Dictionary = data().get("experience_to_reach", {})
	if not table.has(str(level)):
		push_error("HeroProgression : pas de seuil pour le niveau %d" % level)
		return 0
	return int(table[str(level)])


## Expérience accordée par un évènement de combat.
static func award(event: StringName) -> int:
	var table: Dictionary = data().get("experience_awards", {})
	if not table.has(String(event)):
		push_error("HeroProgression : récompense inconnue « %s »" % event)
		return 0
	return int(table[String(event)])


## Gains accordés à chaque montée, sans condition.
static func per_level() -> Dictionary:
	return _grants(data().get("per_level", {}))


## Gains accordés en plus aux niveaux pairs.
static func every_other_level() -> Dictionary:
	return _grants(data().get("every_other_level", {}))


## Retire les clés de commentaire d'un bloc de gains. Un `_note` compté
## comme une statistique donnerait un héros avec une caractéristique
## fantôme, et le bogue serait très difficile à voir.
static func _grants(raw: Dictionary) -> Dictionary:
	var out := {}
	for key: String in raw.keys():
		if not key.begins_with("_"):
			out[StringName(key)] = int(raw[key])
	return out
