# -*- coding: utf-8 -*-
"""Construit le classeur « Simulateur_Patrimonial.xlsx ».

Usage :  python3 build.py [chemin_de_sortie.xlsx]

Les feuilles sont créées dans l'ordre d'affichage souhaité. Les formules se
référencent entre elles par des PLAGES NOMMÉES : l'ordre de construction n'a
donc pas d'importance pour la résolution des noms, qui a lieu à l'ouverture.
"""

import sys
from openpyxl import Workbook

from src import styles, params, client, patrimoine, succession, assurance_vie, retraite, guide

SORTIE = "Simulateur_Patrimonial.xlsx"
SORTIE_COMPAT = "Simulateur_Patrimonial_compatibilite.xlsx"


def main(chemin=SORTIE, compatibilite=False):
    """compatibilite=True : aucun commentaire de cellule, donc aucune partie VML
    héritée dans le paquet OOXML. Les info-bulles sont alors écrites en clair
    dans la colonne de notes de chaque feuille. À utiliser lorsqu'un poste
    verrouillé, un antivirus de messagerie ou une passerelle DLP refuse
    d'ouvrir le classeur complet."""
    styles.MODE_COMPAT = compatibilite
    wb = Workbook()
    wb.remove(wb.active)

    guide.construire_guide(wb)
    client.construire(wb)
    patrimoine.construire(wb)
    succession.construire_devolution(wb)
    succession.construire_droits(wb)
    assurance_vie.construire(wb)
    retraite.construire_carriere(wb)
    retraite.construire_estimation(wb)
    retraite.construire_objectif(wb)
    guide.construire_synthese(wb)
    params.construire(wb)

    wb.properties.title = "Simulateur patrimonial — Succession & Retraite"
    wb.properties.subject = "Aide à l'entretien patrimonial : dévolution, droits de succession, retraite"
    wb.properties.creator = "Simulateur patrimonial"
    wb.active = 0
    # Excel recalcule l'intégralité du classeur à l'ouverture : les valeurs
    # affichées ne dépendent d'aucun cache écrit par un autre tableur.
    wb.calculation.fullCalcOnLoad = True

    wb.save(chemin)
    print("Classeur écrit : {}{}".format(chemin, "  [mode compatibilité]" if compatibilite else ""))
    print("Feuilles      : {}".format(", ".join(wb.sheetnames)))
    print("Noms définis  : {}".format(len(wb.defined_names)))
    return chemin


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--compatibilite" in args:
        args.remove("--compatibilite")
        main(args[0] if args else SORTIE_COMPAT, compatibilite=True)
    elif "--les-deux" in args:
        main(SORTIE)
        main(SORTIE_COMPAT, compatibilite=True)
    else:
        main(args[0] if args else SORTIE)
