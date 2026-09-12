class_name Kingdom
extends RefCounted

## Le royaume : ses réserves, ses habitants, ses chantiers (§ 6, § 9).
##
## LE CYCLE EST UNE EXPÉDITION, PAS UNE MINUTE. Aucun timer, aucune
## énergie — c'est une décision verrouillée, et le § 2 refuse le
## free-to-play. Le royaume produit une fois par sortie conclue, quelle
## qu'en soit la longueur.
##
## Cette règle-là n'est pas un détail d'implémentation, c'est ce qui relie
## les deux moitiés de la boucle du § 3 : une sortie COURTE rapporte plus
## de cycles, une sortie LONGUE rapporte plus de butin. Les deux se
## disputent le même temps, et « je rentre ou je continue ? » gagne un
## troisième terme sans qu'on ait rien ajouté à l'expédition.
##
## IL Y A TOUJOURS MOINS DE BRAS QUE DE PLACES. C'est ce qui fait de
## l'affectation une décision plutôt qu'un remplissage, et le § 50 réclame
## qu'un tour contienne un choix.
##
## L'OR N'EST PAS ICI. Il vit avec la compagnie — voir `ResourceTable`.
## Toutes les méthodes qui touchent à une ressource prennent donc la
## compagnie : c'est le prix, assumé, de n'avoir qu'une seule bourse.
##
## CLASSE PURE. Aucun nœud, aucune sauvegarde, aucun signal.

## Réserves du royaume : { ressource → quantité }. L'or n'y figure jamais.
var stores: Dictionary = {}

## LES HABITANTS SONT DES GENS (§ 9), et c'est la liste qui fait foi.
##
## `population` et `assignments` étaient un COMPTEUR et des comptes :
## douze bras interchangeables, répartis une fois et jamais revus. Un
## nombre n'est pas une décision — et c'est ce qui rendait la ville
## expédiable en trente secondes entre deux sorties.
##
## Les deux anciens noms survivent en PROPRIÉTÉS CALCULÉES juste en
## dessous : une trentaine d'appels et une dizaine de tests les lisent, et
## les réécrire tous n'aurait rien prouvé de plus que de les dériver.
var pawns: Array[Pawn] = []

## Nombre d'habitants. Écrire dedans ajoute ou retire des gens — c'est ce
## qui garde `kingdom.population = N` valable dans les tests et dans la
## relecture d'une sauvegarde ancienne.
var population: int:
	get:
		return pawns.size()
	set(value):
		_resize_population(value)

## Bras posés sur chaque chantier : { chantier → nombre }. DÉRIVÉ des
## postes des habitants, en lecture seule.
var assignments: Dictionary:
	get:
		var out := {}
		for pawn: Pawn in pawns:
			if not pawn.posting.is_empty():
				out[pawn.posting] = int(out.get(pawn.posting, 0)) + 1
		return out

## Cycles de production écoulés. Sert au journal et aux tests, jamais à un
## calcul de production — un royaume ne produit pas plus parce qu'il est
## vieux.
var cycles: int = 0

## Niveau de chaque bâtiment : { bâtiment → niveau }. Zéro signifie « pas
## encore bâti ».
var levels: Dictionary = {}

## Menace qui pèse sur le royaume (§ 37). Elle monte pendant que le joueur
## explore, et déclenche une invasion au-delà du seuil.
var threat: int = 0

## L'assaut déclaré, ou null. Il tombe après quelques étapes : c'est ce
## délai qui en fait un choix — rentrer défendre, ou continuer — plutôt
## qu'une nouvelle.
var invasion: Invasion = null

## Numéro de la fournée de candidats. Il monte d'un cran à chaque
## embauche, et c'est LUI qui renouvelle l'étal du recrutement.
##
## LES CANDIDATS SONT UNE FONCTION, PAS UN TIRAGE. Même raison que les
## rochers du rivage en T9.10 : ils ne doivent pas consommer la graine de
## la partie — sinon recruter décalerait le hasard de tout le reste — et
## surtout ils ne doivent pas changer quand on sort de l'écran et qu'on y
## revient. Un joueur qui peut relancer les dés en cliquant deux fois n'a
## pas trois candidats, il en a huit.
var recruit_round: int = 0

## Le crédit de chaque ville voisine : { ville → −3..+3 } (T12.10). Ce qui
## n'y figure pas vaut zéro, l'inconnu poli.
##
## LE CRÉDIT VIT DANS LA SAUVEGARDE, comme la campagne de T11.4 : le
## fichier dit ce que les villes SONT, la partie dit ce qui s'est passé
## entre elles et le joueur.
var standings: Dictionary = {}

## Le conseil qui attend le joueur, ou vide. Il est tiré à la fin d'un
## cycle et ne s'efface qu'une fois tranché.
##
## IL SURVIT À LA SAUVEGARDE, et il le faut : sur mobile l'application peut
## être tuée entre le retour au royaume et la décision, et un conseil qui
## disparaîtrait dans ce trou serait une décision volée au joueur.
var pending_council: StringName = &""

## Les derniers conseils vus, pour ne pas les reproposer tout de suite.
var recent_councils: Array[String] = []


static func create() -> Kingdom:
	var kingdom := Kingdom.new()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = ResourceTable.starting_amount(resource_id)
	kingdom.population = Worksite.starting_population()
	for building_id: StringName in Buildings.ids():
		kingdom.levels[building_id] = Buildings.starts_at(building_id)
	return kingdom


# --- Les réserves ----------------------------------------------------------

## Ce que le joueur possède d'une ressource, où qu'elle vive.
func amount(resource_id: StringName, company: Company = null) -> int:
	if not ResourceTable.lives_in_kingdom(resource_id):
		return company.gold if company != null else 0
	return int(stores.get(resource_id, 0))


func can_afford(cost: Dictionary, company: Company = null) -> bool:
	for key: Variant in cost.keys():
		var resource_id := StringName(key)
		if amount(resource_id, company) < int(cost[key]):
			return false
	return true


## Paie un coût. Ne prend rien si le compte n'y est pas : une dépense
## partielle laisserait le joueur sans son bâtiment ET sans ses réserves.
func pay(cost: Dictionary, company: Company = null) -> bool:
	if not can_afford(cost, company):
		return false
	for key: Variant in cost.keys():
		_add(StringName(key), -int(cost[key]), company)
	return true


