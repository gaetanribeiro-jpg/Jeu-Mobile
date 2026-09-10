# Simulateur patrimonial — Succession & Retraite

Classeur Excel d'aide à l'entretien patrimonial, conçu comme une alternative
autonome à un logiciel métier de type Big Expert pour les deux usages les plus
courants en agence : **la transmission** et **la retraite**.

Le fichier livré est `Simulateur_Patrimonial.xlsx`. Il est généré par le code de
ce dossier — on ne modifie pas le classeur à la main, on modifie le code et on
le régénère.

---

## Ce que fait le classeur

**Volet transmission**

- Liquidation du régime matrimonial et détermination de l'actif net successoral.
- Dévolution légale complète : descendants, conjoint survivant et ses quatre
  options (1/4 en PP, 100 % en usufruit, DDV 1/4 PP + 3/4 US, DDV quotité
  disponible), ascendants privilégiés, collatéraux privilégiés, ordres
  subséquents et déshérence.
- Réserve héréditaire et quotité disponible, contrôle des legs testamentaires.
- Valorisation de l'usufruit et de la nue-propriété au barème de l'article 669
  du CGI, d'après l'âge du conjoint survivant.
- Droits de succession héritier par héritier : abattements personnels, abattement
  handicap, rappel fiscal des donations de moins de 15 ans, barème progressif de
  l'article 777 du CGI.
- Assurance-vie : prélèvement de l'article 990 I (primes versées avant 70 ans) et
  réintégration à l'assiette des droits de succession au titre de l'article 757 B
  (primes versées après 70 ans).
- **Comparatif automatique des trois options du conjoint** et de leur impact sur
  les droits payés par les enfants — l'argument de conseil le plus opérant.

**Volet retraite**

- Âge légal, durée d'assurance requise et âge du taux plein automatique par
  génération, avec possibilité de forcer chaque valeur.
- Décote, surcote, taux de liquidation, coefficient de proratisation.
- Pension de base (régime général) et pension complémentaire (Agirc-Arrco par
  points), majorations pour trois enfants et plus, prélèvements sociaux.
- **Le même bloc de calcul est appliqué à six âges de départ** (62 à 67 ans)
  **plus l'âge envisagé** : la sensibilité à l'âge de départ est lisible d'un
  seul coup d'œil.
- Objectif de revenu du client, écart à combler, capital nécessaire (consommation
  du capital, rente viagère ou capital préservé), capital déjà projeté, et
  **effort d'épargne mensuel à mettre en place**.
- Comparatif des enveloppes (PER, assurance-vie, PEA, immobilier locatif) avec
  l'économie d'impôt du PER calculée à la TMI réelle du foyer, et double table de
  sensibilité (âge de départ × rendement réel).

