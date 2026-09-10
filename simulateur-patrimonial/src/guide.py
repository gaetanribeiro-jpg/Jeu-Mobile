# -*- coding: utf-8 -*-
"""Feuilles « Guide » (mode d'emploi) et « Synthese » (restitution client)."""

from .styles import *

SH_GUIDE = "Guide"
SH_SYN = "Synthese"


# ===========================================================================
def construire_guide(wb):
    ws = wb.create_sheet(SH_GUIDE)
    largeurs(ws, {"A": 2, "B": 26, "C": 46, "D": 46, "E": 46, "F": 4})
    mise_en_page(ws, zoom=100, freeze="A4", ncols=5)

    titre(ws, 1, "SIMULATEUR PATRIMONIAL — SUCCESSION & RETRAITE", ncols=5,
          sous_titre="Classeur d'aide à l'entretien patrimonial. Livré pré-rempli avec un cas fictif "
                     "d'illustration (famille MARTIN) : écrasez les données par celles de votre client.")

    r = 4
    section(ws, r, "AVERTISSEMENT", ncols=5)
    r += 1
    for texte in [
        "Cet outil produit une ESTIMATION pédagogique destinée à préparer un entretien et à illustrer des "
        "ordres de grandeur. Il ne se substitue ni à une consultation notariale, ni au relevé officiel de "
        "carrière, ni à un conseil en investissement.",
        "Les barèmes sont arrêtés à la date de construction du classeur. VÉRIFIEZ-LES sur la feuille "
        "« Parametres » avant tout usage : ils sont revalorisés chaque année, et le calendrier de l'âge "
        "légal de départ à la retraite a fait l'objet de mesures de suspension discutées fin 2025.",
        "Les simplifications assumées du modèle sont listées en bas de chaque feuille et récapitulées "
        "ci-dessous. Lisez-les avant de présenter un chiffre à un client.",
        "Respectez la politique de votre établissement en matière de données clients : ce fichier contient "
        "des données personnelles et patrimoniales sensibles (RGPD).",
    ]:
        b = lab(ws, "B{}".format(r), "•")
        b.alignment = Alignment(horizontal="right", vertical="top")
        c = lab(ws, "C{}".format(r), texte, size=10)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        ws.merge_cells("C{r}:E{r}".format(r=r))
        ws.row_dimensions[r].height = 52
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "LÉGENDE DES COULEURS", ncols=5)
    r += 1
    for exemple, libelle, style in [
        ("Saisie", "Cellule à remplir : c'est VOUS qui la renseignez.", "input"),
        ("Calcul", "Formule interne à la feuille : ne la modifiez pas.", "calc"),
        ("Report", "Formule reprenant une autre feuille : ne la modifiez pas.", "link"),
        ("Résultat", "Résultat clé de la feuille.", "res"),
        ("⚠️ Alerte", "Contrôle de cohérence : lisez le message affiché.", "alert"),
    ]:
        if style == "input":
            inp(ws, "B{}".format(r), exemple, align="center")
        elif style == "calc":
            calc(ws, "B{}".format(r), exemple, align="center")
            ws["B{}".format(r)].border = BOX
        elif style == "link":
            link(ws, "B{}".format(r), exemple, align="center")
            ws["B{}".format(r)].border = BOX
        elif style == "res":
            resultat(ws, "B{}".format(r), exemple)
        else:
            alerte(ws, "B{}".format(r), exemple)
        lab(ws, "C{}".format(r), libelle)
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "PLAN DU CLASSEUR", ncols=5)
    r += 1
    entetes(ws, r, 2, ["Feuille", "À quoi elle sert", "Ce que VOUS saisissez", "Ce qui est calculé"],
            largeurs=[26, 46, 46, 46])
    r += 1
    plan = [
        ("1. Client", "État civil, famille, profession, fiscalité du foyer.",
         "Identité, situation matrimoniale, enfants, ascendants, revenus, parts fiscales.",
         "Âges, nombre d'héritiers réservataires par branche, impôt sur le revenu et TMI."),
        ("2. Patrimoine", "Inventaire des biens et détermination de la masse successorale.",
         "Simulation du décès (client ou conjoint), biens, mode de détention, dettes, donations antérieures.",
         "Liquidation du régime matrimonial, actif net successoral, assiette fiscale, "
         "abattement résidence principale, rappel fiscal des donations."),
        ("3. Devolution", "Qui hérite, et pour quelle quote-part (Code civil).",
         "Option du conjoint survivant, legs éventuels.",
         "Cas de dévolution applicable, réserve et quotité disponible, quotes-parts en pleine propriété / "
         "usufruit / nue-propriété, valorisation au barème de l'art. 669 CGI."),
        ("4. Droits_Succession", "Combien chaque héritier paie (CGI).",
         "Rien — sauf le lien de parenté des héritiers non standard.",
         "Abattements, base taxable, barème progressif, droits par héritier, coût total de la transmission "
         "et comparatif des trois options du conjoint."),
        ("5. Assurance_Vie", "Capitaux décès et fiscalité propre à l'assurance-vie.",
         "Contrats, primes versées avant / après 70 ans, clauses bénéficiaires.",
         "Prélèvement de l'art. 990 I, base taxable de l'art. 757 B (reprise automatiquement dans les droits "
         "de succession du bénéficiaire)."),
        ("6. Retraite_Carriere", "La personne étudiée et sa carrière.",
         "Trimestres du relevé de carrière, points Agirc-Arrco, âge de départ envisagé, SAM.",
         "Âge légal et durée requise selon la génération, âge d'obtention du taux plein, points acquis par an."),
        ("7. Retraite_Estimation", "Estimation de la pension pour 6 âges de départ + l'âge envisagé.",
         "Rien.",
         "Décote, surcote, taux de liquidation, proratisation, pension de base et complémentaire, "
         "pension nette et taux de remplacement."),
        ("8. Retraite_Objectif", "Écart avec l'objectif du client et effort d'épargne à mettre en place.",
         "Objectif de revenu, autres revenus attendus, épargne déjà constituée et versements en cours.",
         "Capital nécessaire, capital projeté, effort mensuel, comparatif des enveloppes, "
         "sensibilité à l'âge de départ et au rendement."),
        ("9. Synthese", "Restitution en une page pour l'entretien.", "Rien.",
         "Chiffres clés des deux volets et pistes de travail conditionnelles."),
        ("10. Parametres", "Tous les barèmes, taux et hypothèses.",
         "Mise à jour annuelle des barèmes et choix des hypothèses financières.",
         "Rien — c'est la source de toutes les autres feuilles."),
    ]
    for feuille, role, saisie, calcule in plan:
        lab(ws, "B{}".format(r), feuille, bold=True)
        for col, txt in [("C", role), ("D", saisie), ("E", calcule)]:
            c = lab(ws, "{}{}".format(col, r), txt, size=9)
            c.alignment = Alignment(wrap_text=True, vertical="top")
            c.border = BOX
        ws["B{}".format(r)].border = BOX
        ws["B{}".format(r)].alignment = Alignment(vertical="top")
        ws.row_dimensions[r].height = 56
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "ORDRE DE TRAVAIL RECOMMANDÉ", ncols=5)
    r += 1
    for i, etape in enumerate([
        "Vérifier les barèmes de la feuille « Parametres » (une fois par an suffit).",
        "Remplir la feuille « Client » de haut en bas.",
        "Inventorier le patrimoine et choisir qui décède en premier (feuille « Patrimoine »).",
        "Saisir les contrats d'assurance-vie et leurs clauses bénéficiaires.",
        "Lire la dévolution, puis faire varier l'option du conjoint pour montrer l'écart de droits.",
        "Relancer la simulation avec l'autre conjoint comme défunt : les deux scénarios s'imposent.",
        "Basculer sur le volet retraite : carrière, puis estimation, puis objectif.",
        "Présenter la feuille « Synthese » au client.",
    ], 1):
        lab(ws, "B{}".format(r), "Étape {}".format(i), bold=True)
        lab(ws, "C{}".format(r), etape)
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "MISE À JOUR ANNUELLE (feuille « Parametres »)", ncols=5)
    r += 1
    for quoi, quand in [
        ("Abattements et barème des droits de succession (§ 1 et 2)", "Loi de finances — janvier"),
        ("Barème de l'impôt sur le revenu (§ 6)", "Loi de finances — janvier"),
        ("Calendrier de l'âge légal et de la durée d'assurance (§ 7)", "À chaque réforme des retraites"),
        ("PASS et PASS N-1 (§ 8)", "1er janvier"),
        ("Valeur d'achat et valeur de service du point Agirc-Arrco (§ 9)", "1er novembre — agirc-arrco.fr"),
        ("Taux de CSG / CRDS / CASA (§ 10)", "1er janvier"),
        ("Hypothèses d'inflation et de rendement (§ 11)", "À votre main — au moins une fois par an"),
        ("Plafond de déduction PER (§ 12)", "1er janvier"),
    ]:
        lab(ws, "B{}".format(r), "☐", bold=True)
        lab(ws, "C{}".format(r), quoi)
        lab(ws, "D{}".format(r), quand, italic=True, color=C_NOTE)
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "CE QUE LE MODÈLE NE FAIT PAS", ncols=5)
    r += 1
    limites = [
        "Succession : représentation des petits-enfants, fente successorale entre branches, rapport civil "
        "des donations, récompenses entre patrimoines, reconstitution du barème sur les donations rappelées, "
        "droit de retour légal ou conventionnel, exonérations sectorielles (pacte Dutreil, bois et forêts, "
        "monuments historiques), successions internationales.",
        "Assurance-vie : contrats antérieurs au 20/11/1991, primes antérieures au 13/10/1998, clauses "
        "bénéficiaires démembrées, contrats de capitalisation.",
        "Retraite : carrière longue, retraite progressive, catégories actives, régimes spéciaux, "
        "fonction publique, indépendants et professions libérales, polypensionnés, périodes à l'étranger, "
        "minimum contributif, réversion, rachats de trimestres.",
        "Fiscalité : impôt sur la fortune immobilière, plafonnement du quotient familial, décote, "
        "réductions et crédits d'impôt, prélèvement à la source.",
    ]
    for texte in limites:
        b = lab(ws, "B{}".format(r), "•")
        b.alignment = Alignment(horizontal="right", vertical="top")
        c = lab(ws, "C{}".format(r), texte, size=9)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        ws.merge_cells("C{r}:E{r}".format(r=r))
        ws.row_dimensions[r].height = 56
        r += 1

    ws.sheet_properties.tabColor = NAVY
    return ws


