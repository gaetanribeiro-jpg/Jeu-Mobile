extends Node

## Lecture de la musique et des effets.
##
## Squelette F0.7 : les bus, le fondu enchaîné et le pool de lecteurs
## arrivent en P8.15 / P8.17. Les chemins de fichiers passeront par
## `data/assets.json`, jamais en dur ici.

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"


func play_music(_track_id: StringName) -> void:
	pass


func play_sfx(_sound_id: StringName) -> void:
	pass


func set_music_volume(_linear: float) -> void:
	pass


func set_sfx_volume(_linear: float) -> void:
	pass
