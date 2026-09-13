class_name CombatRewards
extends RefCounted

## Ce qu'une rencontre rapporte, une fois qu'elle est finie.
##
## POURQUOI CETTE CLASSE EXISTE PLUTÔT QU'UNE MÉTHODE SUR LE MOTEUR. Le
## combat ne connaît pas la campagne : il ne sait pas ce qu'est un héros,
## un niveau ou une expédition, et c'est ce qui permet de le tester seul et
## de simuler mille combats en headless. Le sens de la dépendance est
## `Hero → Unit`, jamais l'inverse.
##
## Cette classe est donc la couture : elle lit un combat terminé et rend
## des chiffres que la couche campagne applique. C'est ici que la Phase 3
## branchera l'expédition, et la Phase 4 le butin.
##
## L'EXPÉRIENCE VA À L'ÉQUIPE, pas au tueur. Le § 33 parle de la
## progression du héros sans jamais dire « celui qui porte le coup » ;
## récompenser le tueur pousserait le joueur à voler les mises à terre à
## son propre Guerrier, ce qui est exactement l'inverse d'un jeu où le
## Guerrier existe pour encaisser.

## Compte rendu d'une rencontre : ce qu'elle a coûté et ce qu'elle rapporte.
##
## `experience` est le total à verser à CHAQUE héros qui en sort debout.
static func summarise(engine: CombatEngine) -> Dictionary:
	if engine == null:
		return {}
	var downed := 0
	for unit: Unit in engine.board.units():
		if unit.is_enemy() and unit.is_downed():
			downed += 1

	var victory := engine.is_victory()
	var experience := downed * HeroProgression.award(&"enemy_downed")
	if victory:
		experience += HeroProgression.award(&"combat_won")
		experience += HeroProgression.award(&"objective_completed")

	return {
		"victory": victory,
		"finished": engine.is_finished(),
		"rounds": engine.round_index(),
		"enemies_downed": downed,
		"experience": experience,
	}


## Verse l'expérience d'une rencontre à une compagnie, et rend le nombre de
## niveaux ouverts par héros : { identifiant → niveaux }.
##
## Les niveaux sont OUVERTS, pas pris. Certains demandent un choix, et le
## choix appartient au joueur — le lui voler serait le priver de la seule
## décision que la montée en niveau contient.
static func award_to(company: Array[Hero], experience: int) -> Dictionary:
	var out := {}
	if experience <= 0:
		return out
	for hero: Hero in company:
		if hero == null:
			continue
		var gained := hero.add_experience(experience)
		if gained > 0:
			out[hero.id] = gained
	return out
