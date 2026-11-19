class_name DemoPacks
extends RefCounted
## Two example packs for the battle viewer, until the shop exists.


static func build() -> BattleSim:
	var sim := BattleSim.new()
	# Player: a long-teckel Hounds board.
	sim.add_dog("teckel", 0, 0, 0, 2)
	sim.add_dog("teckel_a_poil_dur", 0, 0, 2)
	sim.add_dog("basset_hound", 0, 0, 3)
	sim.add_dog("beagle", 0, 1, 0)
	sim.add_dog("chien_de_saint_hubert", 0, 1, 1)
	sim.add_dog("carlin", 0, 1, 3)
	# Rival kennel: Working and Bagarreurs.
	sim.add_dog("dobermann", 1, 0, 0)
	sim.add_dog("berger_belge_malinois", 1, 0, 1)
	sim.add_dog("jack_russell", 1, 0, 2)
	sim.add_dog("welsh_corgi", 1, 0, 3)
	sim.add_dog("husky_de_siberie", 1, 1, 1)
	sim.add_dog("chihuahua", 1, 1, 2)
	return sim
