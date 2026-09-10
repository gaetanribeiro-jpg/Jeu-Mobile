# -*- coding: utf-8 -*-
"""Construit le classeur « Simulateur_Patrimonial.xlsx ».

Usage :  python3 build.py [chemin_de_sortie.xlsx]

Les feuilles sont créées dans l'ordre d'affichage souhaité. Les formules se
référencent entre elles par des PLAGES NOMMÉES : l'ordre de construction n'a
donc pas d'importance pour la résolution des noms, qui a lieu à l'ouverture.
"""

import sys
from openpyxl import Workbook

from src import params, client, patrimoine, succession, assurance_vie, retraite, guide

SORTIE = "Simulateur_Patrimonial.xlsx"


def main(chemin=SORTIE):
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

    wb.save(chemin)
    print("Classeur écrit : {}".format(chemin))
    print("Feuilles      : {}".format(", ".join(wb.sheetnames)))
    print("Noms définis  : {}".format(len(wb.defined_names)))
    return chemin


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else SORTIE)
