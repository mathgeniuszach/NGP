extends Node

# Config
var config: ConfigFile = ConfigFile.new()
	
# Already loaded packs here in keys of id and version.
var packs = {}
var cart_map = {}
var sel_cart
var loaded_cart
var scene

func print_res():
	var dir = Directory.new()
	dir.list_dir_begin(true)
	var file = dir.get_next()
	while file:
		print(file)
		file = dir.get_next()
	dir.list_dir_end()

func load_config():
	config.load("user://data.cfg")
	pnames[1] = config.get_value("NGP", "username", "player")
	
	options.get_node("PlayerName/Username").text = G.config.get_value("NGP", "username", "player")
	options.get_node("DebugBox/Debug").pressed = G.config.get_value("NGP", "debug", true)
	options.get_node("DebugBox/Fullscreen").pressed = G.config.get_value("NGP", "fullscreen", false)
	options.get_node("Key/Key").text = G.config.get_value("NGP", "key", "")
	options.update_key(G.config.get_value("NGP", "key", ""))
	OS.window_fullscreen = G.config.get_value("NGP", "fullscreen", false)
	
	update_p_list()
	update_s_list()

func save_config(): config.save("user://data.cfg")

func load_packs():
	# Tree root
	var root: TreeItem = packs_list.create_item()
	packs_list.hide_root = true
	
	# Directory
	var pack_dir = Directory.new()
	pack_dir.make_dir("user://packs")
	pack_dir.open("user://packs")
	
	pack_dir.list_dir_begin(true)
	var file: String = pack_dir.get_next()
	while file:
		# If file is pack
		if file.ends_with(".pck"):
			# Create pack item
			var pack_item: TreeItem = packs_list.create_item(root)
			pack_item.set_meta("cart", "")
			# Load pack
			var data = load_pack(file, pack_item)
			pack_item.set_text(0, data[0])
			pack_item.set_meta("desc", data[1])
			pack_item.set_meta("pack", data[2])
			
		file = pack_dir.get_next()
	pack_dir.list_dir_end()

func load_pack(pack_name, pack_item):
	# Attempt to load pack
	if !ProjectSettings.load_resource_pack("user://packs/"+pack_name, false):
		return ["!!%s!!"%pack_name, "This pack failed to load for an unknown reason.\n\nIt could be from a corrupted file."]
	
	# Get pack config
	var pack_config: ConfigFile = ConfigFile.new()
	var err: int = pack_config.load("res://data.cfg")
	# Delete cfg file
	Directory.new().remove("data.cfg")
	# Check validity
	if err != OK:
		return ["??%s??"%pack_name, "This pack failed to load it's config. "+err_string(err)]
	
	# Get pack data
	var pack_id = pack_config.get_value("root", "id")
	var p_major = pack_config.get_value("root", "major", 0)
	var p_minor = pack_config.get_value("root", "minor", 0)
	if typeof(pack_id) != TYPE_STRING or typeof(p_major) != TYPE_INT or typeof(p_minor) != TYPE_INT:
		return ["??%s??"%pack_name, "This pack's root (in config) is formatted incorrectly."]
	if pack_id in packs:
		return ["??%s??"%pack_name, "This pack's id conflicts with another pack. It may have corrupted previous data."]
	
	var cart_dict = {}
	# Load carts
	var cart_list = pack_config.get_value("root", "carts", null)
	if typeof(cart_list) == TYPE_ARRAY:
		for cart_name in cart_list:
			if typeof(cart_name) == TYPE_STRING:
				# Create cart item
				var cart_item: TreeItem = packs_list.create_item(pack_item)
				var cart_title = pack_config.get_value(cart_name, "title", "Untitled Cart")
				var cart_desc = "[center][u]%s[/u][/center]\nAuthor(s): %s\nDescription:\n\n%s" % [
					pack_config.get_value(cart_name, "title", "Untitled Cart"),
					pack_config.get_value(cart_name, "author", "Unknown"),
					pack_config.get_value(cart_name, "desc", "")
				]
				
				# Attempt to load cart
				var cart = load("res://%s/%s.tscn" % [pack_id, cart_name])
				if cart and typeof(cart) == TYPE_OBJECT and cart.get_class() == "PackedScene":
					# Load success
					cart_dict[cart_name] = cart
					cart_item.set_text(0, cart_title)
					cart_item.set_meta("desc", cart_desc)
					cart_item.set_meta("pack", pack_id)
					cart_item.set_meta("cart", cart_name)
				else:
					# Load fail
					cart_item.set_text(0, "!!%s!!" % cart_title)
					cart_item.set_meta("desc", "This cart failed to load for an unknown reason.\n\n"+cart_desc)
					cart_item.set_meta("pack", pack_id)
					cart_item.set_meta("cart", "")
	
		# Add pack data to loaded packs
	packs[pack_id] = [p_major, p_minor]
	cart_map[pack_id] = cart_dict
	# Return success
	return [pack_name, "id: %s\nversion: %d.%d" % [pack_id, p_major, p_minor], pack_id]

