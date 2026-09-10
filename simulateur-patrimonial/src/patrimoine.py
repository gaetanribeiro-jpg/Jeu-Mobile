# -*- coding: utf-8 -*-
"""Feuille « Patrimoine » : inventaire actif/passif, liquidation du régime
matrimonial et détermination de la masse successorale."""

import datetime as dt
from .styles import *

SHEET = "Patrimoine"

CATEGORIES = ["Résidence principale", "Résidence secondaire", "Immobilier locatif",
              "Terrains / SCPI", "Liquidités et livrets", "Comptes-titres / PEA",
              "Parts de société / entreprise", "Biens meubles et divers",
              "Créances et autres"]
DETENTION = ["Propre - Client", "Propre - Conjoint", "Commun (communauté)",
             "Indivision - Client", "Indivision - Conjoint"]
REDEVABLE = ["Client", "Conjoint", "Commun"]

NB_ACTIFS = 18
NB_PASSIFS = 6
NB_DONS = 8

EXEMPLES_ACTIFS = [
    ("Résidence principale", "Maison — Villeurbanne", 450000, "Commun (communauté)", 1.0, 92000),
    ("Résidence secondaire", "Appartement — Annecy", 185000, "Propre - Client", 1.0, 0),
    ("Immobilier locatif", "T3 — Lyon 7e", 240000, "Commun (communauté)", 1.0, 138000),
    ("Immobilier locatif", "Studio — Grenoble (indivis avec sa sœur)", 160000, "Indivision - Client", 0.5, 0),
    ("Liquidités et livrets", "Comptes courants, Livret A, LDDS", 62000, "Commun (communauté)", 1.0, 0),
    ("Comptes-titres / PEA", "PEA — Client", 118000, "Propre - Client", 1.0, 0),
    ("Comptes-titres / PEA", "PEA — Conjoint", 45000, "Propre - Conjoint", 1.0, 0),
    ("Parts de société / entreprise", "SARL Martin Conseil (100 % des parts)", 300000, "Propre - Client", 1.0, 0),
    ("Biens meubles et divers", "Véhicules, mobilier, objets", 35000, "Commun (communauté)", 1.0, 0),
]
EXEMPLES_PASSIFS = [("Prêt à la consommation", "Banque", 12000, "Commun")]
EXEMPLES_DONS = [("Chloé", "Client", "Enfant", dt.date(2019, 6, 15), 60000),
                 ("Lucas", "Client", "Enfant", dt.date(2016, 1, 10), 30000)]


