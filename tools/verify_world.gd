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
	_check_events()
	_check_merchant()
	_check_supplies()
	_check_expedition_rules()
	_check_day_night()

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


# --- Les évènements du § 40 ------------------------------------------------
#
# « Les événements doivent créer des décisions. » Cette phrase est la seule
# règle du § 40, et c'est la seule qu'un fichier de données peut violer
# sans que rien ne plante : un évènement à une option, ou dont une option
# est meilleure que l'autre sur toute la ligne, se joue parfaitement — il
# ne demande simplement plus rien au joueur.

func _check_events() -> void:
	var events := ExpeditionEvent.ids()
	print("\nVérification de %d évènements…\n" % events.size())
	for event_id: StringName in events:
		_check_event(event_id)


func _check_event(event_id: StringName) -> void:
	_check_translation(event_id, ExpeditionEvent.name_key(event_id))
	_check_translation(event_id, ExpeditionEvent.text_key(event_id))

	var options := ExpeditionEvent.options(event_id)
	print("%-10s %-28s %d options"
		% [event_id, TranslationServer.translate(ExpeditionEvent.name_key(event_id)), options.size()])
	if options.size() < 2:
		_problems.append("%s : une seule option, donc aucune décision" % event_id)
		return
	if ExpeditionEvent.weight_of(event_id) <= 0:
		_problems.append("%s : poids nul, il ne sortira jamais" % event_id)

	var scored: Array[Dictionary] = []
	for index in options.size():
		_check_translation(event_id, ExpeditionEvent.option_label(event_id, index))
		var value := _value_of(event_id, index)
		scored.append(value)
		print("    %-26s %s" % [
			TranslationServer.translate(ExpeditionEvent.option_label(event_id, index)),
			_describe(value),
		])

	for a in options.size():
		for b in options.size():
			if a != b and _dominates(scored[a], scored[b]):
				_problems.append(
					"%s : l'option %d est meilleure que la %d sur toute la ligne"
					% [event_id, a, b])


## L'espérance d'une option sur chaque monnaie de l'échange. Une option qui
## parie compte ses deux issues au prorata de sa chance : c'est ce que le
## joueur compare, et c'est donc ce qu'il faut comparer.
func _value_of(event_id: StringName, index: int) -> Dictionary:
	var option := ExpeditionEvent.option(event_id, index)
	var chance := clampf(ExpeditionEvent.option_chance(event_id, index), 0.0, 1.0)
	var value := {"gold": 0.0, "health": 0.0, "items": 0.0, "satchel": 0.0, "combat": 0.0}
	var branches := {"success": chance, "failure": 1.0 - chance}
	for branch: String in branches:
		var weight: float = branches[branch]
		if is_zero_approx(weight):
			continue
		var effects: Dictionary = option.get(branch, {})
		value["gold"] += weight * float(effects.get("gold", 0))
		value["health"] += weight * float(effects.get("health", 0.0))
		# Un objet de rareté relevée vaut plus qu'un objet ordinaire, et
		# l'ignorer ferait passer un autel pour un tas de gravats.
		value["items"] += (weight * float(effects.get("items", 0))
			* (1.0 + float(effects.get("rarity_bonus", 0))))
		value["satchel"] += weight * (float(effects.get("satchel_kept", 1.0)) - 1.0)
		value["combat"] -= weight * (1.0 if bool(effects.get("combat", false)) else 0.0)
	return value


func _dominates(a: Dictionary, b: Dictionary) -> bool:
	var strictly_better := false
	for key: String in a:
		if float(a[key]) < float(b[key]) - 0.0001:
			return false
		if float(a[key]) > float(b[key]) + 0.0001:
			strictly_better = true
	return strictly_better


func _describe(value: Dictionary) -> String:
	var pieces := PackedStringArray()
	if not is_zero_approx(float(value["gold"])):
		pieces.append("or %+.0f" % float(value["gold"]))
	if not is_zero_approx(float(value["health"])):
		pieces.append("PV %+.0f %%" % (float(value["health"]) * 100.0))
	if not is_zero_approx(float(value["items"])):
		pieces.append("objets %.2f" % float(value["items"]))
	if not is_zero_approx(float(value["satchel"])):
		pieces.append("besace %.0f %%" % (float(value["satchel"]) * 100.0))
	if not is_zero_approx(float(value["combat"])):
		pieces.append("un combat")
	return ", ".join(pieces)


