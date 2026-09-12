# ⚔️ Tiny Kingdoms — Vision fondatrice

> Document de référence du projet, version 1.0.
> **Il prime sur tout le reste.** `docs/conception.md` décrit la conception
> précédente (« Reconquête ») ; ce qui y survit est listé dans
> `docs/etat-des-lieux.md`, le reste est caduc.

---

## 1. Mission

Jeu vidéo indépendant en pixel art médiéval-fantasy, bâti sur le pack
**Tiny Swords** de Pixel Frog. Quatre piliers :

- 🏰 **Gestion** et développement d'un royaume
- ⚔️ **RPG tactique** au tour par tour
- 🗺️ **Exploration** et aventure
- 🌙 **Roguelite** — des expéditions à risque

L'inspiration vient de la profondeur tactique d'un Dofus, de la progression
RPG, d'une gestion légère de royaume et de la rejouabilité d'un roguelite.
**Ce n'est une copie ni de Dofus, ni de Fire Emblem, ni de Civilization.**
Le jeu doit avoir sa propre identité.

## 2. Le concept en une phrase

> Construis ton royaume, développe ton armée, pars explorer un monde
> dangereux et mène toi-même tes héros au combat au tour par tour pour
> devenir le plus grand seigneur du continent.

Le joueur est à la fois souverain, héros principal, commandant et
explorateur. Toutes ces dimensions sont interconnectées.

## 3. La boucle de gameplay

```
🏰 ROYAUME → construire / produire / recruter
     ↓
🗺️ EXPLORER → 🎲 événements et rencontres
     ↓
⚔️ COMBAT TACTIQUE
     ↓
💎 LOOT / XP / RESSOURCES
     ↓
👤 améliorer les héros → 🏰 améliorer le royaume
     ↓
🔓 nouvelles zones → 👑 boss → 🌙 invasions
     ↓
🔄 recommencer avec davantage de possibilités
```

**Chaque système doit renforcer les autres.**

## 4. Ton et identité

Accessible, coloré, lisible, fun, légèrement épique — avec assez de
profondeur pour satisfaire un joueur tactique. L'esthétique exploite le
charme de Tiny Swords : personnages miniatures, bâtiments médiévaux,
environnement naturel, couleurs chaleureuses, ennemis immédiatement
reconnaissables. **Un petit monde vivant dans lequel le joueur construit
sa propre légende.**

## 5. Le joueur commence petit

Au départ : un personnage niveau 1, un petit territoire, quelques
habitants, quelques ressources, un bâtiment principal rudimentaire, aucune
armée. À la fin : un véritable royaume fortifié.
**Cette évolution visuelle est extrêmement importante.**

---

## 6. Le royaume

Hub principal du joueur, développé progressivement.

Ressources de départ : 🪵 **bois**, 🪨 **pierre**, 🪙 **or**, 🌾 **nourriture**.
Plus tard, éventuellement : cristaux, ressources rares, métaux, magie.
**Ne pas multiplier les ressources dans le MVP.**

## 7. Construction

| Catégorie | Bâtiments |
|---|---|
| Production | 🌾 Ferme · 🪵 Scierie · ⛏️ Mine |
| Militaire | ⚔️ Caserne · 🏹 Camp d'archers · 🐎 Écurie · ⚒️ Forge |
| Civil | 🏠 Maisons · 🍺 Taverne · 🛒 Marché · 🏥 Infirmerie |
| Défense | 🗼 Tour · 🧱 Mur · 🚪 Porte · 🏰 Château |

## 8. Évolution des bâtiments