func grant(gains: Dictionary, company: Company = null) -> void:
	for key: Variant in gains.keys():
		_add(StringName(key), int(gains[key]), company)


func _add(resource_id: StringName, delta: int, company: Company) -> void:
	if not ResourceTable.exists(resource_id):
		return
	if not ResourceTable.lives_in_kingdom(resource_id):
		if company != null:
			company.gold = maxi(company.gold + delta, 0)
		return
	stores[resource_id] = maxi(int(stores.get(resource_id, 0)) + delta, 0)


# --- Les bras --------------------------------------------------------------

func population_cap() -> int:
	return Worksite.base_population_cap() + int(_grants().get(&"population_cap", 0))


# --- Bâtir -----------------------------------------------------------------

func level_of(building_id: StringName) -> int:
	return int(levels.get(building_id, 0))


func is_built(building_id: StringName) -> bool:
	return level_of(building_id) > 0


## Le niveau le plus haut qu'un bâtiment puisse atteindre aujourd'hui.
##
## LE CHÂTEAU PLAFONNE TOUT LE RESTE. Sans cette règle on monterait une
## caserne au niveau 5 dans un hameau, et la progression du royaume
## n'aurait plus de colonne vertébrale. Le château, lui, ne se plafonne
## que lui-même — sinon rien ne pourrait jamais monter.
func reachable_level(building_id: StringName) -> int:
	var ceiling := Buildings.max_level(building_id)
	if building_id != Buildings.KEYSTONE:
		ceiling = mini(ceiling, level_of(Buildings.KEYSTONE))
	return ceiling


func next_level(building_id: StringName) -> int:
	if not Buildings.exists(building_id):
		return 0
	var wanted := level_of(building_id) + 1
	return wanted if wanted <= Buildings.max_level(building_id) else 0


## Ce que coûte le niveau suivant. Vide s'il n'y en a pas.
func next_cost(building_id: StringName) -> Dictionary:
	var wanted := next_level(building_id)
	if wanted <= 0:
		return {}
	return Buildings.cost_of(building_id, wanted)


## Pourquoi on ne peut pas bâtir : vide si on peut.
func blocked_because(building_id: StringName, company: Company = null) -> StringName:
	if not Buildings.exists(building_id):
		return &"unknown"
	var wanted := next_level(building_id)
	if wanted <= 0:
		return &"maxed"
	if wanted > reachable_level(building_id):
		return &"castle"
	if not can_afford(next_cost(building_id), company):
		return &"cost"
	return &""


func can_build(building_id: StringName, company: Company = null) -> bool:
	return blocked_because(building_id, company).is_empty()


## Monte un bâtiment d'un niveau. Renvoie le niveau atteint, ou zéro.
func build(building_id: StringName, company: Company = null) -> int:
	if not can_build(building_id, company):
		return 0
	var wanted := next_level(building_id)
	if not pay(next_cost(building_id), company):
		return 0
	levels[building_id] = wanted
	# Un plafond qui monte ne déplace personne ; un plafond qui descendrait
	# le ferait, et rien n'interdit à une donnée retouchée de le faire.
	settle_assignments()
	return wanted


# --- Ce que le royaume donne aux héros -------------------------------------
#
# C'est la réponse au § 45, dont la Phase 4 a pour objectif de « connecter
# le royaume au RPG ». Le sens de la dépendance ne bouge pas d'un pouce :
# le royaume rend un bloc de modificateurs, `Hero.effective_stats` l'ajoute
# comme il ajoute l'équipement, et ni `Hero` ni `Unit` ne savent qu'un
# royaume existe.

## Somme des gains de tous les bâtiments bâtis, toutes classes mêlées.
func _grants() -> Dictionary:
	var out := {}
	for building_id: StringName in levels.keys():
		if not Buildings.exists(building_id):
			continue
		var gained := Buildings.grants_up_to(building_id, level_of(building_id))
		for key: Variant in gained.keys():
			out[key] = Buildings.sum_grant(out.get(key, 0), gained[key])
	return out


## Les modificateurs qu'un héros de cette classe reçoit du royaume.
##
## Un bâtiment qui sert une classe ne donne qu'à elle : la caserne ne rend
## pas l'Archer plus fort, sinon bâtir ne serait plus un choix entre trois
## voies mais un cumul.
func hero_bonuses(class_id: StringName) -> Dictionary:
	var out := {}
	for building_id: StringName in levels.keys():
		if not Buildings.exists(building_id) or level_of(building_id) <= 0:
			continue
		var served := Buildings.hero_class(building_id)
		if not served.is_empty() and served != class_id:
			continue
		var gained := Buildings.grants_up_to(building_id, level_of(building_id))
		for key: Variant in gained.keys():
			# Le plafond de population, le soin et la brasserie ne sont pas
			# des statistiques de combat : les laisser passer les ferait
			# atterrir dans `Unit.from_stats`, qui les ignorerait en
			# silence — et un gain qu'on croit acquis sans qu'il le soit
			# est pire qu'un gain absent. La liste est dans les données,
			# parce qu'écrite ici elle oubliait la clé suivante.
			if Buildings.is_kingdom_grant(StringName(key)):
				continue
			out[key] = Buildings.sum_grant(out.get(key, 0), gained[key])
	return out


## Combien de potions le royaume prépare par cycle, et laquelle.
##
## LE PREMIER BÂTIMENT QUI PRODUIT AUTRE CHOSE QU'UN CHIFFRE. Le reproche
## était « les bâtiments ne font que monter des chiffres » : la Tour y
## répond en OUVRANT l'ascension, le Monastère en alimentant le sac.
##
## C'EST UN MAILLON D'OBTENTION, et c'est ce que `verify_world` a appris à
## chercher en Phase 10 : une mécanique complète dont il manque la façon
## d'y accéder n'est pas une mécanique. Les potions ne tombaient que du
## butin et de l'étal — deux fils que l'expédition alimente. Le royaume en
## ouvre un troisième, et c'est le seul qui récompense d'être RENTRÉ.
##
## LA POTION EST COMMUNE, exprès. Le monastère ne doit pas prendre la
## place du butin, qui reste la source des bonnes fioles ; il assure le
## fond de sac, pas la trouvaille.
func brew_per_cycle() -> int:
	return maxi(int(_grants().get(&"brew", 0)), 0)


