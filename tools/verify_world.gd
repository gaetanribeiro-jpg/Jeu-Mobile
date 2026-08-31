extends SceneTree

## Vérifie les régions et les règles d'expédition.
##
##     godot --headless --path . -s tools/verify_world.gd
##
## POURQUOI. Une région se décrit par des NOMS — des cartes, des étapes —
## et un nom mal orthographié ne se voit pas : il se découvre en pleine
## expédition, deux rencontres après le départ, quand la carte suivante
## refuse de se charger et que la sortie est perdue. Cet outil lit les
## noms avant que le joueur ne les rencontre.
##
## Il vérifie aussi que la question du § 29 tient debout. Elle n'existe que
## si continuer rapporte plus, coûte quelque chose, et qu'échouer perd
## quelque chose. Un de ces trois chiffres mis à zéro rendrait la réponse
## automatique, et rien d'autre ne le dirait.

var _problems: Array[String] = []


func _init() -> void:
	var regions := Region.ids()
	print("Vérification de %d régions…\n" % regions.size())
	print("%-18s %4s %-9s %5s %8s  %s"
		% ["région", "acte", "état", "cartes", "chaîne", "boss"])
	print("-".repeat(76))

	for region_id: StringName in regions:
		_check_region(region_id)

	print("-".repeat(76))
	_check_expedition_rules()

	if _problems.is_empty():
		print("\nLe monde est cohérent.")
		quit(0)
		return
	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	quit(1)


func _check_region(region_id: StringName) -> void:
	var unlocked := Region.is_unlocked(region_id)
	var maps := Region.encounter_maps(region_id)
	var chain := Region.chain(region_id)

	if Region.name_key(region_id).is_empty():
		_problems.append("%s : pas de clé de nom" % region_id)
	else:
		_check_translation(region_id, Region.name_key(region_id))
	if not Region.description_key(region_id).is_empty():
		_check_translation(region_id, Region.description_key(region_id))

	var length := "—"
	if not chain.is_empty():
		var body: Dictionary = chain.get("body", {})
		length = "%d–%d+%d" % [
			int(body.get("min", 0)),
			int(body.get("max", 0)),
			Region.chain_tail(region_id).size(),
		]

	print("%-18s %4d %-9s %5d %8s  %s" % [
		region_id,
		Region.act_of(region_id),
		"ouverte" if unlocked else "verrouillée",
		maps.size(),
		length,
		Region.boss_map(region_id) if unlocked else "—",
	])

	# Une région verrouillée n'a rien d'autre à montrer que son nom : elle
	# existe pour que la carte du monde ait quelque chose à afficher, pas
	# pour être jouée. Lui réclamer des cartes serait exiger un contenu
	# qu'on a délibérément remis à plus tard.
	if not unlocked:
		return

	var known := CombatMap.map_ids()
	if maps.is_empty():
		_problems.append("%s : aucune carte de rencontre" % region_id)
	for map_id: StringName in maps:
		if not known.has(map_id):
			_problems.append("%s : carte de rencontre inconnue « %s »" % [region_id, map_id])

	for role: StringName in [&"miniboss_map", &"boss_map"]:
		var map_id: StringName = (
			Region.miniboss_map(region_id) if role == &"miniboss_map"
			else Region.boss_map(region_id)
		)
		if map_id.is_empty():
			_problems.append("%s : pas de %s" % [region_id, role])
		elif not known.has(map_id):
			_problems.append("%s : %s inconnue « %s »" % [region_id, role, map_id])
		elif maps.has(map_id):
			# Sinon le boss tomberait au milieu de la chaîne, et le
			# mini-boss deux fois dans la même sortie.
			_problems.append("%s : %s « %s » est aussi une rencontre ordinaire"
				% [region_id, role, map_id])

	_check_chain(region_id)
	_check_window(region_id)


