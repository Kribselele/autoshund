extends SceneTree
## Prints the result of the demo fight from the viewer, for quick balance checks.
## Run: godot --headless -s tools/sample_fight.gd

func _init() -> void:
	var sim := DemoPacks.build()
	var result := sim.run_to_end()
	print("Winner: %s after %.1f s, %d dogs standing, loser loses %d Treat Bowl points" % [
		["Player", "Rival"][result["winner"]] if result["winner"] != BattleSim.DRAW else "Draw",
		result["time"], result["survivors"], result["loser_damage"]])
	for side in [0, 1]:
		print("Side %d synergies: %s" % [side, Synergies.active(sim.side_units(side, false))])
	quit()
