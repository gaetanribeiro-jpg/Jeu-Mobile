extends Node

## Lecture de la musique et des effets, et les trois volumes du joueur.
##
## POURQUOI CETTE CLASSE EXISTE MAINTENANT. Elle était un squelette vide, et
## un écran d'options avec trois curseurs qui ne commandent rien est
## exactement ce que le projet s'interdit ailleurs — un bâtiment décoratif.
## Les curseurs commandent donc de vrais bus.
##
## CE QUI N'EST TOUJOURS PAS FAIT, et qui demande des oreilles : les
## affectations de `data/audio.json` ont été faites au NOM des fichiers,
## jamais écoutées. Le câblage est prêt ; le choix des sons ne l'est pas.
##
## LES BUS SONT CRÉÉS À L'EXÉCUTION plutôt que dans un `.tres` de
## disposition : trois bus ne valent pas une ressource binaire à maintenir
## hors du dépôt de texte, et les créer ici les rend lisibles.
##
## LES VOLUMES SONT LINÉAIRES CÔTÉ JOUEUR (0 à 1) et en décibels côté
## moteur. La conversion vit ici, une seule fois : un curseur qui parle en
## décibels ne veut rien dire pour personne.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## Volume linéaire en dessous duquel on coupe franchement. `linear_to_db(0)`
## rend -inf, et certains pilotes n'aiment pas ça.
const SILENCE := 0.001

var _music: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _playing: StringName = &""


func _ready() -> void:
	_ensure_buses()
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	add_child(_music)
	# Un petit pool plutôt qu'un lecteur par son : deux coups d'épée
	# simultanés ne doivent pas se couper l'un l'autre, et un lecteur par
	# effet en créerait trente pour rien.
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx.append(player)

	Settings.changed.connect(apply_settings)
	apply_settings()


func _ensure_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)


## Applique les trois volumes du joueur. Appelé au démarrage et à chaque
## mouvement de curseur.
func apply_settings() -> void:
	set_volume(BUS_MASTER, Settings.number(&"audio", &"master_volume", 1.0))
	set_volume(BUS_MUSIC, Settings.number(&"audio", &"music_volume", 1.0))
	set_volume(BUS_SFX, Settings.number(&"audio", &"sfx_volume", 1.0))


func set_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var level := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, level <= SILENCE)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, SILENCE)))


func volume_of(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


# --- Jouer -----------------------------------------------------------------

## Lance une musique. Relancer celle qui tourne déjà ne fait rien : sans ce
## garde, chaque changement d'écran la reprendrait au début.
func play_music(track_id: StringName) -> void:
	if _music == null or _playing == track_id:
		return
	var entry := AudioTable.music(track_id)
	if entry.is_empty():
		return
	var stream := _load(String(entry.get("path", "")))
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = bool(entry.get("loop", true))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = bool(entry.get("loop", true))
	_playing = track_id
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	if _music != null:
		_music.stop()
	_playing = &""


func playing_music() -> StringName:
	return _playing


func play_sfx(sound_id: StringName) -> void:
	if _sfx.is_empty():
		return
	var entry := AudioTable.sfx(sound_id)
	if entry.is_empty():
		return
	var stream := _load(String(entry.get("path", "")))
	if stream == null:
		return
	var player := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	player.stream = stream
	player.play()


## Un son absent ne fait pas tomber le jeu : la règle est la même que pour
## les images du pack, qui ne sont pas dans le dépôt.
func _load(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func set_music_volume(linear: float) -> void:
	Settings.set_value(&"audio", &"music_volume", linear)


func set_sfx_volume(linear: float) -> void:
	Settings.set_value(&"audio", &"sfx_volume", linear)