Plusieurs niveaux par bâtiment (jusqu'à 5). Chaque niveau apporte de
nouvelles unités, une meilleure production, de nouveaux équipements, de
nouvelles mécaniques. **Les améliorations doivent être visibles dans le
royaume quand c'est possible.**

## 9. Population

Le royaume a une population : agriculteurs, bûcherons, mineurs, forgerons,
soldats, archers, marchands, personnages spéciaux. À terme certains
habitants auront nom, niveau, métier, statistiques, traits.
**Introduire progressivement. Ne pas surcomplexifier le MVP.**

---

## 10. Le héros principal

Le joueur contrôle un héros principal, **permanent**, qui ne perd jamais
définitivement sa progression. Il possède niveau, XP, statistiques,
équipement, compétences, passifs et classe.

## 11. Classes

Trois classes dans le MVP.

| Classe | Rôle | Points forts | Faiblesses |
|---|---|---|---|
| ⚔️ **Guerrier** | tank, mêlée, contrôle | PV, défense, dégâts au contact | mobilité moyenne, portée faible |
| 🏹 **Archer** | DPS distance, mobilité | portée, dégâts à distance | fragile au corps-à-corps |
| 🔮 **Mage** | dégâts de zone, contrôle | AoE, effets élémentaires | fragile, dépend du positionnement |

Plus tard : Assassin, Paladin, Lancier, Druide, Berserker…

## 12. Caractéristiques

Simple mais profond : ❤️ Vitalité · ⚔️ Force · 🏹 Agilité · 🔮 Intelligence ·
🛡️ Défense · 🎯 Critique · 💨 Initiative.
Plus tard : maîtrise élémentaire, esquive, résistance, pénétration d'armure.

---

## 13. Combat tactique au tour par tour

**Élément FONDAMENTAL du projet.** Combat sur grille, le joueur contrôle
ses personnages pendant son tour.

### PA — Points d'Action

| Action | Coût |
|---|---|
| Attaque de base | 3 PA |
| Compétence légère | 2 PA |
| Compétence moyenne | 4 PA |
| Compétence puissante | 5–7 PA |
| Potion | 2 PA |

### PM — Points de Mouvement

1 case = 1 PM. Certaines compétences peuvent aussi consommer des PM.

## 14. Exemple de tour

Un personnage avec **8 PA / 5 PM** peut faire :

```
Déplacement 2 PM + Attaque 3 PA + Attaque 3 PA + Déplacement 3 PM
```

ou :

```
Déplacement 3 PM + Compétence puissante 5 PA + Déplacement 2 PM
```

**Le joueur doit choisir comment optimiser son tour.**

## 15. Fin de tour

Les PA restants peuvent éventuellement être convertis en défense
temporaire ; les effets de statut sont calculés ; les cooldowns
progressent ; les effets de terrain s'appliquent.
*La conversion PA → défense peut être testée, elle n'est pas obligatoire
dans le MVP.*

## 16. Ordre des tours

**Timeline d'initiative.** Chaque combattant possède une initiative, et la
timeline entremêle alliés et ennemis :

```
1. Assassin   2. Archer ennemi   3. Héros
4. Gobelin    5. Guerrier        6. Mage ennemi
```

Le joueur doit voir clairement **qui joue maintenant** et **qui joue
ensuite**.

## 17. Portée

Chaque attaque a une portée : épée 1, lance 2, arc 4–7, magie variable.
**La portée doit être affichée dès qu'une compétence est sélectionnée.**

## 18. Zones d'effet

Une case, une ligne, un cône, une zone circulaire, plusieurs cases.
**Les zones doivent être très lisibles.**

## 19. Terrain tactique

Le terrain doit avoir un véritable impact : 🌲 forêt (camouflage, bonus
défensif) · 🪨 rocher · 🌊 eau (ralentissement) · 🔥 feu (dégâts par tour) ·
🟫 boue · 🏔️ hauteur (avantage à distance) · 🏰 mur.
**Commencer avec quelques types seulement.**

## 20. Positionnement

Attaque de dos, attaque de flanc, protection derrière un obstacle,
avantage de hauteur, blocage de passage, contrôle de zone.
**Récompenser la stratégie plutôt que les statistiques.**

## 21. Compétences

Chaque classe possède une attaque de base, des compétences actives, des
passifs et un ultime. Exemple Guerrier : Frappe (3 PA), Coup puissant
(5 PA), Provocation (2 PA), Charge (4 PA + PM).

## 22. Combos entre personnages

Le système doit encourager les synergies :
Provocation → Tir puissant → Gel/ralentissement → Charge.

## 23. Équipe

**MVP : 4 personnages maximum.** Plus tard 5–6. Chacun avec ses propres
PA, PM, compétences, équipement, rôle.

## 24. Personnages recrutables

Aldric le chevalier (tank), Lyra l'archère (DPS distance), Brom le nain
forgeron (bonus de production)… Les personnages importants ont nom,
apparence, histoire, traits, spécialisation.

## 25. Mort des personnages

**Le héros principal ne meurt pas définitivement.** Une mort définitive
pour les personnages secondaires pourra être ajoutée plus tard.
**IMPORTANT : ne pas implémenter cette mécanique dans le MVP.**
D'abord construire un système amusant.

---

## 26. Monde

Le royaume est situé sur une carte du monde, découpée en régions :
Les Terres Vertes (gobelins, loups, bandits), Les Dunes Ardentes, Les
Montagnes Gelées, Les Terres Brisées, Les Terres Maudites, L'Empire Noir.
Chaque région a son environnement, ses ennemis, ses ressources, ses
événements, son mini-boss et son boss.

## 27. Exploration

Légère et agréable. Le joueur découvre ressources, ennemis, coffres,
villages, marchands, ruines, donjons, événements, boss.

## 28. Expéditions

Le cœur roguelite. Avant de partir : destination, équipe, équipement,
objectif. Une expédition enchaîne plusieurs rencontres :

```
Départ → Combat → Événement → Combat → Marchand
       → Combat → Mini-boss → Récompense → Boss
```

## 29. Risque / récompense

Plus le joueur reste longtemps : meilleures récompenses, ennemis plus
dangereux, événements plus risqués. **Rentrer maintenant, ou continuer ?**
C'est une mécanique fondamentale du roguelite.

## 30. Butin

Or, ressources, équipements, matériaux, potions, objets rares.
Équipement : ⚔️ armes · 🛡️ boucliers · 🪖 casques · 🛡️ armures · 💍 accessoires.
Chacun avec statistiques, rareté, bonus.

## 31. Raretés

⚪ Commun · 🟢 Peu commun · 🔵 Rare · 🟣 Épique · 🟠 Légendaire.
**Ne pas ajouter de système excessivement complexe au départ.**

## 32. Loot et royaume

Un même objet peut être vendu, améliorer une arme, améliorer un bâtiment
ou débloquer une technologie. **Cela crée des choix stratégiques.**

## 33. Trois progressions

👤 **Héros** — niveau, statistiques, compétences, équipement.
🏰 **Royaume** — bâtiments, population, armée, technologies.
🌎 **Monde** — régions, boss, factions, réputation.

## 34. Arbre de compétences

Chaque classe a un arbre de progression :
`Frappe → Frappe lourde → Tourbillon → Charge → Maître d'armes`.

## 35. Builds

Guerrier Tank / Guerrier Berserker, Archer Critique / Archer Mobilité…
*Cette profondeur viendra après le MVP.*

## 36. Jour / nuit

Le jour : exploration plus sûre. La nuit : ennemis plus nombreux et
spéciaux, meilleures récompenses, plus de risques.
**Le cycle doit avoir un véritable intérêt gameplay.**

## 37. Invasions du royaume

Pendant que le joueur explore, son royaume peut être attaqué.
🚨 *Votre royaume est attaqué !* — rentrer défendre ou continuer.
L'armée peut défendre seule, mais les résultats sont meilleurs si le
joueur revient.

## 38. Batailles de défense

Une invasion transforme le royaume en carte tactique. Le joueur positionne
les défenseurs, utilise murs et tours, contrôle son héros, donne des ordres.
**Le terrain du royaume devient une carte de combat.**

## 39. Boss

Chaque région a au moins un boss, avec plusieurs phases, attaques
spéciales, comportements uniques, **télégraphes visuels** et récompenses
importantes. Exemple : GRAKK, Seigneur Gobelin — phase 1 hache, phase 2
rage, phase 3 invocations.
**Conçus autour de mécaniques tactiques, pas de gros PV.**

## 40. Événements aléatoires

Marchand, autel (sacrifier des PV contre un bonus), village, embuscade,
ruines. **Les événements doivent créer des décisions.**

## 41. Méta-progression

Une défaite ne remet pas tout à zéro. Le joueur conserve royaume,
bâtiments, niveau permanent, équipements stockés, technologies, déblocages.
Une partie de l'expédition en cours peut être perdue.
**Mourir est une conséquence, pas une punition absolue.**

## 42. Objectif final

Chef de colonie → 👑 **Seigneur du royaume** → 👑 **Roi du continent**.
La campagne révèle progressivement une menace majeure : une puissance
ennemie cherche à conquérir le continent, jusqu'à l'Empire Noir et son
boss final.

## 43. Ce qui rend le jeu unique

Le joueur n'est jamais *uniquement* un gestionnaire, *uniquement* un héros
RPG, *uniquement* un commandant. **Il est les trois**, et chaque activité
influence les autres.

```
ROYAUME → ressources → héros → combats gagnés
        → exploration plus loin → nouvelles ressources → ROYAUME
```

---

## 44. MVP — priorité absolue

**Ne pas développer tout le jeu d'un coup. Un vertical slice jouable.**

- **Royaume** — 1 petite carte, château, maison, ferme, scierie, caserne,
  forge, ressources simples, construction/amélioration
- **Héros** — 1 héros, 3 classes, XP, niveaux, statistiques simples,
  équipement basique
- **Combat** — grille, tour par tour, PA, PM, attaque de base, 2–3
  compétences par classe, portée, obstacles, dégâts, PV, initiative,
  victoire/défaite
- **Exploration** — 1 petite zone, quelques ennemis, coffres, ressources,
  1 mini-boss, 1 boss
- **Loot** — or, quelques armes, armures, potions
- **Roguelite** — expédition, choix continuer/rentrer, récompenses, perte
  partielle à la mort
- **Défense** — 1 invasion simple, combat tactique dans le royaume

## 45. Ordre de développement

| Phase | Contenu | Objectif |
|---|---|---|
| **1 — Core** | déplacement, carte, grille, sélection, PA/PM, tour joueur, tour ennemi, attaque, PV/dégâts, victoire/défaite | un combat tactique amusant |
| **2 — RPG** | XP, niveau, statistiques, classes, compétences, équipement, loot | une progression satisfaisante |
| **3 — Monde** | carte du monde, exploration, rencontres, coffres, expéditions, boss | une vraie boucle aventure |
| **4 — Royaume** | ressources, construction, amélioration, population, recrutement, armée, forge | connecter le royaume au RPG |
| **5 — Interconnexion** | loot → royaume, royaume → héros et armée, exploration → ressources, invasions, défense tactique | faire fonctionner la boucle complète |

## 46. Principes de développement

**Ne pas créer une énorme architecture inutilisable immédiatement.**
Construire de manière modulaire ; chaque système doit pouvoir évoluer
indépendamment. Préférer composants réutilisables, données séparées de la
logique, systèmes configurables, classes simples, événements.

Dégâts, PA, PM, portée, PV, coûts, XP : **modifiables sans réécrire la
logique.**

## 47. Data-driven design

Personnages, ennemis, objets, bâtiments et compétences définis par des
données :

```
Warrior:
  HP: 120
  AP: 8
  MP: 4
  Skills:
    BasicAttack:  { AP: 3, Range: 1, Damage: 20 }
    HeavyStrike:  { AP: 5, Range: 1, Damage: 45 }
```

Créer un nouvel ennemi ou une nouvelle compétence **sans modifier
plusieurs systèmes.**

## 48. UI

Extrêmement lisible. Pendant le combat :

```
┌─────────────────────────────┐
│ Héros       ❤️ 100/120      │
│ PA 8/8       PM 5/5         │
├─────────────────────────────┤
│           GRILLE            │
├─────────────────────────────┤
│ ⚔️ Attaque  🔥 Sort  🧪 Item │
│         FIN DU TOUR         │
└─────────────────────────────┘
```

Le joueur doit toujours savoir combien de PA et de PM il possède, quelles
actions sont possibles, leur portée et leur coût.

## 49. Feedback visuel

Chaque action a un retour clair : animation, effet, nombre de dégâts,
réaction de l'ennemi, zone colorée, son. Déplacement : cases accessibles
mises en évidence. Cible : portée affichée.
**Le jeu doit être très satisfaisant à jouer.**

## 50. Philosophie de game design

1. **Chaque tour doit présenter un choix.** Éviter « je fais toujours
   l'attaque la plus forte ». Le positionnement et la gestion des PA/PM
   doivent compter.
2. **Chaque récompense doit donner envie.** « J'améliore mon héros, ou je
   garde cette ressource pour mon royaume ? »
3. **Le joueur doit sentir sa progression.** Petit village et épée
   rouillée au début ; château fortifié, armée et héros légendaire à la
   fin.

## 51. Ce qu'il ne faut pas faire

Ne pas commencer avec 20 classes, 100 ennemis, 500 objets, 10 régions, une
diplomatie complexe, du multijoueur, un crafting très complexe ou un arbre
technologique gigantesque. **Premier objectif : est-ce que la boucle est
fun ?**

## 52. Première expérience du joueur

Le joueur découvre son petit royaume. Un tutoriel très léger : « Votre
royaume a besoin de ressources. » Il construit une ferme, puis une
caserne. « Des gobelins ont été aperçus dans la forêt. » Il part explorer,
rencontre 3 gobelins, apprend déplacement, PA, PM, attaque, fin de tour.
Il gagne, récupère une épée rouillée et 25 pièces, rentre, améliore sa
caserne — puis 🚨 une invasion gobeline approche.

Il comprend alors : **tout ce que je fais dans le monde a un impact sur
mon royaume.**

## 53. Vision à long terme

Davantage de classes, héros recrutables, personnalités, relations,
factions, diplomatie, commerce, arbre technologique, plusieurs royaumes,
conquête territoriale, donjons, événements narratifs, boss complexes,
objets légendaires, builds poussés, spécialisations, météo, saisons, cycle
jour/nuit approfondi, événements mondiaux.
**Tout cela est secondaire par rapport au cœur du jeu.**

## 54. Priorité absolue du projet

1. ⚔️ Combat tactique amusant
2. 👤 Progression RPG satisfaisante
3. 🗺️ Exploration intéressante
4. 🏰 Royaume gratifiant à développer
5. 🔄 Interconnexion des systèmes
6. 🌎 Contenu supplémentaire

## 55. Règle finale

> À chaque nouvelle feature : **est-ce que ça améliore la boucle
> Royaume → Exploration → Combat → Récompense → Progression ?**
> Si oui, l'étudier. Si non, la repousser.

---

## 🎯 Phrase directrice

> **Tiny Kingdoms** est un Tactical RPG de gestion et d'exploration dans
> lequel le joueur construit son royaume, développe ses héros et son
> armée, explore un monde dangereux et mène lui-même ses compagnons dans
> des combats au tour par tour basés sur les **PA**, les **PM**, le
> positionnement et la stratégie.

Simple à comprendre, difficile à maîtriser. Le joueur doit constamment
avoir envie de se dire : « Encore une expédition. » Puis « Encore une
amélioration. » Puis « Encore un combat. » Puis « Encore un niveau. »
Et finalement : **« Je vais rendre mon royaume invincible. »**
