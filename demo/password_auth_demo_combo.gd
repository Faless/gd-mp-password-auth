extends Control

var paths = []

func _enter_tree():
	var node = $GridContainer
	for ch in node.get_children():
		var pt = NodePath(str(get_path()) + "/GridContainer/" + str(ch.name))
		get_tree().set_multiplayer(SceneMultiplayer.new(), pt)
		paths.push_back(pt)

func _exit_tree():
	for pt in paths:
		get_tree().set_multiplayer(null, pt)
