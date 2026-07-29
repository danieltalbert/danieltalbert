class_name UiModality
extends RefCounted
## Which full-screen surface currently owns the player's attention.
##
## Phase 1 grew its modal UIs one milestone at a time and none of them knew the
## others existed: the knowledge-channel card (m7), the pack (m10), the field
## notebook (m13) and a villager conversation (m8) could all be up at once. That
## is not cosmetic — the pack sets `get_tree().paused`, which stops the quiz
## card's `_process`, so its real-time countdown silently expired behind the pack
## and the cast was dead the moment the player closed it. Meanwhile the channel
## holds `Engine.time_scale` at 0.15 and Kern's invulnerability, so any UI opened
## over it inherits a crawling, invincible world.
##
## The rule, deliberately as small as it can be: a surface CLAIMS modality while
## it is up, RELEASES it when it closes, and asks `any_open()` before opening.
## First one in wins; the others decline and say so. Membership rides in a scene
## tree group rather than a static, so it cannot survive a scene reload stale
## (the `InputSetup._done` lesson).
##
## This is a rule, not a manager: nothing here opens or closes anything.

## Group every claimed surface joins. Claimants expose `is_open()` for logs.
const GROUP: StringName = &"modal_ui"


## Take the screen. Safe to call repeatedly.
static func claim(node: Node) -> void:
	if not node.is_in_group(GROUP):
		node.add_to_group(GROUP)


## Give it back. Safe to call when not held.
static func release(node: Node) -> void:
	if node.is_in_group(GROUP):
		node.remove_from_group(GROUP)


## True if any OTHER surface holds the screen. Pass `self` as `except` so a
## surface re-entering its own open path doesn't block itself.
static func any_open(tree: SceneTree, except: Node = null) -> bool:
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node != except and is_instance_valid(node):
			return true
	return false


## Node names of the current holders, for a log line the next session can read.
static func describe(tree: SceneTree, except: Node = null) -> String:
	var names: PackedStringArray = []
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node != except and is_instance_valid(node):
			names.append(node.name)
	return ", ".join(names) if names.size() > 0 else "nothing"
