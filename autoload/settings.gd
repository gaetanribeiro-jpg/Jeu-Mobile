extends Node

## Les réglages du joueur : ce qu'il choisit une fois et qui doit lui
## survivre.
##
## À PART DE LA SAUVEGARDE DE PARTIE, et c'est la seule décision de fond
## ici. Les réglages vivent dans `user://settings.json` ; commencer une
## nouvelle partie ne doit pas remettre le volume à zéro, et un joueur qui
## a coupé la musique ne veut pas la voir revenir parce qu'il a perdu une
## expédition.
##
## LES DÉFAUTS SONT DANS `data/settings.json`, comme toute autre valeur du
## jeu. Ce fichier-ci ne contient aucun nombre.

const DEFAULTS := "res://data/settings.json"
const PATH := "user://settings.json"

## Émis après tout changement. L'audio s'y branche pour appliquer les
## volumes ; un écran peut s'y brancher pour se rafraîchir.
signal changed

var _values: Dictionary = {}
var _defaults: Dictionary = {}


func _ready() -> void:
	_defaults = _read(DEFAULTS)
	_values = _read(PATH)
	changed.emit()


## Valeur d'un réglage. Retombe sur le défaut, puis sur `fallback`.
func number(section: StringName, key: StringName, fallback: float = 0.0) -> float:
	var chosen: Dictionary = _values.get(String(section), {})
	if chosen.has(String(key)):
		return float(chosen[String(key)])
	var default: Dictionary = _defaults.get(String(section), {})
	if default.has(String(key)):
		return float(default[String(key)])
	return fallback


func flag(section: StringName, key: StringName, fallback: bool = false) -> bool:
	var chosen: Dictionary = _values.get(String(section), {})
	if chosen.has(String(key)):
		return bool(chosen[String(key)])
	var default: Dictionary = _defaults.get(String(section), {})
	if default.has(String(key)):
		return bool(default[String(key)])
	return fallback


## Change un réglage et l'écrit. On écrit TOUT DE SUITE plutôt qu'à la
## fermeture de l'écran : sur mobile, l'application peut mourir entre les
## deux, et un réglage perdu se re-règle avec humeur.
func set_value(section: StringName, key: StringName, value: Variant) -> void:
	if not _values.has(String(section)):
		_values[String(section)] = {}
	(_values[String(section)] as Dictionary)[String(key)] = value
	save()
	changed.emit()


## Remet tout aux défauts.
func reset() -> void:
	_values.clear()
	save()
	changed.emit()


func save() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Settings : écriture impossible dans %s" % PATH)
		return false
	file.store_string(JSON.stringify(_values, "  "))
	file.close()
	return true


## Un fichier de réglages absent ou abîmé n'est pas une panne : on repart
## des défauts. Perdre son volume vaut mieux que perdre le démarrage.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	# `JSON.parse_string` crie dans la console sur une entrée abîmée, et un
	# fichier de réglages abîmé n'est pas une panne : on lit avec un objet
	# `JSON`, qui rend un code d'erreur sans rien afficher.
	var reader := JSON.new()
	if reader.parse(text) != OK or typeof(reader.data) != TYPE_DICTIONARY:
		push_error("Settings : %s ne se lit pas, on repart des défauts" % path)
		return {}
	return reader.data