remote func start_cart(sel):
	if sel:
		# Start cart on clients
		if network_state == HOSTING: rpc("start_cart", sel)
		# Stop cart if necessary
		stop_cart()
		
		# Get cart and load it
		var cart = cart_map[sel[0]][sel[1]]
		scene = cart.instance()
		if "players" in scene: scene.players = players
		if "pnames" in scene: scene.pnames = pnames
		if "sid" in scene: scene.sid = sid
		mainframe.add_child(scene)

remote func stop_cart():
	if network_state == HOSTING: rpc("stop_cart")
	if scene:
		if scene.has_method("_quit"): scene._quit()
		scene.queue_free()
		scene = null

func packs_match(player_packs):
	var fails = PoolStringArray()
	for pack in packs:
		if !(pack in player_packs and packs[pack][0] == player_packs[pack][0]):
			fails.append("Missing '%s' %d.%d" % [pack, packs[pack][0], packs[pack][1]])
	
	if fails: return "\n" + fails.join("\n")

# Ease-of-access variables
var mainframe: Control
var interface: WindowDialog

var s_list: ItemList
var p_list: ItemList
var info_labels
var console_t: RichTextLabel

var help: WindowDialog
var p_menu: PopupMenu
var ser_desc: LineEdit
var packs_list: Tree

var connect
var server
var carts
var options

var join_button: Button
var leave_button: Button
var port_box: SpinBox
var host_button: Button
var code_button: Button

var running = true

func load(main):
	# Top level
	mainframe = main
	help = main.get_node("HelpWindow")
	p_menu = main.get_node("PlayerMenu")
	interface = main.get_node("Interface")
	
	# Tabs
	connect = interface.get_node("TabContainer/Connect")
	server = interface.get_node("TabContainer/Server")
	carts = interface.get_node("TabContainer/Carts")
	options = interface.get_node("TabContainer/Options")
	
	# Other
	info_labels = [connect.get_node("Info"), server.get_node("Console/Info")]
	packs_list = carts.get_node("Packs/PacksList")
	s_list = connect.get_node("ServerList")
	p_list = server.get_node("Players/PlayerList")
	console_t = server.get_node("Console/Console/Text")
	ser_desc = connect.get_node("HostButtons/Desc")
	
	join_button = connect.get_node("JoinButtons/Join")
	leave_button = connect.get_node("JoinButtons/Leave")
	port_box = connect.get_node("HostButtons/Port")
	host_button = connect.get_node("HostButtons/Host")
	code_button = connect.get_node("HostButtons/Code")
	
	# Setup network methods
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	
	# Load config
	load_config()
	# Load packs
	load_packs()

var info = "Not Connected" setget set_info
func set_info(value):
	for label in info_labels: label.text = value
	info = value

