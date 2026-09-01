extends Node

## État global de la partie en cours.
##
## Ne contient pas de logique de jeu : c'est un porteur de données et le
## propriétaire du générateur aléatoire. Toute la logique vit dans `engine/`.

## Générateur aléatoire unique de la partie.
##
## RÈGLE DURE : jamais de `randi()` ni de `randf()` en direct dans le code.
## Tout passe par ici, pour qu'une partie soit rejouable à l'identique à
## partir de sa graine et qu'un bug signalé soit reproductible.
var rng := RandomNumberGenerator.new()

## Graine de la partie. Fixée à la création, sauvegardée, jamais retirée.
var campaign_seed: int = 0

## La compagnie du joueur : ses héros, son or, sa réserve. C'est le seul
## état qui traverse les rencontres, et donc le seul qu'il faille écrire
## sur le disque.
var company := Company.new()

## L'expédition en cours, ou null si le joueur est au royaume.
##
## ELLE FAIT PARTIE DE LA SAUVEGARDE. Sur mobile l'application meurt en
## pleine sortie, et perdre une expédition pour cette raison serait la pire
## des punitions — précisément celle que le § 41 refuse pour la mort.
var expedition: Expedition = null

## Le royaume : ses réserves, ses habitants, ses chantiers, ses bâtiments.
## Il produit UNE FOIS PAR SORTIE CONCLUE — aucun timer, c'est une décision
## verrouillée et le § 2 refuse le free-to-play.
var kingdom := Kingdom.create()

## Le combat en cours, ou null.
##
## SUR MOBILE L'APPLICATION MEURT À TOUT MOMENT. L'expédition survivait
## déjà à ça, le combat non : perdre sept rondes parce qu'un appel arrive
## est exactement la punition que le § 41 refuse.
##
## C'est un MOTEUR, pas un dictionnaire : on le tient sous sa vraie forme
## en mémoire, et on ne le sérialise qu'au moment d'écrire. La scène de
## combat reprend donc un objet vivant, pas une carte à remonter.
var combat: CombatEngine = null

## Identifiant de la carte du combat en cours. Une carte de défense du
## royaume n'existe dans aucun fichier, donc cet identifiant ne suffit pas
## à la reconstruire — c'est le moteur sauvegardé qui porte le plateau, et
## l'identifiant ne sert qu'à savoir de quel combat il s'agit.
var combat_map_id: StringName = &""

## L'heure à laquelle ce combat se livre (§ 36).
##
## ELLE SE SAUVEGARDE, elle ne se déduit pas. `Expedition.moment()` la
## déduit de l'indice d'étape, et c'est juste POUR UNE EXPÉDITION — mais un
## combat n'en vient pas toujours d'une. Un combat du banc d'essai, ou une
## défense de royaume, n'a aucun indice d'où la tirer : le premier essai
## rechargeait la nuit en plein jour, plateau identique et teinte
## disparue. L'heure est une propriété DE CE COMBAT ; elle va donc là où
## va son identifiant de carte.
var combat_moment: StringName = DayNight.DEFAULT_MOMENT


func _ready() -> void:
	if campaign_seed == 0:
		start_new_campaign(_generate_seed())


## Démarre une campagne avec une graine donnée.
func start_new_campaign(seed_value: int) -> void:
	campaign_seed = seed_value
	rng.seed = seed_value
	company = Company.new()
	expedition = null
	kingdom = Kingdom.create()
	combat = null
	combat_map_id = &""
	combat_moment = DayNight.DEFAULT_MOMENT


## Tout ce qu'il faut écrire pour retrouver la partie où on l'a laissée.
func to_save() -> Dictionary:
	var data := {
		"seed": campaign_seed,
		"company": company.to_dictionary(),
		"kingdom": kingdom.to_dictionary(),
	}
	if expedition != null:
		data["expedition"] = expedition.to_dictionary()
	# Un combat fini n'a rien à faire sur le disque : au prochain
	# lancement, « Reprendre » rouvrirait une bataille déjà jouée.
	if combat != null and not combat.is_finished():
		data["combat"] = combat.to_dictionary()
		data["combat_map"] = String(combat_map_id)
		data["combat_moment"] = String(combat_moment)
	return data


## Restaure une partie sauvegardée. Une sauvegarde vide laisse l'état tel
## quel : mieux vaut une partie neuve qu'une partie à moitié effacée.
func from_save(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	campaign_seed = int(data.get("seed", campaign_seed))
	rng.seed = campaign_seed
	company = Company.from_dictionary(data.get("company", {}))
	kingdom = Kingdom.from_dictionary(data.get("kingdom", {}))
	expedition = null
	if data.has("expedition"):
		expedition = Expedition.from_dictionary(data["expedition"])
	combat = null
	combat_map_id = &""
	combat_moment = DayNight.DEFAULT_MOMENT
	if data.has("combat"):
		combat = CombatEngine.from_dictionary(data["combat"])
		combat_map_id = StringName(data.get("combat_map", ""))
		# Une sauvegarde d'avant le cycle n'a pas d'heure : plein jour,
		# qui ne change rien à rien.
		combat_moment = StringName(
			data.get("combat_moment", String(DayNight.DEFAULT_MOMENT))
		)
	return true


## Oublie le combat en cours. À appeler dès qu'il est fini ou abandonné :
## un combat qui traîne dans la sauvegarde se rouvrirait au lancement
## suivant.
func clear_combat() -> void:
	combat = null
	combat_map_id = &""
	combat_moment = DayNight.DEFAULT_MOMENT


## Sauvegarde la partie. À appeler après chaque action significative :
## sur mobile, l'application peut être tuée à tout moment sans prévenir.
func save() -> bool:
	return SaveManager.save_now(to_save())


## Recharge la partie depuis le disque. Renvoie false s'il n'y a rien.
func load_saved() -> bool:
	return from_save(SaveManager.load_game())


## Générateur d'un combat : journalisé, rejouable, indépendant du reste.
## `salt` identifie le combat (index de saison, de nœud…) pour que rejouer
## ce combat-là ne dépende pas de l'ordre des tirages qui l'ont précédé.
func combat_rng(salt: int) -> CombatRng:
	return CombatRng.new(hash([campaign_seed, salt]))


## Une graine neuve, pour une partie neuve. Publique parce que l'écran
## d'options en a besoin : lui faire tirer un nombre au hasard le
## brancherait sur un générateur qui n'est pas celui de la partie, et la
## règle 4 tomberait sur l'action même qui la fonde.
func new_seed() -> int:
	return _generate_seed()


func _generate_seed() -> int:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator.seed
