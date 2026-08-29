extends SceneTree

## Vérifie que chaque son déclaré dans `data/audio.json` existe et se
## charge réellement comme flux audio.
##
##     godot --headless --path . -s tools/verify_audio.gd
##
## Rappelle aussi les sons que le jeu réclame et qu'aucun paquet installé
## ne fournit : les nommer vaut mieux que de leur substituer en silence un
## son approchant.


func _init() -> void:
	var entries := AudioTable.all_entries()
	var missing: Array[String] = []
	var unloadable: Array[String] = []

	for entry: Dictionary in entries:
		var path: String = entry["path"]
		if not FileAccess.file_exists(path):
			missing.append("%s → %s" % [entry["id"], path])
			continue
		if load(path) as AudioStream == null:
			unloadable.append("%s → %s" % [entry["id"], path])

	print("Entrées audio déclarées : %d" % entries.size())
	print("  musiques : %d" % AudioTable.music_ids().size())
	print("  effets   : %d" % AudioTable.sfx_ids().size())
	print("Fichiers manquants : %d" % missing.size())
	print("Fichiers illisibles : %d" % unloadable.size())
	for line: String in missing:
		print("  MANQUANT  %s" % line)
	for line: String in unloadable:
		print("  ILLISIBLE %s" % line)

	var still_needed := AudioTable.missing_ids()
	if not still_needed.is_empty():
		print("\nSons encore à trouver (%d) :" % still_needed.size())
		for id: StringName in still_needed:
			print("  %-18s %s" % [id, AudioTable.table()["missing"][String(id)]])

	if missing.is_empty() and unloadable.is_empty():
		print("\nTous les sons déclarés sont en place.")
		quit(0)
	else:
		print("\nLa table audio ne correspond pas aux fichiers installés.")
		quit(1)