func update_p_list():
	p_list.clear()
	for p in players:
		p_list.add_item(pnames[p])

func update_s_list():
	s_list.clear()
	for p in config.get_value("NGP", "servers", []):
		s_list.add_item(p[1])

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		if running:
			G.info = "Quitting"
			running = false
			Network.leave()
			
			Network.act(EXIT, null)
			Network.thread.wait_to_finish()
			get_tree().quit() # default behavior

enum {
	MSG_INFO,
	MSG_WARN,
	MSG_ERR,
	MSG_PLAYER
}

remote func debug(val: String, code: int = MSG_INFO):
	if config.get_value("NGP", "debug", true):
		match code:
			MSG_INFO:
				console_t.append_bbcode("[color=silver][i]<INFO> "+val+"[/i][/color]\n")
				print("<INFO> "+val)
			MSG_WARN:
				console_t.append_bbcode("[color=yellow][i]<WARN> "+val+"[/i][/color]\n")
				print("<WARN> "+val)
			MSG_ERR:
				console_t.append_bbcode("[color=red][i]<ERR> "+val+"[/i][/color]\n")
				print("<ERR> "+val)
	
	if code == MSG_PLAYER:
		console_t.append_bbcode("[color=teal]"+val+"\n[/color]")
		print(val)

remote func show_line(val: String, bb_code: bool = false):
	if bb_code:
		console_t.append_bbcode(val+"\n")
	else:
		console_t.add_text(val+"\n")

func int_to_base64(val: int) -> String:
	var array = PoolByteArray()
	var data = val
	
	while data != 0:
		array.append(data%256)
		data >>= 8
	
	return Marshalls.raw_to_base64(array)

func base64_to_int(val: String) -> int:
	var array = Marshalls.base64_to_raw(val)
	
	# Turn array into int
	var data: int = 0
	for i in range(len(array)):
		data += array[i] << 8*i
	
	return data

