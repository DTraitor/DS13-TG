//It exists just for compability. Don't add any vars or special behaviours
/datum/species/necromorph
	name = "Necromorph"
	id = SPECIES_VAMPIRE
	//There is no way to become it. Period.
	changesource_flags = NONE
	exotic_bloodtype = "X"

/datum/species/necromorph/check_roundstart_eligible()
	return FALSE
