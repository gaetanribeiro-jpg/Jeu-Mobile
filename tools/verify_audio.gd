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

	# LES REPÈRES : QUEL MOMENT DE JEU JOUE QUEL SON (T11.2).
	#
	# UN REPÈRE QUI POINTE SUR UN SON INEXISTANT NE FAIT PAS DE BRUIT, ET
	# NE SE PLAINT PAS. C'est le pire des défauts sonores : le jeu tourne,
	# l'action se joue, et il manque simplement un son que personne ne
	# cherchait. Renommer une entrée de `sfx` suffit à le provoquer.
	var dangling: Array[String] = []
	for moment: StringName in AudioTable.cue_ids():
		var sound_id := AudioTable.cue(moment)
		if sound_id.is_empty():
			# Un repère volontairement vide est une réponse valable : tous
			# les moments n'ont pas besoin d'un bruit.
			continue
		if not AudioTable.sfx_ids().has(sound_id):
			dangling.append("« %s » → « %s », qui n'est pas un effet déclaré"
				% [moment, sound_id])

	print("Entrées audio déclarées : %d" % entries.size())
	print("  musiques : %d" % AudioTable.music_ids().size())
	print("  effets   : %d" % AudioTable.sfx_ids().size())
	print("  repères  : %d" % AudioTable.cue_ids().size())
	print("Repères sans son : %d" % dangling.size())
	for line: String in dangling:
		print("  REPÈRE    %s" % line)
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

	if missing.is_empty() and unloadable.is_empty() and dangling.is_empty():
		print("\nTous les sons déclarés sont en place.")
		quit(0)
	else:
		print("\nLa table audio ne correspond pas aux fichiers installés.")
		quit(1)