func err_string(code) -> String:
	match code:
		FAILED: return "FAILED"
		ERR_UNAVAILABLE: return "ERR_UNAVAILABLE"
		ERR_UNCONFIGURED: return "ERR_UNCONFIGURED"
		ERR_UNAUTHORIZED: return "ERR_UNAUTHORIZED"
		ERR_PARAMETER_RANGE_ERROR: return "ERR_PARAMETER_RANGE_ERROR"
		ERR_OUT_OF_MEMORY: return "ERR_OUT_OF_MEMORY"
		ERR_FILE_NOT_FOUND: return "ERR_FILE_NOT_FOUND"
		ERR_FILE_BAD_DRIVE: return "ERR_FILE_BAD_DRIVE"
		ERR_FILE_BAD_PATH: return "ERR_FILE_BAD_PATH"
		ERR_FILE_NO_PERMISSION: return "ERR_FILE_NO_PERMISSION"
		ERR_FILE_ALREADY_IN_USE: return "ERR_FILE_ALREADY_IN_USE"
		ERR_FILE_CANT_OPEN: return "ERR_FILE_CANT_OPEN"
		ERR_FILE_CANT_WRITE: return "ERR_FILE_CANT_WRITE"
		ERR_FILE_CANT_READ: return "ERR_FILE_CANT_READ"
		ERR_FILE_UNRECOGNIZED: return "ERR_FILE_UNRECOGNIZED"
		ERR_FILE_CORRUPT: return "ERR_FILE_CORRUPT"
		ERR_FILE_MISSING_DEPENDENCIES: return "ERR_FILE_MISSING_DEPENDENCIES"
		ERR_FILE_EOF: return "ERR_FILE_EOF"
		ERR_CANT_OPEN: return "ERR_CANT_OPEN"
		ERR_CANT_CREATE: return "ERR_CANT_CREATE"
		ERR_QUERY_FAILED: return "ERR_QUERY_FAILED"
		ERR_ALREADY_IN_USE: return "ERR_ALREADY_IN_USE"
		ERR_LOCKED: return "ERR_LOCKED"
		ERR_TIMEOUT: return "ERR_TIMEOUT"
		ERR_CANT_CONNECT: return "ERR_CANT_CONNECT"
		ERR_CANT_RESOLVE: return "ERR_CANT_RESOLVE"
		ERR_CONNECTION_ERROR: return "ERR_CONNECTION_ERROR"
		ERR_CANT_ACQUIRE_RESOURCE: return "ERR_CANT_ACQUIRE_RESOURCE"
		ERR_CANT_FORK: return "ERR_CANT_FORK"
		ERR_INVALID_DATA: return "ERR_INVALID_DATA"
		ERR_INVALID_PARAMETER: return "ERR_INVALID_PARAMETER"
		ERR_ALREADY_EXISTS: return "ERR_ALREADY_EXISTS"
		ERR_DOES_NOT_EXIST: return "ERR_DOES_NOT_EXIST"
		ERR_DATABASE_CANT_READ: return "ERR_DATABASE_CANT_READ"
		ERR_DATABASE_CANT_WRITE: return "ERR_DATABASE_CANT_WRITE"
		ERR_COMPILATION_FAILED: return "ERR_COMPILATION_FAILED"
		ERR_METHOD_NOT_FOUND: return "ERR_METHOD_NOT_FOUND"
		ERR_LINK_FAILED: return "ERR_LINK_FAILED"
		ERR_SCRIPT_FAILED: return "ERR_SCRIPT_FAILED"
		ERR_CYCLIC_LINK: return "ERR_CYCLIC_LINK"
		ERR_INVALID_DECLARATION: return "ERR_INVALID_DECLARATION"
		ERR_DUPLICATE_SYMBOL: return "ERR_DUPLICATE_SYMBOL"
		ERR_PARSE_ERROR: return "ERR_PARSE_ERROR"
		ERR_BUSY: return "ERR_BUSY"
		ERR_SKIP: return "ERR_SKIP"
		ERR_HELP: return "ERR_HELP"
		ERR_BUG: return "ERR_BUG"
		ERR_PRINTER_ON_FIRE: return "ERR_PRINTER_ON_FIRE"
	return ""

