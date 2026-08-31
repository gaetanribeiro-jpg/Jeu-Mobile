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
- **L'Écurie et la cavalerie** — aucun sprite monté dans le pack, ni
  bâtiment ni unité. (2026-08-31)
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

*(vide — à remplir au fil des sessions)*
