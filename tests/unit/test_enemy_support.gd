extends GutTest

## L'acte 4 — le premier ennemi du jeu qui REMONTE.
##
## LE PORTEUR A CHANGÉ, PAS LA MÉCANIQUE. Écrite pour l'aumônier de la
## Compagnie dorée, elle est passée à l'atelier qui répare les
## emplacements quand l'acte a changé de faction — et c'est précisément ce
## qui prouve qu'elle valait la peine : une mécanique qui ne survit pas au
## déménagement de son porteur était une statistique déguisée.
##
## Vingt-huit bêtes en trois actes, et pas une ne récupérait un point de
## vie : entamer quelqu'un était toujours un acquis. L'atelier de la
## Compagnie le reprend, et c'est la seule mécanique inventée pour cet
## acte.
##
## LE PLATEAU SAVAIT DÉJÀ LE FAIRE. `affected_units` fait basculer le sens
## du camp pour un soin depuis T10.1 et `_resolve_heal` rend le même compte
## rendu qu'une attaque — c'est l'IA qui ne cherchait que des héros, et le
## télégraphe qui ne connaissait que `Kind.ATTACK`. Ce qu'on vérifie ici
## est donc la CHAÎNE : l'IA annonce, le télégraphe chiffre, l'activation
## exécute.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


func _board() -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray([
			"............", "............", "............",
			"............", "............", "............",
			"............", "............", "............",
		]),
		CombatRules.ADJACENCY_ORTHOGONAL
	)


func _enemy(board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	board.place_unit(unit, at)
	return unit


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


## L'AUMÔNIER A SEPT D'INITIATIVE, LE GUERRIER QUATRE : il jouerait donc
## AVANT le premier héros et exécuterait à l'ouverture l'intention qu'il
## vient d'annoncer — le télégraphe serait déjà vide quand on le lit, et sa
## compétence en recharge. Le comportement est correct et ancien (le Voleur
## à 9 le fait depuis la Phase 1) ; c'est le test qui doit en tenir compte.
## L'Archer, à huit, rend la main au joueur avant que l'atelier ne joue.
func _engine(board: CombatBoard) -> CombatEngine:
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(4242)
	)
	engine.start()
	return engine


# --- L'IA -----------------------------------------------------------------

func test_l_aumonier_annonce_un_soin_quand_un_allie_saigne() -> void:
	var board := _board()
	var chaplain := _enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var wounded := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_hero(board, &"warrior", Vector2i(1, 4), 3)
	wounded.take_damage(60)

	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, chaplain)
	assert_true(intent.is_support(), "l'atelier doit annoncer un soin")
	assert_eq(
		intent.target_cell(chaplain.cell), wounded.cell,
		"et le porter sur le blessé"
	)


## Sans blessé, il n'a rien à recoudre : il ne doit pas passer son tour à
## soigner des gens qui vont bien.
func test_sans_blesse_il_ne_soigne_pas() -> void:
	var board := _board()
	var chaplain := _enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	_enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_hero(board, &"warrior", Vector2i(1, 4), 3)

	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, chaplain)
	assert_false(intent.is_support(), "personne à recoudre, donc pas de soin")


## LE PLUS BLESSÉ, PAS LE PLUS PROCHE. La règle est sobre exprès ; ce qui
## borne l'atelier est sa recharge, déclarée en données, pas une ruse.
func test_il_recoud_le_plus_blesse() -> void:
	var board := _board()
	var chaplain := _enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var scratched := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	var mauled := _enemy(board, &"war_pig", Vector2i(9, 4), 3)
	_hero(board, &"warrior", Vector2i(1, 4), 4)
	# LES CHIFFRES SUIVENT LES BÊTES : la tour a deux cents points de vie,
	# le sanglier soixante-quinze. Quatre-vingts le mettaient À TERRE, donc
	# `affected_units` l'écartait et l'atelier recousait l'autre — le test
	# passait pour la mauvaise raison.
	scratched.take_damage(10)
	mauled.take_damage(50)

	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, chaplain)
	assert_eq(intent.target_cell(chaplain.cell), mauled.cell)


func test_un_soin_ne_vise_jamais_un_heros() -> void:
	var board := _board()
	var chaplain := _enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var hero := _hero(board, &"warrior", Vector2i(7, 4), 2)
	hero.take_damage(80)

	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, chaplain)
	assert_false(
		intent.is_support(),
		"un héros blessé n'est pas un allié : le soin ne doit pas se déclencher"
	)


# --- Le télégraphe (§ 39) -------------------------------------------------

## SANS ÇA, « QUI TUER D'ABORD » SE POSE À L'AVEUGLE. Le joueur décide de
## sa cible sur le télégraphe ; un soin caché rendrait la mise à terre d'un
## blessé aléatoire de son point de vue.
func test_le_soin_s_annonce_avec_son_chiffre() -> void:
	var board := _board()
	var chaplain := _enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var wounded := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_hero(board, &"archer", Vector2i(1, 4), 3)
	wounded.take_damage(100)

	var engine := _engine(board)
	var found := {}
	for entry: Dictionary in engine.telegraph():
		if int(entry["attacker_id"]) == chaplain.id:
			found = entry
	assert_false(found.is_empty(), "l'atelier doit figurer au télégraphe")
	assert_eq(String(found.get("kind", "")), "support")
	assert_eq(found["cells"], [wounded.cell] as Array[Vector2i])
	assert_gt(int((found["mends"] as Array)[0]), 0, "et annoncer un chiffre")


