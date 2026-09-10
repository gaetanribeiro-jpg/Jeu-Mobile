class_name Ascension
extends RefCounted

## L'ascension des héros, lue dans `data/heroes/ascension.json`.
##
## TROIS RANGS, ET C'EST LA COULEUR QUI LES DIT : Bleu, Violet, Or. Le pack
## dessine cinq classes en cinq couleurs et le jeu n'employait que le Bleu ;
## `Hero.color` existait depuis la Phase 2, avec sa valeur par défaut, et
## n'était câblé nulle part.
##
## UNE COULEUR NE PEUT PAS ÊTRE À LA FOIS UN RANG ET UNE FACTION. Les cinq
## couleurs sont un budget : trois aux héros, deux aux ennemis — le Rouge
## des Rougefer et le Noir de l'Empire. C'est cette arithmétique qui a
## obligé l'acte 4 à se passer d'humains.
##
## DEUX CONDITIONS, ET ELLES NE SONT PAS DE MÊME NATURE. Le NIVEAU est
## acquis par le héros ; la TOUR est bâtie par le royaume. C'est ce qui
## fait de l'ascension le premier point où le § 45 — « connecter le royaume
## au RPG » — se joue vraiment : monter un héros ne suffit pas, il faut
## avoir bâti pour lui.

const PATH := "res://data/heroes/ascension.json"

## Le bâtiment qui autorise l'ascension. Nommé ici plutôt que dans le
## code appelant : le jour où c'est un autre bâtiment, une seule ligne.
const BUILDING := &"tower"

## Pourquoi une ascension est refusée. Chaîne vide = elle est possible.
const BLOCKED_MAXED := &"ascension.maxed"
const BLOCKED_LEVEL := &"ascension.level"
const BLOCKED_TOWER := &"ascension.tower"
const BLOCKED_COST := &"ascension.cost"

static var _data: Dictionary = {}


## Vide le cache de données, pour les tests et le rechargement à chaud.
## PAS `reload()` : ce nom entre en collision avec `Script.reload()`.
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Ascension : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Ascension : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ascension : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func ranks() -> Array:
	return data().get("ranks", [])


static func rank_count() -> int:
	return ranks().size()


## Le rang le plus élevé qui existe. Un héros neuf est au rang 0.
static func top_rank() -> int:
	return maxi(rank_count() - 1, 0)


## Un rang, borné à ce qui existe. Un rang hors table rend le dernier
## plutôt qu'un dictionnaire vide : une sauvegarde d'une version qui en
## déclarait davantage ne doit pas rendre un héros incolore.
static func rank(index: int) -> Dictionary:
	var list := ranks()
	if list.is_empty():
		return {}
	return list[clampi(index, 0, list.size() - 1)]


static func color_of(index: int) -> String:
	return String(rank(index).get("color", "Blue"))


static func name_key_of(index: int) -> String:
	return String(rank(index).get("name_key", ""))


static func requires_level(index: int) -> int:
	return int(rank(index).get("requires_level", 1))


static func requires_tower(index: int) -> int:
	return int(rank(index).get("requires_tower", 0))


static func cost_of(index: int) -> Dictionary:
	return (rank(index).get("cost", {}) as Dictionary).duplicate()


## Les gains d'un seul rang.
static func grants_of(index: int) -> Dictionary:
	return (rank(index).get("grants", {}) as Dictionary).duplicate()


## Les gains CUMULÉS jusqu'à ce rang inclus.
##
## Un héros au rang 2 garde ce que le rang 1 lui a donné : on monte, on ne
## remplace pas. Même forme que `Buildings.grants_up_to`.
static func grants_up_to(index: int) -> Dictionary:
	var out := {}
	for step in range(0, mini(index, top_rank()) + 1):
		for key: Variant in grants_of(step).keys():
			out[key] = int(out.get(key, 0)) + int(grants_of(step)[key])
	return out


## Le rang qui porte cette couleur, ou 0. Sert à relire une sauvegarde
## d'AVANT l'ascension, qui n'a qu'une couleur enregistrée.
static func rank_of_color(color: String) -> int:
	for index in rank_count():
		if color_of(index) == color:
			return index
	return 0


## Le rang qu'un héros atteindrait s'il s'élevait maintenant.
static func next_rank(current: int) -> int:
	return mini(current + 1, top_rank())


## Pourquoi ce héros ne peut pas s'élever, ou chaîne vide s'il le peut.
##
## L'ORDRE DES REFUS EST CELUI DE CE QU'ON PEUT Y FAIRE. « Déjà au sommet »
## d'abord, parce que rien n'y changera ; le niveau ensuite, qui se gagne
## en jouant ; la tour, qui se bâtit ; le coût en dernier, qui est le plus
## facile à réunir. Un écran qui affiche la première raison affiche donc la
## plus structurante.
static func blocked_because(
	hero: Hero, tower_level: int, kingdom: Kingdom = null, company: Company = null
) -> StringName:
	if hero == null:
		return BLOCKED_MAXED
	if hero.rank >= top_rank():
		return BLOCKED_MAXED
	var target := next_rank(hero.rank)
	if hero.level < requires_level(target):
		return BLOCKED_LEVEL
	if tower_level < requires_tower(target):
		return BLOCKED_TOWER
	if kingdom != null and not kingdom.can_afford(cost_of(target), company):
		return BLOCKED_COST
	return &""


static func can_ascend(
	hero: Hero, tower_level: int, kingdom: Kingdom = null, company: Company = null
) -> bool:
	return blocked_because(hero, tower_level, kingdom, company).is_empty()