## La potion préparée par le premier bâtiment qui en prépare une.
func brewed_potion() -> StringName:
	for building_id: StringName in levels.keys():
		if not Buildings.exists(building_id) or level_of(building_id) <= 0:
			continue
		var potion := Buildings.brews(building_id)
		if not potion.is_empty():
			return potion
	return &""


## Le rang d'ascension le plus haut que le royaume autorise aujourd'hui.
##
## C'est la TOUR qui décide, et son niveau se lit directement plutôt que
## par un `grant` : un rang n'est pas une statistique qui s'additionne, et
## le faire passer par `_grants()` l'aurait mélangé aux modificateurs de
## combat, où `Unit.from_stats` l'ignorerait en silence — le piège que
## `hero_bonuses` écarte déjà pour le plafond de population et le soin.
func tower_level() -> int:
	return level_of(Ascension.BUILDING)


## Élève un héros d'un rang. Rend le nouveau rang, ou -1 si c'est refusé.
##
## LE ROYAUME PAIE, LE HÉROS MONTE, et c'est le premier endroit du jeu où
## les deux systèmes se touchent vraiment (§ 45). Recruter demandait déjà
## un bâtiment, mais recruter est un DÉBUT ; élever est ce qui rend le
## royaume nécessaire à un héros qu'on a déjà.
func ascend(hero: Hero, company: Company = null) -> int:
	if not Ascension.can_ascend(hero, tower_level(), self, company):
		return -1
	var target := Ascension.next_rank(hero.rank)
	if not pay(Ascension.cost_of(target), company):
		return -1
	hero.rank = target
	hero.color = Ascension.color_of(target)
	return target


## Pourquoi ce héros ne peut pas s'élever. Chaîne vide s'il le peut.
func cannot_ascend_because(hero: Hero, company: Company = null) -> StringName:
	return Ascension.blocked_because(hero, tower_level(), self, company)


## Fraction des PV que le royaume rend à l'équipe entre deux rencontres.
##
## C'est le seul effet du royaume qui touche à l'expédition elle-même, et
## donc le seul qui déplace la courbe d'usure mesurée en T1.11.
func healing_between_steps() -> float:
	return float(_grants().get(&"heal_between_steps", 0.0))


## Les classes que le royaume sait recruter. Le premier héros de chaque
## classe vient d'un bâtiment : sans caserne, pas de Guerrier.
func recruitable_classes() -> Array[StringName]:
	var out: Array[StringName] = []
	for building_id: StringName in Buildings.ids():
		if level_of(building_id) <= 0:
			continue
		for served: StringName in Buildings.recruits(building_id):
			if not out.has(served):
				out.append(served)
	return out


## Les candidats que ce bâtiment propose en ce moment : trois noms, trois
## CARACTÈRES, et parfois deux CLASSES.
##
## L'HABITANT N'EST PAS UN HÉROS. Recruter ne prend personne à la
## population : un royaume qui perdrait un bûcheron chaque fois qu'il forme
## un Guerrier punirait le joueur d'avoir joué. Le § 9 les distingue
## d'ailleurs — les habitants travaillent, l'armée se bat.
##
## C'EST LE REPROCHE DE GAETAN, TRAITÉ : « un bâtiment = une classe = un
## héros générique ». Avec un seul recruté possible, l'écran n'offrait pas
## une décision, il offrait un bouton. Trois candidats dont aucun n'est
## meilleur — chaque trait rend exactement ce qu'il retire — obligent à
## répondre « de quoi mon équipe manque-t-elle ? ».
##
## AUCUN TIRAGE N'EST CONSOMMÉ sur `rng` : on en DÉRIVE un, salé par le
## bâtiment et par la fournée. Deux conséquences voulues : appeler deux
## fois rend les mêmes trois, et recruter ne décale pas le hasard des
## combats à venir.
func candidates(building_id: StringName, company: Company, rng: CombatRng) -> Array[Hero]:
	var out: Array[Hero] = []
	var taught := Buildings.recruits(building_id)
	if company == null or rng == null or taught.is_empty():
		return out
	if level_of(building_id) <= 0:
		return out
	var draw := rng.derive(hash([String(building_id), recruit_round]))
	# Les candidats se connaissent entre eux : ils évitent les prénoms de
	# la compagnie ET ceux de leurs concurrents, sinon l'étal proposerait
	# deux fois la même personne.
	var seen: Array[Hero] = company.heroes.duplicate()
	var traits: Array[StringName] = []
	for i in Buildings.candidate_count():
		var trait_id := HeroTrait.draw(draw, traits)
		# LA CLASSE TOURNE PLUTÔT QU'ELLE NE SE TIRE, quand le bâtiment en
		# forme plusieurs. Un tirage pourrait rendre trois fois la même et
		# l'étal n'offrirait alors que le choix qu'il offrait avant ; en
		# tournant, une caserne propose toujours les deux.
		var class_id: StringName = taught[i % taught.size()]
		var hero := Hero.recruit(company.next_id(), class_id, draw, seen, "Blue", trait_id)
		if hero == null:
			continue
		traits.append(trait_id)
		seen.append(hero)
		out.append(hero)
	return out


## Engage le candidat numéro `index`. Renvoie le héros, ou null.
##
## LE COÛT EST EN OR ET EN NOURRITURE : l'or parce qu'un héros s'équipe, la
## nourriture parce qu'il mange. Une seule monnaie aurait fait du
## recrutement un robinet ; deux en font un arbitrage contre les bâtiments,
## qui puisent dans la même bourse.
##
## LES DEUX AUTRES CANDIDATS PARTENT AVEC LUI. La fournée avance, donc
## celui qu'on n'a pas pris est perdu : c'est ce qui donne son poids au
## choix. Prendre le troisième « pour plus tard » n'existe pas.
func hire(
	building_id: StringName, index: int, company: Company, rng: CombatRng
) -> Hero:
	var offered := candidates(building_id, company, rng)
	if index < 0 or index >= offered.size():
		return null
	var cost := Buildings.recruit_cost(building_id)
	if cost.is_empty() or not pay(cost, company):
		return null
	var hero := offered[index]
	if not company.take(hero):
		# L'embauche a échoué après le paiement : on rend l'argent plutôt
		# que de laisser le joueur avec un trou dans ses réserves et
		# personne de plus.
		grant(cost, company)
		return null
	recruit_round += 1
	return hero


