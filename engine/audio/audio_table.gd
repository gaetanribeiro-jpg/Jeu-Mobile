class_name AudioTable
extends RefCounted

## Accès unique aux fichiers audio, sur le modèle d'`AssetTable`.
##
## RÈGLE : aucun chemin de fichier audio ailleurs que dans
## `data/audio.json`. Le code demande « le son d'une épée qui touche »,
## pas « impactMetal_medium_000.ogg ». Le jour où on change le son, on
## change une ligne de données et rien d'autre.

const TABLE_PATH := "res://data/audio.json"

static var _table: Dictionary = {}


static func reload() -> void:
	_table = {}


static func table() -> Dictionary:
	if not _table.is_empty():
		return _table
	if not FileAccess.file_exists(TABLE_PATH):
		push_error("AudioTable : %s introuvable" % TABLE_PATH)
		return {}
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("AudioTable : %s illisible" % TABLE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AudioTable : %s n'est pas un objet JSON" % TABLE_PATH)
		return {}
	_table = parsed
	return _table


static func root() -> String:
	return "res://" + String(table().get("meta", {}).get("root", ""))


## Piste de musique. Renvoie { path, loop, use } ou {}.
static func music(track_id: StringName) -> Dictionary:
	return _lookup(&"music", track_id, "musique")


## Effet sonore. Renvoie { path } ou {}.
static func sfx(sound_id: StringName) -> Dictionary:
	return _lookup(&"sfx", sound_id, "effet sonore")


static func music_ids() -> Array[StringName]:
	return _ids(&"music")


static func sfx_ids() -> Array[StringName]:
	return _ids(&"sfx")


## Sons que le jeu réclame et qu'aucun paquet installé ne fournit.
## Le dire est plus utile que de faire semblant avec un son approchant.
static func missing_ids() -> Array[StringName]:
	return _ids(&"missing")


## Toutes les entrées jouables, à plat, pour l'outil de vérification.
static func all_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section: StringName in [&"music", &"sfx"]:
		for id: StringName in _ids(section):
			var entry := _lookup(section, id, "")
			if not entry.is_empty():
				entry["id"] = "%s.%s" % [section, id]
				out.append(entry)
	return out


static func _ids(section: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in table().get(String(section), {}).keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func _lookup(section: StringName, id: StringName, label: String) -> Dictionary:
	var block: Dictionary = table().get(String(section), {})
	var entry: Dictionary = block.get(String(id), {})
	if entry.is_empty():
		if not label.is_empty():
			push_error("AudioTable : %s inconnu « %s »" % [label, id])
		return {}
	var out := entry.duplicate(true)
	out["path"] = root() + String(entry.get("file", ""))
	out.erase("file")
	return out
