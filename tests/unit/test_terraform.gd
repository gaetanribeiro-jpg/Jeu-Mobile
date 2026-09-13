extends GutTest

## Façonner le sol du royaume (T12.15).
##
## CE QUI SE TESTE ICI EST LE REFUS, pas la réussite. Poser une colline
## marche du premier coup ; ce sont les quatre cas où il faut dire non qui
## font la différence entre une mécanique et un bouton — et l'un d'eux,
## « ça couperait l'île en deux », ne se voit sur aucune case prise seule.

const ISLAND := [
	"~~~~~~~~",
	"~..~~..~",
	"~......~",
	"~..~~..~",
	"~~~~~~~~",
]


func _rows(source: Array = ISLAND) -> PackedStringArray:
	var out := PackedStringArray()
	for line: Variant in source:
		out.append(String(line))
	return out


func test_elever_une_butte_change_la_case() -> void:
	var after := Terraform.applied(_rows(), Vector2i(2, 2), &"raise")
	assert_eq(after[2][2], "^", "la case devient une colline")
	assert_eq(after[2][1], ".", "sa voisine ne bouge pas")


func test_on_ne_faconne_que_le_bon_sol() -> void:
	assert_eq(
		Terraform.refusal(_rows(), Vector2i(0, 0), &"raise"), &"TERRAFORM_WRONG_GROUND",
		"on n'élève pas une butte sur la mer"
	)
	assert_eq(
		Terraform.refusal(_rows(), Vector2i(2, 2), &"level"), &"TERRAFORM_WRONG_GROUND",
		"on n'arase pas de l'herbe"
	)


func test_hors_du_plateau() -> void:
	assert_eq(
		Terraform.refusal(_rows(), Vector2i(99, 2), &"raise"), &"TERRAFORM_OFF_BOARD",
		"une case hors du royaume se refuse avant tout le reste"
	)


func test_on_ne_gagne_pas_sur_la_mer_au_large() -> void:
	# (0, 0) est de l'eau sans une seule rive voisine : une case posée là
	# serait injoignable, et c'est la leçon de T12.1.
	assert_eq(
		Terraform.refusal(_rows(), Vector2i(0, 0), &"reclaim"), &"TERRAFORM_NO_SHORE",
		"pas de terre au large"
	)
	assert_eq(
		Terraform.refusal(_rows(), Vector2i(3, 2 - 1), &"reclaim"), &"",
		"le long d'une rive, oui"
	)


func test_on_ne_coupe_pas_son_ile_en_deux() -> void:
	# La rangée 2 est le seul passage entre les deux moitiés de l'île :
	# l'inonder laisserait quatre cases d'un côté sans aucun chemin.
	var narrow := _rows([
		"~~~~~",
		"~.~.~",
		"~...~",
		"~.~.~",
		"~~~~~",
	])
	assert_eq(
		Terraform.refusal(narrow, Vector2i(2, 2), &"dig"), &"TERRAFORM_WOULD_SPLIT",
		"creuser au goulet couperait l'île"
	)
	assert_eq(
		Terraform.refusal(narrow, Vector2i(1, 1), &"dig"), &"",
		"creuser ailleurs est permis"
	)


func test_une_case_occupee_se_refuse() -> void:
	var taken: Array[Vector2i] = [Vector2i(2, 2)]
	assert_eq(
		Terraform.refusal(_rows(), Vector2i(2, 2), &"raise", taken), &"TERRAFORM_OCCUPIED",
		"on n'élève pas une butte sous un château"
	)


func test_chaque_travail_a_son_contraire() -> void:
	# Tout est réversible : c'est chez le joueur, et une faute de goût ne
	# doit jamais être définitive.
	var pairs := {}
	for work_id: StringName in Terraform.work_ids():
		for source: StringName in Terraform.sources(work_id):
			pairs["%s>%s" % [source, Terraform.target(work_id)]] = true
	for key: String in pairs.keys():
		var halves := key.split(">")
		assert_true(
			pairs.has("%s>%s" % [halves[1], halves[0]]),
			"« %s » doit pouvoir se défaire" % key
		)


func test_le_royaume_paie_et_retient_ce_qu_il_a_faconne() -> void:
	var kingdom := Kingdom.create()
	var before := kingdom.ground()
	var cell := _free_grass(kingdom)
	kingdom.grant(Terraform.cost(&"raise"))
	var stock := kingdom.amount(&"stone")
	assert_true(kingdom.shape(cell, &"raise"), "le travail passe")
	assert_lt(kingdom.amount(&"stone"), stock, "il se paie")
	assert_ne(kingdom.ground(), before, "le sol a changé")
	assert_eq(kingdom.ground()[cell.y][cell.x], "^", "et c'est bien une butte")


func test_il_ne_prend_rien_quand_il_refuse() -> void:
	var kingdom := Kingdom.create()
	var stock := kingdom.amount(&"stone")
	assert_false(kingdom.shape(Vector2i(0, 0), &"raise"), "la mer n'est pas de l'herbe")
	assert_eq(kingdom.amount(&"stone"), stock, "et rien n'a été pris")


