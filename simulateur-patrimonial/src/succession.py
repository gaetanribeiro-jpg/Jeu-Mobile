# -*- coding: utf-8 -*-
"""Feuilles « Devolution » et « Droits_Succession ».

Devolution      : qui hérite, et pour quelle quote-part (Code civil).
Droits_Succession : combien chaque héritier paie (CGI), et comparatif des
                  options ouvertes au conjoint survivant.
"""

from .styles import *

SH_DEV = "Devolution"
SH_DRT = "Droits_Succession"

OPT_QUART = "1/4 en pleine propriété (option légale)"
OPT_US = "100 % en usufruit (option légale)"
OPT_DDV_MIXTE = "DDV - 1/4 en PP + 3/4 en usufruit"
OPT_DDV_QD = "DDV - Quotité disponible en pleine propriété"
OPT_AUCUNE = "Aucune (conjoint renonçant ou non héritier)"
OPTIONS = [OPT_QUART, OPT_US, OPT_DDV_MIXTE, OPT_DDV_QD, OPT_AUCUNE]

NB_ENF = 8
NB_PAR = 2
NB_FRE = 4
NB_LEG = 4
NB_HER = 1 + NB_ENF + NB_PAR + NB_FRE + NB_LEG + 1   # 20 lignes

LIENS_SRC = "AbatLien"


