# Installer et faire tourner Tiny Kingdoms

Tout ce qu'il faut faire sur un poste de travail, dans l'ordre, plus la
remise en route d'un poste déjà configuré.

À la fin : le jeu tourne — sur PC en quelques minutes, sur le téléphone
après le § 4, qui est long et ne se fait qu'une fois.

> **Ce fichier a porté le nom « Reconquête » et des chiffres d'une autre
> époque** — 262 tests, huit cartes, trois emplacements d'escouade —
> jusqu'à ce que quelqu'un le rouvre pour s'en servir. Les chiffres
> ci-dessous sont ceux d'aujourd'hui : ils vieillissent, et c'est normal ;
> ce qui compte est que la commande affiche « All tests passed! » et que
> les dix vérificateurs finissent au vert.

---

## 1. Godot 4.6

Godot est un exécutable unique, sans installation.

- Télécharger **Godot 4.6-stable, version standard** (pas .NET/Mono : le
  projet est en GDScript pur) sur <https://godotengine.org/download>.
- Le décompresser où l'on veut. Sur Windows, éviter un dossier dont le
  chemin contient des accents.

> **La version compte.** `project.godot` déclare
> `config/features=("4.6", "GL Compatibility")`. Une version plus ancienne
> refusera d'ouvrir le projet ; une plus récente proposera de le convertir,
> ce qu'il ne faut accepter qu'en connaissance de cause.

**Pour taper `godot` en ligne de commande** — pratique, car toutes les
commandes de ce dépôt en dépendent :
- **Windows** : ajouter le dossier de l'exécutable au `Path`, ou le
  renommer `godot.exe`.
- **macOS** :
  `ln -s /Applications/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot`
- **Linux** : `sudo ln -s /chemin/vers/Godot_v4.6-stable_linux.x86_64 /usr/local/bin/godot`

---

## 2. Le dépôt et le pack d'assets

```bash
git clone <le dépôt> Jeu-Mobile
cd Jeu-Mobile
git checkout claude/mobile-game-project-yko58t
```

Puis copier le pack Tiny Swords — **il n'est pas dans le dépôt**, sa
licence interdit la redistribution. Les instructions détaillées, avec le
piège du sous-dossier de l'Enemy Pack, sont dans
[`assets/tiny_swords/README.md`](../assets/tiny_swords/README.md).

Enfin, importer :

```bash
godot --headless --path . --import
```

> **Le premier import affiche des erreurs de police, c'est normal.**
> Une demi-douzaine de lignes rouges sur `Silver.ttf` et `pixel_theme.tres`.
> Le projet déclare une police en thème, et au tout premier passage cette
> police n'est pas encore importée quand le thème se charge. **Relancer la
> même commande une seconde fois** : elles disparaissent et ne reviennent
> plus. Toute autre erreur, en revanche, mérite attention.

Un import réussi se termine ainsi — une progression, puis une seule ligne
jaune :

```
[ DONE ] first_scan_filesystem
[ DONE ] loading_editor_layout

WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
     at: cleanup (core/object/object.cpp:2641)
```

> **Cet avertissement est sans conséquence.** Godot le produit à chaque
> sortie de l'éditeur en mode `--headless` : il signale que l'éditeur n'a
> pas libéré tous ses propres objets avant de quitter. Il ne dit rien du
> projet, il apparaît sur toutes les machines, et il n'y a rien à corriger.
> Ce qui compte est ce qui n'est PAS là : aucune ligne commençant par
> `ERROR` ou `SCRIPT ERROR`.

---

## 3. Vérifier que tout est en place

