# -*- coding: utf-8 -*-
"""Feuille « Parametres » : tous les barèmes, taux et hypothèses du modèle.

Aucune formule des autres feuilles ne contient de valeur en dur : tout passe
par les plages nommées définies ici, afin que la mise à jour annuelle des
barèmes se fasse en un seul endroit.
"""

from .styles import *

SHEET = "Parametres"


def _bloc_valeurs(ws, wb, r, lignes):
    """Écrit une série (libellé, valeur, nom défini, format, source)."""
    for libelle, valeur, nom, fmt, source in lignes:
        lab(ws, "B{}".format(r), libelle)
        inp(ws, "C{}".format(r), valeur, fmt=fmt, align="center")
        if nom:
            dn(wb, nom, SHEET, A("C", r))
        note(ws, "E{}".format(r), source)
        r += 1
    return r


def construire(wb):
    ws = wb.create_sheet("Parametres")
    largeurs(ws, {"A": 2, "B": 46, "C": 16, "D": 22, "E": 74, "F": 14, "G": 14})
    mise_en_page(ws, zoom=95, freeze="A5", paysage=False, ncols=6)

    titre(ws, 1, "PARAMÈTRES, BARÈMES ET HYPOTHÈSES", ncols=6,
          sous_titre="Toutes les cellules bleues sont modifiables. C'est ici — et nulle part ailleurs — "
                     "que l'on met à jour les barèmes lors de leur revalorisation annuelle.")
    lab(ws, "B3", "⚠️  Barèmes arrêtés à la date de construction du classeur. "
                  "Vérifiez chaque valeur avant un usage en clientèle.",
        bold=True, color=C_WARN, size=10)

    r = 5

    # ------------------------------------------------------------------ 1 ---
    section(ws, r, "1.  SUCCESSION — ABATTEMENTS PERSONNELS ET CATÉGORIE DE BARÈME", ncols=6)
    r += 1
    entetes(ws, r, 2, ["Lien de parenté avec le défunt", "Abattement (€)",
                       "Catégorie de barème", "Référence et commentaire"])
    r += 1
    r_abat_deb = r
    abattements = [
        ("Conjoint survivant", 0, "Exonéré",
         "Art. 796-0 bis CGI : exonération totale de droits de succession."),
        ("Partenaire de PACS", 0, "Exonéré",
         "Art. 796-0 bis CGI : exonéré, mais n'hérite QUE par testament (art. 515-6 C. civ.)."),
        ("Enfant", 100000, "Ligne directe", "Art. 779 I CGI."),
        ("Ascendant (père / mère)", 100000, "Ligne directe", "Art. 779 I CGI."),
        ("Petit-enfant", 1594, "Ligne directe",
         "Art. 788 IV CGI. En cas de représentation, il partage l'abattement de 100 000 € de son auteur."),
        ("Arrière-petit-enfant", 1594, "Ligne directe", "Art. 788 IV CGI."),
        ("Frère / Sœur", 15932, "Frères et sœurs",
         "Art. 779 IV CGI. Exonération totale possible sous conditions (art. 796-0 ter : célibataire/veuf/divorcé, "
         "+50 ans ou infirme, domicilié avec le défunt les 5 dernières années)."),
        ("Neveu / Nièce", 7967, "Parents jusqu'au 4e degré", "Art. 779 V CGI."),
        ("Neveu / Nièce (par représentation)", 15932, "Frères et sœurs",
         "Venant en représentation d'un frère ou d'une sœur prédécédé : reprend l'abattement et le barème de son auteur."),
        ("Oncle / Tante / Cousin germain", 1594, "Parents jusqu'au 4e degré", "Art. 788 IV et 777 CGI."),
        ("Concubin / Tiers", 1594, "Autres", "Art. 788 IV et 777 CGI — taxation à 60 %."),
        ("Aucun (part non taxable)", 0, "Exonéré", "Ligne technique : à utiliser pour neutraliser une part."),
    ]
    for nom_lien, ab, cat, src in abattements:
        lab(ws, "B{}".format(r), nom_lien)
        ws["B{}".format(r)].border = BOX
        inp(ws, "C{}".format(r), ab, fmt=F_EUR, align="center")
        inp(ws, "D{}".format(r), cat, align="center")
        note(ws, "E{}".format(r), src)
        r += 1
    r_abat_fin = r - 1
    dn(wb, "AbatLien", SHEET, "$B${}:$B${}".format(r_abat_deb, r_abat_fin))
    dn(wb, "AbatMontant", SHEET, "$C${}:$C${}".format(r_abat_deb, r_abat_fin))
    dn(wb, "AbatCat", SHEET, "$D${}:$D${}".format(r_abat_deb, r_abat_fin))
    r += 1

    # ------------------------------------------------------------------ 2 ---
    section(ws, r, "2.  SUCCESSION — BARÈME PROGRESSIF DES DROITS (art. 777 CGI)", ncols=6)
    r += 1
    entetes(ws, r, 2, ["Catégorie de barème", "Seuil bas de tranche (€)", "Taux de la tranche",
                       "Taux de la tranche précédente (calculé)"])
    r += 1
    r_bar_deb = r
    bareme = [
        ("Ligne directe", 0, 0.05), ("Ligne directe", 8072, 0.10),
        ("Ligne directe", 12109, 0.15), ("Ligne directe", 15932, 0.20),
        ("Ligne directe", 552324, 0.30), ("Ligne directe", 902838, 0.40),
        ("Ligne directe", 1805677, 0.45),
        ("Frères et sœurs", 0, 0.35), ("Frères et sœurs", 24430, 0.45),
        ("Parents jusqu'au 4e degré", 0, 0.55),
        ("Autres", 0, 0.60),
        ("Exonéré", 0, 0.00),
    ]
    for cat, seuil, taux in bareme:
        lab(ws, "B{}".format(r), cat)
        ws["B{}".format(r)].border = BOX
        inp(ws, "C{}".format(r), seuil, fmt=F_EUR, align="center")
        inp(ws, "D{}".format(r), taux, fmt=F_PCT, align="center")
        # taux de la tranche précédente : 0 si première tranche de la catégorie
        if r == r_bar_deb:
            calc(ws, "E{}".format(r), 0, fmt=F_PCT, align="center")
        else:
            calc(ws, "E{}".format(r),
                 "=IF(B{r}=B{p},D{p},0)".format(r=r, p=r - 1), fmt=F_PCT, align="center")
        r += 1
    r_bar_fin = r - 1
    dn(wb, "BarCat", SHEET, "$B${}:$B${}".format(r_bar_deb, r_bar_fin))
    dn(wb, "BarSeuil", SHEET, "$C${}:$C${}".format(r_bar_deb, r_bar_fin))
    dn(wb, "BarTaux", SHEET, "$D${}:$D${}".format(r_bar_deb, r_bar_fin))
    dn(wb, "BarPrev", SHEET, "$E${}:$E${}".format(r_bar_deb, r_bar_fin))
    note(ws, "B{}".format(r), "Les droits sont calculés par : SOMMEPROD((catégorie)×(base>seuil)×(base−seuil)×(taux−taux précédent)). "
                              "Ajouter une tranche = insérer une ligne DANS le tableau et étendre les plages nommées.")
    r += 2

    # ------------------------------------------------------------------ 3 ---
    section(ws, r, "3.  BARÈME FISCAL DE L'USUFRUIT ET DE LA NUE-PROPRIÉTÉ (art. 669 CGI)", ncols=6)
    r += 1
    entetes(ws, r, 2, ["Âge révolu de l'usufruitier — de", "… à", "Valeur de l'usufruit",
                       "Valeur de la nue-propriété"])
    r += 1
    r_usu_deb = r
    for amin, amax, us in [(0, 20, 0.90), (21, 30, 0.80), (31, 40, 0.70), (41, 50, 0.60),
                           (51, 60, 0.50), (61, 70, 0.40), (71, 80, 0.30), (81, 90, 0.20),
                           (91, 130, 0.10)]:
        inp(ws, "B{}".format(r), amin, fmt=F_INT, align="center")
        inp(ws, "C{}".format(r), amax, fmt=F_INT, align="center")
        inp(ws, "D{}".format(r), us, fmt=F_PCT, align="center")
        calc(ws, "E{}".format(r), "=1-D{}".format(r), fmt=F_PCT, align="center")
        r += 1
    r_usu_fin = r - 1
    dn(wb, "UsuAgeMin", SHEET, "$B${}:$B${}".format(r_usu_deb, r_usu_fin))
    dn(wb, "UsuUS", SHEET, "$D${}:$D${}".format(r_usu_deb, r_usu_fin))
    dn(wb, "UsuNP", SHEET, "$E${}:$E${}".format(r_usu_deb, r_usu_fin))
    note(ws, "B{}".format(r), "Barème applicable à l'usufruit viager. L'usufruit à durée fixe se valorise à 23 % par période de 10 ans (plafonné à la valeur de l'usufruit viager).")
    r += 2

    # ------------------------------------------------------------------ 4 ---
    section(ws, r, "4.  SUCCESSION — AUTRES PARAMÈTRES", ncols=6)
    r += 1
    r = _bloc_valeurs(ws, wb, r, [
        ("Abattement supplémentaire personne handicapée", 159325, "AbatHandicap", F_EUR,
         "Art. 779 II CGI — cumulable avec l'abattement personnel."),
        ("Abattement sur la résidence principale", 0.20, "AbatRP", F_PCT,
         "Art. 764 bis CGI — si occupée par le conjoint/partenaire ou un enfant mineur ou majeur protégé."),
        ("Forfait mobilier (présomption)", 0.05, "ForfaitMobilier", F_PCT,
         "Art. 764 I 3° CGI — 5 % de l'actif brut, sauf inventaire ou déclaration détaillée."),
        ("Frais funéraires déductibles (forfait)", 1500, "FraisFuneraires", F_EUR,
         "Art. 775 CGI."),
        ("Délai de rappel fiscal des donations", 15, "RappelDonations", F_INT,
         "Art. 784 CGI — en années."),
        ("Don familial de sommes d'argent (exonération)", 31865, "DonFamilial", F_EUR,
         "Art. 790 G CGI — donateur de moins de 80 ans, donataire majeur, renouvelable tous les 15 ans."),
    ])
    r += 1

    # ------------------------------------------------------------------ 5 ---
    section(ws, r, "5.  ASSURANCE-VIE — FISCALITÉ DU CAPITAL DÉCÈS", ncols=6)
    r += 1
    r = _bloc_valeurs(ws, wb, r, [
        ("Abattement par bénéficiaire (primes versées avant 70 ans)", 152500, "AV_Abat990", F_EUR,
         "Art. 990 I CGI — abattement individuel, tous contrats confondus."),
        ("Seuil de la 2e tranche du prélèvement 990 I", 700000, "AV_Seuil20", F_EUR,
         "Fraction taxable par bénéficiaire, après abattement."),
        ("Taux 990 I — 1re tranche", 0.20, "AV_Taux1", F_PCT, "Art. 990 I CGI."),
        ("Taux 990 I — 2e tranche", 0.3125, "AV_Taux2", F_PCT2, "Art. 990 I CGI."),
        ("Abattement global (primes versées après 70 ans)", 30500, "AV_Abat757", F_EUR,
         "Art. 757 B CGI — abattement GLOBAL sur les primes, réparti entre les bénéficiaires au prorata. "
         "Les produits capitalisés restent exonérés."),
    ])
    note(ws, "B{}".format(r), "Le conjoint survivant et le partenaire de PACS bénéficiaires sont exonérés dans les deux régimes.")
    r += 2

    # ------------------------------------------------------------------ 6 ---
    section(ws, r, "6.  BARÈME DE L'IMPÔT SUR LE REVENU (pour le calcul de la TMI)", ncols=6)
    r += 1
    entetes(ws, r, 2, ["Tranche — seuil bas par part (€)", "Taux", "Taux tranche précédente (calculé)", "Commentaire"])
    r += 1
    r_ir_deb = r
    for i, (seuil, taux) in enumerate([(0, 0.0), (11497, 0.11), (29315, 0.30),
                                       (83823, 0.41), (180294, 0.45)]):
        inp(ws, "B{}".format(r), seuil, fmt=F_EUR, align="center")
        inp(ws, "C{}".format(r), taux, fmt=F_PCT, align="center")
        if i == 0:
            calc(ws, "D{}".format(r), 0, fmt=F_PCT, align="center")
        else:
            calc(ws, "D{}".format(r), "=C{}".format(r - 1), fmt=F_PCT, align="center")
        r += 1
    r_ir_fin = r - 1
    dn(wb, "IR_Seuil", SHEET, "$B${}:$B${}".format(r_ir_deb, r_ir_fin))
    dn(wb, "IR_Taux", SHEET, "$C${}:$C${}".format(r_ir_deb, r_ir_fin))
    dn(wb, "IR_Prev", SHEET, "$D${}:$D${}".format(r_ir_deb, r_ir_fin))
    note(ws, "B{}".format(r), "Barème indiqué pour les revenus 2024 (impôt 2025) — à actualiser chaque année. "
                              "Le plafonnement des effets du quotient familial n'est pas modélisé.")
    r += 2

    # ------------------------------------------------------------------ 7 ---
    section(ws, r, "7.  RETRAITE — CALENDRIER LÉGAL PAR GÉNÉRATION", ncols=6)
    r += 1
    lab(ws, "B{}".format(r), "⚠️  Calendrier issu de la réforme du 14 avril 2023. Le décalage progressif de l'âge légal a fait "
                             "l'objet de mesures de suspension discutées fin 2025 : VÉRIFIEZ le calendrier applicable "
                             "sur info-retraite.fr et corrigez ce tableau le cas échéant.", color=C_WARN, size=9)
    r += 1
    entetes(ws, r, 2, ["Année de naissance", "Âge légal de départ (années)",
                       "Durée d'assurance requise (trimestres)", "Âge du taux plein automatique"])
    r += 1
    r_gen_deb = r
    calendrier = {1955: (62, 166), 1956: (62, 166), 1957: (62, 166),
                  1958: (62, 167), 1959: (62, 167), 1960: (62, 167),
                  1961: (62.25, 169), 1962: (62.5, 169), 1963: (62.75, 170),
                  1964: (63, 171), 1965: (63.25, 172), 1966: (63.5, 172),
                  1967: (63.75, 172), 1968: (64, 172)}
    for annee in range(1950, 1996):
        age, duree = calendrier.get(annee, (62, 166) if annee < 1955 else (64, 172))
        inp(ws, "B{}".format(r), annee, fmt=F_INT, align="center")
        inp(ws, "C{}".format(r), age, fmt=F_DEC, align="center")
        inp(ws, "D{}".format(r), duree, fmt=F_INT, align="center")
        inp(ws, "E{}".format(r), 67, fmt=F_INT, align="center")
        r += 1
    r_gen_fin = r - 1
    dn(wb, "GenAnnee", SHEET, "$B${}:$B${}".format(r_gen_deb, r_gen_fin))
    dn(wb, "GenAgeLegal", SHEET, "$C${}:$C${}".format(r_gen_deb, r_gen_fin))
    dn(wb, "GenDuree", SHEET, "$D${}:$D${}".format(r_gen_deb, r_gen_fin))
    dn(wb, "GenAgeTP", SHEET, "$E${}:$E${}".format(r_gen_deb, r_gen_fin))
    note(ws, "B{}".format(r), "62,25 = 62 ans et 3 mois. Génération 1961 : 62 ans / 168 trimestres pour les personnes nées "
                              "avant le 1er septembre 1961 — corriger la ligne si besoin.")
    r += 2

    # ------------------------------------------------------------------ 8 ---
    section(ws, r, "8.  RETRAITE — RÉGIME GÉNÉRAL (CNAV)", ncols=6)
    r += 1
    r = _bloc_valeurs(ws, wb, r, [
        ("Taux plein de liquidation", 0.50, "TauxPlein", F_PCT, "50 % du salaire annuel moyen."),
        ("Décote par trimestre manquant", 0.0125, "DecoteTrim", F_PCT2,
         "1,25 point par trimestre, dans la limite de 20 trimestres."),
        ("Nombre maximal de trimestres de décote", 20, "DecoteMax", F_INT, "Taux plancher : 37,5 %."),
        ("Surcote par trimestre supplémentaire", 0.0125, "SurcoteTrim", F_PCT2,
         "Trimestres cotisés au-delà de la durée requise ET de l'âge légal."),
        ("Plafond annuel de la Sécurité sociale (PASS)", 48060, "PASS", F_EUR,
         "Valeur 2026 — à actualiser chaque 1er janvier."),
        ("PASS de l'année précédente (pour le plafond PER)", 47100, "PASS_N1", F_EUR, "Valeur 2025."),
        ("Nombre d'années retenues pour le salaire annuel moyen", 25, "NbAnneesSAM", F_INT,
         "25 meilleures années, chacune plafonnée au PASS de l'année considérée."),
        ("Majoration de pension pour 3 enfants et plus", 0.10, "MajEnfants", F_PCT,
         "Régime de base — majoration imposable."),
    ])
    r += 1

    # ------------------------------------------------------------------ 9 ---
    section(ws, r, "9.  RETRAITE — COMPLÉMENTAIRE AGIRC-ARRCO", ncols=6)
    r += 1
    r = _bloc_valeurs(ws, wb, r, [
        ("Valeur d'achat du point (salaire de référence)", 20.1877, "ArrcoAchat", F_EUR4,
         "Valeur 2025 — à actualiser sur agirc-arrco.fr."),
        ("Valeur de service du point", 1.4386, "ArrcoService", F_EUR4,
         "Valeur 2025 — à actualiser sur agirc-arrco.fr."),
        ("Taux de calcul des points — tranche 1 (≤ 1 PASS)", 0.0620, "ArrcoT1", F_PCT2,
         "Taux contractuel. Le taux réellement prélevé est de 7,87 % (taux d'appel de 127 %)."),
        ("Taux de calcul des points — tranche 2 (1 à 8 PASS)", 0.1700, "ArrcoT2", F_PCT2,
         "Taux contractuel. Taux réellement prélevé : 21,59 %."),
        ("Majoration familiale (3 enfants et plus)", 0.10, "ArrcoMajFam", F_PCT,
         "Sur la pension complémentaire, plafonnée."),
        ("Plafond annuel de la majoration familiale", 2359, "ArrcoMajPlafond", F_EUR, "Valeur 2025."),
        ("Appliquer les coefficients majorants de report (1 = oui)", 0, "ArrcoCoefOn", F_INT,
         "Majoration de 10 % / 20 % / 30 % pour un départ décalé de 2 / 3 / 4 ans après le taux plein — "
         "avantage TEMPORAIRE (1 an). Désactivé par défaut pour ne pas surestimer la pension. "
         "Le coefficient minorant de 10 % est supprimé pour les départs postérieurs au 01/12/2023."),
    ])
    r += 1

    # ----------------------------------------------------------------- 10 ---
    section(ws, r, "10.  PRÉLÈVEMENTS SOCIAUX SUR LES PENSIONS", ncols=6)
    r += 1
    r_ps = r
    r = _bloc_valeurs(ws, wb, r, [
        ("CSG (taux normal)", 0.083, "PS_CSG", F_PCT2, "Taux réduit 3,8 % / taux médian 6,6 % selon le revenu fiscal de référence."),
        ("CRDS", 0.005, "PS_CRDS", F_PCT2, ""),
        ("CASA", 0.003, "PS_CASA", F_PCT2, "Contribution additionnelle de solidarité pour l'autonomie."),
        ("Cotisation maladie sur la retraite complémentaire", 0.01, "PS_Maladie", F_PCT2, ""),
    ])
    lab(ws, "B{}".format(r), "Taux global sur la pension de base", bold=True)
    calc(ws, "C{}".format(r), "=C{}+C{}+C{}".format(r_ps, r_ps + 1, r_ps + 2), fmt=F_PCT2, align="center", bold=True)
    dn(wb, "PS_Base", SHEET, A("C", r))
    r += 1
    lab(ws, "B{}".format(r), "Taux global sur la pension complémentaire", bold=True)
    calc(ws, "C{}".format(r), "=C{}+C{}+C{}+C{}".format(r_ps, r_ps + 1, r_ps + 2, r_ps + 3),
         fmt=F_PCT2, align="center", bold=True)
    dn(wb, "PS_Comp", SHEET, A("C", r))
    r += 2

    # ----------------------------------------------------------------- 11 ---
    section(ws, r, "11.  HYPOTHÈSES FINANCIÈRES DE PROJECTION", ncols=6)
    r += 1
    r = _bloc_valeurs(ws, wb, r, [
        ("Inflation annuelle retenue", 0.020, "Inflation", F_PCT,
         "Sert à raisonner en euros constants. Hypothèse de l'utilisateur."),
        ("Rendement annuel net — phase de constitution", 0.040, "RendConstit", F_PCT,
         "Net de frais de gestion, brut de fiscalité. Hypothèse de l'utilisateur — non contractuel."),
        ("Rendement annuel net — phase de restitution", 0.025, "RendRestit", F_PCT,
         "Allocation prudente une fois à la retraite. Hypothèse de l'utilisateur."),
        ("Progression annuelle des salaires", 0.015, "ProgSalaire", F_PCT, "Hypothèse de l'utilisateur."),
        ("Âge retenu pour la fin du besoin de revenu", 92, "EsperanceVie", F_INT,
         "Prudence : au-delà de l'espérance de vie moyenne. Hypothèse de l'utilisateur."),
        ("Taux de conversion en rente viagère", 0.040, "TauxRente", F_PCT,
         "Ordre de grandeur d'une rente immédiate à 64-65 ans, sans réversion. À confirmer auprès de l'assureur."),
        ("Coefficient de passage salaire actuel → SAM", 0.85, "CoefSAM", F_PCT,
         "Les 25 meilleures années sont en moyenne inférieures au dernier salaire. "
         "Hypothèse d'approximation — à remplacer par le SAM du relevé de carrière dès que possible."),
    ])
    r += 1

    # ----------------------------------------------------------------- 12 ---
    section(ws, r, "12.  PLAFOND DE DÉDUCTION DU PLAN D'ÉPARGNE RETRAITE (PER)", ncols=6)
    r += 1
    r = _bloc_valeurs(ws, wb, r, [
        ("Taux de déduction des revenus professionnels", 0.10, "PER_Taux", F_PCT,
         "Art. 163 quatervicies CGI — salariés."),
        ("Plafond exprimé en PASS N-1", 8, "PER_PlafondPASS", F_INT, "10 % de 8 PASS N-1."),
        ("Plancher exprimé en PASS N-1", 0.10, "PER_PlancherPASS", F_PCT, "10 % du PASS N-1."),
        ("Prélèvement forfaitaire unique (PFU)", 0.30, "PFU", F_PCT, "12,8 % IR + 17,2 % prélèvements sociaux."),
        ("Prélèvements sociaux sur les produits de placement", 0.172, "PS_Placement", F_PCT2, ""),
        ("Taux réduit assurance-vie après 8 ans (≤ 150 k€ de primes)", 0.075, "AV_Taux8ans", F_PCT2,
         "Hors prélèvements sociaux, après abattement annuel de 4 600 € / 9 200 €."),
        ("Abattement annuel assurance-vie après 8 ans (couple)", 9200, "AV_AbatAnnuel", F_EUR,
         "4 600 € pour une personne seule."),
    ])

    ws.sheet_properties.tabColor = "7F7F7F"
    return ws
