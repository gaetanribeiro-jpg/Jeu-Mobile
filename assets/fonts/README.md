# Polices

Déposer ici le ou les fichiers `.ttf` / `.otf` / `.woff2` de la police du jeu.
Le dossier est versionné, les polices elles-mêmes ne le sont pas tant que le
choix n'est pas arrêté — une fois choisie, la police est committée avec sa
licence et son entrée dans `CREDITS.md`.

## Vérifier une police

```bash
# toutes les polices présentes dans ce dossier
godot --headless --path . -s tools/verify_font.gd
# une police précise
godot --headless --path . -s tools/verify_font.gd -- assets/fonts/MaPolice.ttf
```

L'outil confronte la police à `data/i18n/required_glyphs.txt` et nomme les
glyphes absents. Un glyphe absent s'affiche en carré vide dans le jeu, et
on ne s'en aperçoit qu'après avoir écrit quatre-vingt-dix cartes d'événement.

Puis, pour le rendu réel — l'outil dit si le glyphe existe, pas s'il est
beau — ouvrir `scenes/ui/font_test.tscn` et toucher l'écran pour passer
d'une police à l'autre.

## Ce qui a déjà été mesuré (2026-08-28)

Six polices pixel testées sur les 136 glyphes indispensables. **Toutes les
six les couvrent** — accents, ligatures Æ/Œ, guillemets français, points de
suspension, apostrophe courbe.

| Police | Licence | Verdict de lisibilité |
|---|---|---|
| **Pixelify Sans** | OFL | La plus lisible en corps de texte. Large, propre, accents nets. |
| **VT323** | OFL | Très lisible, condensée, allure terminal. Beaucoup de texte au mètre carré. |
| **Jersey 10** | OFL | Condensée et anguleuse, la plus « médiévale » des six. Le `†` lui manque. |
| **Silkscreen** | OFL | Les minuscules sont des petites capitales : bonne pour un HUD, illisible sur trois phrases. |
| **Press Start 2P** | OFL | Trop large pour du corps de texte : une carte d'événement déborde. Titres seulement. |
| **Micro 5** | OFL | Trop petite pour être lue sur un téléphone. Écartée. |

**Silver (Poppy Works) est installée et vérifiée** (2026-08-29). Elle couvre
les 136 glyphes indispensables **et** les 4 glyphes de confort : la
recommandation du § 13.4 tient. C'est la police par défaut du projet.

Reste le contrôle que l'outil ne peut pas faire — un glyphe peut exister et
rester illisible à la taille réelle. Ouvrir `scenes/ui/font_test.tscn` **sur
le téléphone**, pas sur l'écran du PC.

Sa licence exacte reste à noter dans `CREDITS.md` : elle accompagne le
téléchargement itch.io.

Rien n'oblige à n'en avoir qu'une : une police large pour les titres et une
police lisible pour le corps est un choix courant et bon marché.
