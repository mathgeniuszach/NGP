extends Control

func _input(event):
	# Show interface
	if event.is_action_pressed("interface_open"):
		if $Interface.visible:
			$Interface.hide()
		else:
			$Interface.show()
		get_tree().set_input_as_handled()

# Show interface by default
func _ready():
	# Randomize randomizer
	randomize()
	# Set min window size
	OS.min_window_size = Vector2(450, 450)
	# No autoquit
	get_tree().set_auto_accept_quit(false)
	# Load G
	G.load(self)
	
	# Show interface
	$Interface.show()
	# Load help text
	var file = File.new()
	file.open("res://help.txt", File.READ)
	$HelpWindow/HelpText.bbcode_text = file.get_as_text()
	file.close()

# Make sure when window is resized the interface is fixed
func _on_Mainframe_resized():
	$Interface.fix_interface_size()
	$Interface.fix_interface_pos()