func test_un_royaume_sans_le_sou_ne_faconne_pas() -> void:
	var kingdom := Kingdom.create()
	for resource_id: StringName in kingdom.stores.keys():
		kingdom.stores[resource_id] = 0
	assert_eq(
		kingdom.shape_refusal(_free_grass(kingdom), &"raise"), &"TERRAFORM_TOO_DEAR",
		"le prix se dit EN DERNIER : d'abord si c'est possible, ensuite si c'est payable"
	)


func test_le_sol_faconne_survit_a_la_sauvegarde() -> void:
	var kingdom := Kingdom.create()
	var cell := _free_grass(kingdom)
	kingdom.grant(Terraform.cost(&"raise"))
	assert_true(kingdom.shape(cell, &"raise"), "le travail passe")
	var reread := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_eq(reread.ground(), kingdom.ground(), "l'aller-retour rend le même sol")


func test_un_royaume_neuf_prend_le_sol_du_fichier() -> void:
	var kingdom := Kingdom.create()
	assert_eq(kingdom.ground(), KingdomGround.rows(),
		"vide veut dire « celui du fichier », ce qui laisse retoucher l'île de départ")


## Une case d'herbe que rien n'occupe. La chercher plutôt que l'écrire
## garde le test valable quand l'île de départ change.
func _free_grass(kingdom: Kingdom) -> Vector2i:
	var taken := kingdom.occupied_cells()
	var rows := kingdom.ground()
	for y in rows.size():
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			if taken.has(cell):
				continue
			if Terraform.allowed(rows, cell, &"raise", taken):
				return cell
	return Vector2i(-1, -1)


## CE QU'ON FAÇONNE EST CE SUR QUOI ON SE BAT (§ 38, § 43). C'est la seule
## chose qui sépare cette mécanique d'une décoration, donc c'est la seule
## qu'il faut absolument tenir : si la carte de défense cesse de lire le
## sol du royaume, terraformer redevient un joli bouton.
func test_le_sol_faconne_arrive_sur_la_carte_de_defense() -> void:
	var kingdom := Kingdom.create()
	var rng := CombatRng.new(1)
	var raid := Invasion.declare(rng, kingdom.building_levels(), 0)
	var before := DefenceMap.build(kingdom, raid, CombatRng.new(1))
	assert_not_null(before, "la carte se fabrique")

	# On élève tout ce qu'on peut sur la moitié DROITE, celle que la carte
	# de défense montre : c'est par là que l'assaut arrive.
	var taken := kingdom.occupied_cells()
	var raised := 0
	for x in range(KingdomGround.width() - 6, KingdomGround.width()):
		for y in KingdomGround.height():
			var cell := Vector2i(x, y)
			if not Terraform.allowed(kingdom.ground(), cell, &"raise", taken):
				continue
			kingdom.grant(Terraform.cost(&"raise"))
			if kingdom.shape(cell, &"raise"):
				raised += 1
	assert_gt(raised, 0, "il y avait bien de quoi élever")

	var after := DefenceMap.build(kingdom, raid, CombatRng.new(1))
	assert_ne(_terrains(after), _terrains(before),
		"la carte de défense a changé avec le sol du royaume")


## L'ASSAUT DOIT POUVOIR ARRIVER, QUOI QU'ON AIT CREUSÉ. Façonner son
## royaume doit pouvoir compliquer sa défense, jamais l'annuler : un joueur
## qui noierait tout son rivage gagnerait la bataille sans la livrer.
func test_on_ne_peut_pas_annuler_sa_propre_bataille() -> void:
	var kingdom := Kingdom.create()
	var taken := kingdom.occupied_cells()
	for x in KingdomGround.width():
		for y in KingdomGround.height():
			var cell := Vector2i(x, y)
			if not Terraform.allowed(kingdom.ground(), cell, &"dig", taken):
				continue
			kingdom.grant(Terraform.cost(&"dig"))
			kingdom.shape(cell, &"dig")

	var rng := CombatRng.new(3)
	var map := DefenceMap.build(kingdom, Invasion.declare(rng, 1, 0), CombatRng.new(3))
	assert_not_null(map, "la carte se fabrique encore")
	assert_false(map.deployment_cells.is_empty(), "le joueur a où se poser")
	var enemies := map.board.active_units(Unit.Side.ENEMIES)
	assert_false(enemies.is_empty(), "et l'assaut a des corps")
	for enemy: Unit in enemies:
		var tile := map.board.tile_at(enemy.cell)
		assert_true(tile != null and tile.is_walkable(),
			"un assaillant posé à l'eau se noierait avant le premier coup")


func _terrains(map: CombatMap) -> PackedStringArray:
	var out := PackedStringArray()
	for y in map.board.grid.height:
		var line := ""
		for x in map.board.grid.width:
			var tile := map.board.tile_at(Vector2i(x, y))
			line += String(tile.terrain_id) if tile != null else "?"
		out.append(line)
	return out
