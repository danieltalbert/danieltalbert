class_name MeadowLandmarks
extends Node3D
## Plants the named places Bit will notice across Datasedge Meadows, at the
## canonical map positions baked into MeadowTerrain (town, millpond, Vault,
## etc.). Each spawns a BitLandmark that registers itself for the companion to
## scan. These anchors are also where a later milestone drops the real POI
## props, so the geography stays consistent between Bit's naming and the world.
##
## Naming lines are in Bit's voice (curious, loyal, vain, water-shy) and respect
## canon — including NOT spoiling who Kern is at the Vault.

var _terrain: Node


func build(terrain: Node) -> void:
	_terrain = terrain

	_add("bootstrap_town", "Bootstrap", 0.0, 30.0, 42.0, false, [
		"That's Bootstrap. The whole town grew up from almost nothing, one careful step at a time. Sounds like somebody I know.",
		"Bootstrap, dead ahead — warm beds, warmer gossip, and a mayor forever rehearsing a speech.",
	])
	_add("old_millpond", "the Old Millpond", 95.0, 10.0, 30.0, false, [
		"The Old Millpond. Something down there keeps count of the coins, they say — and I keep my distance. That is a LOT of water.",
		"The mill! Lovely wheel. Absolutely dreadful swimming conditions, in my professional opinion.",
	])
	# The Seed Vault ruins, Whispering Well, Boundary Stones and Hivewise Apiary
	# used to be named from bare coordinates here, because nothing was built for
	# them. MeadowSites now raises real props at those places and registers each
	# one's BitLandmark on the prop itself, so their naming lines live there — a
	# second anchor here would name them twice, from the wrong spot.
	_add("gradient_peaks_vista", "the Gradient Peaks", 0.0, -1010.0, 150.0, false, [
		"Look north — the Gradient Peaks. Every trail up there climbs toward the same cold summit. We'll go someday. Bundle up.",
	])
	_add("latent_forest_vista", "the Latent Forest", 1080.0, 44.0, 150.0, false, [
		"That deep treeline to the east is the Latent Forest. Bigger inside than out, they say. Don't wander in without me — you'd never find the way back.",
	])


func _add(id: String, name_text: String, x: float, z: float, radius: float,
		senses: bool, lines: Array[String]) -> void:
	var lm: BitLandmark = BitLandmark.new()
	lm.name = "Landmark_" + id
	lm.configure(id, name_text, radius, lines, senses)
	var y: float = 1.2
	if _terrain != null and _terrain.has_method("get_height"):
		y = _terrain.get_height(x, z) + 1.2
	lm.position = Vector3(x, y, z)
	add_child(lm)
