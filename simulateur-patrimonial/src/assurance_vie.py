# -*- coding: utf-8 -*-
"""Feuille « Assurance_Vie » : contrats, clauses bénéficiaires et fiscalité du
capital décès (art. 990 I et 757 B du CGI).

L'assurance-vie est hors succession civile : elle ne fait pas partie de la masse
partagée, mais elle est taxée selon ses propres règles. Les primes versées après
70 ans (art. 757 B) sont en revanche réintégrées dans l'assiette des droits de
succession du bénéficiaire, sur la feuille « Droits_Succession ».
"""

from .styles import *

SHEET = "Assurance_Vie"
NB_CONTRATS = 6
NB_CLAUSES = 14
NB_BENEF = 8

LIENS_SRC = "AbatLien"

EX_CONTRATS = [
    ("Multisupport Sérénité", "Assureur A", "Client", 520000, 520000, 330000, 0),
    ("Contrat Horizon", "Assureur B", "Conjoint", 95000, 95000, 70000, 0),
]
EX_CLAUSES = [(1, "Chloé", "Enfant", 1 / 3), (1, "Lucas", "Enfant", 1 / 3),
              (1, "Emma", "Enfant", 1 / 3), (2, "Jean", "Conjoint survivant", 1.0)]
EX_BENEF = [("Chloé", "Enfant"), ("Lucas", "Enfant"), ("Emma", "Enfant"),
            ("Sophie", "Conjoint survivant")]