## Pourquoi on ne peut pas recruter ici : vide si on peut.
func cannot_recruit_because(building_id: StringName, company: Company = null) -> StringName:
	if Buildings.recruits(building_id).is_empty():
		return &"not_a_trainer"
	if level_of(building_id) <= 0:
		return &"not_built"
	if not can_afford(Buildings.recruit_cost(building_id), company):
		return &"cost"
	return &""


## Les habitants postés sur un chantier, dans l'ordre de la liste.
func workers_at(worksite_id: StringName) -> Array[Pawn]:
	var out: Array[Pawn] = []
	for pawn: Pawn in pawns:
		if pawn.posting == worksite_id:
			out.append(pawn)
	return out


## Les habitants qui montent la garde — ceux qu'on n'a posés nulle part.
func watch() -> Array[Pawn]:
	return workers_at(&"")


func pawn_by_id(pawn_id: int) -> Pawn:
	for pawn: Pawn in pawns:
		if pawn.id == pawn_id:
			return pawn
	return null


func assigned_to(worksite_id: StringName) -> int:
	return workers_at(worksite_id).size()


func assigned_total() -> int:
	var total := 0
	for pawn: Pawn in pawns:
		if not pawn.posting.is_empty():
			total += 1
	return total


## Habitants qui ne tiennent aucun chantier. Ils mangent quand même — et
## depuis T12.8 ils montent la garde, donc ils ne sont plus perdus.
func idle_pawns() -> int:
	return watch().size()


func can_assign(worksite_id: StringName) -> bool:
	if not Worksite.exists(worksite_id):
		return false
	return idle_pawns() > 0 and assigned_to(worksite_id) < Worksite.slots_of(worksite_id)


## Poste QUELQU'UN sur un chantier. Sans nom, c'est le plus EXPÉRIMENTÉ du
## métier qui y va.
##
## LE DÉFAUT EST LE MEILLEUR, et ce n'est pas un détail : un royaume qu'on
## remplit sans réfléchir doit rester jouable, et le geste rapide ne doit
## pas être le mauvais. Le joueur qui veut arbitrer désigne quelqu'un ;
## celui qui veut aller vite prend le bon par défaut.
func assign(worksite_id: StringName, pawn_id: int = -1) -> bool:
	if not can_assign(worksite_id):
		return false
	var chosen: Pawn = null
	if pawn_id >= 0:
		chosen = pawn_by_id(pawn_id)
		if chosen == null or not chosen.posting.is_empty():
			return false
	else:
		for pawn: Pawn in watch():
			if chosen == null or pawn.level_at(worksite_id) > chosen.level_at(worksite_id):
				chosen = pawn
	if chosen == null:
		return false
	chosen.posting = worksite_id
	return true


## Rappelle quelqu'un d'un chantier vers la garde. Sans nom, c'est le
## MOINS expérimenté qui part : le geste rapide garde les spécialistes.
func unassign(worksite_id: StringName, pawn_id: int = -1) -> bool:
	var posted := workers_at(worksite_id)
	if posted.is_empty():
		return false
	var chosen: Pawn = null
	if pawn_id >= 0:
		chosen = pawn_by_id(pawn_id)
		if chosen == null or chosen.posting != worksite_id:
			return false
	else:
		for pawn: Pawn in posted:
			if chosen == null or pawn.level_at(worksite_id) < chosen.level_at(worksite_id):
				chosen = pawn
	if chosen == null:
		return false
	chosen.posting = &""
	return true


## Renvoie à la garde les bras qu'un chantier rétréci ne peut plus tenir.
## À appeler quand la population baisse ou qu'un chantier change de taille :
## un chantier tenu par des gens qui n'existent plus produirait du bois
## avec des fantômes.
##
## LES DERNIERS ARRIVÉS PARTENT LES PREMIERS, ce qui revient à garder les
## plus anciens — donc les plus expérimentés, puisque l'expérience se
## gagne en restant.
func settle_assignments() -> void:
	for worksite_id: StringName in Worksite.ids():
		var limit := Worksite.slots_of(worksite_id)
		var posted := workers_at(worksite_id)
		for i in range(limit, posted.size()):
			posted[i].posting = &""


## Ajuste la population à un nombre donné. Les arrivants reçoivent un
## identifiant neuf, les partants sont pris parmi les derniers venus.
func _resize_population(wanted: int) -> void:
	var target := maxi(wanted, 0)
	while pawns.size() > target:
		pawns.pop_back()
	while pawns.size() < target:
		pawns.append(Pawn.create(_next_pawn_id()))


## Prochain identifiant d'habitant. Il ne redescend jamais : deux
## habitants qui le partageraient s'écraseraient à la sauvegarde.
func _next_pawn_id() -> int:
	var highest := -1
	for pawn: Pawn in pawns:
		highest = maxi(highest, pawn.id)
	return highest + 1


# --- La menace (§ 37) ------------------------------------------------------
#
# Jusqu'ici, partir en expédition ne coûtait rien au royaume : il produisait
# pendant l'absence, sans risque. L'invasion le met EN JEU, et donne au § 29
# une seconde question — « je rentre pour le butin » devient « je rentre
# pour le butin OU pour défendre ».

## Somme des niveaux bâtis. C'est la mesure de ce qu'il y a à prendre, et
## de ce qui tient debout : elle sert à la menace comme à la défense.
func building_levels() -> int:
	var total := 0
	for building_id: StringName in levels.keys():
		if Buildings.exists(building_id):
			total += level_of(building_id)
	return total


## Une étape d'expédition de plus loin du royaume. Renvoie l'assaut s'il
## vient de se déclarer, sinon null.
##
## LA MENACE EST UN COMPTEUR, PAS UNE PROBABILITÉ. Un tirage pourrait
## épargner un joueur toute une partie, et une mécanique qu'on peut ne
## jamais rencontrer n'en est pas une.
func raise_threat(rng: CombatRng, depth: int) -> Invasion:
	if invasion != null:
		invasion.advance()
		return null
	threat += Invasion.threat_per_step(building_levels())
	if threat < Invasion.threat_trigger():
		return null
	threat = 0
	invasion = Invasion.declare(rng, building_levels(), depth)
	return invasion


