extends Control

func _on_Leave_pressed():
	Network.act(G.DISCONNECTING, null)

func _on_Join_pressed():
	Network.act(G.CONNECTING, [$JoinButtons/Joiner.text, $JoinButtons/Server.text])

func _on_Host_pressed():
	Network.act(G.BINDING, $HostButtons/Port.value)

func _on_Code_pressed():
	if Network.join_code:
		OS.clipboard = Network.join_code
		G.debug("Join code copied to clipboard.")

func _on_ServerList_item_selected(index):
	var item = G.config.get_value("NGP", "servers", [])[index]
	$JoinButtons/Joiner.text = item[0]
	$JoinButtons/Server.text = item[1]
	
	$JoinButtons/Remove.disabled = false
	$JoinButtons/Up.disabled = false
	$JoinButtons/Down.disabled = false

func _on_Add_pressed():
	var arr = G.config.get_value("NGP", "servers", [])
	arr.append([$JoinButtons/Joiner.text, $JoinButtons/Server.text])
	G.config.set_value("NGP", "servers", arr)
	G.save_config()
	
	G.s_list.add_item($JoinButtons/Server.text)
	G.s_list.select(G.s_list.get_item_count()-1)

func _on_Remove_pressed():
	if G.s_list.is_anything_selected():
		var sel: int = G.s_list.get_selected_items()[0]
		
		var arr: Array = G.config.get_value("NGP", "servers", [])
		arr.remove(sel)
		G.config.set_value("NGP", "servers", arr)
		G.save_config()
		
		G.s_list.remove_item(sel)
		
		if !G.s_list.is_anything_selected():
			$JoinButtons/Remove.disabled = true
			$JoinButtons/Up.disabled = true
			$JoinButtons/Down.disabled = true

func _on_Up_pressed():
	if G.s_list.is_anything_selected():
		var sel = G.s_list.get_selected_items()[0]
		if sel > 0:
			var arr: Array = G.config.get_value("NGP", "servers", [])
			var v2 = arr[sel-1]
			var v = arr[sel]
			arr[sel-1] = v
			arr[sel] = v2
			G.config.set_value("NGP", "servers", arr)
			G.save_config()
			
			G.s_list.move_item(sel, sel-1)

func _on_Down_pressed():
	if G.s_list.is_anything_selected():
		var sel = G.s_list.get_selected_items()[0]
		if sel < G.s_list.get_item_count()-1:
			var arr: Array = G.config.get_value("NGP", "servers", [])
			var v = arr[sel]
			var v2 = arr[sel+1]
			arr[sel] = v2
			arr[sel+1] = v
			G.config.set_value("NGP", "servers", arr)
			G.save_config()
			
			G.s_list.move_item(sel, sel+1)