Le raisonnement retraite est mené **en euros constants** : les rendements sont
convertis en taux réels (nets d'inflation), et tous les montants s'interprètent
en pouvoir d'achat d'aujourd'hui.

---

## Les onze feuilles

| Feuille | Rôle |
|---|---|
| `Guide` | Mode d'emploi, légende des couleurs, ordre de travail, limites du modèle |
| `Client` | État civil, famille, profession, impôt sur le revenu et TMI |
| `Patrimoine` | Inventaire actif/passif, masse successorale, donations antérieures |
| `Devolution` | Qui hérite et pour quelle quote-part (Code civil) |
| `Droits_Succession` | Liquidation des droits + comparatif des options du conjoint |
| `Assurance_Vie` | Contrats, clauses bénéficiaires, articles 990 I et 757 B |
| `Retraite_Carriere` | Personne étudiée, paramètres légaux, carrière, SAM, points |
| `Retraite_Estimation` | Pension estimée pour 6 âges de départ + l'âge envisagé |
| `Retraite_Objectif` | Écart, capital nécessaire, effort d'épargne, enveloppes |
| `Synthese` | Restitution en une page + pistes de travail conditionnelles |
| `Parametres` | Tous les barèmes, taux et hypothèses |

Le classeur est livré **pré-rempli avec un cas fictif** (famille MARTIN) afin
que chaque cellule montre le format attendu et que les enchaînements de calcul
soient immédiatement lisibles. Toutes les cellules bleues sur fond crème sont à
écraser par les données réelles.

---

## Principes de construction

- **Aucune valeur en dur dans les formules.** Tous les barèmes, taux et
  hypothèses vivent sur la feuille `Parametres` et sont atteints par plages
  nommées (248 noms définis). La mise à jour annuelle se fait en un seul endroit.
- **Code couleur cohérent** : bleu = saisie, noir = calcul interne à la feuille,
  vert = report d'une autre feuille, marine = résultat clé, saumon = alerte.
- **Contrôles de cohérence intégrés** : total des quotités = 100 %, écart entre
  le tableau de dévolution et la masse civile, répartition des clauses
  bénéficiaires à 100 %, cohérence de l'option du conjoint avec la présence
  d'enfants non communs et d'une donation au dernier vivant, legs excédant la
  quotité disponible.
- **Barème progressif générique** : les droits sont calculés par
  `SOMMEPROD((catégorie)×(base>seuil)×(base−seuil)×(taux−taux précédent))`.
  Ajouter une tranche ou une catégorie ne demande aucune modification de formule.
- **Un seul bloc de calcul retraite pour sept scénarios** : pas de duplication
  entre un calcul « principal » et une table de sensibilité qui divergeraient.

---

## Régénérer le classeur

```bash
pip install openpyxl
python3 build.py                      # écrit Simulateur_Patrimonial.xlsx
```

Vérification des formules (nécessite LibreOffice Calc) :

```bash
python3 <chemin>/recalc.py Simulateur_Patrimonial.xlsx 300
```

Organisation du code :

```
build.py            assemble les feuilles dans l'ordre d'affichage
src/styles.py       palette, formats de nombre, helpers d'écriture
src/params.py       feuille Parametres (barèmes) + définition des plages nommées
src/client.py       feuille Client
src/patrimoine.py   feuille Patrimoine
src/succession.py   feuilles Devolution et Droits_Succession
src/assurance_vie.py feuille Assurance_Vie
src/retraite.py     feuilles Retraite_Carriere / _Estimation / _Objectif
src/guide.py        feuilles Guide et Synthese
```

Les feuilles se référencent entre elles **uniquement par plages nommées** :
l'ordre de construction n'a donc pas d'incidence, et déplacer une ligne dans une
feuille ne casse pas les autres.

---

## Vérifications effectuées

Le classeur a été recalculé par LibreOffice Calc : **1 284 formules, 0 erreur**.

Au-delà de l'absence d'erreur, les résultats ont été confrontés à un calcul
manuel sur le cas livré, puis sur neuf configurations de dévolution obtenues en
modifiant les données d'entrée et en recalculant :

| Scénario | Vérification |
|---|---|
| Cas de référence | Masse 954 000 €, assiette 918 200 €, droits 90 313 € |
| Décès du conjoint | Masse 316 000 €, l'enfant d'un premier lit n'hérite plus, donations non rappelées |
| Conjoint 100 % en usufruit | Droits 44 403 € — identiques à l'option B du comparatif |
| DDV 1/4 PP + 3/4 US | Droits 21 506 € — identiques à l'option C du comparatif |
| Sans descendant, conjoint + 1 parent | 3/4 – 1/4 (art. 757-1 C. civ.) |
| Célibataire, 1 parent + 1 frère | 1/4 – 3/4 (art. 738 C. civ.), barème collatéral à 35 % puis 45 % |
| Aucun héritier | Bascule sur les ordres subséquents, taxation à 55 % |
| Partenaire de PACS | Non héritier légal : les enfants recueillent 100 % |
| Conjoint survivant de 40 ans | Usufruit valorisé à 70 % (art. 669 CGI) |
| Primes versées après 70 ans | Ventilation au prorata, abattement global de 30 500 € réparti, base réintégrée aux droits |

Les deux recoupements les plus utiles : le comparatif des options du conjoint
retombe exactement sur le moteur principal lorsqu'on sélectionne l'option
correspondante, et le total réparti du tableau de dévolution est égal au centime
près à la masse civile dans toutes les configurations testées.

---

## Limites assumées

Elles sont rappelées en bas de chaque feuille et récapitulées sur le `Guide`.
Les principales :

- **Succession** : pas de représentation automatique des petits-enfants, pas de
  fente successorale entre branches, pas de rapport civil des donations, pas de
  récompenses entre patrimoines, pas de reconstitution du barème sur les
  donations rappelées (seule la consommation de l'abattement est modélisée), pas
  de droit de retour, pas d'exonération sectorielle (Dutreil, bois et forêts,
  monuments historiques), pas de succession internationale.
- **Assurance-vie** : pas de contrats antérieurs au 20/11/1991, pas de primes
  antérieures au 13/10/1998, pas de clause bénéficiaire démembrée.
- **Retraite** : régime général + Agirc-Arrco uniquement. Pas de carrière longue,
  de retraite progressive, de catégorie active, de régime spécial, de fonction
  publique, d'indépendant ou de profession libérale, de polypensionné, de
  minimum contributif, de réversion ni de rachat de trimestres.
- **Fiscalité** : pas d'IFI, pas de plafonnement du quotient familial, pas de
  décote ni de réductions et crédits d'impôt.

> Les barèmes sont arrêtés à la date de construction du classeur. Ils doivent
> être vérifiés sur la feuille `Parametres` avant tout usage en clientèle —
> notamment le calendrier de l'âge légal de départ à la retraite, qui a fait
> l'objet de mesures de suspension discutées fin 2025.

Ce classeur produit une estimation destinée à préparer un entretien. Il ne se
substitue ni à une consultation notariale, ni au relevé officiel de carrière, ni
à un conseil en investissement. Il contient des données personnelles et
patrimoniales sensibles : son usage doit respecter la politique de
l'établissement en matière de données clients (RGPD).