def construire(wb):
    ws = wb.create_sheet("Patrimoine")
    largeurs(ws, {"A": 2, "B": 46, "C": 38, "D": 16, "E": 24, "F": 12, "G": 16,
                  "H": 17, "I": 13, "J": 18, "K": 4, "L": 62})
    mise_en_page(ws, zoom=90, freeze="A5", ncols=10)

    titre(ws, 1, "PATRIMOINE DU FOYER ET MASSE SUCCESSORALE", ncols=10,
          sous_titre="Inventaire des biens, liquidation du régime matrimonial et détermination de l'actif "
                     "net successoral qui sera partagé dans la feuille « Devolution ».")

    r = 4
    section(ws, r, "1.  HYPOTHÈSE DE SIMULATION", ncols=10)
    r += 1
    lab(ws, "B{}".format(r), "Simulation du décès de", bold=True)
    inp(ws, "C{}".format(r), "Client", align="center")
    dv_liste(ws, "C{}".format(r), ["Client", "Conjoint"])
    dn(wb, "Defunt", SHEET, A("C", r))
    note(ws, "E{}".format(r), "Bascule l'ensemble du classeur : détention des biens, héritiers, abattements. "
                              "Faites tourner les deux scénarios pour une étude complète.")
    r += 1
    lab(ws, "B{}".format(r), "Défunt simulé", italic=True)
    link(ws, "C{}".format(r), '=IF(Defunt="Client",NomClient,NomConjoint)', align="center")
    dn(wb, "NomDefunt", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Conjoint survivant", italic=True)
    link(ws, "C{}".format(r), '=IF(Defunt="Client",NomConjoint,NomClient)', align="center")
    dn(wb, "NomSurvivant", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Âge du conjoint survivant retenu pour valoriser l'usufruit")
    inp(ws, "C{}".format(r), '=IF(Defunt="Client",AgeConjoint,AgeClient)', fmt=F_INT, align="center",
        comment="Par défaut : l'âge actuel (décès simulé aujourd'hui). Remplacez par un âge projeté "
                "pour simuler un décès plus tardif — le barème de l'article 669 du CGI en dépend directement.")
    dn(wb, "AgeUsufruitier", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Valeur fiscale de l'usufruit (art. 669 CGI)", italic=True)
    calc(ws, "C{}".format(r), "=IFERROR(INDEX(UsuUS,MATCH(AgeUsufruitier,UsuAgeMin,1)),0)",
         fmt=F_PCT, align="center")
    dn(wb, "TauxUsufruit", SHEET, A("C", r))
    calc(ws, "D{}".format(r), "=1-TauxUsufruit", fmt=F_PCT, align="center")
    lab(ws, "E{}".format(r), "← valeur de la nue-propriété", italic=True, size=8, color=C_NOTE)
    r += 2

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  ACTIF DU PATRIMOINE (hors assurance-vie, traitée sur sa propre feuille)", ncols=10)
    r += 1
    entetes(ws, r, 2, ["Catégorie", "Désignation du bien", "Valeur vénale du bien (€)",
                       "Mode de détention", "Quote-part détenue par le foyer",
                       "Capital restant dû (€)", "Valeur nette détenue (€)",
                       "% entrant dans la succession", "Quote-part successorale nette (€)"])
    r += 1
    ra = r
    for i in range(NB_ACTIFS):
        ex = EXEMPLES_ACTIFS[i] if i < len(EXEMPLES_ACTIFS) else (None, None, None, None, 1.0, None)
        inp(ws, "B{}".format(r), ex[0])
        inp(ws, "C{}".format(r), ex[1])
        inp(ws, "D{}".format(r), ex[2], fmt=F_EUR, align="right")
        inp(ws, "E{}".format(r), ex[3], align="center")
        inp(ws, "F{}".format(r), ex[4], fmt=F_PCT, align="center")
        inp(ws, "G{}".format(r), ex[5], fmt=F_EUR, align="right")
        calc(ws, "H{}".format(r), "=IFERROR(D{r}*F{r}-G{r},0)".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "I{}".format(r),
             '=IF($E{r}="Propre - Client",IF(Defunt="Client",1,0),'
             'IF($E{r}="Propre - Conjoint",IF(Defunt="Conjoint",1,0),'
             'IF($E{r}="Commun (communauté)",0.5,'
             'IF($E{r}="Indivision - Client",IF(Defunt="Client",1,0),'
             'IF($E{r}="Indivision - Conjoint",IF(Defunt="Conjoint",1,0),0)))))'.format(r=r),
             fmt=F_PCT, align="center")
        calc(ws, "J{}".format(r), "=H{r}*I{r}".format(r=r), fmt=F_EUR, align="right")
        for col in "HIJ":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    rb = r - 1
    dv_liste(ws, "B{}:B{}".format(ra, rb), CATEGORIES)
    dv_liste(ws, "E{}:E{}".format(ra, rb), DETENTION)
    dn(wb, "ActCategorie", SHEET, "$B${}:$B${}".format(ra, rb))
    dn(wb, "ActValeurNette", SHEET, "$H${}:$H${}".format(ra, rb))
    dn(wb, "ActPartSucc", SHEET, "$J${}:$J${}".format(ra, rb))
    dn(wb, "ActDetention", SHEET, "$E${}:$E${}".format(ra, rb))

    lab(ws, "B{}".format(r), "TOTAL DE L'ACTIF", bold=True)
    total(ws, "D{}".format(r), "=SUM(D{}:D{})".format(ra, rb), fmt=F_EUR, align="right")
    total(ws, "G{}".format(r), "=SUM(G{}:G{})".format(ra, rb), fmt=F_EUR, align="right")
    total(ws, "H{}".format(r), "=SUM(H{}:H{})".format(ra, rb), fmt=F_EUR, align="right")
    total(ws, "J{}".format(r), "=SUM(J{}:J{})".format(ra, rb), fmt=F_EUR, align="right")
    dn(wb, "ActifNetFoyer", SHEET, A("H", r))
    dn(wb, "ActifSuccBrut", SHEET, A("J", r))
    dn(wb, "DetteImmoFoyer", SHEET, A("G", r))
    r += 1
    note(ws, "B{}".format(r), "Quote-part détenue : laissez 100 % sauf indivision avec un tiers. "
                              "Communauté universelle avec clause d'attribution intégrale : saisissez la détention "
                              "« Propre - Conjoint » pour neutraliser la transmission.")
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  PASSIF NON ADOSSÉ À UN BIEN (dettes diverses, impôts, découverts)", ncols=10)
    r += 1
    entetes(ws, r, 2, ["Nature de la dette", "Créancier", "Montant restant dû (€)",
                       "Redevable", "", "", "", "", "Quote-part à la charge du défunt (€)"])
    r += 1
    rp = r
    for i in range(NB_PASSIFS):
        ex = EXEMPLES_PASSIFS[i] if i < len(EXEMPLES_PASSIFS) else (None, None, None, None)
        inp(ws, "B{}".format(r), ex[0])
        inp(ws, "C{}".format(r), ex[1])
        inp(ws, "D{}".format(r), ex[2], fmt=F_EUR, align="right")
        inp(ws, "E{}".format(r), ex[3], align="center")
        calc(ws, "J{}".format(r),
             '=D{r}*IF($E{r}="Client",IF(Defunt="Client",1,0),'
             'IF($E{r}="Conjoint",IF(Defunt="Conjoint",1,0),'
             'IF($E{r}="Commun",0.5,0)))'.format(r=r), fmt=F_EUR, align="right")
        ws["J{}".format(r)].border = BOX
        r += 1
    rq = r - 1
    dv_liste(ws, "E{}:E{}".format(rp, rq), REDEVABLE)
    lab(ws, "B{}".format(r), "TOTAL DU PASSIF DIVERS", bold=True)
    total(ws, "D{}".format(r), "=SUM(D{}:D{})".format(rp, rq), fmt=F_EUR, align="right")
    total(ws, "J{}".format(r), "=SUM(J{}:J{})".format(rp, rq), fmt=F_EUR, align="right")
    dn(wb, "PassifDiversFoyer", SHEET, A("D", r))
    dn(wb, "PassifDiversDefunt", SHEET, A("J", r))
    r += 2

    # ------------------------------------------------------------------ 4 ---
    section(ws, r, "4.  DÉTERMINATION DE LA MASSE SUCCESSORALE", ncols=10)
    r += 1
    lab(ws, "B{}".format(r), "Le conjoint ou un enfant occupe la résidence principale")
    inp(ws, "C{}".format(r), "Oui", align="center")
    dv_liste(ws, "C{}".format(r), ["Oui", "Non"])
    dn(wb, "OccupationRP", SHEET, A("C", r))
    note(ws, "E{}".format(r), "Condition de l'abattement de 20 % de l'article 764 bis du CGI.")
    r += 1
    lab(ws, "B{}".format(r), "Appliquer le forfait mobilier de 5 % (art. 764 CGI)")
    inp(ws, "C{}".format(r), "Non", align="center")
    dv_liste(ws, "C{}".format(r), ["Oui", "Non"])
    dn(wb, "ForfaitMobilierOn", SHEET, A("C", r))
    note(ws, "E{}".format(r), "À activer si le mobilier n'est PAS déjà inventorié dans l'actif ci-dessus. "
                              "L'exemple livré déclare le mobilier ligne à ligne : le forfait est donc désactivé.")
    r += 2

    lignes_masse = [
        ("Actif brut successoral (quote-part du défunt)", "=ActifSuccBrut", "ActifSuccBrutRef", False),
        ("Forfait mobilier de 5 % (à ajouter)", '=IF(ForfaitMobilierOn="Oui",ActifSuccBrut*ForfaitMobilier,0)',
         "ForfaitMobilierMontant", False),
        ("− Passif divers à la charge du défunt", "=-PassifDiversDefunt", None, False),
        ("− Frais funéraires (forfait art. 775 CGI)", "=-FraisFuneraires", None, False),
        ("ACTIF NET SUCCESSORAL (masse civile à partager)", None, "MasseCivile", True),
        ("− Abattement de 20 % sur la résidence principale",
         '=-IF(OccupationRP="Oui",SUMIFS(ActPartSucc,ActCategorie,"Résidence principale")*AbatRP,0)',
         "AbatRPMontant", False),
        ("ASSIETTE TAXABLE AUX DROITS DE SUCCESSION", None, "MasseFiscale", True),
    ]
    r_masse_deb = r
    for libelle, formule, nom, gras in lignes_masse:
        lab(ws, "B{}".format(r), libelle, bold=gras)
        if formule is None:
            if nom == "MasseCivile":
                formule = "=SUM(D{}:D{})".format(r_masse_deb, r - 1)
            else:  # MasseFiscale
                formule = "=D{}+D{}".format(r - 2, r - 1)
            resultat(ws, "D{}".format(r), formule, fmt=F_EUR)
        else:
            calc(ws, "D{}".format(r), formule, fmt=F_EUR, align="right")
            ws["D{}".format(r)].border = BOX
        if nom:
            dn(wb, nom, SHEET, A("D", r))
        r += 1
    lab(ws, "B{}".format(r), "Coefficient de passage masse civile → assiette fiscale", italic=True)
    calc(ws, "D{}".format(r), "=IF(MasseCivile=0,1,MasseFiscale/MasseCivile)", fmt=F_PCT2, align="right",
         comment="L'abattement de 20 % sur la résidence principale réduit l'assiette fiscale sans modifier "
                 "le partage civil. Ce coefficient applique la réduction au prorata sur la part de chaque héritier.")
    dn(wb, "CoefFiscal", SHEET, A("D", r))
    r += 2

    # ------------------------------------------------------------------ 5 ---
    section(ws, r, "5.  DONATIONS ANTÉRIEURES CONSENTIES PAR LE DÉFUNT (rappel fiscal de 15 ans)", ncols=10)
    r += 1
    entetes(ws, r, 2, ["Donataire (prénom, identique à la feuille Client)", "Donateur",
                       "Lien de parenté avec le donateur", "Date de la donation",
                       "Montant donné (€)", "Rappelable ?", "Abattement déjà consommé (€)", "", ""])
    r += 1
    rd = r
    for i in range(NB_DONS):
        ex = EXEMPLES_DONS[i] if i < len(EXEMPLES_DONS) else (None, None, None, None, None)
        inp(ws, "B{}".format(r), ex[0])
        inp(ws, "C{}".format(r), ex[1], align="center")
        inp(ws, "D{}".format(r), ex[2], align="center")
        inp(ws, "E{}".format(r), ex[3], fmt=F_DATE, align="center")
        inp(ws, "F{}".format(r), ex[4], fmt=F_EUR, align="right")
        calc(ws, "G{}".format(r),
             '=IF(OR(E{r}="",C{r}<>Defunt),"Non",'
             'IF(E{r}>=EDATE(DateSimu,-12*RappelDonations),"Oui","Non"))'.format(r=r),
             align="center")
        calc(ws, "H{}".format(r),
             '=IF(G{r}="Oui",MIN(F{r},IFERROR(INDEX(AbatMontant,MATCH(D{r},AbatLien,0)),0)),0)'.format(r=r),
             fmt=F_EUR, align="right")
        for col in "GH":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    re_ = r - 1
    dv_liste(ws, "C{}:C{}".format(rd, re_), ["Client", "Conjoint"])
    dv_liste(ws, "D{}:D{}".format(rd, re_), source="Parametres!$B$7:$B$18")
    dn(wb, "DonNom", SHEET, "$B${}:$B${}".format(rd, re_))
    dn(wb, "DonMontant", SHEET, "$F${}:$F${}".format(rd, re_))
    dn(wb, "DonAbatConso", SHEET, "$H${}:$H${}".format(rd, re_))
    lab(ws, "B{}".format(r), "TOTAL des abattements déjà consommés", bold=True)
    total(ws, "H{}".format(r), "=SUM(H{}:H{})".format(rd, re_), fmt=F_EUR, align="right")
    r += 1
    note(ws, "B{}".format(r), "Seules les donations consenties PAR LE DÉFUNT SIMULÉ sont rappelées : la colonne « Donateur » assure la bascule automatique lorsque l'on change de défunt. "
                              "Le modèle reprend la consommation de l'abattement (effet principal du rappel fiscal). "
                              "La reconstitution du barème progressif sur les donations rappelées n'est PAS modélisée : "
                              "en présence de donations importantes, les droits réels seront supérieurs à l'estimation.")
    r += 2

    # ------------------------------------------------------------------ 6 ---
    section(ws, r, "6.  SYNTHÈSE DU PATRIMOINE DU FOYER", ncols=10)
    r += 1
    for libelle, formule, nom, fort in [
        ("Actif brut (valeur vénale des biens détenus)",
         "=SUMPRODUCT(D{a}:D{b},F{a}:F{b})".format(a=ra, b=rb), "PatBrutFoyer", False),
        ("Endettement total du foyer", "=DetteImmoFoyer+PassifDiversFoyer", "DetteFoyer", False),
        ("Patrimoine net hors assurance-vie", "=PatBrutFoyer-DetteFoyer", "PatNetHorsAV", False),
        ("Capitaux d'assurance-vie (valeur de rachat)", "=AV_ValeurRachat", "PatAV", False),
        ("PATRIMOINE NET GLOBAL DU FOYER", "=PatNetHorsAV+PatAV", "PatrimoineNetGlobal", True),
    ]:
        lab(ws, "B{}".format(r), libelle, bold=fort)
        if fort:
            resultat(ws, "D{}".format(r), formule, fmt=F_EUR)
        else:
            calc(ws, "D{}".format(r), formule, fmt=F_EUR, align="right")
            ws["D{}".format(r)].border = BOX
        dn(wb, nom, SHEET, A("D", r))
        r += 1

    ws.sheet_properties.tabColor = BLEU
    return ws
