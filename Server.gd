extends Control

var pid: int

func _on_Clear_pressed():
	$Console/Console/Text.clear()

func _on_Sender_text_entered(new_text):
	$Console/SenderBar/Sender.clear()
	G.msg(new_text)

func _on_PlayerList_item_rmb_selected(index, at_position):
	pid = G.players[index]
	G.p_menu.clear()
	G.p_menu.add_item("Copy ID (#%d)" % pid)
	if G.network_state == G.HOSTING and pid != 1:
		G.p_menu.add_item("Kick")
	
	G.p_menu.popup(Rect2(G.interface.rect_position+at_position+Vector2(8, 50), Vector2(10, 10)))


func _on_PlayerMenu_id_pressed(id):
	match id:
		0: # Copy id
			OS.clipboard = str(pid)
		1: # Kick
			Network.peer.disconnect_peer(pid)