Onze commandes. Elles doivent toutes finir au vert. Si l'une échoue, ne
joue pas : tu chercherais un défaut de jeu là où il y a un défaut
d'installation.

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit     # 1016 tests
godot --headless --path . -s tools/verify_scripts.gd  # engine, scenes, tools, tests
godot --headless --path . -s tools/verify_assets.gd   # 592 entrées, 0 écart
godot --headless --path . -s tools/verify_audio.gd    # 30 sons
godot --headless --path . -s tools/verify_font.gd     # 136 glyphes
godot --headless --path . -s tools/verify_maps.gd     # 54 cartes
godot --headless --path . -s tools/verify_items.gd    # 34 objets
godot --headless --path . -s tools/verify_skills.gd   # 4 arbres, 11 nœuds chacun
godot --headless --path . -s tools/verify_world.gd    # régions, évènements, carte
godot --headless --path . -s tools/verify_kingdom.gd  # ressources, chantiers, voisines
godot --headless --path . -s tools/verify_ui.gd       # thème, teintes, tranches
```

**Si le compte de tests est nettement plus bas**, avec des scripts marqués
« ignorés : Pack Tiny Swords absent », c'est que le pack n'est pas au bon
endroit. Ce n'est pas une panne, c'est l'étape 2 qui reste à finir — et
presque toujours le sous-dossier `Enemy Pack/` de la seconde archive.

> **Des lignes rouges défilent pendant les tests, et c'est voulu.** Une
> vingtaine, du genre `ERROR: Unit : classe de héros inconnue « paladin »`
> ou `ERROR: CombatRules : terrain inconnu « lave »`. Ce sont des tests qui
> vérifient qu'une mauvaise entrée produit une erreur NOMMÉE au lieu d'un
> plantage : le message affiché EST ce qu'ils vérifient. Ce qui compte est
> le résumé final :
>
> ```
> Scripts              65
> Tests              1016
> Passing Tests      1016
>
> ---- All tests passed! ----
> ```
>
> Rien ne doit suivre cette ligne. Si `Failing Tests` apparaît, ou si le
> résumé est suivi d'un `WARNING` ou d'un `ERROR`, c'est autre chose.

Et pour jouer sur le PC, avant même de penser au téléphone :

```bash
godot --path .
```

---

## 4. Le SDK Android

C'est la partie la plus longue, et elle ne se fait qu'une fois.

### 4.1 Un JDK 17

Godot 4 construit l'APK avec Gradle, qui réclame un **JDK 17**. Un JDK
plus récent échoue avec un message peu clair.

- **Temurin 17** : <https://adoptium.net> — c'est le plus simple.
- Vérifier : `java -version` doit afficher `17.x`.

### 4.2 Le SDK

Deux chemins, au choix :

- **Android Studio** (le plus simple) : l'installer, le lancer une fois,
  et laisser l'assistant télécharger le SDK. Noter le chemin qu'il
  indique dans *Settings ▸ Languages & Frameworks ▸ Android SDK*.
- **Les outils en ligne de commande seuls**, si l'on ne veut pas de l'IDE :
  télécharger les *Command line tools* sur
  <https://developer.android.com/studio#command-line-tools-only>, puis
  installer les composants avec `sdkmanager`.

Les composants nécessaires : **platform-tools**, **build-tools**, et une
**platform** récente.

### 4.3 Le brancher dans Godot

Ouvrir le projet dans l'éditeur, puis
**Éditeur ▸ Paramètres de l'éditeur ▸ Export ▸ Android** :

- **Android SDK Path** : le chemin noté plus haut.
- **Debug Keystore** : une clé de signature de debug. Godot sait la créer
  depuis cet écran. Sinon, à la main :

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
  -keypass android -keystore debug.keystore -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 \
  -deststoretype pkcs12
```

### 4.4 Les modèles d'export

**Éditeur ▸ Gérer les modèles d'export ▸ Télécharger et installer.**
Environ 600 Mo, une fois par version de Godot. Sans eux, l'export échoue
en disant qu'il manque les modèles.

> **Le meilleur guide, c'est Godot lui-même.** *Projet ▸ Exporter* affiche
> en rouge, en bas de la fenêtre, exactement ce qui manque et pourquoi.
> Tant qu'il reste du rouge, l'export ne partira pas ; quand tout est
> vert, il partira.

---

## 5. Créer le préréglage d'export

**Projet ▸ Exporter ▸ Ajouter ▸ Android.**

- **Nommer le préréglage exactement `Android`** — la ligne de commande de
  `CLAUDE.md` le désigne par ce nom.
- Vérifier que **arm64-v8a** est coché dans les architectures : c'est ce
  que demandent tous les téléphones modernes.
- Ne rien changer d'autre pour l'instant. Aucune permission n'est
  nécessaire : le jeu est hors ligne et n'utilise ni réseau, ni caméra,
  ni position.

