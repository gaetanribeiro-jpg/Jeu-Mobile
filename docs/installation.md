# Installer et faire tourner Reconquête

Tout ce qu'il faut faire sur un poste de travail, dans l'ordre. Les tâches
**F0.1** et **F0.9** de la conception, plus la remise en route d'un poste
déjà configuré.

À la fin : le jeu tourne sur le téléphone, et les deux jalons sont
constatés — **Jalon 0** (l'application s'installe et affiche le titre) et
**Jalon 1** (un combat complet, jouable au doigt).

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

Cinq commandes. Elles doivent toutes finir au vert.

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit    # 262 tests
godot --headless --path . -s tools/verify_assets.gd  # 535 entrées, 0 écart
godot --headless --path . -s tools/verify_audio.gd   # 30 sons
godot --headless --path . -s tools/verify_font.gd    # 140 glyphes
godot --headless --path . -s tools/verify_maps.gd    # 8 cartes
```

**Si les tests annoncent 239 au lieu de 262**, avec deux scripts marqués
« ignorés : Pack Tiny Swords absent », c'est que le pack n'est pas au bon
endroit. Ce n'est pas une panne, c'est l'étape 2 qui reste à finir.

> **Des lignes rouges défilent pendant les tests, et c'est voulu.** Une
> vingtaine, du genre `ERROR: Unit : classe de héros inconnue « paladin »`
> ou `ERROR: CombatRules : terrain inconnu « lave »`. Ce sont des tests qui
> vérifient qu'une mauvaise entrée produit une erreur NOMMÉE au lieu d'un
> plantage : le message affiché EST ce qu'ils vérifient. Ce qui compte est
> le résumé final :
>
> ```
> Scripts              20
> Tests               262
> Passing Tests       262
> Asserts            4717
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
godot --headless --path . --export-debug "Android" build/reconquete.apk
adb install -r build/reconquete.apk
```

---

## 7. Ce qu'il faut regarder en jouant

Les deux jalons sont atteints dès que l'application se lance : l'écran de
titre (**Jalon 0**) donne accès aux huit cartes de l'Acte I (**Jalon 1**).

Le § « Méthode de travail » de `CLAUDE.md` demande de jouer le combat
**vingt fois avant de continuer**. Voici ce que je ne peux pas voir, et
qui décide de la suite :

1. **Les cibles tactiles.** Une case fait-elle vraiment 48 dp sous le
   doigt ? Le § 11.3 vise une case de 64 px à l'échelle 2, mais le
   cadrage automatique peut la rendre plus petite sur un écran étroit.
2. **Les boutons du bas recouvrent le plateau.** Gênant, ou acceptable ?
3. **Les durées d'animation.** Trop lentes, trop rapides ? Tout est dans
   `data/combat/view.json`, section `durations` — un nombre à changer, pas
   une ligne de code.
4. **Le tour ennemi** est rejoué un évènement à la fois. Comprend-on ce
   qui s'est passé, ou est-ce trop long ?
5. **La fluidité.** Cible : 60 images par seconde. Je rends en logiciel
   dans mon conteneur, je ne peux pas la mesurer.
6. **La composition de l'escouade.** Trois emplacements, quatre classes,
   doublons permis : les boutons de l'écran de titre les font défiler.
   Le renoncement se sent-il ?

Pour décrire un problème de ressenti, le § « Règles de travail avec Claude
Code » demande du concret : pas « c'est mou » mais « il y a 400 ms entre
le tap et le début de l'animation, et l'unité glisse au lieu de marcher ».

---

## Remettre en route un poste déjà configuré

```bash
git pull
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit
godot --path .
```
