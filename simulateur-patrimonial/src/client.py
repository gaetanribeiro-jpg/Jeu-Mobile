# -*- coding: utf-8 -*-
"""Feuille « Client » : état civil, famille, profession, fiscalité du foyer.

C'est la seule feuille où l'on saisit la composition de la famille. Toutes les
autres feuilles en déduisent la dévolution successorale et les droits ouverts.
"""

import datetime as dt
from .styles import *

SHEET = "Client"

SIT_MAT = ["Marié(e)", "Pacsé(e)", "Concubin(e)", "Célibataire", "Divorcé(e)", "Veuf(ve)"]
REGIMES = ["Communauté légale (réduite aux acquêts)", "Séparation de biens",
           "Communauté universelle", "Participation aux acquêts", "Sans objet"]
FILIATION = ["Commun au couple", "Du client uniquement", "Du conjoint uniquement"]
STATUTS = ["Salarié du privé", "Fonctionnaire", "Artisan / Commerçant (TNS)",
           "Profession libérale", "Dirigeant assimilé salarié", "Exploitant agricole",
           "Sans activité", "Retraité"]
OUI_NON = ["Oui", "Non"]

NB_ENFANTS = 8


def construire(wb):
    ws = wb.create_sheet("Client")
    largeurs(ws, {"A": 2, "B": 44, "C": 26, "D": 26, "E": 26, "F": 14, "G": 20, "H": 4, "I": 60})
    mise_en_page(ws, zoom=100, freeze="A6", paysage=False, ncols=7)

    titre(ws, 1, "FICHE CLIENT — FOYER, FAMILLE ET REVENUS", ncols=7,
          sous_titre="Renseignez uniquement les cellules bleues sur fond crème. "
                     "Les cellules noires ou vertes sont calculées : ne les écrasez pas.")

    R = {}

    # ------------------------------------------------------------------------
    r = 4
    section(ws, r, "1.  PARAMÈTRES DE L'ÉTUDE", ncols=7)
    r += 1
    lab(ws, "B{}".format(r), "Date de la simulation")
    inp(ws, "C{}".format(r), "=TODAY()", fmt=F_DATE, align="center",
        comment="Laissez =AUJOURDHUI() pour une date glissante, ou saisissez une date fixe "
                "pour figer l'étude (les âges et le rappel fiscal des donations en dépendent).")
    dn(wb, "DateSimu", SHEET, A("C", r))
    note(ws, "E{}".format(r), "Sert de référence pour les âges et pour le rappel fiscal des donations sur 15 ans.")
    r += 1
    lab(ws, "B{}".format(r), "Conseiller / agence")
    inp(ws, "C{}".format(r), "")
    r += 1
    lab(ws, "B{}".format(r), "Référence du dossier")
    inp(ws, "C{}".format(r), "")
    r += 2

    # ------------------------------------------------------------------------
    section(ws, r, "2.  IDENTIFICATION DU FOYER", ncols=7)
    r += 1
    entetes(ws, r, 2, ["", "CLIENT", "CONJOINT / PARTENAIRE", ""])
    r += 1
    r_civ = r
    for libelle, v_cl, v_cj in [("Civilité", "M.", "Mme"),
                                ("Nom", "MARTIN", "MARTIN"),
                                ("Prénom", "Jean", "Sophie")]:
        lab(ws, "B{}".format(r), libelle)
        inp(ws, "C{}".format(r), v_cl, align="center")
        inp(ws, "D{}".format(r), v_cj, align="center")
        r += 1
    r_nais = r
    lab(ws, "B{}".format(r), "Date de naissance")
    inp(ws, "C{}".format(r), dt.date(1968, 3, 12), fmt=F_DATE, align="center")
    inp(ws, "D{}".format(r), dt.date(1971, 7, 25), fmt=F_DATE, align="center")
    dn(wb, "DateNaisClient", SHEET, A("C", r))
    dn(wb, "DateNaisConjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Âge au jour de la simulation", italic=True)
    calc(ws, "C{}".format(r), '=IFERROR(DATEDIF({},DateSimu,"Y"),"")'.format(A("C", r_nais)),
         fmt=F_INT, align="center")
    calc(ws, "D{}".format(r), '=IFERROR(DATEDIF({},DateSimu,"Y"),"")'.format(A("D", r_nais)),
         fmt=F_INT, align="center")
    dn(wb, "AgeClient", SHEET, A("C", r))
    dn(wb, "AgeConjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Identité complète", italic=True)
    calc(ws, "C{}".format(r), '=TRIM({}&" "&{})'.format(A("C", r_civ + 2), A("C", r_civ + 1)), align="center")
    calc(ws, "D{}".format(r), '=TRIM({}&" "&{})'.format(A("D", r_civ + 2), A("D", r_civ + 1)), align="center")
    dn(wb, "NomClient", SHEET, A("C", r))
    dn(wb, "NomConjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Résidence fiscale")
    inp(ws, "C{}".format(r), "France", align="center")
    inp(ws, "D{}".format(r), "France", align="center")
    note(ws, "E{}".format(r), "Le modèle suppose un défunt et des héritiers résidents fiscaux français (art. 750 ter CGI).")
    r += 2

    # ------------------------------------------------------------------------
    section(ws, r, "3.  SITUATION FAMILIALE", ncols=7)
    r += 1
    lab(ws, "B{}".format(r), "Situation matrimoniale")
    inp(ws, "C{}".format(r), "Marié(e)", align="center")
    dv_liste(ws, "C{}".format(r), SIT_MAT)
    dn(wb, "SitMat", SHEET, A("C", r))
    note(ws, "E{}".format(r), "Seul le MARIAGE confère la qualité d'héritier légal. Le partenaire de PACS "
                              "et le concubin n'héritent que par testament (le PACS reste exonéré de droits, pas le concubinage).")
    r += 1
    lab(ws, "B{}".format(r), "Régime matrimonial")
    inp(ws, "C{}".format(r), "Communauté légale (réduite aux acquêts)", align="center")
    dv_liste(ws, "C{}".format(r), REGIMES)
    dn(wb, "RegimeMat", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Date du mariage / du PACS")
    inp(ws, "C{}".format(r), dt.date(2003, 6, 14), fmt=F_DATE, align="center")
    r += 1
    lab(ws, "B{}".format(r), "Donation au dernier vivant (DDV) en place")
    inp(ws, "C{}".format(r), "Oui", align="center")
    dv_liste(ws, "C{}".format(r), OUI_NON)
    dn(wb, "DDV", SHEET, A("C", r))
    note(ws, "E{}".format(r), "Art. 1094-1 C. civ. : élargit les options du conjoint (100 % en usufruit ou 1/4 PP + 3/4 US), "
                              "y compris en présence d'enfants d'un premier lit.")
    r += 1
    lab(ws, "B{}".format(r), "Testament rédigé")
    inp(ws, "C{}".format(r), "Non", align="center")
    dv_liste(ws, "C{}".format(r), OUI_NON)
    dn(wb, "Testament", SHEET, A("C", r))
    r += 2

    # ------------------------------------------------------------------------
    section(ws, r, "4.  ENFANTS", ncols=7)
    r += 1
    entetes(ws, r, 2, ["Prénom", "Date de naissance", "Âge", "Filiation", "Vivant",
                       "Situation de handicap"],
            largeurs=[44, 26, 26, 26, 14, 20])
    r += 1
    r_enf_deb = r
    exemples = [("Chloé", dt.date(1994, 9, 8), "Du client uniquement", "Oui", "Non"),
                ("Lucas", dt.date(2003, 5, 21), "Commun au couple", "Oui", "Non"),
                ("Emma", dt.date(2006, 11, 3), "Commun au couple", "Oui", "Non")]
    for i in range(NB_ENFANTS):
        ex = exemples[i] if i < len(exemples) else (None, None, None, None, None)
        inp(ws, "B{}".format(r), ex[0])
        inp(ws, "C{}".format(r), ex[1], fmt=F_DATE, align="center")
        calc(ws, "D{}".format(r), '=IF(C{r}="","",IFERROR(DATEDIF(C{r},DateSimu,"Y"),""))'.format(r=r),
             fmt=F_INT, align="center")
        ws["D{}".format(r)].border = BOX
        inp(ws, "E{}".format(r), ex[2], align="center")
        inp(ws, "F{}".format(r), ex[3], align="center")
        inp(ws, "G{}".format(r), ex[4], align="center")
        r += 1
    r_enf_fin = r - 1
    dv_liste(ws, "E{}:E{}".format(r_enf_deb, r_enf_fin), FILIATION)
    dv_liste(ws, "F{}:F{}".format(r_enf_deb, r_enf_fin), OUI_NON)
    dv_liste(ws, "G{}:G{}".format(r_enf_deb, r_enf_fin), OUI_NON)
    dn(wb, "EnfPrenom", SHEET, "$B${}:$B${}".format(r_enf_deb, r_enf_fin))
    dn(wb, "EnfNaiss", SHEET, "$C${}:$C${}".format(r_enf_deb, r_enf_fin))
    dn(wb, "EnfAge", SHEET, "$D${}:$D${}".format(r_enf_deb, r_enf_fin))
    dn(wb, "EnfFiliation", SHEET, "$E${}:$E${}".format(r_enf_deb, r_enf_fin))
    dn(wb, "EnfVivant", SHEET, "$F${}:$F${}".format(r_enf_deb, r_enf_fin))
    dn(wb, "EnfHandicap", SHEET, "$G${}:$G${}".format(r_enf_deb, r_enf_fin))
    note(ws, "I{}".format(r_enf_deb), "Un enfant prédécédé laissant lui-même des enfants ouvre la représentation "
                                      "(art. 751 C. civ.) : saisissez alors ses enfants sur des lignes distinctes.")
    r += 1
    for libelle, formule, nom in [
        ("Enfants vivants communs au couple",
         '=COUNTIFS(EnfFiliation,"Commun au couple",EnfVivant,"Oui")', "NbEnfCommuns"),
        ("Enfants vivants du client uniquement",
         '=COUNTIFS(EnfFiliation,"Du client uniquement",EnfVivant,"Oui")', "NbEnfPropClient"),
        ("Enfants vivants du conjoint uniquement",
         '=COUNTIFS(EnfFiliation,"Du conjoint uniquement",EnfVivant,"Oui")', "NbEnfPropConjoint"),
        ("TOTAL des enfants héritiers du CLIENT", "=NbEnfCommuns+NbEnfPropClient", "NbEnfClient"),
        ("TOTAL des enfants héritiers du CONJOINT", "=NbEnfCommuns+NbEnfPropConjoint", "NbEnfConjoint"),
    ]:
        lab(ws, "B{}".format(r), libelle, italic=not libelle.startswith("TOTAL"),
            bold=libelle.startswith("TOTAL"))
        calc(ws, "C{}".format(r), formule, fmt=F_INT, align="center",
             bold=libelle.startswith("TOTAL"))
        dn(wb, nom, SHEET, A("C", r))
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "5.  ASCENDANTS ET COLLATÉRAUX (utiles en l'absence d'enfant)", ncols=7)
    r += 1
    entetes(ws, r, 2, ["", "CLIENT", "CONJOINT / PARTENAIRE", ""])
    r += 1
    r_pere = r
    for libelle, v_cl, v_cj, fmt in [("Père vivant", "Non", "Oui", None),
                                     ("Mère vivante", "Oui", "Oui", None)]:
        lab(ws, "B{}".format(r), libelle)
        inp(ws, "C{}".format(r), v_cl, align="center")
        inp(ws, "D{}".format(r), v_cj, align="center")
        dv_liste(ws, "C{r}:D{r}".format(r=r), OUI_NON)
        r += 1
    lab(ws, "B{}".format(r), "Nombre d'ascendants privilégiés survivants", italic=True)
    calc(ws, "C{}".format(r), '=IF(C{a}="Oui",1,0)+IF(C{b}="Oui",1,0)'.format(a=r_pere, b=r_pere + 1),
         fmt=F_INT, align="center")
    calc(ws, "D{}".format(r), '=IF(D{a}="Oui",1,0)+IF(D{b}="Oui",1,0)'.format(a=r_pere, b=r_pere + 1),
         fmt=F_INT, align="center")
    dn(wb, "NbParentsClient", SHEET, A("C", r))
    dn(wb, "NbParentsConjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Nombre de frères et sœurs vivants")
    inp(ws, "C{}".format(r), 1, fmt=F_INT, align="center")
    inp(ws, "D{}".format(r), 2, fmt=F_INT, align="center")
    dn(wb, "NbFreresClient", SHEET, A("C", r))
    dn(wb, "NbFreresConjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Nombre de neveux / nièces venant en représentation")
    inp(ws, "C{}".format(r), 0, fmt=F_INT, align="center")
    inp(ws, "D{}".format(r), 0, fmt=F_INT, align="center")
    dn(wb, "NbNeveuxClient", SHEET, A("C", r))
    dn(wb, "NbNeveuxConjoint", SHEET, A("D", r))
    note(ws, "E{}".format(r), "Neveux et nièces représentant un frère ou une sœur prédécédé (art. 752-2 C. civ.).")
    r += 2

    # ------------------------------------------------------------------------
    section(ws, r, "6.  SITUATION PROFESSIONNELLE ET REVENUS", ncols=7)
    r += 1
    entetes(ws, r, 2, ["", "CLIENT", "CONJOINT / PARTENAIRE", ""])
    r += 1
    lab(ws, "B{}".format(r), "Statut professionnel")
    inp(ws, "C{}".format(r), "Salarié du privé", align="center")
    inp(ws, "D{}".format(r), "Salarié du privé", align="center")
    dv_liste(ws, "C{r}:D{r}".format(r=r), STATUTS)
    dn(wb, "StatutClient", SHEET, A("C", r))
    dn(wb, "StatutConjoint", SHEET, A("D", r))
    note(ws, "E{}".format(r), "Le module retraite est calibré pour le régime général + Agirc-Arrco (salariés du privé). "
                              "Pour un fonctionnaire ou un indépendant, reportez directement l'estimation de son régime.")
    r += 1
    lab(ws, "B{}".format(r), "Profession")
    inp(ws, "C{}".format(r), "Cadre commercial", align="center")
    inp(ws, "D{}".format(r), "Infirmière", align="center")
    r += 1
    lab(ws, "B{}".format(r), "Date d'entrée dans la vie active")
    inp(ws, "C{}".format(r), dt.date(1991, 9, 1), fmt=F_DATE, align="center")
    inp(ws, "D{}".format(r), dt.date(1994, 10, 1), fmt=F_DATE, align="center")
    r += 1
    lab(ws, "B{}".format(r), "Revenu annuel BRUT (€)")
    inp(ws, "C{}".format(r), 78000, fmt=F_EUR, align="center")
    inp(ws, "D{}".format(r), 42000, fmt=F_EUR, align="center")
    dn(wb, "RevBrutClient", SHEET, A("C", r))
    dn(wb, "RevBrutConjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Revenu annuel NET IMPOSABLE (€)")
    inp(ws, "C{}".format(r), 62000, fmt=F_EUR, align="center")
    inp(ws, "D{}".format(r), 34000, fmt=F_EUR, align="center")
    dn(wb, "RNI_Client", SHEET, A("C", r))
    dn(wb, "RNI_Conjoint", SHEET, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Revenu NET MENSUEL perçu (€)")
    inp(ws, "C{}".format(r), 4300, fmt=F_EUR, align="center")
    inp(ws, "D{}".format(r), 2500, fmt=F_EUR, align="center")
    dn(wb, "RevNetMensClient", SHEET, A("C", r))
    dn(wb, "RevNetMensConjoint", SHEET, A("D", r))
    note(ws, "E{}".format(r), "Sert de base au taux de remplacement à la retraite.")
    r += 2

    # ------------------------------------------------------------------------
    section(ws, r, "7.  FISCALITÉ DU FOYER", ncols=7)
    r += 1
    lab(ws, "B{}".format(r), "Nombre de parts fiscales")
    inp(ws, "C{}".format(r), 3, fmt=F_DEC, align="center")
    dn(wb, "PartsFiscales", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Revenu net imposable du foyer", italic=True)
    calc(ws, "C{}".format(r), "=RNI_Client+RNI_Conjoint", fmt=F_EUR, align="center")
    dn(wb, "RNI_Foyer", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Quotient familial", italic=True)
    calc(ws, "C{}".format(r), "=IF(PartsFiscales=0,0,RNI_Foyer/PartsFiscales)", fmt=F_EUR, align="center")
    dn(wb, "QuotientFamilial", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Impôt sur le revenu estimé", italic=True)
    calc(ws, "C{}".format(r),
         "=SUMPRODUCT((QuotientFamilial>IR_Seuil)*(QuotientFamilial-IR_Seuil)*(IR_Taux-IR_Prev))*PartsFiscales",
         fmt=F_EUR, align="center",
         comment="Barème progressif appliqué au quotient familial. Hors plafonnement du quotient, "
                 "décote, réductions et crédits d'impôt : ordre de grandeur destiné au seul calcul de la TMI.")
    dn(wb, "IR_Estime", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Taux moyen d'imposition", italic=True)
    calc(ws, "C{}".format(r), "=IF(RNI_Foyer=0,0,IR_Estime/RNI_Foyer)", fmt=F_PCT, align="center")
    r += 1
    lab(ws, "B{}".format(r), "TAUX MARGINAL D'IMPOSITION (TMI)", bold=True)
    resultat(ws, "C{}".format(r),
             "=IFERROR(INDEX(IR_Taux,MATCH(QuotientFamilial,IR_Seuil,1)),0)", fmt=F_PCT)
    dn(wb, "TMI", SHEET, A("C", r))
    note(ws, "E{}".format(r), "Détermine l'économie d'impôt d'un versement sur un PER (feuille « Retraite_Objectif »).")
    r += 2

    lab(ws, "B{}".format(r),
        "Ce classeur est livré pré-rempli avec un cas fictif d'illustration (famille MARTIN). "
        "Écrasez chaque cellule bleue par les données réelles du client.",
        italic=True, color=C_WARN)

    ws.sheet_properties.tabColor = BLEU
    return ws