`export_presets.cfg` n'est pas versionné (il contient des chemins propres
à la machine). Il est donc à recréer sur chaque poste, ou à sortir du
`.gitignore` si l'on n'en a qu'un.

---

## 6. Sur le téléphone

### Préparer le téléphone

1. **Paramètres ▸ À propos du téléphone** : toucher **sept fois** le
   *Numéro de build*. Les options de développement apparaissent.
2. **Paramètres ▸ Options pour les développeurs** : activer le **débogage
   USB**.
3. Brancher le téléphone en USB et accepter l'autorisation qui s'affiche
   dessus.
4. Vérifier : `adb devices` doit lister l'appareil (`adb` est dans
   `platform-tools`).

### Déployer

Le plus rapide, **le déploiement en un clic** : une fois le téléphone
détecté, une petite icône Android apparaît en haut à droite de l'éditeur.
Un clic construit, installe et lance. C'est ce qu'il faut utiliser pour
itérer.

Sinon, en ligne de commande :

```bash
mkdir -p build
godot --headless --path . --export-debug "Android" build/tiny_kingdoms.apk
adb install -r build/tiny_kingdoms.apk
```

---

## 7. Ce qu'il faut regarder en jouant

Le jeu se joue en entier sur PC : écran de titre → carte du monde →
composition de l'équipe → route du § 28 → rentrer ou continuer → royaume.
`pointing/emulate_touch_from_mouse` est actif, donc la souris se comporte
comme un doigt et le ressenti est proche de celui qu'on aura sur
l'appareil.

**Le banc d'essai, en bas à droite de l'écran de titre**, ouvre n'importe
laquelle des 54 cartes en deux clics, sans traverser une expédition
entière. C'est par lui que seize défauts ont été trouvés.

Voici ce que je ne peux pas voir, et qui attend des yeux :

1. **Le mouvement de l'interface** (T12.13). Les boutons réagissent au
   survol et à l'appui, les écrans entrent en fondu. Mou, nerveux, ou
   juste ? Tout est dans `data/ui/theme.json`, section `motion` — un
   nombre à changer, pas une ligne de code.
2. **La cadence du conseil du royaume** (T12.10). Un conseil à chaque
   retour : trop, pas assez ? Et ses chiffres pèsent-ils quelque chose au
   regard de ce que la ville produit ? Aucun instrument ne le mesure.
3. **Le renfort d'un combat** (T12.12), de bout en bout : l'acheter au
   départ, traverser deux ou trois rencontres sans l'employer, puis
   l'appeler. La question qui compte : a-t-on HÉSITÉ à le dépenser ?
4. **Le prêt d'un héros** (T12.12). Partir à trois pendant trois cycles :
   décision douloureuse, ou simple bouton ?
5. **La difficulté.** La courbe mesurée monte de 15 % à 36 % des points de
   vie par combat, de l'acte 1 à l'acte 6 — mais `simulate_combats` ne boit
   pas de potion et ne concentre jamais ses coups. Ses chiffres sont un
   PLANCHER : le vrai jeu devrait être plus facile. De combien ?
6. **Les trente repères sonores** (T11.2). Le câblage est fait ; les
   affectations ont été faites au NOM DES FICHIERS et jamais écoutées. Il
   y en a sûrement des ridicules. Tout est dans `data/audio.json`, bloc
   `cues`.
7. **Le Mage dessiné en Moine.** Décision prise par défaut pour ne pas
   bloquer — le pack n'a pas de mage. À confirmer ou à rejeter maintenant
   que le combat tourne.

Deux points restent invérifiables tant qu'il n'y a pas de téléphone : la
taille réelle des cibles tactiles, et les 60 images par seconde sur
l'appareil. Tout le reste se juge à la souris.

**Pour décrire un problème de ressenti, du concret.** Pas « c'est mou »
mais « il y a un demi-temps entre le clic et le début du mouvement, et
l'unité glisse au lieu de marcher ». Un nom d'écran, un geste, et ce qu'on
attendait à la place : avec ça on trouve la ligne à changer.

---

## Remettre en route un poste déjà configuré

```bash
git pull
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit
godot --path .
```