def construire(wb):
    ws = wb.create_sheet(SHEET)
    largeurs(ws, {"A": 2, "B": 30, "C": 24, "D": 18, "E": 18, "F": 18, "G": 19,
                  "H": 19, "I": 18, "J": 19, "K": 19, "L": 18, "M": 18, "N": 18,
                  "O": 4, "P": 55})
    mise_en_page(ws, zoom=85, freeze="A6", ncols=14)
    col_notes(ws, "P")

    titre(ws, 1, "ASSURANCE-VIE — CAPITAUX DÉCÈS ET FISCALITÉ", ncols=14,
          sous_titre="Hors succession civile (art. L.132-12 C. assur.). Fiscalité propre : prélèvement de "
                     "l'art. 990 I pour les primes versées avant 70 ans, droits de succession de l'art. 757 B "
                     "pour les primes versées après 70 ans.")

    r = 4
    section(ws, r, "1.  CONTRATS D'ASSURANCE-VIE DU FOYER", ncols=14)
    r += 1
    entetes(ws, r, 2, ["Nom du contrat", "Compagnie", "Souscripteur", "Valeur de rachat (€)",
                       "Capital décès (€)", "Primes versées AVANT 70 ans (€)",
                       "Primes versées APRÈS 70 ans (€)", "Total des primes (€)",
                       "Capital rattaché aux primes < 70 ans (€)",
                       "Capital rattaché aux primes > 70 ans (€)", "Dénoué par le décès simulé",
                       "Total des quotes-parts des clauses", "Contrôle"])
    r += 1
    rc = r
    for i in range(NB_CONTRATS):
        ex = EX_CONTRATS[i] if i < len(EX_CONTRATS) else (None,) * 7
        inp(ws, "B{}".format(r), ex[0])
        inp(ws, "C{}".format(r), ex[1])
        inp(ws, "D{}".format(r), ex[2], align="center")
        inp(ws, "E{}".format(r), ex[3], fmt=F_EUR, align="right")
        inp(ws, "F{}".format(r), ex[4], fmt=F_EUR, align="right")
        inp(ws, "G{}".format(r), ex[5], fmt=F_EUR, align="right")
        inp(ws, "H{}".format(r), ex[6], fmt=F_EUR, align="right")
        calc(ws, "I{}".format(r), "=G{r}+H{r}".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "J{}".format(r), "=IF(I{r}=0,0,F{r}*G{r}/I{r})".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "K{}".format(r), "=F{r}-J{r}".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "L{}".format(r), '=IF(AND(D{r}<>"",D{r}=Defunt),1,0)'.format(r=r), fmt=F_INT, align="center")
        calc(ws, "M{}".format(r), "=SUMIF(ClauseContrat,{i},ClausePct)".format(i=i + 1),
             fmt=F_PCT, align="center")
        calc(ws, "N{}".format(r),
             '=IF(F{r}=0,"",IF(ABS(M{r}-1)>0.001,"⚠️ répartition ≠ 100 %","✅ 100 %"))'.format(r=r),
             align="center")
        for col in "IJKLMN":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    rc_fin = r - 1
    dv_liste(ws, "D{}:D{}".format(rc, rc_fin), ["Client", "Conjoint"])
    dn(wb, "CtrNom", SHEET, "$B${}:$B${}".format(rc, rc_fin))
    dn(wb, "CtrCapitalDeces", SHEET, "$F${}:$F${}".format(rc, rc_fin))
    dn(wb, "CtrPrimes70Plus", SHEET, "$H${}:$H${}".format(rc, rc_fin))
    dn(wb, "CtrCap70Moins", SHEET, "$J${}:$J${}".format(rc, rc_fin))
    dn(wb, "CtrDenoue", SHEET, "$L${}:$L${}".format(rc, rc_fin))

    lab(ws, "B{}".format(r), "TOTAUX", bold=True)
    total(ws, "E{}".format(r), "=SUM(E{}:E{})".format(rc, rc_fin), fmt=F_EUR, align="right")
    dn(wb, "AV_ValeurRachat", SHEET, A("E", r))
    total(ws, "F{}".format(r), "=SUM(F{}:F{})".format(rc, rc_fin), fmt=F_EUR, align="right")
    total(ws, "H{}".format(r), "=SUMPRODUCT(H{a}:H{b},L{a}:L{b})".format(a=rc, b=rc_fin),
          fmt=F_EUR, align="right")
    dn(wb, "AV_TotalPrimes70Plus", SHEET, A("H", r))
    r += 1
    note(ws, "B{}".format(r), "La ventilation du capital décès entre primes versées avant et après 70 ans est faite "
                              "au prorata des primes. « Dénoué par le décès simulé » vaut 1 lorsque le souscripteur "
                              "est le défunt retenu sur la feuille « Patrimoine ».")
    r += 2

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  CLAUSES BÉNÉFICIAIRES", ncols=14)
    r += 1
    entetes(ws, r, 2, ["N° de contrat", "Bénéficiaire (prénom identique à la feuille Client)",
                       "Lien avec le défunt", "Quote-part de la clause",
                       "Capital attribué (€)", "dont issu de primes < 70 ans (€)",
                       "Primes > 70 ans attribuées (€)"])
    r += 1
    rl = r
    for i in range(NB_CLAUSES):
        ex = EX_CLAUSES[i] if i < len(EX_CLAUSES) else (None, None, None, None)
        inp(ws, "B{}".format(r), ex[0], fmt=F_INT, align="center")
        inp(ws, "C{}".format(r), ex[1])
        inp(ws, "D{}".format(r), ex[2], align="center")
        inp(ws, "E{}".format(r), ex[3], fmt=F_PCT2, align="center")
        calc(ws, "F{}".format(r),
             "=IFERROR(INDEX(CtrCapitalDeces,B{r})*E{r}*INDEX(CtrDenoue,B{r}),0)".format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "G{}".format(r),
             "=IFERROR(INDEX(CtrCap70Moins,B{r})*E{r}*INDEX(CtrDenoue,B{r}),0)".format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "H{}".format(r),
             "=IFERROR(INDEX(CtrPrimes70Plus,B{r})*E{r}*INDEX(CtrDenoue,B{r}),0)".format(r=r),
             fmt=F_EUR, align="right")
        for col in "FGH":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    rl_fin = r - 1
    dv_liste(ws, "B{}:B{}".format(rl, rl_fin), [str(i) for i in range(1, NB_CONTRATS + 1)])
    dv_liste(ws, "D{}:D{}".format(rl, rl_fin), source=LIENS_SRC)
    dn(wb, "ClauseContrat", SHEET, "$B${}:$B${}".format(rl, rl_fin))
    dn(wb, "ClauseBenef", SHEET, "$C${}:$C${}".format(rl, rl_fin))
    dn(wb, "ClausePct", SHEET, "$E${}:$E${}".format(rl, rl_fin))
    dn(wb, "ClauseCapital", SHEET, "$F${}:$F${}".format(rl, rl_fin))
    dn(wb, "ClauseCap70Moins", SHEET, "$G${}:$G${}".format(rl, rl_fin))
    dn(wb, "ClausePrimes70Plus", SHEET, "$H${}:$H${}".format(rl, rl_fin))

    lab(ws, "B{}".format(r), "TOTAL DES CAPITAUX TRANSMIS PAR LE DÉCÈS SIMULÉ", bold=True)
    total(ws, "F{}".format(r), "=SUM(F{}:F{})".format(rl, rl_fin), fmt=F_EUR, align="right")
    dn(wb, "AV_CapitalTotal", SHEET, A("F", r))
    total(ws, "G{}".format(r), "=SUM(G{}:G{})".format(rl, rl_fin), fmt=F_EUR, align="right")
    total(ws, "H{}".format(r), "=SUM(H{}:H{})".format(rl, rl_fin), fmt=F_EUR, align="right")
    dn(wb, "AV_Primes70PlusTransmises", SHEET, A("H", r))
    r += 1
    note(ws, "B{}".format(r), "La colonne « Contrôle » du tableau des contrats (colonne N ci-dessus) vérifie que "
                              "les quotes-parts de chaque clause totalisent bien 100 %.")
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  FISCALITÉ PAR BÉNÉFICIAIRE", ncols=14)
    r += 1
    lab(ws, "B{}".format(r), "Saisissez chaque bénéficiaire UNE SEULE FOIS : les capitaux issus des différentes "
                             "clauses sont agrégés automatiquement, comme le fait l'administration fiscale "
                             "(abattements individuels, tous contrats confondus).", italic=True, size=9)
    r += 1
    entetes(ws, r, 2, ["Bénéficiaire", "Lien avec le défunt", "Exonéré ?",
                       "Capital issu de primes < 70 ans (€)", "Abattement art. 990 I (€)",
                       "Base taxable art. 990 I (€)", "PRÉLÈVEMENT ART. 990 I (€)",
                       "Primes > 70 ans attribuées (€)", "Quote-part de l'abattement de 30 500 € (€)",
                       "BASE SOUMISE AUX DROITS (art. 757 B) (€)", "Capital total perçu (€)",
                       "Net perçu après prélèvement 990 I (€)"])
    r += 1
    rb = r
    for i in range(NB_BENEF):
        ex = EX_BENEF[i] if i < len(EX_BENEF) else (None, None)
        inp(ws, "B{}".format(r), ex[0])
        inp(ws, "C{}".format(r), ex[1], align="center")
        calc(ws, "D{}".format(r),
             '=IF(B{r}="","",IF(IFERROR(INDEX(AbatCat,MATCH(C{r},AbatLien,0)),"")="Exonéré","Oui","Non"))'.format(r=r),
             align="center")
        calc(ws, "E{}".format(r), '=IF(B{r}="",0,SUMIFS(ClauseCap70Moins,ClauseBenef,B{r}))'.format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "F{}".format(r), '=IF(D{r}="Oui",0,MIN(E{r},AV_Abat990))'.format(r=r), fmt=F_EUR, align="right")
        calc(ws, "G{}".format(r), '=IF(D{r}="Oui",0,MAX(0,E{r}-F{r}))'.format(r=r), fmt=F_EUR, align="right")
        calc(ws, "H{}".format(r),
             "=MIN(G{r},AV_Seuil20)*AV_Taux1+MAX(0,G{r}-AV_Seuil20)*AV_Taux2".format(r=r),
             fmt=F_EUR, align="right", bold=True)
        calc(ws, "I{}".format(r), '=IF(B{r}="",0,SUMIFS(ClausePrimes70Plus,ClauseBenef,B{r}))'.format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "J{}".format(r),
             '=IF(OR(D{r}="Oui",AV_Primes70PlusTransmises=0),0,'
             "AV_Abat757*I{r}/AV_Primes70PlusTransmises)".format(r=r), fmt=F_EUR, align="right")
        calc(ws, "K{}".format(r), '=IF(D{r}="Oui",0,MAX(0,I{r}-J{r}))'.format(r=r),
             fmt=F_EUR, align="right", bold=True)
        calc(ws, "L{}".format(r), '=IF(B{r}="",0,SUMIFS(ClauseCapital,ClauseBenef,B{r}))'.format(r=r),
             fmt=F_EUR, align="right")
        calc(ws, "M{}".format(r), "=L{r}-H{r}".format(r=r), fmt=F_EUR, align="right")
        for col in "BCDEFGHIJKLM":
            ws["{}{}".format(col, r)].border = BOX
        r += 1
    rb_fin = r - 1
    dv_liste(ws, "C{}:C{}".format(rb, rb_fin), source=LIENS_SRC)
    dn(wb, "AV_BenefNom", SHEET, "$B${}:$B${}".format(rb, rb_fin))
    dn(wb, "AV_Exonere", SHEET, "$D${}:$D${}".format(rb, rb_fin))
    dn(wb, "AV_AbatUtilise", SHEET, "$F${}:$F${}".format(rb, rb_fin))
    dn(wb, "AV_Taxable757", SHEET, "$K${}:$K${}".format(rb, rb_fin))

    lab(ws, "B{}".format(r), "TOTAUX", bold=True)
    for col, nom in [("E", None), ("G", None), ("I", None), ("K", None), ("L", None), ("M", None)]:
        total(ws, "{}{}".format(col, r), "=SUM({c}{a}:{c}{b})".format(c=col, a=rb, b=rb_fin),
              fmt=F_EUR, align="right")
    resultat(ws, "H{}".format(r), "=SUM(H{}:H{})".format(rb, rb_fin), fmt=F_EUR)
    dn(wb, "AV_Prelevement990", SHEET, A("H", r))
    r += 1
    lab(ws, "B{}".format(r), "Contrôle : capitaux répartis vs capitaux transmis", italic=True)
    calc(ws, "L{}".format(r), "=L{}-AV_CapitalTotal".format(r - 1), fmt=F_EUR, align="right", bold=True)
    r += 2

    note(ws, "B{}".format(r), "Art. 990 I CGI — primes versées AVANT 70 ans : abattement de 152 500 € par bénéficiaire "
                              "(tous contrats du même assuré confondus), puis 20 % jusqu'à 700 000 € de part taxable et "
                              "31,25 % au-delà. Le conjoint et le partenaire de PACS sont exonérés (art. 796-0 bis).")
    r += 1
    note(ws, "B{}".format(r), "Art. 757 B CGI — primes versées APRÈS 70 ans : seules les PRIMES sont taxables, après un "
                              "abattement GLOBAL de 30 500 € réparti entre les bénéficiaires taxables au prorata. "
                              "Les produits capitalisés restent exonérés. La base ainsi calculée (colonne K) est reprise "
                              "automatiquement dans l'assiette des droits de succession du bénéficiaire, "
                              "feuille « Droits_Succession » colonne F.")
    r += 1
    note(ws, "B{}".format(r), "Non modélisé : contrats souscrits avant le 20/11/1991, primes versées avant le 13/10/1998, "
                              "clauses démembrées (usufruit / nue-propriété du capital décès) et contrats de capitalisation.")

    ws.sheet_properties.tabColor = "7030A0"
    return ws
