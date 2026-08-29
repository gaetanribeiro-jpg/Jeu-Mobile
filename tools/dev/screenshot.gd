extends SceneTree

## Capture une scène en image, pour pouvoir REGARDER le rendu.
##
##     xvfb-run -a godot --path . -s tools/dev/screenshot.gd -- <scene.tscn> <sortie.png> [frames]
##
## Sert au développement seul : je ne peux pas jouer au jeu, mais je peux
## au moins vérifier qu'une scène s'affiche comme prévu avant de la livrer.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: screenshot.gd -- <scene> <sortie.png> [frames]")
		quit(1)
		return
	var scene_path: String = args[0]
	var out_path: String = args[1]
	var frames := int(args[2]) if args.size() > 2 else 12

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("scène introuvable : %s" % scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())

	await process_frame
	for i in frames:
		await process_frame
	await create_timer(0.4).timeout
	for i in 3:
		await process_frame

	var image := root.get_texture().get_image()
	image.save_png(out_path)
	print("capture : %s (%dx%d)" % [out_path, image.get_width(), image.get_height()])
	quit(0)