func upnp_err_string(code) -> String:
	match code:
		UPNP.UPNP_RESULT_NOT_AUTHORIZED: return "UPNP_RESULT_NOT_AUTHORIZED"
		UPNP.UPNP_RESULT_PORT_MAPPING_NOT_FOUND: return "UPNP_RESULT_PORT_MAPPING_NOT_FOUND"
		UPNP.UPNP_RESULT_INCONSISTENT_PARAMETERS: return "UPNP_RESULT_INCONSISTENT_PARAMETERS"
		UPNP.UPNP_RESULT_NO_SUCH_ENTRY_IN_ARRAY: return "UPNP_RESULT_NO_SUCH_ENTRY_IN_ARRAY"
		UPNP.UPNP_RESULT_ACTION_FAILED: return "UPNP_RESULT_ACTION_FAILED"
		UPNP.UPNP_RESULT_SRC_IP_WILDCARD_NOT_PERMITTED: return "UPNP_RESULT_SRC_IP_WILDCARD_NOT_PERMITTED"
		UPNP.UPNP_RESULT_EXT_PORT_WILDCARD_NOT_PERMITTED: return "UPNP_RESULT_EXT_PORT_WILDCARD_NOT_PERMITTED"
		UPNP.UPNP_RESULT_INT_PORT_WILDCARD_NOT_PERMITTED: return "UPNP_RESULT_INT_PORT_WILDCARD_NOT_PERMITTED"
		UPNP.UPNP_RESULT_REMOTE_HOST_MUST_BE_WILDCARD: return "UPNP_RESULT_REMOTE_HOST_MUST_BE_WILDCARD"
		UPNP.UPNP_RESULT_EXT_PORT_MUST_BE_WILDCARD: return "UPNP_RESULT_EXT_PORT_MUST_BE_WILDCARD"
		UPNP.UPNP_RESULT_NO_PORT_MAPS_AVAILABLE: return "UPNP_RESULT_NO_PORT_MAPS_AVAILABLE"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM: return "UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING: return "UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING"
		UPNP.UPNP_RESULT_SAME_PORT_VALUES_REQUIRED: return "UPNP_RESULT_SAME_PORT_VALUES_REQUIRED"
		UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED: return "UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED"
		UPNP.UPNP_RESULT_INVALID_GATEWAY: return "UPNP_RESULT_INVALID_GATEWAY"
		UPNP.UPNP_RESULT_INVALID_PORT: return "UPNP_RESULT_INVALID_PORT"
		UPNP.UPNP_RESULT_INVALID_PROTOCOL: return "UPNP_RESULT_INVALID_PROTOCOL"
		UPNP.UPNP_RESULT_INVALID_DURATION: return "UPNP_RESULT_INVALID_DURATION"
		UPNP.UPNP_RESULT_INVALID_ARGS: return "UPNP_RESULT_INVALID_ARGS"
		UPNP.UPNP_RESULT_INVALID_RESPONSE: return "UPNP_RESULT_INVALID_RESPONSE"
		UPNP.UPNP_RESULT_INVALID_PARAM: return "UPNP_RESULT_INVALID_PARAM"
		UPNP.UPNP_RESULT_HTTP_ERROR: return "UPNP_RESULT_HTTP_ERROR"
		UPNP.UPNP_RESULT_SOCKET_ERROR: return "UPNP_RESULT_SOCKET_ERROR"
		UPNP.UPNP_RESULT_MEM_ALLOC_ERROR: return "UPNP_RESULT_MEM_ALLOC_ERROR"
		UPNP.UPNP_RESULT_NO_GATEWAY: return "UPNP_RESULT_NO_GATEWAY"
		UPNP.UPNP_RESULT_NO_DEVICES: return "UPNP_RESULT_NO_DEVICES"
		UPNP.UPNP_RESULT_UNKNOWN_ERROR: return "UPNP_RESULT_UNKNOWN_ERROR"
	return ""

# Network states
enum {
	DISCONNECTED,
	DISCONNECTING,
	CONNECTED,
	CONNECTING,
	HOSTING,
	BINDING,
	EXIT
}

var network_state: int = DISCONNECTED setget set_network_state
func set_network_state(value: int):
	match value:
		DISCONNECTED:
			join_button.disabled = false
			leave_button.disabled = true
			port_box.editable = true
			host_button.disabled = false
			code_button.disabled = true
		DISCONNECTING:
			join_button.disabled = true
			leave_button.disabled = true
			host_button.disabled = true
		CONNECTED:
			join_button.disabled = false
			code_button.disabled = false
		CONNECTING:
			join_button.disabled = true
			leave_button.disabled = false
			host_button.disabled = true
		HOSTING:
			join_button.disabled = false
			leave_button.disabled = false
			code_button.disabled = false
		BINDING:
			join_button.disabled = true
			leave_button.disabled = true
			port_box.editable = false
			host_button.disabled = true
	
	network_state = value

# Networking 
var sid = 1
var players = [1]
var pnames = {}

func msg(msg: String):
	if msg:
		if G.network_state == CONNECTED:
			rpc_id(1, "_parse_msg", msg)
		else:
			_parse_msg(msg, true)

