extends GutTest

## T11.4 — l'écran qui annonce ce qu'une région conclue vient de changer.
##
## Battre le boss rendait exactement la même main que rentrer en chemin :
## le joueur retombait sur le menu et rien ne lui disait qu'il venait de
## finir quelque chose. Un jeu qui ne marque pas ses paliers n'en a pas.


var _screen: Control


func should_skip_script():
	var entry := AssetTable.sprite(&"ui", &"banner")
	if entry.is_empty() or not FileAccess.file_exists(entry["path"]):
		return "Pack Tiny Swords absent — voir docs/installation.md"
	return false


func before_each() -> void:
	UiTheme.clear_cache()
	var packed: PackedScene = load("res://scenes/ui/ending_screen.tscn")
	_screen = packed.instantiate()
	_screen.configure("Une terre s'ouvre", "Du sable à perte de vue.")
	add_child_autofree(_screen)
	await wait_process_frames(2)


func _texts_of(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child: Node in node.get_children():
		out.append_array(_texts_of(child))
	return out


func test_l_ecran_dit_ce_qui_vient_de_changer() -> void:
	var texts := _texts_of(_screen)
	assert_true(texts.has("Une terre s'ouvre"), "l'annonce doit être là")
	assert_true(texts.has("Du sable à perte de vue."), "et ce qui l'accompagne")


func test_il_offre_une_seule_sortie() -> void:
	# Un écran d'annonce n'est pas un menu : une porte, et elle rend la
	# main. Deux boutons obligeraient à choisir sans rien à choisir.
	var buttons: Array[Button] = []
	var stack: Array[Node] = [_screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			buttons.append(node as Button)
		stack.append_array(node.get_children())
	assert_eq(buttons.size(), 1, "une seule porte")

	var closed := [false]
	_screen.closed.connect(func() -> void: closed[0] = true)
	buttons[0].pressed.emit()
	assert_true(closed[0], "elle doit rendre la main")