## Ce que les bâtiments bâtis opposent à un assaut. Vient de leurs gains
## déclarés, pas de leurs NIVEAUX : la tour de guet en donne trois par
## niveau, la maison aucun.
func ward_strength() -> int:
	return maxi(int(_grants().get(&"ward", 0)), 0)


## Les bras montés à la garde : ceux qu'on n'a PAS mis sur un chantier.
##
## C'EST LA DÉCISION QUI MANQUAIT AU ROYAUME, et elle se prend à chaque
## retour : un bras à la garde vaut quatre fois un bras au travail pour la
## défense, et ne produit rien. Se protéger se paie donc en production,
## contre une menace qu'on voit monter.
##
## LES BRAS EN TROP CESSENT D'ÊTRE PERDUS. À population maximale le royaume
## a quatorze habitants pour douze places : deux étaient OISIFS pour
## toujours, et le carnet affirmait pourtant « il y a toujours moins de
## bras que de places ». Ce n'était plus vrai au sommet, et la tension du
## système s'y évaporait.
func garrison() -> int:
	return idle_pawns()


## L'assaut que ce royaume ATTIRE, sans le tirage. C'est ce qu'il faut
## afficher au joueur pour qu'il décide combien de bras il met à la garde :
## la menace monte pendant l'expédition et retombe au retour, donc il n'y a
## presque jamais d'invasion DÉCLARÉE au moment où l'on compose la garde.
##
## SANS LA VARIANCE, ET C'EST VOLONTAIRE. Le vrai assaut tire à ±20 % ; on
## annonce le socle, pas le pire cas. Annoncer le pire ferait garnison
## pleine à chaque sortie, annoncer une moyenne mentirait une fois sur
## deux. Le socle se compare, et le joueur apprend vite qu'il faut de la
## marge — ce qui est la bonne leçon.
func expected_assault() -> int:
	return Invasion.declare(null, building_levels(), 0).strength


## Le royaume tiendrait-il SEUL l'assaut qu'il attire aujourd'hui ?
##
## C'est la question que la garde pose, réduite à un oui ou un non — et
## c'est ce qu'il faut pour un coup d'œil. Le § 37 veut que rentrer soit
## meilleur, jamais obligatoire : ce booléen dit donc si l'on PEUT partir
## tranquille, pas si l'on doit rentrer.
func holds_alone() -> bool:
	return defence_strength() >= expected_assault()


func defence_strength(hero_levels: int = 0) -> int:
	return Invasion.defence_of(
		ward_strength(), assigned_total(), garrison(), hero_levels
	)


## Résout l'assaut. `hero_levels` est la somme des niveaux des héros
## rentrés défendre — zéro si l'armée est seule (§ 37).
##
## Renvoie { repelled, strength, defence, spoils, plundered }.
func resolve_invasion(company: Company, hero_levels: int = 0) -> Dictionary:
	if invasion == null:
		return {}
	return settle_invasion(company, invasion.is_repelled_by(defence_strength(hero_levels)),
		defence_strength(hero_levels))


## Applique une issue DÉJÀ DÉCIDÉE. C'est par là que passe la bataille du
## § 38 : quand le joueur défend lui-même, c'est le plateau qui tranche, et
## comparer deux nombres par-dessus reviendrait à lui dire qu'il a gagné
## pour de faux.
func settle_invasion(company: Company, repelled: bool, defence: int = 0) -> Dictionary:
	if invasion == null:
		return {}
	var raid := invasion
	var report := {
		"repelled": repelled,
		"strength": raid.strength,
		"defence": defence,
		"spoils": 0,
		"plundered": {},
	}
	if repelled:
		report["spoils"] = raid.spoils()
		grant({&"gold": raid.spoils()}, company)
	else:
		report["plundered"] = Invasion.plunder(self, company)
	invasion = null
	return report


# --- Le cycle de production ------------------------------------------------

