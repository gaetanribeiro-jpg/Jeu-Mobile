# Plus tard

Toute idée qui n'est pas dans le périmètre en cours atterrit ici, et n'en
sort que par une décision explicite. C'est la parade au risque n° 2 du
§ 51 de `docs/vision.md` : « ne pas commencer avec 20 classes, 100
ennemis, 500 objets, 10 régions… ». Le premier objectif est *est-ce que la
boucle est fun ?*

Format : une ligne, une idée, la date, et pourquoi on ne la fait pas maintenant.

---

## Reporté par la conception elle-même

- **Le Marché** — coupé au § 5.4, aucun sprite dans le pack. (2026-08-28)
- **Le mode « Fer »** — tâche A9.8, après le reste. (2026-08-28)
- **iOS** — dernier de la liste des sacrifices § 15. (2026-08-28)
- **Couleurs de faction au-delà des 5 fournies** — demande Aseprite et du
  temps de sprite ; les 5 suffisent largement. (2026-08-28)

## Rangé par le pivot vers Tiny Kingdoms (2026-08-31)

Systèmes construits ou conçus pour « Reconquête », hors périmètre de la
vision actuelle. **Les fichiers de données restent dans le dépôt** : rien
n'est à réécrire le jour où on les ressort.

- **L'Ordre** — les quatre pistes de maîtrise de classe, les secondes
  capacités au rang 3, l'Élévation au rang 5, la Convocation, le Renom, la
  Retraite. La vision confie la méta-progression au royaume (§ 41) ; deux
  systèmes de méta se marcheraient dessus. C'était la meilleure idée de
  l'ancienne conception, elle mérite mieux qu'une greffe. (2026-08-31)
- **Les blessures et la mort définitive** — 3 blessures = mort, le
  Mémorial, le Monastère qui soigne. Le § 25 l'interdit explicitement dans
  le MVP : « d'abord construire un système amusant ». Données conservées
  dans `data/heroes/wounds.json`. (2026-08-31)
- **Les saisons et la gestion de comté** — remplacées par le royaume et le
  cycle jour/nuit (§ 36). (2026-08-31)
- **Le Lancier** — classe entièrement construite, sprites 5 directions
  compris, la seule unité directionnelle du pack. Premier candidat au
  premier ajout de classe post-MVP (§ 11). (2026-08-31)
- **Le Moine comme classe distincte** — son sprite sert au Mage. Le jour où
  un vrai sprite de mage existe, le Moine redevient disponible. (2026-08-31)
- ~~**L'Écurie et la cavalerie** — aucun sprite monté dans le pack~~ —
  **FAUX, corrigé le 2026-09-05.** Le pack dessine un gobelin lancier
  MONTÉ SUR UN SANGLIER (attente, course, attaque) et un sanglier seul,
  dans la catégorie `extra` que l'inventaire des bêtes ne comptait pas.
  La cavalerie ENNEMIE existe depuis le 2026-09-05 (acte 4). Reste
  l'Écurie côté royaume, et une monture pour un héros : aucun sprite de
  héros monté, seul le gobelin l'est. (2026-08-31, corrigé 2026-09-05)
- **Les murs et les portes du royaume** — aucune tuile. La défense
  s'appuie sur les tours et le relief. (2026-08-31)

## Perdu dans la refonte du combat, à récupérer

- **La Bénédiction du Moine** — annulait une attaque télégraphiée sur une
  case. C'était la troisième réponse au télégraphe (sortir de la case,
  abattre l'ennemi, ou annuler le coup), et elle disparaît avec le Moine.
  Le Mage pourrait la reprendre sous un autre nom. (2026-08-31)
- **La Repousse du Lancier** — la deuxième réponse au télégraphe :
  déplacer l'attaquant pour dévier sa menace. Le moteur sait toujours
  pousser (`CombatBoard.push`), plus personne ne sait le déclencher.
  À rendre à une classe dès qu'on en ajoute une. (2026-08-31)

## Idées en attente

### Demandé par Gaetan, pas encore fait (2026-09-05)

- ~~**L'ascension des héros par la couleur**~~ — **FAIT le 2026-09-10.**
  Bleu → Violet → Or, trois rangs, ouverts par la Tour.
