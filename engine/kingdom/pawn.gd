class_name Pawn
extends RefCounted

## Un habitant du royaume (§ 9) : un nom, un poste, et un métier par
## chantier.
##
## LES HABITANTS ÉTAIENT UN COMPTEUR. `population: int` et
## `assignments: { chantier → nombre }` : douze bras interchangeables,
## qu'on répartissait une fois et qu'on ne regardait plus. C'est un
## NOMBRE, pas une décision — et c'est ce qui rendait la ville expédiable
## en trente secondes entre deux sorties.
##
## UN MÉTIER S'APPREND OÙ L'ON TRAVAILLE, et séparément par chantier : un
## bûcheron de rang 4 est un carrier de rang 0. Déplacer quelqu'un coûte
## donc quelque chose de PRÉCIS, et ce coût est la décision. Garder son
## meilleur bûcheron sur le bois, ou le poster à la garde parce que
## l'assaut arrive : les deux moitiés de la ville se disputent enfin les
## mêmes personnes, et pas seulement les mêmes bras.
##
## SON NOM EST UNE FONCTION DE SON IDENTIFIANT, jamais un tirage. Le décor
## n'a pas à consommer la graine de la partie — même règle que les rochers
## du rivage (T9.10) et que le renfort de nuit. La contrepartie est
## qu'une sauvegarde rendra toujours les mêmes noms, ce qui est exactement
## ce qu'on veut d'un village.
##
## CLASSE PURE : aucun nœud, aucune sauvegarde, aucun signal.

## Identifiant unique et stable. Il ne redescend jamais : deux habitants
## ne doivent pas le partager, sinon une sauvegarde en écrase un.
var id: int = 0

## Le chantier où il passe le cycle, ou vide s'il monte la garde.
var posting: StringName = &""

## Expérience accumulée, PAR MÉTIER : { chantier → points }.
var experience: Dictionary = {}


static func create(pawn_id: int) -> Pawn:
	var pawn := Pawn.new()
	pawn.id = maxi(pawn_id, 0)
	return pawn


## Son prénom, pris dans la liste par son identifiant. Pas de tirage :
## voir l'en-tête.
##
## LE PAS EST PREMIER AVEC LA TAILLE DE LA LISTE, et ce n'est pas de la
## coquetterie. `pool[id]` donnait Aldric, Anselme, Arnaud, Aubry… : le
## village sortait dans l'ORDRE ALPHABÉTIQUE, ce qui se lit comme une
## liste et pas comme des gens. Un pas premier parcourt toute la liste
## sans jamais répéter un nom avant de l'avoir épuisée — on garde donc
## l'unicité ET la fonction pure, on perd seulement l'alphabet.
const NAME_STRIDE := 37

func given_name() -> String:
	var pool := HeroNames.all_given()
	if pool.is_empty():
		return "?"
	return pool[(id * NAME_STRIDE) % pool.size()]


# --- Le métier -------------------------------------------------------------

func experience_at(worksite_id: StringName) -> int:
	return int(experience.get(worksite_id, 0))


## Son rang à ce métier, plafonné par les données.
func level_at(worksite_id: StringName) -> int:
	var per_level := maxi(Worksite.xp_per_level(), 1)
	return mini(experience_at(worksite_id) / per_level, Worksite.max_trade_level())


## Ce qu'il rapporte en un cycle à ce chantier. La base du chantier, plus
## une FRACTION de cette base par rang — un seul réglage vaut donc pour
## les quatre, et une scierie comme une mine doublent au même rang.
func yield_at(worksite_id: StringName) -> int:
	var base := Worksite.per_cycle(worksite_id)
	var bonus := float(base) * Worksite.yield_per_level() * float(level_at(worksite_id))
	return base + int(floor(bonus))


## Est-il au sommet de ce métier ? L'écran le dit : sans ça, le joueur
## continue d'y laisser quelqu'un qui n'apprend plus.
func is_master_at(worksite_id: StringName) -> bool:
	return level_at(worksite_id) >= Worksite.max_trade_level()


## Un cycle passé au travail. Rien ne s'apprend à la garde : monter la
## garde est un service rendu, pas un métier — et c'est ce qui rend le
## choix coûteux des deux côtés.
func work_a_cycle() -> void:
	if posting.is_empty():
		return
	experience[posting] = experience_at(posting) + Worksite.xp_per_cycle()


# --- Sérialisation ---------------------------------------------------------

func to_dictionary() -> Dictionary:
	var learned := {}
	for worksite_id: Variant in experience.keys():
		learned[String(worksite_id)] = int(experience[worksite_id])
	return {"id": id, "posting": String(posting), "experience": learned}


static func from_dictionary(data: Dictionary) -> Pawn:
	var pawn := Pawn.create(int(data.get("id", 0)))
	var posted := StringName(data.get("posting", ""))
	# Un chantier retiré des données depuis la sauvegarde renvoie son monde
	# à la garde, sans emporter la partie avec lui — même règle que la
	# réserve et le sac.
	if Worksite.exists(posted):
		pawn.posting = posted
	for key: Variant in (data.get("experience", {}) as Dictionary).keys():
		if Worksite.exists(StringName(key)):
			pawn.experience[StringName(key)] = int((data["experience"] as Dictionary)[key])
	return pawn
