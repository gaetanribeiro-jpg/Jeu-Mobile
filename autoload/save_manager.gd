extends Node

## Sauvegarde JSON versionnée, avec copie de secours.
##
## RÈGLE DURE : on sauvegarde après chaque action significative. Sur mobile
## l'application peut être tuée à tout moment sans prévenir.
##
## Squelette F0.7 : l'écriture et la migration réelles arrivent en H2.10.

const SAVE_PATH := "user://save_0.json"
const BACKUP_PATH := "user://save_0.bak"

## Version du format. À incrémenter dès qu'un champ change de sens,
## avec la fonction de migration correspondante.
const SAVE_VERSION := 1

var _pending := false


## Sauvegarde immédiate. Renvoie true si le fichier a bien été écrit.
func save_now(payload: Dictionary) -> bool:
	var data := payload.duplicate(true)
	data["version"] = SAVE_VERSION

	if FileAccess.file_exists(SAVE_PATH):
		var previous := FileAccess.get_file_as_bytes(SAVE_PATH)
		if previous.size() > 0:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_buffer(previous)
				backup.close()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: écriture impossible dans %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	EventBus.game_saved.emit()
	return true


## Charge la sauvegarde, ou la copie de secours si la principale est illisible.
## Renvoie un dictionnaire vide s'il n'y a rien à charger.
func load_game() -> Dictionary:
	var data := _read(SAVE_PATH)
	if data.is_empty():
		data = _read(BACKUP_PATH)
	if not data.is_empty():
		data = migrate(data)
		EventBus.game_loaded.emit()
	return data


## Amène une sauvegarde ancienne au format courant.
func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version == SAVE_VERSION:
		return data
	# Les migrations viendront s'empiler ici, une par version franchie.
	data["version"] = SAVE_VERSION
	return data


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: %s illisible" % path)
		return {}
	return parsed
