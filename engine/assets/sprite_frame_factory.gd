class_name SpriteFrameFactory
extends RefCounted

## Découpe les feuilles d'animation du pack en `SpriteFrames`.
##
## Les feuilles font de 768 à 5120 px de large et le nombre d'images varie
## d'une animation à l'autre. Les découper à la souris, ce serait 535
## occasions de se tromper d'une image — d'où ce découpage automatique,
## à partir des seules valeurs de `data/assets.json`.
##
## Une feuille est une bande horizontale de `frames` cadres de
## `frame_w` × `frame_h`. Les cadres ne sont PAS tous carrés : la tour
## pirate sur l'eau fait 8 cadres de 128 × 192. On ne relit pas la taille
## réelle du PNG ici : cette classe fait confiance à la table, et c'est
## `tools/verify_assets.gd` qui la met en doute.
##
## Cette classe ne manipule que des ressources, jamais de nœud : elle reste
## donc testable en headless comme le reste d'`engine/`.
##
## Les ressources sont construites à la demande et mises en cache, plutôt
## que pré-générées en centaines de `.tres`. Une seule source de vérité,
## rien à régénérer quand Pixel Frog met le pack à jour.

const ANIMATION_NAME := &"default"

static var _cache: Dictionary = {}


## Vide le cache. Utile aux tests et au rechargement à chaud.
static func clear_cache() -> void:
	_cache.clear()


## Découpe une texture en bande horizontale de cadres.
## C'est le cœur de la classe, et il ne touche à aucun fichier.
static func slice(
	texture: Texture2D, frames: int, frame_width: int, frame_height: int, fps: int
) -> SpriteFrames:
	var resource := SpriteFrames.new()
	if texture == null or frames <= 0 or frame_width <= 0 or frame_height <= 0:
		push_error("SpriteFrameFactory : découpage impossible (%d cadres de %dx%d)"
			% [frames, frame_width, frame_height])
		return resource

	# SpriteFrames naît avec une animation "default" ; on la reconfigure
	# plutôt que d'en ajouter une seconde.
	resource.set_animation_speed(ANIMATION_NAME, fps)
	resource.set_animation_loop(ANIMATION_NAME, true)
	for i in frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		# Sans filter_clip, les cadres voisins bavent d'un pixel sur les
		# bords à l'échelle 2 — le défaut le plus visible en pixel art.
		atlas.filter_clip = true
		resource.add_frame(ANIMATION_NAME, atlas)
	return resource


## SpriteFrames d'une animation d'unité humaine, dans une couleur de faction.
## Renvoie null si l'entrée ou le fichier manque.
static func for_unit(unit_id: StringName, animation: StringName, color: String) -> SpriteFrames:
	return _from_entry(
		"unit:%s:%s:%s" % [unit_id, animation, color],
		AssetTable.unit_animation(unit_id, animation, color)
	)


## SpriteFrames d'une animation d'ennemi.
static func for_enemy(enemy_id: StringName, animation: StringName) -> SpriteFrames:
	return _from_entry(
		"enemy:%s:%s" % [enemy_id, animation],
		AssetTable.enemy_animation(enemy_id, animation)
	)


## SpriteFrames d'une entrée de catégorie simple (terrain, fx, ui…).
static func for_sprite(category: StringName, key: StringName) -> SpriteFrames:
	return _from_entry(
		"sprite:%s:%s" % [category, key],
		AssetTable.sprite(category, key)
	)


static func _from_entry(cache_key: String, entry: Dictionary) -> SpriteFrames:
	if _cache.has(cache_key):
		return _cache[cache_key]
	if entry.is_empty():
		return null
	if StringName(entry.get("kind", AssetTable.KIND_IMAGE)) != AssetTable.KIND_STRIP:
		push_error(
			"SpriteFrameFactory : « %s » n'est pas une bande d'animation mais un « %s »"
			% [entry["path"], entry.get("kind", "?")]
		)
		return null
	var texture: Texture2D = load(entry["path"])
	if texture == null:
		push_error("SpriteFrameFactory : texture introuvable — %s" % entry["path"])
		return null
	var resource := slice(
		texture, int(entry["frames"]), int(entry["frame_w"]), int(entry["frame_h"]),
		AssetTable.fps()
	)
	_cache[cache_key] = resource
	return resource
