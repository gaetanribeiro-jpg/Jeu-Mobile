extends Control

## Écran d'amorçage — Jalon 0.
## Affiche le titre du jeu, rien de plus. Sert de preuve que le projet
## se lance, s'exporte et s'installe sur le téléphone.

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle


func _ready() -> void:
	_title.text = tr("GAME_TITLE")
	_subtitle.text = tr("BOOT_SUBTITLE")