# --- Le marchand -----------------------------------------------------------

func _check_merchant() -> void:
	print("\nL'étal du marchand :\n")
	print("%-12s %6s %8s" % ["rareté", "prix", "rachat"])
	for rarity: StringName in Equipment.rarities():
		var sample := &""
		for item_id: StringName in Equipment.ids():
			if Equipment.rarity_of(item_id) == rarity:
				sample = item_id
				break
		if sample.is_empty():
			continue
		var price := Merchant.price_of(sample)
		var resale := Merchant.resale_of(sample)
		print("%-12s %6d %8d" % [rarity, price, resale])
		if price <= 0:
			_problems.append("un objet %s ne coûte rien" % rarity)
		if resale >= price:
			# Acheter puis revendre deviendrait gratuit, ou rentable : l'or
			# et les objets seraient la même chose, et le choix du § 32 —
			# vendre, ou équiper, ou bâtir — s'effondrerait.
			_problems.append("revendre un objet %s rapporte autant qu'il coûte" % rarity)

	if Merchant.stock_size() < 2:
		_problems.append("l'étal ne propose pas de choix")
	if Merchant.stock_size() > Equipment.ids().size():
		_problems.append("l'étal veut plus d'objets qu'il n'en existe")

	# Un étal qu'on vide avec l'or d'une seule rencontre n'est pas une
	# décision, c'est une distribution.
	var encounter_gold := (Loot.number(&"gold", &"per_enemy", 0.0) * 4.0
		+ Loot.number(&"gold", &"victory_bonus", 0.0))
	var cheapest := 0
	for item_id: StringName in Equipment.ids():
		var price := Merchant.price_of(item_id)
		if cheapest == 0 or price < cheapest:
			cheapest = price
	print("\nune rencontre rapporte %.0f, l'objet le moins cher vaut %d"
		% [encounter_gold, cheapest])
	if float(cheapest) < encounter_gold * 0.5:
		_problems.append("l'étal est trop bon marché pour qu'acheter soit un choix")


## LES POTIONS DOIVENT ÊTRE OBTENABLES (T10.2).
##
## C'EST EXACTEMENT LA FAUTE QUE CE CONTRÔLE EXISTE POUR ATTRAPER, et le
## projet l'a commise pendant toute la Phase 10 : `consumables.json`
## déclarait trois potions, le combat savait les boire, la barre d'action
## les affichait — et rien au monde n'en distribuait une seule. Le sac de
## départ tenait lieu de mécanique. Une réserve qui ne se renouvelle pas
## n'est pas une ressource, c'est un compte à rebours, et le troisième
## terme de « je rentre ou je continue ? » (§ 29) disparaît avec elle.
##
## Aucun test unitaire ne l'aurait dit : chaque moitié était juste.
func _check_supplies() -> void:
	print("\nLe ravitaillement en potions :\n")
	if Consumable.ids().is_empty():
		_problems.append("aucune potion déclarée")
		return

	var dropped := Loot.number(&"supplies", &"on_victory", 0.0)
	var stalled := Merchant.stock_supplies()
	print("butin : %.0f %% par victoire · étal : %d place(s)" % [dropped * 100.0, stalled])
	if dropped <= 0.0 and stalled <= 0:
		_problems.append("aucune potion ne s'obtient : ni le butin ni l'étal n'en donne")
	if dropped <= 0.0:
		_problems.append("le butin ne rend jamais de potion")
	if stalled <= 0:
		_problems.append("le marchand n'en vend pas")

	# UNE POTION DOIT SE PAYER DANS L'ORDRE DE GRANDEUR D'UNE RENCONTRE.
	# Moins cher, on en achète dix et l'usure du roguelite disparaît ;
	# beaucoup plus cher, elle n'est jamais le meilleur usage de l'or.
	var encounter_gold := (Loot.number(&"gold", &"per_enemy", 0.0) * 4.0
		+ Loot.number(&"gold", &"victory_bonus", 0.0))
	for item_id: StringName in Consumable.ids():
		var price := Merchant.price_of(item_id)
		print("  %-22s %4d or" % [item_id, price])
		if price <= 0:
			_problems.append("la potion « %s » ne coûte rien" % item_id)
			continue
		if float(price) < encounter_gold * 0.25:
			_problems.append(
				"la potion « %s » coûte %d pour une rencontre à %.0f : trop peu"
				% [item_id, price, encounter_gold]
			)
		if float(price) > encounter_gold * 3.0:
			_problems.append(
				"la potion « %s » coûte %d pour une rencontre à %.0f : trop cher"
				% [item_id, price, encounter_gold]
			)

	# LA DÉFAITE NE DOIT PAS RAVITAILLER. Le § 41 refuse la punition
	# absolue, et c'est pour ça que l'équipement tombe quand même ; mais
	# une équipe qui vient de perdre a déjà vidé son sac, et lui rendre
	# une potion effacerait la dépense.
	if Loot.number(&"supplies", &"on_defeat", 0.0) > 0.0:
		_problems.append("une défaite rend des potions : la dépense s'annule")