# ===========================================================================
#  FEUILLE DEVOLUTION
# ===========================================================================
def construire_devolution(wb):
    ws = wb.create_sheet(SH_DEV)
    largeurs(ws, {"A": 2, "B": 40, "C": 30, "D": 13, "E": 13, "F": 13, "G": 13,
                  "H": 17, "I": 17, "J": 17, "K": 19, "L": 12, "M": 4, "N": 60})
    mise_en_page(ws, zoom=90, freeze="A5", ncols=12)
    col_notes(ws, "N")

    titre(ws, 1, "DÉVOLUTION SUCCESSORALE — QUI HÉRITE, ET DE COMBIEN ?", ncols=12,
          sous_titre="Application des règles de dévolution légale du Code civil à la situation familiale "
                     "saisie sur la feuille « Client » et à la masse calculée sur la feuille « Patrimoine ».")

    r = 4
    section(ws, r, "1.  SITUATION SUCCESSORALE (reprise automatique)", ncols=12)
    r += 1
    for libelle, formule, nom, fmt in [
        ("Défunt simulé", "=NomDefunt", None, None),
        ("Conjoint survivant", "=NomSurvivant", None, None),
        ("Masse civile à partager (actif net successoral)", "=MasseCivile", None, F_EUR),
        ("Le conjoint est-il héritier légal ?", '=IF(SitMat="Marié(e)","Oui","Non — seul le mariage confère la qualité d\'héritier")', None, None),
        ("Nombre d'enfants héritiers du défunt", '=IF(Defunt="Client",NbEnfClient,NbEnfConjoint)', "NbEnfDefunt", F_INT),
        ("  dont enfants NON communs au couple", '=IF(Defunt="Client",NbEnfPropClient,NbEnfPropConjoint)', "NbEnfNonCommuns", F_INT),
        ("Ascendants privilégiés survivants (père / mère)", '=IF(Defunt="Client",NbParentsClient,NbParentsConjoint)', "NbParentsDefunt", F_INT),
        ("Frères et sœurs vivants", '=IF(Defunt="Client",NbFreresClient,NbFreresConjoint)', "NbFreresDefunt", F_INT),
        ("Donation au dernier vivant en place", "=DDV", None, None),
    ]:
        lab(ws, "B{}".format(r), libelle)
        link(ws, "C{}".format(r), formule, fmt=fmt, align="center" if fmt else "left")
        if nom:
            dn(wb, nom, SH_DEV, A("C", r))
        r += 1
    lab(ws, "B{}".format(r), "Conjoint survivant retenu dans la dévolution (1 = oui)", italic=True)
    calc(ws, "C{}".format(r), '=IF(SitMat="Marié(e)",1,0)', fmt=F_INT, align="center")
    dn(wb, "ConjHeritier", SH_DEV, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Cas de dévolution applicable", bold=True)
    calc(ws, "C{}".format(r),
         '=IF(NbEnfDefunt>0,'
         'IF(ConjEffectif=1,"Descendants + conjoint survivant — art. 757 C. civ.",'
         '"Descendants seuls — art. 734 et 735 C. civ."),'
         'IF(ConjEffectif=1,'
         'IF(NbParentsDefunt>0,"Conjoint + ascendants privilégiés — art. 757-1 C. civ.",'
         '"Conjoint seul — art. 757-2 C. civ."),'
         'IF(OR(NbParentsDefunt>0,NbFreresDefunt>0),'
         '"Ascendants et/ou collatéraux privilégiés — art. 738 C. civ.",'
         '"Ordres subséquents (ascendants ou collatéraux ordinaires) ou déshérence")))',
         bold=True)
    r += 1
    note(ws, "B{}".format(r), "Art. 757-3 C. civ. : en l'absence de descendant et d'ascendant, les frères et sœurs "
                              "reprennent la moitié des biens que le défunt avait reçus de ses parents par succession "
                              "ou donation (droit de retour) — cas particulier non automatisé ici.")
    r += 2

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  OPTION DU CONJOINT SURVIVANT", ncols=12)
    r += 1
    lab(ws, "B{}".format(r), "Option retenue par le conjoint", bold=True)
    inp(ws, "C{}".format(r), OPT_QUART, align="left")
    dv_liste(ws, "C{}".format(r), OPTIONS)
    dn(wb, "OptionConjoint", SH_DEV, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Conjoint effectivement héritier (1 = oui)", italic=True)
    calc(ws, "C{}".format(r), '=IF(OR(ConjHeritier=0,OptionConjoint="{}"),0,1)'.format(OPT_AUCUNE),
         fmt=F_INT, align="center")
    dn(wb, "ConjEffectif", SH_DEV, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Contrôle de cohérence")
    alerte(ws, "C{}".format(r),
           '=IF(ConjHeritier=0,"Aucun conjoint survivant héritier : l\'option est sans objet.",'
           'IF(AND(NbEnfNonCommuns>0,DDV="Non",OptionConjoint<>"{q}",OptionConjoint<>"{a}"),'
           '"⚠️ En présence d\'un enfant non commun et SANS donation au dernier vivant, le conjoint ne peut opter que pour le 1/4 en pleine propriété (art. 757 C. civ.).",'
           'IF(AND(LEFT(OptionConjoint,3)="DDV",DDV="Non"),'
           '"⚠️ Option issue d\'une donation au dernier vivant alors qu\'aucune DDV n\'est déclarée sur la feuille Client.",'
           '"✅ Option cohérente avec la situation familiale déclarée.")))'.format(q=OPT_QUART, a=OPT_AUCUNE))
    ws.row_dimensions[r].height = 30
    r += 2
    lab(ws, "B{}".format(r), "Réserve héréditaire globale (art. 913 C. civ.)")
    calc(ws, "C{}".format(r), "=1-QD", fmt=F_PCT, align="center")
    dn(wb, "Reserve", SH_DEV, A("C", r))
    calc(ws, "D{}".format(r), "=Reserve*MasseCivile", fmt=F_EUR, align="right")
    r += 1
    lab(ws, "B{}".format(r), "Quotité disponible ordinaire")
    calc(ws, "C{}".format(r),
         "=IF(NbEnfDefunt=1,1/2,IF(NbEnfDefunt=2,1/3,IF(NbEnfDefunt>=3,1/4,IF(ConjHeritier=1,3/4,1))))",
         fmt=F_PCT, align="center",
         comment="1 enfant : 1/2 — 2 enfants : 1/3 — 3 enfants et plus : 1/4. "
                 "Sans descendant mais avec conjoint : réserve du conjoint de 1/4 (art. 914-1 C. civ.).")
    dn(wb, "QD", SH_DEV, A("C", r))
    calc(ws, "D{}".format(r), "=QD*MasseCivile", fmt=F_EUR, align="right")
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  QUOTITÉS THÉORIQUES CALCULÉES", ncols=12)
    r += 1
    quotites = [
        ("Conjoint — pleine propriété", "Q_ConjPP",
         '=IF(ConjEffectif=0,0,IF(NbEnfDefunt>0,'
         'IF(OptionConjoint="{us}",0,IF(OptionConjoint="{mixte}",0.25,IF(OptionConjoint="{qd}",QD,0.25))),'
         'IF(NbParentsDefunt=2,0.5,IF(NbParentsDefunt=1,0.75,1))))'.format(
             us=OPT_US, mixte=OPT_DDV_MIXTE, qd=OPT_DDV_QD)),
        ("Conjoint — usufruit", "Q_ConjUS",
         '=IF(ConjEffectif=0,0,IF(NbEnfDefunt>0,'
         'IF(OptionConjoint="{us}",1,IF(OptionConjoint="{mixte}",0.75,0)),0))'.format(
             us=OPT_US, mixte=OPT_DDV_MIXTE)),
        ("Enfants — pleine propriété (globalement)", "Q_EnfPP",
         "=IF(NbEnfDefunt=0,0,MAX(0,1-Q_ConjPP-Q_ConjUS))"),
        ("Enfants — nue-propriété (globalement)", "Q_EnfNP",
         "=IF(NbEnfDefunt=0,0,Q_ConjUS)"),
        ("Ascendants privilégiés (globalement)", "Q_Parents",
         "=IF(NbEnfDefunt>0,0,IF(ConjEffectif=1,MAX(0,1-Q_ConjPP),"
         "IF(NbFreresDefunt>0,NbParentsDefunt*0.25,IF(NbParentsDefunt>0,1,0))))"),
        ("Frères et sœurs (globalement)", "Q_Freres",
         "=IF(OR(NbEnfDefunt>0,ConjEffectif=1,NbFreresDefunt=0),0,MAX(0,1-NbParentsDefunt*0.25))"),
        ("Autres héritiers / État", "Q_Autres",
         "=MAX(0,1-Q_ConjPP-Q_ConjUS-Q_EnfPP-Q_Parents-Q_Freres)"),
    ]
    for libelle, nom, formule in quotites:
        lab(ws, "B{}".format(r), libelle)
        calc(ws, "C{}".format(r), formule, fmt=F_PCT, align="center")
        dn(wb, nom, SH_DEV, A("C", r))
        r += 1
    lab(ws, "B{}".format(r), "CONTRÔLE — total des quotités (doit valoir 100 %)", bold=True)
    total(ws, "C{}".format(r), "=Q_ConjPP+Q_ConjUS+Q_EnfPP+Q_Parents+Q_Freres+Q_Autres",
          fmt=F_PCT, align="center")
    r += 1
    calc(ws, "B{}".format(r),
         '=IF(NbFreresDefunt>4,"⚠️ Plus de 4 frères et sœurs déclarés : le tableau ci-dessous n\'en affiche que 4. '
         'Ajoutez des lignes et étendez les plages nommées.","")')
    ws["B{}".format(r)].font = Font(name=POLICE, size=9, bold=True, color=C_WARN)
    r += 2

    # ------------------------------------------------------------------ 4 ---
    section(ws, r, "4.  LEGS PARTICULIERS (testament) — prélevés en priorité sur la quotité disponible", ncols=12)
    r += 1
    entetes(ws, r, 2, ["Bénéficiaire du legs", "Lien de parenté avec le défunt",
                       "Montant du legs (€)", "", "", "", "", "", "", ""])
    r += 1
    rl = r
    for i in range(NB_LEG):
        inp(ws, "B{}".format(r), None)
        inp(ws, "C{}".format(r), None, align="center")
        inp(ws, "D{}".format(r), None, fmt=F_EUR, align="right")
        r += 1
    rl_fin = r - 1
    dv_liste(ws, "C{}:C{}".format(rl, rl_fin), source=LIENS_SRC)
    dn(wb, "LegsBenef", SH_DEV, "$B${}:$B${}".format(rl, rl_fin))
    dn(wb, "LegsLien", SH_DEV, "$C${}:$C${}".format(rl, rl_fin))
    dn(wb, "LegsMontant", SH_DEV, "$D${}:$D${}".format(rl, rl_fin))
    lab(ws, "B{}".format(r), "TOTAL DES LEGS", bold=True)
    total(ws, "D{}".format(r), "=SUM(D{}:D{})".format(rl, rl_fin), fmt=F_EUR, align="right")
    dn(wb, "TotalLegs", SH_DEV, A("D", r))
    r += 1
    lab(ws, "B{}".format(r), "Contrôle de la réserve héréditaire")
    alerte(ws, "C{}".format(r),
           '=IF(TotalLegs=0,"Aucun legs saisi.",'
           'IF(TotalLegs<=QD*MasseCivile,"✅ Les legs restent dans la quotité disponible.",'
           '"⚠️ Les legs excèdent la quotité disponible : ils seront réductibles à la demande des héritiers réservataires (art. 920 C. civ.)."))')
    ws.row_dimensions[r].height = 28
    r += 1
    lab(ws, "B{}".format(r), "MASSE RESTANT À PARTAGER ENTRE LES HÉRITIERS LÉGAUX", bold=True)
    resultat(ws, "D{}".format(r), "=MAX(0,MasseCivile-TotalLegs)", fmt=F_EUR)
    dn(wb, "MasseDevolution", SH_DEV, A("D", r))
    r += 2

    # ------------------------------------------------------------------ 5 ---
    section(ws, r, "5.  TABLEAU DE DÉVOLUTION", ncols=12)
    r += 1
    entetes(ws, r, 2, ["Héritier", "Lien de parenté", "Héritier ?",
                       "Quote-part en PP", "Quote-part en US", "Quote-part en NP",
                       "Valeur en pleine propriété (€)", "Valeur de l'usufruit (€)",
                       "Valeur de la nue-propriété (€)", "VALEUR FISCALE REÇUE (€)",
                       "Handicap"])
    r += 1
    rh = r

    def _ligne(nom_f, lien_f, present_f, pp_f, us_f, np_f, handicap_f, pp_valeur=None):
        nonlocal r
        link(ws, "B{}".format(r), nom_f)
        link(ws, "C{}".format(r), lien_f)
        calc(ws, "D{}".format(r), present_f, fmt=F_INT, align="center")
        calc(ws, "E{}".format(r), pp_f, fmt=F_PCT2, align="center")
        calc(ws, "F{}".format(r), us_f, fmt=F_PCT2, align="center")
        calc(ws, "G{}".format(r), np_f, fmt=F_PCT2, align="center")
        calc(ws, "H{}".format(r), pp_valeur or "=MasseDevolution*E{}".format(r), fmt=F_EUR, align="right")
        calc(ws, "I{}".format(r), "=MasseDevolution*F{}*TauxUsufruit".format(r), fmt=F_EUR, align="right")
        calc(ws, "J{}".format(r), "=MasseDevolution*G{}*(1-TauxUsufruit)".format(r), fmt=F_EUR, align="right")
        total(ws, "K{}".format(r), "=H{r}+I{r}+J{r}".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "L{}".format(r), handicap_f, align="center")
        for col in "BCDEFGHIJL":
            ws["{}{}".format(col, r)].border = BOX
        r += 1

    # 1 — conjoint
    _ligne("=NomSurvivant", '="Conjoint survivant"', "=ConjEffectif",
           "=Q_ConjPP*D{}".format(r), "=Q_ConjUS*D{}".format(r), "0", '="Non"')
    # 2..9 — enfants
    for i in range(1, NB_ENF + 1):
        _ligne('=IF(INDEX(EnfPrenom,{i})="","",INDEX(EnfPrenom,{i}))'.format(i=i),
               '=IF(D{r}=1,"Enfant","")'.format(r=r),
               '=IF(AND(INDEX(EnfVivant,{i})="Oui",OR(INDEX(EnfFiliation,{i})="Commun au couple",'
               'INDEX(EnfFiliation,{i})=IF(Defunt="Client","Du client uniquement","Du conjoint uniquement"))),1,0)'.format(i=i),
               "=IF(NbEnfDefunt=0,0,Q_EnfPP/NbEnfDefunt)*D{}".format(r),
               "0",
               "=IF(NbEnfDefunt=0,0,Q_EnfNP/NbEnfDefunt)*D{}".format(r),
               '=IF(INDEX(EnfHandicap,{i})="Oui","Oui","Non")'.format(i=i))
    # 10..11 — ascendants
    for k in range(1, NB_PAR + 1):
        _ligne('="Ascendant privilégié n° {k} (père / mère)"'.format(k=k),
               '=IF(D{r}=1,"Ascendant (père / mère)","")'.format(r=r),
               "=IF(AND(NbParentsDefunt>={k},Q_Parents>0),1,0)".format(k=k),
               "=IF(NbParentsDefunt=0,0,Q_Parents/NbParentsDefunt)*D{}".format(r),
               "0", "0", '="Non"')
    # 12..15 — frères et sœurs
    for k in range(1, NB_FRE + 1):
        _ligne('="Frère / sœur n° {k}"'.format(k=k),
               '=IF(D{r}=1,"Frère / Sœur","")'.format(r=r),
               "=IF(AND(NbFreresDefunt>={k},Q_Freres>0),1,0)".format(k=k),
               "=IF(NbFreresDefunt=0,0,Q_Freres/MAX(NbFreresDefunt,1))*D{}".format(r),
               "0", "0", '="Non"')
    # 16..19 — légataires
    for k in range(1, NB_LEG + 1):
        _ligne('=IF(INDEX(LegsBenef,{k})="","",INDEX(LegsBenef,{k}))'.format(k=k),
               '=IF(INDEX(LegsMontant,{k})>0,INDEX(LegsLien,{k}),"")'.format(k=k),
               "=IF(INDEX(LegsMontant,{k})>0,1,0)".format(k=k),
               "0", "0", "0", '="Non"',
               pp_valeur="=INDEX(LegsMontant,{k})".format(k=k))
    # 20 — autres héritiers
    lien_autres_row = r
    link(ws, "B{}".format(r), '="Autres héritiers (ordres 3 et 4) ou État"')
    inp(ws, "C{}".format(r), "Oncle / Tante / Cousin germain", align="center")
    dv_liste(ws, "C{}".format(r), source=LIENS_SRC)
    calc(ws, "D{}".format(r), "=IF(Q_Autres>0,1,0)", fmt=F_INT, align="center")
    calc(ws, "E{}".format(r), "=Q_Autres", fmt=F_PCT2, align="center")
    calc(ws, "F{}".format(r), "0", fmt=F_PCT2, align="center")
    calc(ws, "G{}".format(r), "0", fmt=F_PCT2, align="center")
    calc(ws, "H{}".format(r), "=MasseDevolution*E{}".format(r), fmt=F_EUR, align="right")
    calc(ws, "I{}".format(r), "0", fmt=F_EUR, align="right")
    calc(ws, "J{}".format(r), "0", fmt=F_EUR, align="right")
    total(ws, "K{}".format(r), "=H{r}+I{r}+J{r}".format(r=r), fmt=F_EUR, align="right")
    calc(ws, "L{}".format(r), '="Non"', align="center")
    for col in "BCDEFGHIJL":
        ws["{}{}".format(col, r)].border = BOX
    r += 1
    rh_fin = r - 1

    dn(wb, "HerNom", SH_DEV, "$B${}:$B${}".format(rh, rh_fin))
    dn(wb, "HerLien", SH_DEV, "$C${}:$C${}".format(rh, rh_fin))
    dn(wb, "HerPresent", SH_DEV, "$D${}:$D${}".format(rh, rh_fin))
    dn(wb, "HerValeur", SH_DEV, "$K${}:$K${}".format(rh, rh_fin))
    dn(wb, "HerHandicap", SH_DEV, "$L${}:$L${}".format(rh, rh_fin))

    lab(ws, "B{}".format(r), "TOTAL RÉPARTI", bold=True)
    total(ws, "H{}".format(r), "=SUM(H{}:H{})".format(rh, rh_fin), fmt=F_EUR, align="right")
    total(ws, "I{}".format(r), "=SUM(I{}:I{})".format(rh, rh_fin), fmt=F_EUR, align="right")
    total(ws, "J{}".format(r), "=SUM(J{}:J{})".format(rh, rh_fin), fmt=F_EUR, align="right")
    total(ws, "K{}".format(r), "=SUM(K{}:K{})".format(rh, rh_fin), fmt=F_EUR, align="right")
    r += 1
    lab(ws, "B{}".format(r), "CONTRÔLE — écart avec la masse civile", italic=True)
    calc(ws, "K{}".format(r), "=K{}-MasseCivile".format(r - 1), fmt=F_EUR, align="right", bold=True)
    r += 1
    note(ws, "B{}".format(r),
         "L'usufruit et la nue-propriété sont valorisés selon l'article 669 du CGI, d'après l'âge du conjoint "
         "survivant retenu sur la feuille « Patrimoine ». Au décès de l'usufruitier, la réunion de l'usufruit "
         "à la nue-propriété se fait EN FRANCHISE DE DROITS (art. 1133 CGI).")
    r += 1
    note(ws, "B{}".format(r),
         "Simplifications assumées : pas de représentation automatique des petits-enfants, pas de fente "
         "successorale entre branches paternelle et maternelle, pas de rapport civil des donations, "
         "pas de récompenses entre patrimoines propres et commun.")

    ws.sheet_properties.tabColor = "C55A11"
    return ws


# ===========================================================================
#  FEUILLE DROITS DE SUCCESSION
# ===========================================================================
def construire_droits(wb):
    ws = wb.create_sheet(SH_DRT)
    largeurs(ws, {"A": 2, "B": 34, "C": 26, "D": 16, "E": 16, "F": 15, "G": 16,
                  "H": 15, "I": 13, "J": 15, "K": 15, "L": 16, "M": 22, "N": 16,
                  "O": 11, "P": 16, "Q": 4, "R": 55})
    mise_en_page(ws, zoom=85, freeze="C8", ncols=16)
    col_notes(ws, "R")

    titre(ws, 1, "DROITS DE SUCCESSION — LIQUIDATION PAR HÉRITIER", ncols=16,
          sous_titre="Abattements personnels (art. 779 et 788 CGI), rappel fiscal des donations de moins de "
                     "15 ans et barème progressif de l'article 777 du CGI.")

    r = 4
    section(ws, r, "1.  RAPPEL DES ASSIETTES", ncols=16)
    r += 1
    for libelle, formule, fmt in [
        ("Masse civile partagée", "=MasseCivile", F_EUR),
        ("Assiette taxable après abattement résidence principale", "=MasseFiscale", F_EUR),
        ("Coefficient de passage civil → fiscal", "=CoefFiscal", F_PCT2),
    ]:
        lab(ws, "B{}".format(r), libelle)
        link(ws, "C{}".format(r), formule, fmt=fmt, align="right")
        r += 1
    r += 1

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  LIQUIDATION DES DROITS, HÉRITIER PAR HÉRITIER", ncols=16)
    r += 1
    entetes(ws, r, 2, ["Héritier", "Lien de parenté", "Part reçue — valeur civile (€)",
                       "Assiette fiscale de la part (€)", "Primes d'assurance-vie art. 757 B (€)",
                       "Base avant abattement (€)", "Abattement personnel (€)",
                       "Abattement handicap (€)", "− consommé par donations (€)", "Abattement net (€)",
                       "BASE TAXABLE (€)", "Catégorie de barème", "DROITS DE SUCCESSION (€)",
                       "Taux moyen", "Net perçu de la succession (€)"])
    r += 1
    rd = r
    for k in range(1, NB_HER + 1):
        link(ws, "B{}".format(r), '=IF(INDEX(HerNom,{k})="","",INDEX(HerNom,{k}))'.format(k=k))
        link(ws, "C{}".format(r), '=IF(INDEX(HerPresent,{k})=1,INDEX(HerLien,{k}),"")'.format(k=k))
        link(ws, "D{}".format(r), "=INDEX(HerValeur,{k})".format(k=k), fmt=F_EUR, align="right")
        calc(ws, "E{}".format(r), "=D{}*CoefFiscal".format(r), fmt=F_EUR, align="right")
        calc(ws, "F{}".format(r), '=IF(B{r}="",0,SUMIFS(AV_Taxable757,AV_BenefNom,B{r}))'.format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "G{}".format(r), "=E{r}+F{r}".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "H{}".format(r),
             '=IF(G{r}=0,0,IFERROR(INDEX(AbatMontant,MATCH(C{r},AbatLien,0)),0))'.format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "I{}".format(r),
             '=IF(AND(G{r}>0,INDEX(HerHandicap,{k})="Oui"),AbatHandicap,0)'.format(r=r, k=k),
             fmt=F_EUR, align="right")
        calc(ws, "J{}".format(r), '=IF(B{r}="",0,SUMIFS(DonAbatConso,DonNom,B{r}))'.format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "K{}".format(r), "=MAX(0,H{r}+I{r}-J{r})".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "L{}".format(r), "=MAX(0,G{r}-K{r})".format(r=r), fmt=F_EUR, align="right", bold=True)
        calc(ws, "M{}".format(r),
             '=IF(C{r}="","",IFERROR(INDEX(AbatCat,MATCH(C{r},AbatLien,0)),"Autres"))'.format(r=r),
             align="center")
        calc(ws, "N{}".format(r),
             '=IF(OR(M{r}="",M{r}="Exonéré"),0,'
             'SUMPRODUCT((BarCat=M{r})*(L{r}>BarSeuil)*(L{r}-BarSeuil)*(BarTaux-BarPrev)))'.format(r=r),
             fmt=F_EUR, align="right", bold=True)
        calc(ws, "O{}".format(r), "=IF(D{r}+F{r}=0,0,N{r}/(D{r}+F{r}))".format(r=r), fmt=F_PCT, align="center")
        calc(ws, "P{}".format(r), "=D{r}-N{r}".format(r=r), fmt=F_EUR, align="right")
        for col in "BCDEFGHIJKLMNOP":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    rd_fin = r - 1
    dn(wb, "DrAbatNet", SH_DRT, "$K${}:$K${}".format(rd, rd_fin))
    dn(wb, "DrBaseAvantAbat", SH_DRT, "$G${}:$G${}".format(rd, rd_fin))
    dn(wb, "DrDroits", SH_DRT, "$N${}:$N${}".format(rd, rd_fin))
    dn(wb, "DrNom", SH_DRT, "$B${}:$B${}".format(rd, rd_fin))

    lab(ws, "B{}".format(r), "TOTAUX", bold=True)
    for col in "DEFLP":
        total(ws, "{}{}".format(col, r), "=SUM({c}{a}:{c}{b})".format(c=col, a=rd, b=rd_fin),
              fmt=F_EUR, align="right")
    resultat(ws, "N{}".format(r), "=SUM(N{}:N{})".format(rd, rd_fin), fmt=F_EUR)
    dn(wb, "TotalDroits", SH_DRT, A("N", r))
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  SYNTHÈSE DU COÛT DE LA TRANSMISSION", ncols=16)
    r += 1
    for libelle, formule, nom, fmt, fort in [
        ("Droits de succession dus (hors assurance-vie art. 990 I)", "=TotalDroits", None, F_EUR, True),
        ("Prélèvement sur l'assurance-vie (art. 990 I)", "=AV_Prelevement990", None, F_EUR, False),
        ("COÛT TOTAL DE LA TRANSMISSION", "=TotalDroits+AV_Prelevement990", "CoutTransmission", F_EUR, True),
        ("Patrimoine transmis (succession + assurance-vie)", "=MasseCivile+AV_CapitalTotal", "PatrimoineTransmis", F_EUR, False),
        ("Taux de frottement fiscal global", "=IF(PatrimoineTransmis=0,0,CoutTransmission/PatrimoineTransmis)",
         "TauxFrottement", F_PCT, True),
    ]:
        lab(ws, "B{}".format(r), libelle, bold=fort)
        if fort:
            resultat(ws, "D{}".format(r), formule, fmt=fmt)
        else:
            link(ws, "D{}".format(r), formule, fmt=fmt, align="right")
            ws["D{}".format(r)].border = BOX
        if nom:
            dn(wb, nom, SH_DRT, A("D", r))
        r += 1
    r += 1

    # ------------------------------------------------------------------ 4 ---
    section(ws, r, "4.  COMPARATIF DES OPTIONS DU CONJOINT — IMPACT SUR LES DROITS DES ENFANTS", ncols=16)
    r += 1
    lab(ws, "B{}".format(r),
        "À situation patrimoniale identique, le choix du conjoint entre pleine propriété et usufruit change "
        "la base taxable des enfants. Le comparatif ci-dessous recalcule les droits pour chacune des options.",
        italic=True, size=9)
    r += 1
    entetes(ws, r, 2, ["Enfant", "Abattement net disponible (€)",
                       "Option A — conjoint 1/4 en PP", "", "Option B — conjoint 100 % en usufruit", "",
                       "Option C — conjoint 1/4 PP + 3/4 US", ""])
    r += 1
    entetes(ws, r, 4, ["Part taxable (€)", "Droits (€)", "Part taxable (€)", "Droits (€)",
                       "Part taxable (€)", "Droits (€)"])
    r += 1
    rc = r
    for i in range(1, NB_ENF + 1):
        her_idx = 1 + i  # ligne de l'enfant dans le tableau de dévolution
        droits_idx = rd + her_idx - 1
        link(ws, "B{}".format(r), '=IF(INDEX(HerNom,{k})="","",INDEX(HerNom,{k}))'.format(k=her_idx))
        link(ws, "C{}".format(r), "=K{}".format(droits_idx), fmt=F_EUR, align="right")
        # coefficients de part fiscale par option
        coefs = {"D": "0.75",
                 "F": "(1-TauxUsufruit)",
                 "H": "0.75*(1-TauxUsufruit)"}
        for col, coef in coefs.items():
            calc(ws, "{}{}".format(col, r),
                 "=IF(OR(NbEnfDefunt=0,INDEX(HerPresent,{k})=0),0,"
                 "MasseDevolution*CoefFiscal*{c}/NbEnfDefunt)".format(k=her_idx, c=coef),
                 fmt=F_EUR, align="right")
            col_d = chr(ord(col) + 1)
            calc(ws, "{}{}".format(col_d, r),
                 '=SUMPRODUCT((BarCat="Ligne directe")*(MAX(0,{c}{r}-C{r})>BarSeuil)'
                 "*(MAX(0,{c}{r}-C{r})-BarSeuil)*(BarTaux-BarPrev))".format(c=col, r=r),
                 fmt=F_EUR, align="right")
        for col in "BCDEFGHI":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    rc_fin = r - 1
    lab(ws, "B{}".format(r), "TOTAL DES DROITS PAYÉS PAR LES ENFANTS", bold=True)
    for col in "EGI":
        resultat(ws, "{}{}".format(col, r), "=SUM({c}{a}:{c}{b})".format(c=col, a=rc, b=rc_fin), fmt=F_EUR)
    dn(wb, "CmpOptionA", SH_DRT, A("E", r))
    dn(wb, "CmpOptionB", SH_DRT, A("G", r))
    dn(wb, "CmpOptionC", SH_DRT, A("I", r))
    r += 1
    lab(ws, "B{}".format(r), "Économie par rapport à l'option A", italic=True)
    calc(ws, "G{}".format(r), "=CmpOptionA-CmpOptionB", fmt=F_EUR, align="right", bold=True)
    calc(ws, "I{}".format(r), "=CmpOptionA-CmpOptionC", fmt=F_EUR, align="right", bold=True)
    r += 1
    lab(ws, "B{}".format(r), "Valeur transmise au conjoint", italic=True)
    calc(ws, "E{}".format(r), "=MasseDevolution*0.25", fmt=F_EUR, align="right")
    calc(ws, "G{}".format(r), "=MasseDevolution*TauxUsufruit", fmt=F_EUR, align="right")
    calc(ws, "I{}".format(r), "=MasseDevolution*(0.25+0.75*TauxUsufruit)", fmt=F_EUR, align="right")
    r += 2
    lab(ws, "B{}".format(r),
        "Lecture : l'usufruit protège le conjoint (il conserve la jouissance et les revenus de la totalité des biens) "
        "et réduit immédiatement la base taxable des enfants, qui ne recueillent que la nue-propriété. "
        "À l'extinction de l'usufruit, ils deviennent pleins propriétaires SANS aucun droit supplémentaire "
        "(art. 1133 CGI). En contrepartie, les enfants ne disposent pas des biens du vivant du conjoint.",
        italic=True, size=9)
    ws.row_dimensions[r].height = 30
    r += 1
    note(ws, "B{}".format(r),
         "Le comparatif suppose une DDV permettant les options B et C ; il ignore les legs et les primes "
         "d'assurance-vie soumises à l'article 757 B.")

    ws.sheet_properties.tabColor = "C55A11"
    return ws
