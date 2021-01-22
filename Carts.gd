extends HSplitContainer

func _on_Folder_pressed():
	Directory.new().make_dir("user://packs")
	OS.shell_open(ProjectSettings.globalize_path("user://packs"))

func _on_PacksList_item_selected():
	var item: TreeItem = $Packs/PacksList.get_selected()
	$Other/Info/InfoText.clear()
	$Other/Info/InfoText.bbcode_text = item.get_meta("desc")
	G.sel_cart = [item.get_meta("pack"), item.get_meta("cart")]
	if G.sel_cart[1]: $Other/Buttons/Play.disabled = false
	else: $Other/Buttons/Play.disabled = true

func _on_PacksList_nothing_selected():
	$Other/Info/InfoText.clear()
	G.sel_cart = null
	$Other/Buttons/Play.disabled = true

func _on_Play_pressed():
	G.start_cart(G.sel_cart)
	G.loaded_cart = G.sel_cart
	
	$Other/Buttons/Stop.disabled = false
	$Other/Buttons/Refresh.disabled = false

func _on_Stop_pressed():
	G.stop_cart()
	G.loaded_cart = null
	
	$Other/Buttons/Stop.disabled = true
	$Other/Buttons/Refresh.disabled = true

func _on_Refresh_pressed():
	G.start_cart(G.loaded_cart)