# ===========================================================================
def construire_synthese(wb):
    ws = wb.create_sheet(SH_SYN)
    largeurs(ws, {"A": 2, "B": 58, "C": 26, "D": 26, "E": 26, "F": 88})
    mise_en_page(ws, zoom=100, freeze="A4", paysage=False, ncols=6)

    titre(ws, 1, "SYNTHÈSE DE L'ÉTUDE PATRIMONIALE", ncols=6,
          sous_titre="Restitution des chiffres clés. Toutes les valeurs sont reprises automatiquement "
                     "des feuilles de calcul.")

    r = 4
    section(ws, r, "LE FOYER", ncols=6)
    r += 1
    for libelle, formule, fmt in [
        ("Client", "=NomClient", None),
        ("Conjoint / partenaire", "=NomConjoint", None),
        ("Situation matrimoniale et régime", '=SitMat&" — "&RegimeMat', None),
        ("Nombre d'enfants du foyer", "=NbEnfCommuns+NbEnfPropClient+NbEnfPropConjoint", F_INT),
        ("Patrimoine net global (assurance-vie incluse)", "=PatrimoineNetGlobal", F_EUR),
        ("Taux marginal d'imposition", "=TMI", F_PCT),
    ]:
        lab(ws, "B{}".format(r), libelle)
        link(ws, "C{}".format(r), formule, fmt=fmt, align="center" if fmt else "left")
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "VOLET 1 — TRANSMISSION", ncols=6)
    r += 1
    for libelle, formule, fmt, fort in [
        ("Décès simulé", "=NomDefunt", None, False),
        ("Cas de dévolution retenu", '=IF(NbEnfDefunt>0,"Descendants","Sans descendant")&" — option : "&OptionConjoint', None, False),
        ("Actif net successoral (masse civile)", "=MasseCivile", F_EUR, False),
        ("Capitaux d'assurance-vie transmis", "=AV_CapitalTotal", F_EUR, False),
        ("Part revenant au conjoint survivant (valeur fiscale)", "=INDEX(HerValeur,1)", F_EUR, False),
        ("Part revenant aux enfants (valeur fiscale)", "=SUM(INDEX(HerValeur,2):INDEX(HerValeur,9))", F_EUR, False),
        ("DROITS DE SUCCESSION", "=TotalDroits", F_EUR, True),
        ("Prélèvement sur l'assurance-vie (art. 990 I)", "=AV_Prelevement990", F_EUR, False),
        ("COÛT TOTAL DE LA TRANSMISSION", "=CoutTransmission", F_EUR, True),
        ("Taux de frottement fiscal", "=TauxFrottement", F_PCT, True),
    ]:
        lab(ws, "B{}".format(r), libelle, bold=fort)
        if fort:
            resultat(ws, "C{}".format(r), formule, fmt=fmt)
        else:
            link(ws, "C{}".format(r), formule, fmt=fmt, align="center" if fmt else "left")
            ws["C{}".format(r)].border = BOX
        r += 1
    r += 1

    section(ws, r, "VOLET 2 — RETRAITE", ncols=6)
    r += 1
    for libelle, formule, fmt, fort in [
        ("Personne étudiée", "=Rt_Nom", None, False),
        ("Âge légal de départ / âge du taux plein", '=Rt_AgeLegal&" ans  /  "&Rt_AgeTauxPlein&" ans"', None, False),
        ("Âge de départ envisagé", "=Rt_AgeDepart", F_DEC, False),
        ("Pension brute mensuelle estimée", "=Rt_PensionBruteMens", F_EUR, False),
        ("PENSION NETTE MENSUELLE ESTIMÉE", "=Rt_PensionNetteMens", F_EUR, True),
        ("Revenu net mensuel actuel", "=Rt_RevNetMens", F_EUR, False),
        ("TAUX DE REMPLACEMENT", "=Rt_TauxRemplacement", F_PCT, True),
        ("Objectif de revenu net mensuel", "=Ob_Objectif", F_EUR, False),
        ("Écart mensuel à combler", "=Ob_EcartMens", F_EUR, False),
        ("Capital nécessaire au départ", "=Ob_CapitalNecessaire", F_EUR, False),
        ("Capital déjà projeté au départ", "=Ob_CapitalProjete", F_EUR, False),
        ("EFFORT D'ÉPARGNE MENSUEL À METTRE EN PLACE", "=Ob_EffortMensuel", F_EUR, True),
    ]:
        lab(ws, "B{}".format(r), libelle, bold=fort)
        if fort:
            resultat(ws, "C{}".format(r), formule, fmt=fmt)
        else:
            link(ws, "C{}".format(r), formule, fmt=fmt, align="center" if fmt else "left")
            ws["C{}".format(r)].border = BOX
        r += 1
    r += 1

    # ------------------------------------------------------------------------
    section(ws, r, "PISTES DE TRAVAIL (générées automatiquement)", ncols=6)
    r += 1
    entetes(ws, r, 2, ["Constat", "Montant en jeu", "", ""], largeurs=[58, 22, 22, 4])
    r += 1
    pistes = [
        ('=IF(AbatSuccDisponibles>1000,'
         '"Des abattements de succession restent inutilisés. Une donation ou une donation-partage permettrait '
         'de les mobiliser dès maintenant — le compteur se recharge tous les 15 ans.",'
         '"Les abattements en ligne directe sont saturés : travailler le démembrement, l\'assurance-vie ou '
         'la donation aux petits-enfants.")',
         "=AbatSuccDisponibles"),
        ('=IF(AbatAVDisponibles>1000,'
         '"Des abattements d\'assurance-vie de 152 500 € par bénéficiaire restent disponibles : un versement '
         'avant 70 ans reste le levier le plus efficace.",'
         '"Les abattements d\'assurance-vie sont utilisés : au-delà, la taxation est de 20 % puis 31,25 %.")',
         "=AbatAVDisponibles"),
        ('=IF(CmpOptionA-CmpOptionB>1000,'
         '"L\'option du conjoint pour l\'usufruit total réduirait sensiblement les droits des enfants, tout en '
         'protégeant le conjoint (jouissance et revenus de la totalité des biens).",'
         '"L\'option pour l\'usufruit total n\'apporte pas d\'économie significative dans cette configuration.")',
         "=MAX(0,CmpOptionA-CmpOptionB)"),
        ('=IF(TotalDroits>LiquiditesSucc,'
         '"⚠️ Les liquidités et valeurs mobilières de la succession ne couvrent pas les droits, exigibles dans '
         'les 6 mois du décès. Prévoir une clause bénéficiaire d\'assurance-vie dédiée, un contrat de prévoyance '
         'ou un crédit de droits de succession.",'
         '"Les liquidités de la succession couvrent les droits exigibles ; l\'écart indiqué est la marge disponible.")',
         "=ABS(TotalDroits-LiquiditesSucc)"),
        ('=IF(Rt_TauxRemplacement<0.6,'
         '"Le taux de remplacement est inférieur à 60 % : la baisse de revenu au passage à la retraite sera '
         'sensible et justifie un plan d\'épargne dédié.",'
         '"Le taux de remplacement est satisfaisant au regard du revenu actuel.")',
         "=Ob_EcartMens"),
        ('=IF(Ob_EffortMensuel>0.25*Rt_RevNetMens,'
         '"⚠️ L\'effort d\'épargne dépasse 25 % du revenu net : réviser l\'objectif, décaler l\'âge de départ '
         'ou allonger la durée d\'épargne.",'
         'IF(Ob_EffortMensuel=0,"Aucun effort d\'épargne supplémentaire n\'est nécessaire.",'
         '"L\'effort d\'épargne paraît soutenable — à confronter à la capacité d\'épargne réelle du client."))',
         "=Ob_EffortMensuel"),
        ('=IF(INDEX(Rt_ScenPensionNetteMens,6)-INDEX(Rt_ScenPensionNetteMens,3)>0,'
         '"Reporter le départ de 64 à 67 ans augmenterait la pension nette mensuelle du montant indiqué '
         '(effet cumulé de la surcote, des trimestres supplémentaires et des points Agirc-Arrco).","")',
         "=MAX(0,INDEX(Rt_ScenPensionNetteMens,6)-INDEX(Rt_ScenPensionNetteMens,3))"),
    ]
    for texte, montant in pistes:
        c = calc(ws, "B{}".format(r), texte, align="left")
        c.alignment = Alignment(wrap_text=True, vertical="center")
        c.border = BOX
        link(ws, "C{}".format(r), montant, fmt=F_EUR, align="center", bold=True)
        ws["C{}".format(r)].border = BOX
        ws.row_dimensions[r].height = 52
        r += 1
    r += 1

    # --- cellules techniques alimentant les pistes ---------------------------
    section(ws, r, "CELLULES TECHNIQUES", ncols=6)
    r += 1
    for libelle, formule, nom in [
        ("Abattements de succession restant disponibles",
         "=SUMPRODUCT((DrAbatNet>DrBaseAvantAbat)*(DrAbatNet-DrBaseAvantAbat))", "AbatSuccDisponibles"),
        ("Abattements d'assurance-vie restant disponibles",
         '=SUMPRODUCT((AV_BenefNom<>"")*(AV_Exonere="Non")*(AV_Abat990-AV_AbatUtilise))', "AbatAVDisponibles"),
        ("Liquidités et valeurs mobilières dans la succession",
         '=SUMIFS(ActPartSucc,ActCategorie,"Liquidités et livrets")'
         '+SUMIFS(ActPartSucc,ActCategorie,"Comptes-titres / PEA")', "LiquiditesSucc"),
    ]:
        lab(ws, "B{}".format(r), libelle, italic=True, size=9)
        calc(ws, "C{}".format(r), formule, fmt=F_EUR, align="center")
        dn(wb, nom, SH_SYN, A("C", r))
        r += 1
    r += 1
    note(ws, "B{}".format(r), "Document établi à titre d'information. Estimations non contractuelles, "
                              "établies sur la base des informations communiquées par le client et des barèmes "
                              "en vigueur à la date indiquée sur la feuille « Client ».")

    ws.sheet_properties.tabColor = NAVY
    return ws