remote func _parse_msg(msg: String, local=false):
	var id = 1
	if !local: id = get_tree().get_rpc_sender_id()
	
	# Check for command
	if msg.begins_with("/"):
		var args = msg.split(" ")
		match args[0]:
			"/~": # LOL
				if len(args) < 2:
					if local: debug("Too few args", MSG_ERR)
					else: rpc_id(id, "debug", "Too few args", MSG_ERR)
				else:
					var line = "<%s> %s" % [pnames[id], msg.substr(3)]
					show_line(line, true)
					if G.network_state == HOSTING: rpc("show_line", line, true)
			"/~~": # undo LOL because people could be rude because they are rude sometimes
				console_t.pop()
			"/w": # Whisper
				if len(args) < 3:
					if local: debug("Too few args", MSG_ERR)
					else: rpc_id(id, "debug", "Too few args", MSG_ERR)
				else:
					var p = int(args[1])
					if p in players:
						var line = "{%s to %s} %s" % [pnames[id], pnames[p], msg.substr(4+len(args[1]))]
						# Receiver
						if p == 1: show_line(line)
						else: rpc_id(players[p], "show_line", line)
						# Sender
						if local: show_line(line)
						else: rpc_id(id, "show_line", line)
					else:
						if local: debug("Invalid player", MSG_ERR)
						else: rpc_id(id, "debug", "Invalid player", MSG_ERR)
			_:
				if local: debug("Invalid command", MSG_ERR)
				else: rpc_id(id, "debug", "Invalid command", MSG_ERR)
	else:
		# Normal message
		var line = "<%s> %s" % [pnames[id], msg]
		show_line(line)
		if network_state == HOSTING: rpc("show_line", line)

func _player_connected(id: int): pass # Welp unfortunately this is unused

func _player_disconnected(id: int):
	if id in players:
		debug("'%s' has left" % pnames[id], MSG_PLAYER)
		players.erase(id)
		pnames.erase(id)
		update_p_list()
		if scene and scene.has_method("_player_leave"): scene._player_leave(id)

remote func _player_info(player_name: String, code=null, player_packs=null):
	# Get id
	var id = get_tree().get_rpc_sender_id()
	# Check if this is a new connection or just a name update
	if player_packs != null:
		# Check if join code is valid
		if code != Network.join_code:
			rpc_id(id, "debug", "Join code is out of date!", MSG_ERR)
			Network.peer.disconnect_peer(id)
			return
		# Check if connection has valid packs
		var errs = packs_match(player_packs)
		if errs:
			# On failure, disconnect
			rpc_id(id, "debug", "Mismatch of packs with server!" + errs, MSG_ERR)
			Network.peer.disconnect_peer(id)
			return
		# On success
		# Forward message to other players
		for p in players: if p != 1: rpc_id(p, "_client_info", id, player_name)
		
		# Append player to list
		players.append(id)
		pnames[id] = player_name
		
		# Initiate player
		rpc_id(id, "_initiate", players, pnames, id)
		if loaded_cart: rpc("start_cart", loaded_cart)
		# Other stuff
		debug("'%s' has joined" % player_name, MSG_PLAYER)
		update_p_list()
		if scene and scene.has_method("_player_join"): scene._player_join(id)
			
	else:
		# Just a name update, forward to clients
		for p in players: if p != 1: rpc_id(p, "_client_info", id, player_name)
		# Update name
		debug("'%s' has changed their name to '%s'" % [pnames[id], player_name], MSG_PLAYER)
		pnames[id] = player_name
		update_p_list()
		if scene.has_method("_update_name"): scene._update_name(id)

remote func _client_info(id: int, player_name: String):
	if id in pnames: # Old connection
		debug("'%s' has changed their name to '%s'" % [pnames[id], player_name], MSG_PLAYER)
		pnames[id] = player_name
		update_p_list()
		if scene.has_method("_update_name"): scene._update_name(id)
	else: # New connection
		# Append player to list
		players.append(id)
		pnames[id] = player_name
		
		# Other stuff
		debug("'%s' has joined" % player_name, MSG_PLAYER)
		update_p_list()
		if scene and scene.has_method("_player_join"): scene._player_join(id)

remote func _initiate(players_, pnames_, sid_):
	players = players_
	pnames = pnames_
	sid = sid_
	update_p_list()
