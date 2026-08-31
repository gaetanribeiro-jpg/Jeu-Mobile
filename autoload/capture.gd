extends Node

## Capture d'écran du JEU RÉEL, pilotée par la ligne de commande.
##
##     xvfb-run -a godot --path . --resolution 1280x720 -- --capture /tmp/x.png
##     xvfb-run -a godot --path . -- --capture /tmp/x.png --frames 90
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
const DEFAULT_FRAMES := 45

var _path := ""
var _frames := DEFAULT_FRAMES


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var at := arguments.find(ARG_PATH)
	if at < 0 or at + 1 >= arguments.size():
		return
	_path = arguments[at + 1]

	var frames_at := arguments.find(ARG_FRAMES)
	if frames_at >= 0 and frames_at + 1 < arguments.size():
		_frames = maxi(arguments[frames_at + 1].to_int(), 1)
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
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_path)
	if error != OK:
		push_error("Capture : écriture impossible dans %s" % _path)
	else:
		print("capture : %s (%dx%d)" % [_path, image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)