## Une sortie conclue = un cycle. Renvoie de quoi le raconter au joueur :
## { produced, eaten, arrived, hungry }.
##
## L'ORDRE COMPTE. On produit d'abord, on mange ensuite, on accueille en
## dernier : sinon un habitant arriverait pour manger une nourriture que
## personne n'a encore récoltée, et le premier cycle affamerait le royaume
## qu'on vient de fonder.
## `rng` sert au conseil du retour (T12.10) et à rien d'autre. Il est
## optionnel : un test qui mesure la production n'a pas à se soucier de la
## diplomatie, et un cycle sans générateur ne propose simplement rien.
func run_cycle(company: Company = null, rng: CombatRng = null) -> Dictionary:
	cycles += 1
	# ÊTRE CHEZ SOI PROTÈGE. La menace retombe au retour, sinon elle
	# s'accumulerait d'une sortie à l'autre et un royaume avancé vivrait
	# sous alarme permanente.
	threat = 0
	settle_assignments()

	# CHACUN REND CE QUE SON MÉTIER VAUT (§ 9). Ce n'est plus « la base du
	# chantier × le nombre de bras » : un bûcheron de rang 4 rapporte
	# presque le double d'un débutant, et c'est la seconde piste de
	# progression du royaume — celle qui ne s'achète pas.
	var produced := {}
	for pawn: Pawn in pawns:
		if pawn.posting.is_empty():
			continue
		var resource_id := Worksite.resource_of(pawn.posting)
		produced[resource_id] = int(produced.get(resource_id, 0)) + pawn.yield_at(pawn.posting)
	grant(produced, company)

	# LE MÉTIER S'APPREND APRÈS AVOIR PRODUIT, jamais avant : sinon le
	# premier cycle d'un nouveau venu paierait déjà son premier rang, et
	# le compte rendu annoncerait une récolte qu'il n'a pas faite.
	#
	# QUI MONTE D'UN RANG EST RELEVÉ ICI. Sans ça, la progression des
	# métiers est invisible jusqu'à ce qu'on rouvre un panneau — et une
	# récompense qu'on ne voit pas ne récompense rien. C'est le retour qui
	# manquait à la décision « qui je laisse où ».
	var promoted: Array[Dictionary] = []
	for pawn: Pawn in pawns:
		if pawn.posting.is_empty():
			continue
		var before := pawn.level_at(pawn.posting)
		var worksite_id := pawn.posting
		pawn.work_a_cycle()
		if pawn.level_at(worksite_id) > before:
			promoted.append({
				"name": pawn.given_name(),
				"worksite": worksite_id,
				"level": pawn.level_at(worksite_id),
				"master": pawn.is_master_at(worksite_id),
			})

	var eaten := Worksite.food_per_pawn() * population
	var larder := amount(&"food")
	# Personne ne meurt de faim : la réserve tombe à zéro et le royaume
	# n'accueille plus. Le § 41 refuse la punition absolue, et affamer un
	# village pendant que le joueur est en expédition en serait une — il
	# n'était même pas là pour l'empêcher.
	var hungry := larder < eaten
	_add(&"food", -eaten, company)

	var arrived := false
	if not hungry and population < population_cap() and amount(&"food") >= Worksite.arrival_food():
		_add(&"food", -Worksite.arrival_food(), company)
		# UN ARRIVANT EST QUELQU'UN, et il arrive À LA GARDE : il ne prend
		# pas tout seul la place d'un spécialiste sur un chantier, c'est au
		# joueur de le placer. Un habitant qui s'affecterait seul serait un
		# bras de plus, pas une personne de plus.
		pawns.append(Pawn.create(_next_pawn_id()))
		arrived = true

	# LA POTION VA DANS LE SAC, PAS DANS LA RÉSERVE — même raisonnement
	# qu'en T10.2 : elle est buvable à la sortie suivante, sinon le fil
	# d'obtention s'arrête juste avant de servir.
	var brewed := {}
	var potion := brewed_potion()
	var batch := brew_per_cycle()
	if company != null and batch > 0 and Consumable.exists(potion):
		company.supplies[potion] = int(company.supplies.get(potion, 0)) + batch
		brewed[potion] = batch

	# LES PRÊTS SE RÈGLENT AU CYCLE, comme tout le reste du royaume. Un
	# prêt compté en cycles et pas en minutes est la même décision verrouillée
	# que la production : pas de timer, pas d'énergie (§ 2).
	var returned := settle_loans(company)

	# LE CONSEIL SE TIRE À LA FIN DU CYCLE, et il attend. Un conseil déjà
	# posé n'est pas remplacé : il a été tiré pour une décision que le
	# joueur n'a pas encore prise, et l'écraser la lui volerait.
	#
	# LE TIRAGE EST UNE FONCTION DU CYCLE, pas un tirage : on DÉRIVE le
	# générateur du numéro de cycle. Deux conséquences voulues — sortir de
	# l'écran du royaume et y revenir rend le même conseil, et le conseil
	# ne décale pas le hasard des combats à venir. Même règle que les
	# candidats du recrutement (T12.3) et que les rochers du rivage (T9.10).
	if rng != null and pending_council.is_empty():
		pending_council = KingdomEvent.draw(
			rng.derive(hash(["council", cycles])), recent_councils, standings
		)

	return {
		"produced": produced,
		"eaten": eaten,
		"arrived": arrived,
		"hungry": hungry,
		"brewed": brewed,
		"promoted": promoted,
		"council": String(pending_council),
		"returned": returned,
		"cycle": cycles,
	}


# --- Le conseil et les villes voisines (T12.10) -----------------------------
#
# LE ROYAUME AVAIT DEUX DÉCISIONS ET PAS UNE TROISIÈME. Bâtir quoi, et qui
# travaille où : deux arbitrages qu'on pose une fois et qu'on revoit
# rarement. Le conseil en ajoute une qui se REPOSE à chaque retour, et
# c'est ce que le § 50 réclame — un tour doit contenir un choix.
#
# LES VILLES SONT UNE MÉMOIRE. Le crédit ne s'achète pas : il monte quand
# on commerce, descend quand on refuse, et OUVRE des offres. C'est ce qui
# le sépare de l'or, et ce qui empêche un royaume riche de tout obtenir
# d'un coup au premier retour.

## Le crédit d'une ville. Zéro pour celle avec qui rien ne s'est passé.
func standing_of(town_id: StringName) -> int:
	return Neighbour.clamp_standing(int(standings.get(town_id, 0)))


## Le nom du palier où en est une ville, pour l'écran.
func standing_key(town_id: StringName) -> String:
	return Neighbour.standing_key(standing_of(town_id))


## Fait bouger un crédit et rend sa nouvelle valeur.
func shift_standing(town_id: StringName, delta: int) -> int:
	if not Neighbour.exists(town_id):
		return 0
	standings[town_id] = Neighbour.clamp_standing(standing_of(town_id) + delta)
	return int(standings[town_id])


## Le conseil qui attend, ou vide.
func council() -> StringName:
	return pending_council if KingdomEvent.exists(pending_council) else &""


## Une option qu'on ne peut pas payer reste PROPOSÉE, grisée : savoir ce
## qu'on ne peut pas s'offrir fait partie de la décision. Même règle que
## l'étal du marchand et que les évènements d'expédition.
func can_choose(index: int, company: Company = null) -> bool:
	if council().is_empty():
		return false
	# UNE OPTION QUI N'EXISTE PAS N'EST PAS CHOISISSABLE, et le dire ici
	# évite que `resolve_council` la porte jusqu'à la table, qui pousserait
	# une erreur pour un index qu'aucun bouton n'a jamais offert.
	if KingdomEvent.option(council(), index).is_empty():
		return false
	return can_afford(KingdomEvent.option_cost(council(), index), company)


## Tranche le conseil en cours. Renvoie de quoi le raconter au joueur, ou
## vide si l'option n'existe pas ou n'est pas payable.
##
## LE CONSEIL S'EFFACE APRÈS, jamais avant : une option refusée pour cause
## de réserves vides ne doit pas emporter la décision avec elle.
func resolve_council(index: int, company: Company = null, rng: CombatRng = null) -> Dictionary:
	var event_id := council()
	if event_id.is_empty() or not can_choose(index, company):
		return {}
	var effects := KingdomEvent.resolve(event_id, index, rng)
	if effects.is_empty():
		return {}
	var report := _apply_council(effects, company, rng)
	pending_council = &""
	recent_councils.append(String(event_id))
	while recent_councils.size() > KingdomEvent.recent_kept():
		recent_councils.pop_front()
	return report