## ANNONCER LA VALEUR BRUTE MENTIRAIT dans le seul cas qui compte : un
## ennemi presque intact afficherait « +29 » et n'en reprendrait que trois.
func test_le_chiffre_annonce_est_plafonne_par_ce_qui_manque() -> void:
	var board := _board()
	_enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var wounded := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_hero(board, &"archer", Vector2i(1, 4), 3)
	wounded.take_damage(3)

	var engine := _engine(board)
	var announced := -1
	for entry: Dictionary in engine.telegraph():
		if String(entry.get("kind", "")) == "support":
			announced = int((entry["mends"] as Array)[0])
	assert_eq(announced, 3, "on n'annonce que ce qui manque vraiment")


## LE SOIN N'EST PAS UNE MENACE NÉGATIVE. Il ne doit ni teinter la case en
## rouge, ni s'additionner au total de dégâts d'une case — il masquerait
## une vraie menace au lieu de s'en distinguer.
func test_un_soin_ne_compte_pas_dans_la_menace() -> void:
	var board := _board()
	_enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var wounded := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_hero(board, &"archer", Vector2i(1, 4), 3)
	wounded.take_damage(100)

	var engine := _engine(board)
	assert_eq(
		engine.threat_on(wounded.cell), 0,
		"la case d'un soin ne porte aucune menace"
	)


# --- L'exécution ----------------------------------------------------------

func test_le_soin_annonce_est_le_soin_applique() -> void:
	var board := _board()
	var chaplain := _enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var wounded := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_hero(board, &"archer", Vector2i(1, 4), 3)
	wounded.take_damage(100)

	var engine := _engine(board)
	var announced := 0
	for entry: Dictionary in engine.telegraph():
		if int(entry["attacker_id"]) == chaplain.id:
			announced = int((entry["mends"] as Array)[0])
	var before := wounded.hit_points

	# On fait tourner la timeline jusqu'à ce que l'atelier ait exécuté.
	for _i in 40:
		if wounded.hit_points != before:
			break
		engine.end_activation()
	assert_eq(
		wounded.hit_points - before, announced,
		"le chiffre annoncé doit être le chiffre appliqué"
	)


# --- `requires_not_moved` -------------------------------------------------

## IL ÉTAIT IGNORÉ PAR L'IA, et c'était un mensonge : l'ennemi choisissait
## sa compétence sans jamais le lire, donc il se serait déplacé PUIS aurait
## porté un coup réservé à qui reste planté.
func test_un_ennemi_qui_a_bouge_retombe_sur_son_autre_coup() -> void:
	var board := _board()
	var chief := _enemy(board, &"the_boar_chief", Vector2i(5, 4), 1)
	_hero(board, &"warrior", Vector2i(4, 4), 2)

	var ai := EnemyAI.new(CombatRng.new(1))
	assert_eq(
		ai.intent_here(board, chief).ability_id, &"chief_lance",
		"arrêté, il annonce sa lance — trente-quatre en ligne de deux"
	)
	chief.has_moved = true
	assert_eq(
		ai.intent_here(board, chief).ability_id, &"boar_charge",
		"ayant chargé, la lance lui est interdite et il retombe sur son coup ordinaire"
	)


# --- La sauvegarde --------------------------------------------------------

## Le télégraphe fait partie de ce qu'on sauvegarde (T7.1). Une intention
## de soutien qui se rechargerait en attaque ferait frapper un aumônier.
func test_une_intention_de_soutien_survit_a_la_sauvegarde() -> void:
	var intent := CombatIntent.support_cell(
		7, &"field_suture", Vector2i(8, 4), Vector2i(7, 4)
	)
	var restored := CombatIntent.from_dictionary(intent.to_dictionary())
	assert_true(restored.is_support())
	assert_false(restored.is_attack())
	assert_eq(restored.ability_id, &"field_suture")
	assert_eq(restored.target_cell(Vector2i(8, 4)), Vector2i(7, 4))


## LES DEUX TABLEAUX FONT TOUJOURS LA LONGUEUR DE `cells`.
##
## Un consommateur du télégraphe indexe `damage` par la position dans
## `cells` — c'est ce que font la couche de combat, `threat_on` et un test
## d'intégration écrit à la Phase 1. Laisser `damage` VIDE sur une entrée de
## soutien était donc un piège : deux appelants avaient été protégés à la
## main, le troisième est tombé. On ne protège pas les appelants, on retire
## le piège.
func test_le_telegraphe_rend_des_tableaux_de_meme_longueur() -> void:
	var board := _board()
	_enemy(board, &"repair_shed", Vector2i(8, 4), 1)
	var wounded := _enemy(board, &"watch_tower", Vector2i(7, 4), 2)
	_enemy(board, &"siege_cannon", Vector2i(6, 4), 3)
	_hero(board, &"archer", Vector2i(1, 4), 4)
	wounded.take_damage(100)

	var engine := _engine(board)
	var kinds := {}
	for entry: Dictionary in engine.telegraph():
		var cells: Array = entry["cells"]
		kinds[String(entry.get("kind", ""))] = true
		assert_eq(
			(entry["damage"] as Array).size(), cells.size(),
			"« damage » doit faire la longueur de « cells »"
		)
		assert_eq(
			(entry["mends"] as Array).size(), cells.size(),
			"« mends » aussi"
		)
	assert_true(kinds.has("support"), "le relevé doit contenir un soutien")
	assert_true(kinds.has("attack"), "et une attaque, pour couvrir les deux")