## Les étapes déclarées doivent être des étapes que l'expédition sait
## résoudre. Une étape inconnue bloquerait la chaîne au milieu.
func _check_chain(region_id: StringName) -> void:
	var known: Array[StringName] = [
		Expedition.KIND_COMBAT,
		Expedition.KIND_MINIBOSS,
		Expedition.KIND_BOSS,
		Expedition.KIND_REWARD,
		&"event",
		&"merchant",
	]
	var pattern := Region.chain_pattern(region_id)
	var tail := Region.chain_tail(region_id)
	if pattern.is_empty():
		_problems.append("%s : la chaîne n'a pas de corps" % region_id)
	for kind: StringName in pattern + tail:
		if not known.has(kind):
			_problems.append("%s : étape inconnue « %s »" % [region_id, kind])

	if not tail.has(Expedition.KIND_BOSS):
		# Une expédition sans boss n'a pas de fin : rien ne distingue plus
		# « je suis rentré » de « j'ai tout fait ».
		_problems.append("%s : la chaîne ne finit pas sur un boss" % region_id)

	var body: Dictionary = Region.chain(region_id).get("body", {})
	if int(body.get("min", 0)) < 1:
		_problems.append("%s : une expédition peut n'avoir aucun corps" % region_id)
	if int(body.get("max", 0)) < int(body.get("min", 0)):
		_problems.append("%s : longueurs de chaîne inversées" % region_id)


## La fenêtre doit vraiment glisser sur toute la profondeur atteignable,
## sinon l'escalade du § 29 est déclarée sans être appliquée.
func _check_window(region_id: StringName) -> void:
	var maps := Region.encounter_maps(region_id)
	var body: Dictionary = Region.chain(region_id).get("body", {})
	var deepest := int(body.get("max", 0)) + Region.chain_tail(region_id).size()

	var shallow := Region.map_window(region_id, 0)
	var deep := Region.map_window(region_id, deepest)
	if shallow.size() < 2:
		_problems.append("%s : la fenêtre ne propose pas de choix au départ" % region_id)
	if shallow == deep and maps.size() > shallow.size():
		_problems.append(
			"%s : la fenêtre ne glisse pas — l'escalade du § 29 ne s'applique pas"
			% region_id)
	if not shallow.is_empty() and deep.has(shallow[0]) and maps.size() > shallow.size():
		_problems.append("%s : la carte la plus facile sort encore au fond" % region_id)
	print("    fenêtre : %s … %s" % [", ".join(_as_strings(shallow)), ", ".join(_as_strings(deep))])


## Les trois chiffres qui font la décision du § 29. Aucun ne peut valoir
## zéro sans que la question ne se réponde toute seule.
func _check_expedition_rules() -> void:
	print("")
	var gold_step := Loot.number(&"depth", &"gold_per_step", 0.0)
	var kept := ExpeditionRules.satchel_kept_on_wipe()
	var recovery := ExpeditionRules.downed_recovery()

	print("continuer rapporte : +%.0f %% d'or par rencontre" % (gold_step * 100.0))
	print("continuer coûte    : %.0f %% de PV rendus entre deux étapes"
		% (ExpeditionRules.healing_between_steps() * 100.0))
	print("échouer perd       : %.0f %% de la besace" % ((1.0 - kept) * 100.0))
	print("un héros à terre   : se relève à %.0f %% de ses PV" % (recovery * 100.0))

	if gold_step <= 0.0:
		_problems.append("s'enfoncer ne rapporte rien : la question du § 29 n'existe pas")
	if kept >= 1.0:
		_problems.append("une déroute ne coûte rien : continuer est toujours gratuit")
	if kept < 0.0 or kept > 1.0:
		_problems.append("part de besace gardée hors de [0, 1]")
	if recovery <= 0.0:
		# Un héros qui repart à terre est mort pour de bon, et le § 25 dit
		# le contraire.
		_problems.append("un héros à terre repart à terre : c'est une mort définitive")
	if ExpeditionRules.retreat_min_steps() < 1:
		_problems.append("on peut rentrer sans être parti")


func _check_translation(region_id: StringName, key: String) -> void:
	if TranslationServer.translate(key) == key:
		_problems.append("%s : la clé « %s » n'est pas traduite" % [region_id, key])


func _as_strings(ids: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for id_: StringName in ids:
		out.append(String(id_))
	return out
