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


func _ready() -> void:
	if campaign_seed == 0:
		start_new_campaign(_generate_seed())


## Démarre une campagne avec une graine donnée.
func start_new_campaign(seed_value: int) -> void:
	campaign_seed = seed_value
	rng.seed = seed_value


## Dérive un générateur indépendant pour un sous-système (un combat,
## une Convocation), afin qu'il soit rejouable seul sans dépendre de
## l'ordre exact des tirages précédents.
func derive_rng(salt: int) -> RandomNumberGenerator:
	var derived := RandomNumberGenerator.new()
	derived.seed = hash([campaign_seed, salt])
	return derived


func _generate_seed() -> int:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator.seed