- **La refonte de la ville** — **entamée le 2026-09-10.** Le royaume
  existe (6 bâtiments × 5 niveaux, 4 chantiers, invasions, défense) et
  deux reproches sur quatre sont levés : la Tour OUVRE l'ascension au lieu
  de monter un chiffre, et le recrutement propose trois candidats aux
  caractères échangés au lieu d'un héros générique. **Restent :** les
  quatre autres bâtiments ne font toujours que monter des chiffres, et 30
  objets pour 25 cases de tableau.
  **« 2 des 8 bâtiments du pack dorment » était FAUX** (vérifié le
  2026-09-10) : les trois maisons servent DÉJÀ, une par palier de niveau
  du bâtiment `houses` — c'est le seul dont le pack sait montrer
  l'évolution, et le § 8 était honoré depuis la Phase 4. Avec la Tour, les
  huit bâtiments du pack sont maintenant employés, aucun ne dort.
- ~~**Les actes 5 et 6**~~ — **FAITS le 2026-09-10.** Terres Maudites (le
  vampire y entre enfin, avec le `drain` qui était sa question non écrite)
  et Empire Noir (faction humaine Noire, la seconde des deux couleurs
  réservées aux ennemis). La campagne se joue de bout en bout.
- **ACHETER DES CRÉDITS PIXELLAB, ou un futur pack Pixel Frog** — c'est le
  constat que les actes 4, 5 et 6 avaient pour but d'établir, et il est
  maintenant chiffré. **Le pack est ENTIÈREMENT consommé** : les 21 visages
  de bêtes (actes 1–3), toute la catégorie `extra` (actes 4 et 5, dont les
  quatre dernières images inemployées), les deux couleurs de faction
  (actes 3 et 6). Il ne reste RIEN pour un acte 7. La balance PixelLab est
  à **0,00 $** : le vampire l'a vidée, et c'est ce qui a empêché de dessiner
  un bestiaire neuf pour l'acte 5 — il a donc été bâti sur les quatre
  dernières images du pack plus le vampire. (2026-09-10)
- **Des objectifs variés dans l'ACTE 3** — 30 cartes sur 36 n'avaient que
  « éliminer », l'acte 4 est corrigé, l'acte 3 ne l'est pas : ses neuf
  cartes sont toutes « éliminer ».
- **Des ennemis PERCHÉS en hauteur** — `hill` donne déjà +1 de portée et
  +1 de dégâts, et aucune bête n'est posée dessus exprès. Idée de Gaetan,
  à moitié faite : l'acte 4 a des collines, personne ne les tient.
- **Changer de composition, avoir d'autres personnages** — suppose plus de
  trois classes, ou un vivier de héros au-delà de l'équipe de quatre.
  Aujourd'hui le roster EST l'équipe.

### Constats ouverts, à trancher à l'œil par Gaetan

- **Le rouge du sol de l'acte 4** est franc — plus saturé que le sable ou
  le gel. Il distingue l'acte d'un coup d'œil ; huit rondes dessus, c'est
  à juger. (2026-09-05)
- **Le télégraphe violet du soin ennemi** — se lit-il comme une
  information distincte du rouge de la menace, ou s'y noie-t-il ? Toute la
  question de l'acte 4 en dépend. (2026-09-05)
- **La palissade se lit mal sur le sol rouille** — le pack ne dessine
  qu'un piquet de clôture, fin et pâle. (2026-09-05)
- **Le sol violet des Terres Maudites** est franc, plus encore que le rouge
  de l'acte 4. Il distingue l'acte d'un coup d'œil ; huit rondes dessus,
  c'est à juger. (2026-09-10)
- **Le troll relevé est une animation de MORT jouée en boucle** — un corps
  qui n'arrive pas à tomber. C'est exactement ce que l'acte raconte, et
  c'est la seule fois du projet où une animation change de SENS sans
  changer d'image. Si elle se lit comme un bug plutôt que comme un râle,
  il faut la ralentir ou n'en garder que les dernières images. (2026-09-10)
- **L'acte 5 est mesuré par un pilote qui joue le CONTRAIRE de ce qu'il
  demande** — `simulate_combats` ne concentre jamais ses coups, et
  concentrer est toute la réponse à l'acte. Ses 34 % sont donc un plancher
  plus bas qu'ailleurs : un joueur qui a compris le trouvera plus facile.
  À rejuger à l'œil. (2026-09-10)
