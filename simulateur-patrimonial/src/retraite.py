# -*- coding: utf-8 -*-
"""Feuilles retraite.

Retraite_Carriere    : la personne étudiée, ses paramètres légaux et sa carrière.
Retraite_Estimation  : estimation de la pension, calculée pour 6 âges de départ
                       plus l'âge envisagé — un seul bloc de formules, 7 colonnes.
Retraite_Objectif    : écart avec l'objectif de revenu, capital nécessaire et
                       effort d'épargne mensuel à mettre en place.
"""

from .styles import *

SH_CAR = "Retraite_Carriere"
SH_EST = "Retraite_Estimation"
SH_OBJ = "Retraite_Objectif"

AGES_SCENARIOS = [62, 63, 64, 65, 66, 67]
COLS = ["D", "E", "F", "G", "H", "I", "J"]


# ===========================================================================
def construire_carriere(wb):
    ws = wb.create_sheet(SH_CAR)
    largeurs(ws, {"A": 2, "B": 52, "C": 18, "D": 18, "E": 4, "F": 78})
    mise_en_page(ws, zoom=100, freeze="A5", paysage=False, ncols=6)

    titre(ws, 1, "RETRAITE — PERSONNE ÉTUDIÉE, PARAMÈTRES LÉGAUX ET CARRIÈRE", ncols=6,
          sous_titre="Modèle calibré pour un salarié du privé : régime général (CNAV) + complémentaire "
                     "Agirc-Arrco. Basculez le sélecteur pour étudier le conjoint.")

    r = 4
    section(ws, r, "1.  PERSONNE ÉTUDIÉE", ncols=6)
    r += 1
    lab(ws, "B{}".format(r), "Personne étudiée", bold=True)
    inp(ws, "C{}".format(r), "Client", align="center")
    dv_liste(ws, "C{}".format(r), ["Client", "Conjoint"])
    dn(wb, "Rt_Personne", SH_CAR, A("C", r))
    r += 1
    for libelle, formule, nom, fmt in [
        ("Identité", '=IF(Rt_Personne="Client",NomClient,NomConjoint)', "Rt_Nom", None),
        ("Date de naissance", '=IF(Rt_Personne="Client",DateNaisClient,DateNaisConjoint)', "Rt_DateNais", F_DATE),
        ("Année de naissance", "=YEAR(Rt_DateNais)", "Rt_AnneeNais", F_INT),
        ("Âge actuel", '=IF(Rt_Personne="Client",AgeClient,AgeConjoint)', "Rt_AgeActuel", F_INT),
        ("Statut professionnel", '=IF(Rt_Personne="Client",StatutClient,StatutConjoint)', "Rt_Statut", None),
        ("Salaire annuel brut actuel", '=IF(Rt_Personne="Client",RevBrutClient,RevBrutConjoint)',
         "Rt_SalaireBrut", F_EUR),
        ("Revenu net mensuel actuel", '=IF(Rt_Personne="Client",RevNetMensClient,RevNetMensConjoint)',
         "Rt_RevNetMens", F_EUR),
        ("Nombre d'enfants", '=IF(Rt_Personne="Client",NbEnfClient,NbEnfConjoint)', "Rt_NbEnfants", F_INT),
    ]:
        lab(ws, "B{}".format(r), libelle)
        link(ws, "C{}".format(r), formule, fmt=fmt, align="center")
        dn(wb, nom, SH_CAR, A("C", r))
        r += 1
    lab(ws, "B{}".format(r), "Contrôle du régime")
    alerte_large(ws, "C{}".format(r), (
           '=IF(Rt_Statut="Salarié du privé","✅ Régime général + Agirc-Arrco : le modèle s\'applique.",'
           '"⚠️ Statut hors régime général : reportez directement l\'estimation communiquée par la caisse '
           '(fonction publique, SSI, CNAVPL, MSA) dans la feuille « Retraite_Objectif ».")'), span=4, hauteur=44)
    r += 2

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  PARAMÈTRES LÉGAUX (issus du calendrier par génération)", ncols=6)
    r += 1
    entetes(ws, r, 2, ["", "Calendrier légal", "Valeur retenue", ""])
    r += 1
    for libelle, formule_cal, nom, fmt, src in [
        ("Âge légal de départ (années)", "=IFERROR(INDEX(GenAgeLegal,MATCH(Rt_AnneeNais,GenAnnee,0)),64)",
         "Rt_AgeLegal", F_DEC, "Feuille Parametres § 7."),
        ("Durée d'assurance requise (trimestres)", "=IFERROR(INDEX(GenDuree,MATCH(Rt_AnneeNais,GenAnnee,0)),172)",
         "Rt_DureeRequise", F_INT, "Feuille Parametres § 7."),
        ("Âge du taux plein automatique", "=IFERROR(INDEX(GenAgeTP,MATCH(Rt_AnneeNais,GenAnnee,0)),67)",
         "Rt_AgeTP", F_INT, "Taux plein sans condition de durée."),
    ]:
        lab(ws, "B{}".format(r), libelle)
        calc(ws, "C{}".format(r), formule_cal, fmt=fmt, align="center")
        inp(ws, "D{}".format(r), "=C{}".format(r), fmt=fmt, align="center",
            comment="Valeur reprise du calendrier. Écrasez-la si la réglementation applicable diffère "
                    "ou si le client relève d'un dispositif particulier (carrière longue, incapacité, "
                    "catégorie active).")
        dn(wb, nom, SH_CAR, A("D", r))
        note(ws, "F{}".format(r), src)
        r += 1
    note(ws, "B{}".format(r), "⚠️ Dispositifs non modélisés : carrière longue, retraite progressive, "
                              "incapacité permanente, catégories actives, régimes spéciaux, rachats de trimestres.")
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  CARRIÈRE (à recopier depuis le relevé de carrière — info-retraite.fr)", ncols=6)
    r += 1
    lab(ws, "B{}".format(r), "Trimestres validés au relevé de carrière")
    inp(ws, "C{}".format(r), 145, fmt=F_INT, align="center")
    dn(wb, "Rt_TrimReleve", SH_CAR, A("C", r))
    note(ws, "F{}".format(r), "Tous régimes de base confondus.")
    r += 1
    lab(ws, "B{}".format(r), "Année du relevé de carrière")
    inp(ws, "C{}".format(r), 2025, fmt=F_INT, align="center")
    dn(wb, "Rt_AnneeReleve", SH_CAR, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Âge à la date du relevé", italic=True)
    calc(ws, "C{}".format(r), "=Rt_AnneeReleve-Rt_AnneeNais", fmt=F_INT, align="center")
    dn(wb, "Rt_AgeReleve", SH_CAR, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Trimestres de majoration à ajouter (maternité, éducation, service…)")
    inp(ws, "C{}".format(r), 0, fmt=F_INT, align="center",
        comment="À renseigner UNIQUEMENT si ces trimestres ne figurent pas déjà sur le relevé de carrière, "
                "pour éviter tout double compte. 8 trimestres par enfant pour la mère salariée du privé, "
                "dont 4 partageables au titre de l'éducation.")
    dn(wb, "Rt_TrimMajo", SH_CAR, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Trimestres acquis à la date du relevé (total)", italic=True)
    calc(ws, "C{}".format(r), "=Rt_TrimReleve+Rt_TrimMajo", fmt=F_INT, align="center")
    dn(wb, "Rt_TrimTotalReleve", SH_CAR, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Âge auquel le taux plein serait atteint", italic=True)
    calc(ws, "C{}".format(r),
         "=MIN(Rt_AgeTP,MAX(Rt_AgeLegal,Rt_AgeReleve+(Rt_DureeRequise-Rt_TrimTotalReleve)/4))",
         fmt=F_DEC, align="center")
    dn(wb, "Rt_AgeTauxPlein", SH_CAR, A("C", r))
    note(ws, "F{}".format(r), "Le plus tardif entre l'âge légal et l'âge d'obtention de la durée requise, "
                              "plafonné à l'âge du taux plein automatique.")
    r += 1
    lab(ws, "B{}".format(r), "ÂGE DE DÉPART ENVISAGÉ", bold=True)
    inp(ws, "C{}".format(r), 64, fmt=F_DEC, align="center")
    dn(wb, "Rt_AgeDepart", SH_CAR, A("C", r))
    note(ws, "F{}".format(r), "Alimente la colonne « Départ envisagé » de la feuille « Retraite_Estimation ».")
    r += 2

    # ------------------------------------------------------------------ 4 ---
    section(ws, r, "4.  SALAIRE ANNUEL MOYEN (SAM) ET POINTS AGIRC-ARRCO", ncols=6)
    r += 1
    lab(ws, "B{}".format(r), "Mode de détermination du SAM")
    inp(ws, "C{}".format(r), "Estimation automatique", align="center")
    dv_liste(ws, "C{}".format(r), ["Saisie directe", "Estimation automatique"])
    dn(wb, "Rt_ModeSAM", SH_CAR, A("C", r))
    note(ws, "F{}".format(r), "Préférez « Saisie directe » dès que le client dispose d'une estimation officielle.")
    r += 1
    lab(ws, "B{}".format(r), "SAM saisi (25 meilleures années, plafonnées au PASS)")
    inp(ws, "C{}".format(r), 40000, fmt=F_EUR, align="center")
    dn(wb, "Rt_SAM_Saisi", SH_CAR, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "SAM estimé automatiquement", italic=True)
    calc(ws, "C{}".format(r), "=MIN(Rt_SalaireBrut,PASS)*CoefSAM", fmt=F_EUR, align="center")
    dn(wb, "Rt_SAM_Auto", SH_CAR, A("C", r))
    note(ws, "F{}".format(r), "Salaire brut plafonné au PASS × coefficient de carrière (feuille Parametres § 11). "
                              "APPROXIMATION : les 25 meilleures années sont en moyenne inférieures au dernier salaire.")
    r += 1
    lab(ws, "B{}".format(r), "SALAIRE ANNUEL MOYEN RETENU", bold=True)
    resultat(ws, "C{}".format(r), '=IF(Rt_ModeSAM="Saisie directe",Rt_SAM_Saisi,Rt_SAM_Auto)', fmt=F_EUR)
    dn(wb, "Rt_SAM", SH_CAR, A("C", r))
    r += 2
    lab(ws, "B{}".format(r), "Points Agirc-Arrco acquis au relevé")
    inp(ws, "C{}".format(r), 4800, fmt=F_INT, align="center")
    dn(wb, "Rt_PointsReleve", SH_CAR, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Points acquis chaque année (calculés sur le salaire actuel)", italic=True)
    calc(ws, "C{}".format(r),
         "=IF(ArrcoAchat=0,0,(MIN(Rt_SalaireBrut,PASS)*ArrcoT1"
         "+MAX(0,MIN(Rt_SalaireBrut,8*PASS)-PASS)*ArrcoT2)/ArrcoAchat)",
         fmt=F_DEC, align="center",
         comment="Points = (assiette T1 × 6,20 % + assiette T2 × 17 %) / valeur d'achat du point. "
                 "Le salaire est supposé stable en euros constants sur la période restante.")
    dn(wb, "Rt_PointsAnnuels", SH_CAR, A("C", r))
    r += 2
    note(ws, "B{}".format(r), "Le raisonnement est mené EN EUROS CONSTANTS : salaire, SAM et valeurs du point sont "
                              "supposés évoluer comme l'inflation. Les montants de pension s'interprètent donc "
                              "en pouvoir d'achat d'aujourd'hui.")

    ws.sheet_properties.tabColor = "1F7A4D"
    return ws


# ===========================================================================
def construire_estimation(wb):
    ws = wb.create_sheet(SH_EST)
    largeurs(ws, {"A": 2, "B": 54, "C": 3, "D": 15, "E": 15, "F": 15, "G": 15,
                  "H": 15, "I": 15, "J": 18, "K": 4, "L": 62})
    mise_en_page(ws, zoom=95, freeze="D8", ncols=10)

    titre(ws, 1, "RETRAITE — ESTIMATION DE LA PENSION SELON L'ÂGE DE DÉPART", ncols=10,
          sous_titre="Le même bloc de calcul est appliqué à six âges de départ, plus l'âge envisagé. "
                     "Montants exprimés en euros constants (pouvoir d'achat d'aujourd'hui).")

    r = 4
    lab(ws, "B{}".format(r), "Personne étudiée", bold=True)
    link(ws, "D{}".format(r), "=Rt_Nom")
    r += 2

    section(ws, r, "SCÉNARIOS D'ÂGE DE DÉPART", ncols=10)
    r += 1
    entetes(ws, r, 2, ["Étape de calcul", "", "62 ans", "63 ans", "64 ans", "65 ans",
                       "66 ans", "67 ans", "DÉPART ENVISAGÉ"])
    r += 1

    rows = {}

    def ligne(cle, libelle, gabarit, fmt=None, style="calc", indent=False, hauteur=None):
        """Écrit une ligne du bloc : libellé + 7 colonnes."""
        nonlocal r
        lab(ws, "B{}".format(r), ("    " if indent else "") + libelle,
            bold=(style == "fort"), italic=(style == "note"))
        for c in COLS:
            f = gabarit.format(c=c, **rows)
            if style == "fort":
                resultat(ws, "{}{}".format(c, r), f, fmt=fmt)
            else:
                cell = calc(ws, "{}{}".format(c, r), f, fmt=fmt, align="center")
                cell.border = BOX
                if c == "J":
                    cell.font = Font(name=POLICE, size=10, bold=True, color=C_CALC)
                    cell.fill = PatternFill("solid", fgColor=GREY)
        rows[cle] = r
        if hauteur:
            ws.row_dimensions[r].height = hauteur
        r += 1
        return r - 1

    # --- âge de départ : saisi en dur pour les 6 scénarios, lié pour la 7e ---
    lab(ws, "B{}".format(r), "Âge de départ", bold=True)
    for i, c in enumerate(COLS[:-1]):
        inp(ws, "{}{}".format(c, r), AGES_SCENARIOS[i], fmt=F_DEC, align="center")
    resultat(ws, "J{}".format(r), "=Rt_AgeDepart", fmt=F_DEC)
    rows["age"] = r
    dn(wb, "Rt_ScenAges", SH_EST, "$D${r}:$I${r}".format(r=r))
    r += 1

    ligne("annee", "Année de départ estimée", "=Rt_AnneeNais+{c}${age}", F_INT)
    ligne("possible", "Départ possible au regard de l'âge légal ?",
          '=IF({c}${age}<Rt_AgeLegal,"NON","Oui")')
    ligne("trim", "Trimestres acquis au départ",
          "=Rt_TrimTotalReleve+4*MAX(0,{c}${age}-Rt_AgeReleve)", F_INT)
    ligne("duree", "Durée d'assurance requise", "=Rt_DureeRequise", F_INT, indent=True)
    ligne("manq", "Trimestres manquants", "=MAX(0,{c}${duree}-{c}${trim})", F_INT, indent=True)
    ligne("jusqu67", "Trimestres restant jusqu'à l'âge du taux plein",
          "=MAX(0,(Rt_AgeTP-{c}${age})*4)", F_INT, indent=True)
    ligne("dec", "Trimestres de décote retenus",
          "=MIN(DecoteMax,MIN({c}${manq},{c}${jusqu67}))", F_INT, indent=True)
    ligne("sur", "Trimestres de surcote",
          "=MAX(0,MIN({c}${trim}-{c}${duree},({c}${age}-Rt_AgeLegal)*4))", F_INT, indent=True)
    ligne("taux", "Taux de liquidation",
          "=IF(OR({c}${age}>=Rt_AgeTP,{c}${trim}>={c}${duree}),"
          "TauxPlein+{c}${sur}*SurcoteTrim,TauxPlein-{c}${dec}*DecoteTrim)", F_PCT2)
    ligne("prorata", "Coefficient de proratisation",
          "=IF({c}${duree}=0,0,MIN(1,{c}${trim}/{c}${duree}))", F_PCT2)
    ligne("sam", "Salaire annuel moyen retenu", "=Rt_SAM", F_EUR, indent=True)
    ligne("base0", "Pension de base annuelle brute",
          "={c}${sam}*{c}${taux}*{c}${prorata}", F_EUR)
    ligne("majbase", "Majoration pour 3 enfants et plus",
          "=IF(Rt_NbEnfants>=3,{c}${base0}*MajEnfants,0)", F_EUR, indent=True)
    ligne("base", "PENSION DE BASE BRUTE (annuelle)", "={c}${base0}+{c}${majbase}", F_EUR, style="fort")

    r += 1
    ligne("points", "Points Agirc-Arrco au départ",
          "=Rt_PointsReleve+Rt_PointsAnnuels*MAX(0,{c}${age}-Rt_AgeReleve)", F_INT)
    ligne("coefarrco", "Coefficient de report Agirc-Arrco",
          "=IF(ArrcoCoefOn=0,1,IF({c}${age}>=Rt_AgeTauxPlein+4,1.3,"
          "IF({c}${age}>=Rt_AgeTauxPlein+3,1.2,IF({c}${age}>=Rt_AgeTauxPlein+2,1.1,1))))", F_DEC, indent=True)
    ligne("comp0", "Pension complémentaire annuelle brute",
          "={c}${points}*ArrcoService*{c}${coefarrco}", F_EUR)
    ligne("majcomp", "Majoration familiale (3 enfants et plus)",
          "=IF(Rt_NbEnfants>=3,MIN({c}${comp0}*ArrcoMajFam,ArrcoMajPlafond),0)", F_EUR, indent=True)
    ligne("comp", "PENSION COMPLÉMENTAIRE BRUTE (annuelle)", "={c}${comp0}+{c}${majcomp}", F_EUR, style="fort")

    r += 1
    ligne("brutan", "TOTAL BRUT ANNUEL", "={c}${base}+{c}${comp}", F_EUR, style="fort")
    ligne("brutmens", "Total brut mensuel", "={c}${brutan}/12", F_EUR)
    ligne("ps", "Prélèvements sociaux (CSG, CRDS, CASA, maladie)",
          "=-({c}${base}*PS_Base+{c}${comp}*PS_Comp)", F_EUR, indent=True)
    ligne("netan", "TOTAL NET ANNUEL", "={c}${brutan}+{c}${ps}", F_EUR)
    ligne("netmens", "PENSION NETTE MENSUELLE", "={c}${netan}/12", F_EUR, style="fort")
    dn(wb, "Rt_ScenPensionNetteMens", SH_EST, "$D${r}:$I${r}".format(r=rows["netmens"]))
    dn(wb, "Rt_PensionNetteMens", SH_EST, A("J", rows["netmens"]))
    dn(wb, "Rt_PensionNetteAn", SH_EST, A("J", rows["netan"]))
    dn(wb, "Rt_PensionBruteMens", SH_EST, A("J", rows["brutmens"]))

    ligne("revact", "Revenu net mensuel actuel", "=Rt_RevNetMens", F_EUR, indent=True)
    ligne("remp", "TAUX DE REMPLACEMENT (net / net)",
          "=IF({c}${revact}=0,0,{c}${netmens}/{c}${revact})", F_PCT, style="fort")
    dn(wb, "Rt_TauxRemplacement", SH_EST, A("J", rows["remp"]))

    r += 1
    lab(ws, "B{}".format(r), "Gain d'un report d'un an (pension nette mensuelle)", italic=True)
    for i, c in enumerate(COLS[:-1]):
        if i == 0:
            calc(ws, "{}{}".format(c, r), '="—"', align="center")
        else:
            prev = COLS[i - 1]
            calc(ws, "{}{}".format(c, r),
                 "={c}${n}-{p}${n}".format(c=c, p=prev, n=rows["netmens"]), fmt=F_EUR, align="center")
    r += 2

    note(ws, "B{}".format(r), "Décote : 1,25 point par trimestre manquant, dans la limite de 20 trimestres, "
                              "le nombre retenu étant le PLUS FAIBLE entre les trimestres manquants et les "
                              "trimestres restant jusqu'à l'âge du taux plein automatique.")
    r += 1
    note(ws, "B{}".format(r), "Surcote : 1,25 point par trimestre cotisé au-delà de la durée requise ET de l'âge légal.")
    r += 1
    note(ws, "B{}".format(r), "Non modélisés : minimum contributif, pensions de réversion, périodes à l'étranger, "
                              "polypensionnés hors régime général, rachats de trimestres, plafonnement du cumul "
                              "emploi-retraite. Estimation indicative — seule la caisse de retraite fait foi.")

    ws.sheet_properties.tabColor = "1F7A4D"
    return ws


# ===========================================================================
def construire_objectif(wb):
    ws = wb.create_sheet(SH_OBJ)
    largeurs(ws, {"A": 2, "B": 56, "C": 18, "D": 16, "E": 16, "F": 16, "G": 16,
                  "H": 16, "I": 16, "J": 4, "K": 62})
    mise_en_page(ws, zoom=95, freeze="A5", ncols=9)

    titre(ws, 1, "RETRAITE — OBJECTIF DE REVENU ET EFFORT D'ÉPARGNE", ncols=9,
          sous_titre="Raisonnement en euros constants : les taux de rendement sont convertis en taux RÉELS "
                     "(nets d'inflation). Les montants s'interprètent en pouvoir d'achat d'aujourd'hui.")

    r = 4
    section(ws, r, "1.  OBJECTIF DE REVENU À LA RETRAITE", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "Mode de définition de l'objectif")
    inp(ws, "C{}".format(r), "Montant mensuel", align="center")
    dv_liste(ws, "C{}".format(r), ["Montant mensuel", "% du revenu net actuel"])
    dn(wb, "Ob_Mode", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Objectif — montant net mensuel souhaité (€ d'aujourd'hui)")
    inp(ws, "C{}".format(r), 3800, fmt=F_EUR, align="center")
    dn(wb, "Ob_Montant", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Objectif — en % du revenu net actuel")
    inp(ws, "C{}".format(r), 0.75, fmt=F_PCT, align="center")
    dn(wb, "Ob_Pct", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "OBJECTIF RETENU (€ nets / mois)", bold=True)
    resultat(ws, "C{}".format(r), '=IF(Ob_Mode="Montant mensuel",Ob_Montant,Ob_Pct*Rt_RevNetMens)', fmt=F_EUR)
    dn(wb, "Ob_Objectif", SH_OBJ, A("C", r))
    r += 2

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  RESSOURCES ESTIMÉES ET ÉCART À COMBLER", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "Pension nette mensuelle estimée (âge de départ envisagé)")
    link(ws, "C{}".format(r), "=Rt_PensionNetteMens", fmt=F_EUR, align="center")
    r += 1
    lab(ws, "B{}".format(r), "Autres revenus nets mensuels attendus (loyers, pension du conjoint…)")
    inp(ws, "C{}".format(r), 400, fmt=F_EUR, align="center")
    dn(wb, "Ob_AutresRevenus", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "TOTAL DES RESSOURCES", bold=True)
    total(ws, "C{}".format(r), "=Rt_PensionNetteMens+Ob_AutresRevenus", fmt=F_EUR, align="center")
    dn(wb, "Ob_Ressources", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "ÉCART MENSUEL À COMBLER", bold=True)
    resultat(ws, "C{}".format(r), "=MAX(0,Ob_Objectif-Ob_Ressources)", fmt=F_EUR)
    dn(wb, "Ob_EcartMens", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Écart annuel", italic=True)
    calc(ws, "C{}".format(r), "=Ob_EcartMens*12", fmt=F_EUR, align="center")
    dn(wb, "Ob_EcartAn", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Taux de remplacement avant effort d'épargne", italic=True)
    calc(ws, "C{}".format(r), "=IF(Rt_RevNetMens=0,0,Ob_Ressources/Rt_RevNetMens)", fmt=F_PCT, align="center")
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  CAPITAL NÉCESSAIRE AU JOUR DU DÉPART", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "Méthode de restitution du capital")
    inp(ws, "C{}".format(r), "Consommation du capital", align="center")
    dv_liste(ws, "C{}".format(r), ["Consommation du capital", "Rente viagère", "Capital préservé"])
    dn(wb, "Ob_Methode", SH_OBJ, A("C", r))
    note(ws, "K{}".format(r), "Consommation : le capital est épuisé à l'âge de fin de besoin. "
                              "Rente viagère : conversion auprès d'un assureur, capital aliéné. "
                              "Capital préservé : seuls les revenus sont consommés, le capital est transmis.")
    r += 1
    for libelle, formule, nom, fmt in [
        ("Âge de départ retenu", "=Rt_AgeDepart", None, F_DEC),
        ("Âge de fin du besoin de revenu", "=EsperanceVie", None, F_INT),
        ("Durée de la phase de restitution (années)", "=MAX(0,EsperanceVie-Rt_AgeDepart)", "Ob_DureeRestit", F_DEC),
        ("Taux de rendement RÉEL net en restitution",
         "=(1+RendRestit)/(1+Inflation)-1", "Ob_TauxReelRestit", F_PCT2),
    ]:
        lab(ws, "B{}".format(r), libelle, italic=True)
        link(ws, "C{}".format(r), formule, fmt=fmt, align="center")
        if nom:
            dn(wb, nom, SH_OBJ, A("C", r))
        r += 1
    lab(ws, "B{}".format(r), "CAPITAL NÉCESSAIRE AU DÉPART", bold=True)
    resultat(ws, "C{}".format(r),
             '=IF(Ob_EcartAn=0,0,'
             'IF(Ob_Methode="Rente viagère",IF(TauxRente=0,0,Ob_EcartAn/TauxRente),'
             'IF(Ob_Methode="Capital préservé",IF(Ob_TauxReelRestit<=0,Ob_EcartAn*Ob_DureeRestit,Ob_EcartAn/Ob_TauxReelRestit),'
             'IF(ABS(Ob_TauxReelRestit)<0.000001,Ob_EcartAn*Ob_DureeRestit,'
             'Ob_EcartAn*(1-(1+Ob_TauxReelRestit)^-Ob_DureeRestit)/Ob_TauxReelRestit))))',
             fmt=F_EUR)
    dn(wb, "Ob_CapitalNecessaire", SH_OBJ, A("C", r))
    r += 2

    # ------------------------------------------------------------------ 4 ---
    section(ws, r, "4.  RESSOURCES DÉJÀ CONSTITUÉES", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "Épargne déjà dédiée à la retraite (€ aujourd'hui)")
    inp(ws, "C{}".format(r), 118000, fmt=F_EUR, align="center")
    dn(wb, "Ob_EpargneActuelle", SH_OBJ, A("C", r))
    note(ws, "K{}".format(r), "PER, assurance-vie, PEA, comptes-titres — uniquement la part réellement affectée "
                              "au projet retraite (n'y intégrez pas la résidence principale).")
    r += 1
    lab(ws, "B{}".format(r), "Versements mensuels déjà en place (€)")
    inp(ws, "C{}".format(r), 150, fmt=F_EUR, align="center")
    dn(wb, "Ob_VersementsActuels", SH_OBJ, A("C", r))
    r += 1
    for libelle, formule, nom, fmt in [
        ("Nombre d'années jusqu'au départ", "=MAX(0,Rt_AgeDepart-Rt_AgeActuel)", "Ob_AnneesRestantes", F_DEC),
        ("Nombre de mois jusqu'au départ", "=Ob_AnneesRestantes*12", "Ob_MoisRestants", F_INT),
        ("Taux de rendement RÉEL net en constitution",
         "=(1+RendConstit)/(1+Inflation)-1", "Ob_TauxReelConstit", F_PCT2),
        ("Taux réel mensuel équivalent", "=(1+Ob_TauxReelConstit)^(1/12)-1", "Ob_TauxMensuel", '0.0000%'),
    ]:
        lab(ws, "B{}".format(r), libelle, italic=True)
        calc(ws, "C{}".format(r), formule, fmt=fmt, align="center")
        if nom:
            dn(wb, nom, SH_OBJ, A("C", r))
        r += 1
    lab(ws, "B{}".format(r), "Capital projeté au départ (€ constants)", bold=True)
    total(ws, "C{}".format(r),
          "=Ob_EpargneActuelle*(1+Ob_TauxMensuel)^Ob_MoisRestants"
          "+IF(Ob_MoisRestants=0,0,IF(ABS(Ob_TauxMensuel)<0.0000001,Ob_VersementsActuels*Ob_MoisRestants,"
          "Ob_VersementsActuels*((1+Ob_TauxMensuel)^Ob_MoisRestants-1)/Ob_TauxMensuel))",
          fmt=F_EUR, align="center")
    dn(wb, "Ob_CapitalProjete", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "CAPITAL RESTANT À CONSTITUER", bold=True)
    resultat(ws, "C{}".format(r), "=MAX(0,Ob_CapitalNecessaire-Ob_CapitalProjete)", fmt=F_EUR)
    dn(wb, "Ob_CapitalManquant", SH_OBJ, A("C", r))
    r += 2

    # ------------------------------------------------------------------ 5 ---
    section(ws, r, "5.  EFFORT D'ÉPARGNE À METTRE EN PLACE", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "EFFORT MENSUEL SUPPLÉMENTAIRE (versements constants)", bold=True)
    resultat(ws, "C{}".format(r),
             "=IF(Ob_MoisRestants<=0,0,IF(ABS(Ob_TauxMensuel)<0.0000001,Ob_CapitalManquant/Ob_MoisRestants,"
             "Ob_CapitalManquant*Ob_TauxMensuel/((1+Ob_TauxMensuel)^Ob_MoisRestants-1)))", fmt=F_EUR)
    dn(wb, "Ob_EffortMensuel", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Effort annuel", italic=True)
    calc(ws, "C{}".format(r), "=Ob_EffortMensuel*12", fmt=F_EUR, align="center")
    dn(wb, "Ob_EffortAnnuel", SH_OBJ, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Effort en % du revenu net actuel", italic=True)
    calc(ws, "C{}".format(r), "=IF(Rt_RevNetMens=0,0,Ob_EffortMensuel/Rt_RevNetMens)", fmt=F_PCT, align="center")
    r += 1
    lab(ws, "B{}".format(r), "Versement unique équivalent aujourd'hui", italic=True)
    calc(ws, "C{}".format(r), "=Ob_CapitalManquant/(1+Ob_TauxMensuel)^Ob_MoisRestants", fmt=F_EUR, align="center")
    r += 1
    lab(ws, "B{}".format(r), "Diagnostic")
    alerte_large(ws, "C{}".format(r), (
           '=IF(Ob_EcartMens=0,"✅ Les ressources estimées couvrent déjà l\'objectif : aucun effort d\'épargne nécessaire.",'
           'IF(Ob_CapitalManquant=0,"✅ Le capital déjà constitué suffit à couvrir l\'écart de revenu.",'
           'IF(Ob_EffortMensuel>0.25*Rt_RevNetMens,'
           '"⚠️ L\'effort dépasse 25 % du revenu net actuel : révisez l\'objectif, décalez l\'âge de départ ou allongez la durée d\'épargne.",'
           '"Effort soutenable au regard du revenu actuel — à confronter à la capacité d\'épargne réelle du client.")))'),
                 span=6, hauteur=46)
    r += 2

    # ------------------------------------------------------------------ 6 ---
    section(ws, r, "6.  CHOIX DE L'ENVELOPPE D'ÉPARGNE", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "Taux marginal d'imposition du foyer")
    link(ws, "C{}".format(r), "=TMI", fmt=F_PCT, align="center")
    r += 1
    lab(ws, "B{}".format(r), "Plafond annuel de déduction PER disponible", italic=True)
    calc(ws, "C{}".format(r),
         "=MAX(PER_PlancherPASS*PASS_N1,MIN(PER_Taux*Rt_SalaireBrut,PER_Taux*PER_PlafondPASS*PASS_N1))",
         fmt=F_EUR, align="center",
         comment="10 % des revenus professionnels de l'année précédente, dans la limite de 8 PASS N-1, "
                 "avec un plancher de 10 % du PASS N-1. Hors reliquats des trois années précédentes "
                 "et hors mutualisation avec le conjoint.")
    dn(wb, "Ob_PlafondPER", SH_OBJ, A("C", r))
    r += 1
    entetes(ws, r, 2, ["Enveloppe", "Versement annuel", "Économie d'impôt à l'entrée",
                       "Effort net réel annuel"])
    for col, lib, span in [("F", "Fiscalité à la sortie", 2), ("H", "Disponibilité", 2)]:
        entetes(ws, r, ws["{}1".format(col)].column, [lib])
        ws.merge_cells("{c}{r}:{f}{r}".format(c=col, r=r,
                       f=chr(ord(col) + span - 1)))
    r += 1
    enveloppes = [
        ("PER individuel", "=MIN(Ob_EffortAnnuel,Ob_PlafondPER)",
         "=MIN(Ob_EffortAnnuel,Ob_PlafondPER)*TMI",
         "Capital : IR au barème sur les versements + PFU 30 % sur les gains. Rente : régime des pensions.",
         "Bloqué jusqu'à la retraite (sauf achat de la résidence principale et accidents de la vie)"),
        ("Assurance-vie", "=Ob_EffortAnnuel", "=0",
         "Après 8 ans : abattement annuel de 4 600 € / 9 200 €, puis 7,5 % + 17,2 % de prélèvements sociaux.",
         "Disponible à tout moment"),
        ("PEA", "=Ob_EffortAnnuel", "=0",
         "Après 5 ans : exonération d'IR, 17,2 % de prélèvements sociaux sur les gains.",
         "Disponible (retrait avant 5 ans = clôture)"),
        ("Immobilier locatif / SCPI", "=Ob_EffortAnnuel", "=0",
         "Revenus fonciers au barème + prélèvements sociaux ; plus-value immobilière à la revente.",
         "Faible (revente longue, SCPI peu liquides)"),
    ]
    re_deb = r
    for nom_env, versement, economie, sortie, dispo in enveloppes:
        lab(ws, "B{}".format(r), nom_env, bold=True)
        ws["B{}".format(r)].border = BOX
        calc(ws, "C{}".format(r), versement, fmt=F_EUR, align="center")
        calc(ws, "D{}".format(r), economie, fmt=F_EUR, align="center")
        calc(ws, "E{}".format(r), "=C{r}-D{r}".format(r=r), fmt=F_EUR, align="center", bold=True)
        for col, txt in [("F", sortie), ("H", dispo)]:
            c = lab(ws, "{}{}".format(col, r), txt, size=8)
            c.alignment = Alignment(wrap_text=True, vertical="center")
            c.border = BOX
            ws.merge_cells("{c}{r}:{f}{r}".format(c=col, r=r, f=chr(ord(col) + 1)))
        for col in "CDE":
            ws["{}{}".format(col, r)].border = BOX
        ws.row_dimensions[r].height = 54
        r += 1
    r += 1
    note(ws, "B{}".format(r), "L'économie d'impôt du PER est un DIFFÉRÉ d'imposition, pas un gain définitif : "
                              "les versements déduits sont réimposés à la sortie. L'arbitrage dépend de l'écart "
                              "entre la TMI d'aujourd'hui et celle attendue à la retraite.")
    r += 2

    # ------------------------------------------------------------------ 7 ---
    section(ws, r, "7.  SENSIBILITÉ À L'ÂGE DE DÉPART", ncols=9)
    r += 1
    lab(ws, "B{}".format(r), "Effet d'un report du départ sur l'effort d'épargne, à objectif de revenu inchangé.",
        italic=True, size=9)
    r += 1
    entetes(ws, r, 2, ["", "", "62 ans", "63 ans", "64 ans", "65 ans", "66 ans", "67 ans"])
    r += 1
    sc = ["D", "E", "F", "G", "H", "I"]
    srows = {}

    def ligne_sens(cle, libelle, gabarit, fmt=None, fort=False):
        nonlocal r
        lab(ws, "B{}".format(r), libelle, bold=fort, italic=not fort)
        for i, c in enumerate(sc):
            f = gabarit.format(c=c, i=i + 1, **srows)
            if fort:
                resultat(ws, "{}{}".format(c, r), f, fmt=fmt)
            else:
                cell = calc(ws, "{}{}".format(c, r), f, fmt=fmt, align="center")
                cell.border = BOX
        srows[cle] = r
        r += 1

    ligne_sens("age", "Âge de départ", "=INDEX(Rt_ScenAges,{i})", F_DEC)
    ligne_sens("possible", "Départ possible au regard de l'âge légal ?",
               '=IF({c}${age}<Rt_AgeLegal,"NON","Oui")')
    ligne_sens("pens", "Pension nette mensuelle estimée", "=INDEX(Rt_ScenPensionNetteMens,{i})", F_EUR)
    ligne_sens("ecart", "Écart mensuel à combler",
               "=MAX(0,Ob_Objectif-{c}${pens}-Ob_AutresRevenus)", F_EUR)
    ligne_sens("duree", "Durée de restitution (années)", "=MAX(0,EsperanceVie-{c}${age})", F_DEC)
    ligne_sens("capital", "Capital nécessaire au départ",
               "=IF({c}${ecart}=0,0,IF(ABS(Ob_TauxReelRestit)<0.000001,{c}${ecart}*12*{c}${duree},"
               "{c}${ecart}*12*(1-(1+Ob_TauxReelRestit)^-{c}${duree})/Ob_TauxReelRestit))", F_EUR)
    ligne_sens("mois", "Mois de constitution restants",
               "=MAX(0,({c}${age}-Rt_AgeActuel)*12)", F_INT)
    ligne_sens("projete", "Capital projeté au départ",
               "=Ob_EpargneActuelle*(1+Ob_TauxMensuel)^{c}${mois}"
               "+IF({c}${mois}=0,0,Ob_VersementsActuels*((1+Ob_TauxMensuel)^{c}${mois}-1)/Ob_TauxMensuel)", F_EUR)
    ligne_sens("manquant", "Capital restant à constituer",
               "=MAX(0,{c}${capital}-{c}${projete})", F_EUR)
    ligne_sens("effort", "EFFORT MENSUEL NÉCESSAIRE",
               "=IF({c}${mois}<=0,0,{c}${manquant}*Ob_TauxMensuel/((1+Ob_TauxMensuel)^{c}${mois}-1))",
               F_EUR, fort=True)
    r += 1

    section(ws, r, "8.  SENSIBILITÉ AU RENDEMENT RÉEL DE L'ÉPARGNE", ncols=9)
    r += 1
    entetes(ws, r, 2, ["Rendement réel net annuel", "", "0,0 %", "1,0 %", "2,0 %", "3,0 %", "4,0 %", "5,0 %"])
    r += 1
    lab(ws, "B{}".format(r), "Effort mensuel nécessaire", bold=True)
    for i, c in enumerate(sc):
        taux = i / 100.0
        tm = "((1+{t})^(1/12)-1)".format(t=taux if taux else 0.0000001)
        resultat(ws, "{}{}".format(c, r),
                 "=IF(Ob_MoisRestants<=0,0,MAX(0,Ob_CapitalNecessaire-Ob_EpargneActuelle*(1+{tm})^Ob_MoisRestants"
                 "-Ob_VersementsActuels*((1+{tm})^Ob_MoisRestants-1)/{tm})"
                 "*{tm}/((1+{tm})^Ob_MoisRestants-1))".format(tm=tm), fmt=F_EUR)
    r += 2

    note(ws, "B{}".format(r), "Hypothèses de rendement non contractuelles, hors frais d'entrée et d'arbitrage. "
                              "Ce document ne constitue ni un conseil en investissement, ni une garantie de résultat.")

    ws.sheet_properties.tabColor = "1F7A4D"
    return ws
