extends WindowDialog

# Anti-overflow
var stuck: bool = false

# Show interface by default
func _ready(): show()

# Make sure when interface is moved or resized that it stays in view
func _on_Interface_item_rect_changed(): fix_interface_pos()

func fix_interface_pos():
	if not stuck:
		stuck = true
		var main = $".."
		
		# Change position if outside of left-rop bounds
		var pos: Vector2 = rect_position
		if pos.x < 2: pos.x = 2
		if pos.y < 20: pos.y = 20
		# Change position if outside of right-bottom bounds
		var end = pos + rect_size
		if end.x > main.rect_size.x-2: pos.x -= end.x - main.rect_size.x+2
		if end.y > main.rect_size.y-2: pos.y -= end.y - main.rect_size.y+2
		rect_position = pos
		
		stuck = false
func fix_interface_size():
	if not stuck:
		stuck = true
		var main = $".."
		
		# Change size if too large
		if rect_size.x > main.rect_size.x-4: rect_size.x = main.rect_size.x-4
		if rect_size.y > main.rect_size.y-22: rect_size.y = main.rect_size.y-22
		
		stuck = false

# Prevent interface from closing
func _on_Interface_popup_hide():
	$Interface.show()

func _on_Interface_resized():
	fix_interface_size()

# Button events
func _on_Min_pressed():
	rect_size = Vector2(0, 0)
	fix_interface_size()
func _on_Max_pressed():
	rect_size = $"..".rect_size
	fix_interface_size()