## Applique ce qu'une option a produit. C'est ICI que le royaume encaisse ;
## `KingdomEvent` n'a fait que lire la table et jeter le dé.
func _apply_council(effects: Dictionary, company: Company, rng: CombatRng) -> Dictionary:
	var moved := {}
	for resource_id: StringName in ResourceTable.ids():
		var delta := int(effects.get(String(resource_id), 0))
		if delta != 0:
			_add(resource_id, delta, company)
			moved[resource_id] = delta

	if effects.has("threat"):
		threat = maxi(threat + int(effects["threat"]), 0)

	# QUI PART EST LE MOINS EXPÉRIMENTÉ, et c'est la règle du rappel de
	# T12.8 poussée d'un cran : le geste rapide ne doit pas détruire ce que
	# le joueur a patiemment formé. Un déserteur emporte son métier avec
	# lui ; qu'il emporte le meilleur serait une punition déguisée.
	var arrived := 0
	var left: Array[String] = []
	var newcomers := int(effects.get("population", 0))
	while newcomers < 0 and not pawns.is_empty():
		var leaving: Pawn = null
		for pawn: Pawn in pawns:
			if leaving == null or _invested(pawn) < _invested(leaving):
				leaving = pawn
		left.append(leaving.given_name())
		pawns.erase(leaving)
		newcomers += 1
	# UN ARRIVANT N'ENTRE PAS SI LE ROYAUME NE PEUT PAS LE NOURRIR. Le
	# plafond de population est une promesse faite ailleurs dans l'écran ;
	# un conseil qui le dépasserait la ferait mentir.
	while newcomers > 0 and pawns.size() < population_cap():
		pawns.append(Pawn.create(_next_pawn_id()))
		newcomers -= 1
		arrived += 1
	if not left.is_empty():
		settle_assignments()

	var learned := {}
	for key: Variant in (effects.get("trade_xp", {}) as Dictionary).keys():
		var worksite_id := StringName(key)
		var amount := int((effects["trade_xp"] as Dictionary)[key])
		var taught := workers_at(worksite_id)
		for pawn: Pawn in taught:
			pawn.learn(worksite_id, amount)
		if not taught.is_empty():
			learned[worksite_id] = taught.size()

	var credits := {}
	for key: Variant in (effects.get("standing", {}) as Dictionary).keys():
		var town_id := StringName(key)
		credits[town_id] = shift_standing(town_id, int((effects["standing"] as Dictionary)[key]))

	# LA POTION VA DANS LE SAC, PAS DANS LA RÉSERVE — règle de T10.2 : elle
	# est buvable à la sortie suivante, sinon le fil d'obtention s'arrête
	# juste avant de servir.
	var flasks := {}
	for key: Variant in (effects.get("potions", {}) as Dictionary).keys():
		var potion := StringName(key)
		var count := int((effects["potions"] as Dictionary)[key])
		if company != null and count > 0 and Consumable.exists(potion):
			company.supplies[potion] = int(company.supplies.get(potion, 0)) + count
			flasks[potion] = count

	var champion := _welcome_champion(effects.get("hero", {}), company, rng)

	var report := effects.duplicate()
	report["moved"] = moved
	report["arrived"] = arrived
	report["left"] = left
	report["learned"] = learned
	report["credits"] = credits
	report["flasks"] = flasks
	report["champion"] = champion
	return report


## Ce qu'un habitant a appris en tout, tous métiers confondus. Sert à
## désigner celui qui part : le moins investi, pas le dernier arrivé.
func _invested(pawn: Pawn) -> int:
	var total := 0
	for worksite_id: Variant in pawn.experience.keys():
		total += int(pawn.experience[worksite_id])
	return total


## Le champion qu'une ville confie, s'il y en a un.
##
## IL ARRIVE DÉJÀ AGUERRI, et c'est tout l'intérêt : la caserne ne sait
## former que des recrues de niveau 1, et monter quelqu'un coûte des
## combats. Un champion est ce que le crédit achète et que l'or ne peut
## pas.
func _welcome_champion(raw: Variant, company: Company, rng: CombatRng) -> Hero:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty() or company == null:
		return null
	var gift: Dictionary = raw
	var hero := Hero.recruit(
		company.next_id(), StringName(gift.get("class", "")), rng, company.heroes,
		String(gift.get("color", "Blue")), StringName(gift.get("trait", ""))
	)
	if hero == null:
		return null
	# IL ARRIVE AVEC L'EXPÉRIENCE DE SON RANG, pas avec un niveau posé à la
	# main : la table de progression reste la seule source, et le champion
	# continue de monter comme n'importe qui après son arrivée. Un niveau
	# sans son expérience aurait fait un héros qui ne progresse plus.
	hero.experience = HeroProgression.experience_to_reach(
		maxi(int(gift.get("level", 1)), 1)
	)
	hero.level_up_free()
	if not company.take(hero):
		return null
	return hero


# --- Prêter un héros à une voisine (T12.12) --------------------------------
#
# C'EST LA DÉCISION DU § 9 TRANSPOSÉE AUX HÉROS : « qui peux-tu te
# passer ? ». Le coût est un CORPS, dans un jeu où l'équipe est de quatre —
# et c'est ce qui donne enfin une valeur au recruté de trop, que T12.7
# avait rendu jouable sans lui donner d'emploi.

## Pourquoi on ne peut pas prêter celui-là : vide si on peut.
func cannot_lend_because(
	hero: Hero, town_id: StringName, company: Company = null
) -> StringName:
	if hero == null or company == null:
		return &"nobody"
	if not Neighbour.exists(town_id):
		return &"no_town"
	if not hero.is_available():
		return &"already_away"
	# ON NE CONFIE PAS UN DES SIENS À UNE VILLE BROUILLÉE. Le crédit ouvre
	# des offres (T12.10) ; il ferme aussi des portes.
	if standing_of(town_id) < Neighbour.loan_minimum_standing():
		return &"standing"
	if company.available().size() <= Neighbour.loan_minimum_left():
		return &"too_few"
	return &""


func can_lend(hero: Hero, town_id: StringName, company: Company = null) -> bool:
	return cannot_lend_because(hero, town_id, company).is_empty()


