class_name Campaign
extends RefCounted

## L'avancement du joueur dans le monde : quelles régions il a menées à
## leur terme, et donc lesquelles se sont ouvertes (T11.4).
##
## CE MAILLON MANQUAIT DEPUIS TOUJOURS, et son absence ne cassait rien :
## `regions.json` déclarait six régions dont cinq `"unlocked": false`, et
## **aucune ligne du jeu n'écrivait jamais `unlocked`**. Battre le boss de
## l'acte 1 changeait une ligne de texte et renvoyait le joueur sur la
## même carte. Une boucle sans terme n'est pas une campagne.
##
## L'AVANCEMENT VIT DANS LA SAUVEGARDE, PAS DANS LES DONNÉES. Le fichier
## de régions dit ce qui est ouvert AU DÉPART d'une partie neuve ; ce qui
## s'est ouvert DEPUIS appartient à la partie. Les confondre rendrait
## l'avancement commun à toutes les parties — et impossible à effacer par
## « nouvelle partie ».
##
## L'ORDRE VIENT DES ACTES, PAS D'UNE LISTE ÉCRITE À LA MAIN. Chaque
## région déclare son acte ; celle de l'acte n + 1 s'ouvre quand une
## région de l'acte n est menée à son terme. Ajouter une région ne demande
## donc rien d'autre que de lui donner un numéro d'acte.

## Régions menées à leur terme, identifiant → vrai.
var cleared: Dictionary = {}


## La région est-elle jouable ?
##
## Vrai si elle est ouverte d'origine, ou si un acte précédent est conclu.
func is_open(region_id: StringName) -> bool:
	if Region.is_unlocked(region_id):
		return true
	var act := Region.act_of(region_id)
	for other: StringName in Region.ids():
		if Region.act_of(other) == act - 1 and is_cleared(other):
			return true
	return false


func is_cleared(region_id: StringName) -> bool:
	return bool(cleared.get(String(region_id), false))


## Enregistre qu'une région a été menée à son terme. Renvoie la région que
## ça vient d'ouvrir, ou rien.
##
## ON NE DÉCLARE PAS DEUX FOIS. Refaire l'acte 1 après l'avoir fini est
## permis — le joueur peut vouloir du butin — mais ça ne doit pas
## réannoncer une ouverture qu'il connaît déjà.
func clear_region(region_id: StringName) -> StringName:
	if not Region.exists(region_id) or is_cleared(region_id):
		return &""
	cleared[String(region_id)] = true
	var act := Region.act_of(region_id)
	for other: StringName in Region.ids():
		if Region.act_of(other) == act + 1:
			return other
	return &""


## Toutes les régions jouables aujourd'hui, dans l'ordre des actes.
func open_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for region_id: StringName in Region.ids():
		if is_open(region_id):
			out.append(region_id)
	return out


## La campagne est finie quand toute région JOUABLE est conclue.
##
## « Jouable », pas « déclarée » : une région d'acte 7 écrite mais dont
## l'acte 6 n'existe pas encore ne doit pas empêcher la fin. C'est ce qui
## permet d'ajouter un acte sans repousser l'écran de fin dans le vide.
func is_complete() -> bool:
	var open := open_ids()
	if open.is_empty():
		return false
	for region_id: StringName in open:
		if not is_cleared(region_id):
			return false
	return true


func to_dictionary() -> Dictionary:
	return {"cleared": cleared.duplicate()}


static func from_dictionary(data: Dictionary) -> Campaign:
	var run := Campaign.new()
	var raw: Variant = data.get("cleared", {})
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary).keys():
			# Une région retirée des données depuis la sauvegarde disparaît
			# de l'avancement, sans emporter la partie avec elle.
			if Region.exists(StringName(key)):
				run.cleared[String(key)] = bool((raw as Dictionary)[key])
	return run
