extends Control

func _on_Username_text_entered(new_text): update_username(new_text)
func _on_Username_focus_exited(): update_username($PlayerName/Username.text)

func _on_Key_text_entered(new_text): update_key(new_text)
func _on_Key_focus_exited(): update_key($Key/Key.text)

func update_username(username):
	G.config.set_value("NGP", "username", username)
	G.save_config()
	if Network.peer: G.rpc_id(1, "_player_info", username)
	G.pnames[G.sid] = username
	G.update_p_list()

func update_key(key):
	G.config.set_value("NGP", "key", key)
	var h = key.sha256_text()
	Network.keyA = ("0x"+h.left(7)).hex_to_int()
	Network.keyB = ("0x"+h.right(len(h)-7)).hex_to_int()
	G.save_config()

func _on_Debug_toggled(button_pressed):
	G.config.set_value("NGP", "debug", button_pressed)
	G.save_config()

func _on_Fullscreen_toggled(button_pressed):
	G.config.set_value("NGP", "fullscreen", button_pressed)
	OS.window_fullscreen = button_pressed
	G.save_config()

func _on_HelpButton_pressed():
	G.help.popup_centered()
