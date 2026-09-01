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


## Tout ce qu'il faut écrire pour retrouver la partie où on l'a laissée.
func to_save() -> Dictionary:
	var data := {
		"seed": campaign_seed,
		"company": company.to_dictionary(),
		"kingdom": kingdom.to_dictionary(),
	}
	if expedition != null:
		data["expedition"] = expedition.to_dictionary()
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
	return true


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