## Le cycle jour / nuit (§ 36), et la seule chose qu'il ne doit pas être :
## un choix évident dans un sens ou dans l'autre.
##
## Les deux moitiés se vérifient l'une par l'autre. Une nuit qui ajoute un
## ennemi sans rien payer de plus est une punition, et personne ne
## continuerait. Une nuit qui paie sans rien ajouter est un cadeau, et
## tout le monde continuerait. Dans les deux cas le § 29 s'effondre — et
## aucun test unitaire ne le dirait, parce que chaque moitié serait juste.
func _check_day_night() -> void:
	var schedule := DayNight.schedule()
	if schedule.is_empty():
		_problems.append("le cycle jour/nuit n'a pas de calendrier")
		return

	for moment: StringName in schedule:
		if not DayNight.exists(moment):
			_problems.append("le calendrier appelle un moment inconnu « %s »" % moment)
	if DayNight.moment_at(0) != schedule[0]:
		_problems.append("le départ ne tombe pas sur la première heure du calendrier")

	var lines := PackedStringArray()
	var paying := 0
	var costing := 0
	for moment: StringName in DayNight.moments():
		if not DayNight.exists(moment):
			continue
		var bonus := DayNight.loot_bonus(moment)
		var extra := DayNight.reinforcements(moment)
		var gold := float(bonus.get("gold_multiplier", 1.0))
		var rarity := int(bonus.get("rarity_bonus", 0))
		if gold > 1.0 or rarity > 0:
			paying += 1
		if extra > 0:
			costing += 1
		# Une heure qui coûte sans payer, ou l'inverse, casse le § 29 à
		# elle seule : on n'a plus une décision, on a une réponse.
		if extra > 0 and gold <= 1.0 and rarity <= 0:
			_problems.append("« %s » ajoute %d ennemi(s) et ne paie rien" % [moment, extra])
		var key := DayNight.name_key(moment)
		if key.is_empty() or TranslationServer.translate(key) == key:
			_problems.append("« %s » n'a pas de nom traduit" % moment)
		lines.append("  %-8s +%d ennemi  or ×%.2f  rareté +%d"
			% [moment, extra, gold, rarity])

	print("\ncycle jour / nuit : %s" % " → ".join(_as_strings(schedule)))
	for line: String in lines:
		print(line)

	if costing == 0:
		_problems.append("aucune heure ne coûte quoi que ce soit : la nuit est un décor")
	if paying == 0:
		_problems.append("aucune heure ne paie : la nuit est une punition sèche")

	# Le renfort doit avoir de quoi être tiré, sinon la nuit n'ajoute rien
	# et la vérification ci-dessus passerait sur une promesse vide.
	for region_id: StringName in Region.ids():
		var roster := Region.night_roster(region_id)
		if roster.is_empty():
			continue
		for enemy_id: StringName in roster:
			if Unit.enemy_stats(enemy_id).is_empty():
				_problems.append("%s : renfort de nuit inconnu « %s »" % [region_id, enemy_id])