## Confie un héros à une ville pour quelques cycles. Il quitte l'équipe
## tout de suite ; il revient au cycle dit, payé et aguerri.
func lend(hero: Hero, town_id: StringName, company: Company = null) -> bool:
	if not can_lend(hero, town_id, company):
		return false
	hero.away_town = town_id
	hero.away_cycles = Neighbour.loan_cycles()
	# L'ÉQUIPE SE REMET D'APLOMB TOUT DE SUITE, sinon le joueur part avec
	# un fantôme : `squad_units` rendrait trois corps pour quatre noms.
	company.settle_squad()
	return true


## Fait passer un cycle à ceux qui sont en mission, et ramène ceux dont le
## temps est fait. Renvoie la liste de ce qu'il faut raconter.
##
## IL REVIENT PLUS FORT QU'IL N'EST PARTI, et c'est voulu : sans ça, prêter
## serait une punition qu'on n'accepterait que par obligation. L'expérience
## est calée sur ce qu'une sortie rapporte, donc prêter n'est jamais
## MEILLEUR que jouer — c'est un plancher qu'on encaisse contre un corps.
func settle_loans(company: Company = null) -> Array[Dictionary]:
	var back: Array[Dictionary] = []
	if company == null:
		return back
	for hero: Hero in company.heroes:
		if hero.is_available():
			continue
		hero.away_cycles -= 1
		if hero.away_cycles > 0:
			continue
		var town_id := hero.away_town
		var cycles := maxi(Neighbour.loan_cycles(), 1)
		var wages := Neighbour.loan_gold() * cycles
		var learned := Neighbour.loan_experience() * cycles
		hero.away_cycles = 0
		hero.away_town = &""
		_add(&"gold", wages, company)
		hero.add_experience(learned)
		hero.level_up_free()
		shift_standing(town_id, Neighbour.loan_standing())
		back.append({
			"name": hero.display_name(),
			"town": String(town_id),
			"gold": wages,
			"experience": learned,
			"level": hero.level,
		})
	if not back.is_empty():
		company.settle_squad()
	return back


# --- Sérialisation ---------------------------------------------------------

func to_dictionary() -> Dictionary:
	var saved_stores := {}
	for resource_id: StringName in stores.keys():
		saved_stores[String(resource_id)] = int(stores[resource_id])
	var saved_people: Array = []
	for pawn: Pawn in pawns:
		saved_people.append(pawn.to_dictionary())
	var saved_levels := {}
	for building_id: StringName in levels.keys():
		saved_levels[String(building_id)] = int(levels[building_id])
	var saved_standings := {}
	for town_id: StringName in standings.keys():
		saved_standings[String(town_id)] = int(standings[town_id])
	return {
		"stores": saved_stores,
		"pawns": saved_people,
		"levels": saved_levels,
		"cycles": cycles,
		"threat": threat,
		"recruit_round": recruit_round,
		"standings": saved_standings,
		"council": String(pending_council),
		"recent_councils": recent_councils.duplicate(),
		"invasion": invasion.to_dictionary() if invasion != null else {},
	}


static func from_dictionary(data: Dictionary) -> Kingdom:
	var kingdom := Kingdom.create()
	if data.is_empty():
		return kingdom
	kingdom.stores.clear()
	for key: Variant in (data.get("stores", {}) as Dictionary).keys():
		var resource_id := StringName(key)
		# Une ressource retirée des données depuis la sauvegarde disparaît
		# des réserves, sans emporter la partie avec elle.
		if ResourceTable.exists(resource_id) and ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = int((data["stores"] as Dictionary)[key])
	# LES HABITANTS D'ABORD : `population` et `assignments` ne sont plus
	# que des vues sur la liste, et une sauvegarde ANCIENNE n'a que ces
	# deux-là. On lit donc les gens s'ils sont écrits, et on retombe sur le
	# compteur sinon — une partie d'avant le § 9 garde ses habitants, elle
	# perd seulement leurs métiers, qui n'existaient pas.
	kingdom.pawns.clear()
	for raw: Variant in data.get("pawns", []):
		kingdom.pawns.append(Pawn.from_dictionary(raw))
	if kingdom.pawns.is_empty():
		kingdom.population = int(data.get("population", 0))
		for key: Variant in (data.get("assignments", {}) as Dictionary).keys():
			if not Worksite.exists(StringName(key)):
				continue
			for i in int((data["assignments"] as Dictionary)[key]):
				kingdom.assign(StringName(key))
	kingdom.cycles = int(data.get("cycles", 0))
	for key: Variant in (data.get("levels", {}) as Dictionary).keys():
		var building_id := StringName(key)
		# Un bâtiment retiré des données depuis la sauvegarde disparaît du
		# royaume, sans emporter la partie avec lui.
		if Buildings.exists(building_id):
			kingdom.levels[building_id] = clampi(
				int((data["levels"] as Dictionary)[key]),
				Buildings.starts_at(building_id),
				Buildings.max_level(building_id)
			)
	kingdom.threat = int(data.get("threat", 0))
	# Sans elle, rouvrir une partie sauvegardée reproposerait la fournée du
	# tout premier jour — et l'étal du recrutement remonterait le temps.
	kingdom.recruit_round = maxi(int(data.get("recruit_round", 0)), 0)
	# UNE VILLE RETIRÉE DES DONNÉES DISPARAÎT DES CRÉDITS, sans emporter la
	# partie avec elle — même règle que pour les ressources et les
	# bâtiments juste au-dessus.
	for key: Variant in (data.get("standings", {}) as Dictionary).keys():
		var town_id := StringName(key)
		if Neighbour.exists(town_id):
			kingdom.standings[town_id] = Neighbour.clamp_standing(
				int((data["standings"] as Dictionary)[key])
			)
	# LE CONSEIL SURVIT À LA SAUVEGARDE. Sur mobile l'application peut être
	# tuée entre le retour au royaume et la décision, et un conseil perdu
	# dans ce trou serait une décision volée au joueur.
	var waiting := StringName(data.get("council", ""))
	kingdom.pending_council = waiting if KingdomEvent.exists(waiting) else &""
	kingdom.recent_councils.clear()
	for raw: Variant in data.get("recent_councils", []):
		if KingdomEvent.exists(StringName(raw)):
			kingdom.recent_councils.append(String(raw))
	kingdom.invasion = Invasion.from_dictionary(data.get("invasion", {}))
	kingdom.settle_assignments()
	return kingdom
