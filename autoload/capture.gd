extends Node

## Capture d'écran du JEU RÉEL, pilotée par la ligne de commande.
##
##     xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png
##     xvfb-run -a godot --path . -- --capture /tmp/x.png --frames 90
##     xvfb-run -a godot --path . -- --capture /tmp/x.png --press "Partir|Partir pour"
##
## `--press` presse des boutons par leur TEXTE, dans l'ordre, en laissant
## respirer entre chacun. C'est ce qui permet de photographier un écran
## qu'on n'atteint qu'en naviguant — et de le photographier tel que le
## joueur l'atteint, pas monté à la main dans un banc d'essai. Un préfixe
## suffit ; un bouton désactivé ou absent arrête la séquence et le dit,
## plutôt que de capturer un écran qu'on croira être le bon.
##
## POURQUOI CET AUTOLOAD EXISTE. `tools/dev/screenshot.gd` monte une scène
## dans un script lancé par `-s`, et un tel script ne reçoit AUCUN
## autoload. Pire : l'identifiant `GameState` est résolu à la COMPILATION,
## donc tout écran qui lit la partie sauvegardée ne compile même pas — il
## reste sur son texte de secours, et la capture ne montre rien.
##
## Installer les singletons à la main ne répare rien, puisque l'échec est
## antérieur. La seule façon de photographier un écran qui touche à la
## campagne est donc de lancer le JEU, pas une simulation de jeu. C'est ce
## que fait cette classe.
##
## Elle est INERTE sans son argument : aucun coût pour une version livrée,
## et `--capture` n'existe sur aucun téléphone.

const ARG_PATH := "--capture"
const ARG_FRAMES := "--frames"
const ARG_PRESS := "--press"
const DEFAULT_FRAMES := 45

## Images laissées passer après chaque pression : un écran qui se construit
## en `_ready` n'est pas encore mis en page à l'image suivante.
const SETTLE_FRAMES := 12

var _path := ""
var _frames := DEFAULT_FRAMES
var _press: PackedStringArray = []


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var at := arguments.find(ARG_PATH)
	if at < 0 or at + 1 >= arguments.size():
		return
	_path = arguments[at + 1]

	var frames_at := arguments.find(ARG_FRAMES)
	if frames_at >= 0 and frames_at + 1 < arguments.size():
		_frames = maxi(arguments[frames_at + 1].to_int(), 1)

	var press_at := arguments.find(ARG_PRESS)
	if press_at >= 0 and press_at + 1 < arguments.size():
		_press = arguments[press_at + 1].split("|", false)
	set_process(true)


func _process(_delta: float) -> void:
	if _path.is_empty():
		set_process(false)
		return
	# On laisse passer quelques images : une scène construite en `_ready`
	# n'a pas encore été mise en page à la première, et la capture montrerait
	# un écran vide dont on conclurait à tort qu'il est cassé.
	_frames -= 1
	if _frames > 0:
		return
	set_process(false)
	if not _press.is_empty() and not await _walk():
		# On ne photographie PAS un écran qu'on n'a pas atteint : l'image
		# montrerait l'écran précédent, et on en conclurait que la
		# navigation marche.
		get_tree().quit(1)
		return
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_path)
	if error != OK:
		push_error("Capture : écriture impossible dans %s" % _path)
	else:
		print("capture : %s (%dx%d)" % [_path, image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)


## Presse la suite de boutons demandée, en laissant l'écran se construire
## entre chacun.
func _walk() -> bool:
	for label: String in _press:
		var button := _find_button(get_tree().root, label)
		if button == null:
			push_error("Capture : aucun bouton actif « %s »" % label)
			return false
		button.pressed.emit()
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
	return true


## Le premier bouton visible, actif et cliquable dont le texte commence par
## `label`. Un bouton désactivé ne compte pas : le presser ne ferait rien,
## et la capture montrerait l'écran précédent sans qu'on le sache.
func _find_button(node: Node, label: String) -> Button:
	if node is Button:
		var button := node as Button
		if not button.disabled and button.is_visible_in_tree() and button.text.begins_with(label):
			return button
	for child: Node in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null
