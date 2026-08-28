extends Control

## Contrôle visuel de la police — tâche F0.10.
##
## `tools/verify_font.gd` dit si un glyphe existe. Cette scène dit s'il est
## lisible : un é peut être présent et pourtant baver sur la ligne du dessus
## à l'échelle du téléphone.
##
## Toucher l'écran fait défiler les polices trouvées dans `assets/fonts/`.
## À regarder sur le téléphone, pas sur l'écran du PC : c'est la taille
## réelle qui tranche.

const FONTS_DIR := "res://assets/fonts/"
const FONT_EXTENSIONS := ["ttf", "otf", "woff", "woff2", "fnt", "font"]

@onready var _labels: Array[Label] = [
	%Title, %Upper, %Lower, %Punct, %Card, %Prompt, %Stats, %Resources
]
@onready var _font_name: Label = %FontName
@onready var _hint: Label = %Hint

var _fonts: Array[String] = []
var _index := 0


func _ready() -> void:
	%Title.text = tr("FONT_TEST_TITLE")
	%Upper.text = tr("ACCENT_TEST_UPPER")
	%Lower.text = tr("ACCENT_TEST_LOWER")
	%Punct.text = tr("ACCENT_TEST_PUNCT")
	%Card.text = tr("FONT_TEST_SAMPLE_CARD")
	%Prompt.text = tr("FONT_TEST_PROMPT")
	%Stats.text = tr("FONT_TEST_STATS")
	%Resources.text = tr("FONT_TEST_RESOURCES")
	_hint.text = tr("FONT_TEST_HINT")

	_fonts = _find_fonts()
	_apply()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventScreenTouch and event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if pressed or clicked:
		if _fonts.is_empty():
			return
		_index = (_index + 1) % _fonts.size()
		_apply()


func _find_fonts() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(FONTS_DIR)
	if dir == null:
		return out
	for name_ in dir.get_files():
		var clean: String = name_.trim_suffix(".import").trim_suffix(".remap")
		if FONT_EXTENSIONS.has(clean.get_extension().to_lower()):
			if not out.has(FONTS_DIR + clean):
				out.append(FONTS_DIR + clean)
	out.sort()
	return out


func _apply() -> void:
	if _fonts.is_empty():
		_font_name.text = tr("FONT_TEST_NO_FONT")
		_hint.visible = false
		return

	var path := _fonts[_index]
	var font: Font = load(path)
	if font == null:
		_font_name.text = "%s — illisible" % path.get_file()
		return

	_font_name.text = "%d/%d — %s" % [_index + 1, _fonts.size(), path.get_file()]
	for label: Label in _labels:
		label.add_theme_font_override("font", font)
