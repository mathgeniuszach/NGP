extends Node

# IP encoding
const r_size = 16384 # 2^14
var gr: int = ("0x"+OS.get_unique_id().substr(1, 5)).hex_to_int() % r_size
const key_size = 281474976710656 # 2^48

var keyA = 29123874469483
var keyB = 130403584488383

# Base64 regex matcher
var base64regex = RegEx.new()

# Threading
var thread = Thread.new()
var semaphore = Semaphore.new()
var action: int = -1
var args = null
# Networking
var upnp = UPNP.new()
var peer: NetworkedMultiplayerENet # PacketPeerUDP or UDPServer.
var is_server: bool = false

# Code of connected server
var join_code: String = ""
# Name of server connected to
var join_name: String = ""

var server_port: int

# NOTE: storing ip methods here probably isn't the best idea,
# but a pck file script has other ways of accessing it anyway

# HTTPRequest doesn't block, so we gotta go rambo
func get_public_ip():
	var http = HTTPClient.new()
	
	# Public ip service
	if http.connect_to_host("http://api64.ipify.org", 80) != OK: return
	
	# Wait until resolved and connected.
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(100)
	if http.get_status() != HTTPClient.STATUS_CONNECTED: return
	
	# Some headers (not sure if this is necessary)
	var headers = ["User-Agent: Pirulo/1.0 (Godot)", "Accept: */*"]
	if http.request(HTTPClient.METHOD_GET, "/", headers) != OK: return
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		http.poll()
		OS.delay_msec(100)
	
	if http.get_status() != HTTPClient.STATUS_BODY and http.get_status() != HTTPClient.STATUS_CONNECTED: return
	
	var rb = PoolByteArray() # Array that will hold the data.
	while http.get_status() == HTTPClient.STATUS_BODY:
		# While there is body left to be read
		http.poll()
		var chunk = http.read_response_body_chunk() # Get a chunk.
		if chunk.size() == 0:
			OS.delay_usec(100)
		else:
			rb = rb + chunk # Append to read buffer.
	
	return rb.get_string_from_utf8()

func _encode_ip(ip: String, port: int):
	# Probably shouldn't be a function, but I don't really have a choice here
	# First, split ip into string parts
	var sdata = ip.split(".")
	
	# Then, turn the parts into a single integer and sum to get iv
	var data: int = 0
	var iv: int = 0
	for i in range(4):
		if !sdata[i].is_valid_integer(): return
		var v = int(sdata[i])
		if v < 0 or 255 < v: return
		
		data += v << 8*i
		iv += v
	data = (data << 16) + port
	iv = (iv + port) % 256
	
	# Then encrypt the data (keys are not members to keep them safer)
	# XOR encryption isn't the best encryption, but it works well enough
	data ^= (keyA*gr+gr)%key_size
	data ^= (keyB*iv-iv)%key_size
	data = data * r_size + gr
	
	# Turn int into byte array
	var array = PoolByteArray()
	while data != 0:
		array.append(data%256)
		data >>= 8
	array.append(iv)
	
	return Marshalls.raw_to_base64(array)

func _decode_ip(data: String):
	# Decode code into IP. Once again, probably shouldn't be it's own function.
	var array = Marshalls.base64_to_raw(data)
	# Get iv
	var iv: int = array[8]
	array.remove(8)
	
	# Turn array into int
	var mdata: int = 0
	for i in range(8):
		mdata += array[i] << 8*i
	
	# Get r (system id)
	var r: int = mdata%r_size
	mdata /= r_size
	
	# Decrypt data
	mdata ^= (130403584488383*iv-iv)%key_size
	mdata ^= (29123874469483*r+r)%key_size
	
	# Get port
	var port: int = mdata % 65536
	mdata >>= 16
	# Get ip
	var pool_ip = PoolStringArray()
	for _i in range(4):
		pool_ip.append(str(mdata%256))
		mdata >>= 8
	
	return [pool_ip.join("."), port]

func _ready():
	# Setup base64regex
	base64regex.compile("^[a-zA-Z0-9+\/]{12}$")
	# Setup separate thread (for handling network events)
	thread.start(self, "_thread")
	# Networking
	get_tree().connect("connected_to_server", self, "_connected_ok", [], CONNECT_DEFERRED)
	get_tree().connect("connection_failed", self, "_connected_fail", [], CONNECT_DEFERRED)
	get_tree().connect("server_disconnected", self, "_server_disconnected", [], CONNECT_DEFERRED)

func _connected_ok():
	G.info = "Connected to '%s'" % join_name
	G.debug(G.info)
	G.network_state = G.CONNECTED
	# Send player name
	G.rpc_id(1, "_player_info", G.config.get_value("NGP", "username", "player"), join_code, G.packs)

func _server_disconnected():
	cleanup()
	G.info = "Not Connected"
	G.debug("Server closed connection")
	G.network_state = G.DISCONNECTED

func _connected_fail():
	cleanup()
	G.info = "Not Connected"
	G.debug("Server connection failed", G.MSG_ERR) # TODO: figure out how to get reason
	G.network_state = G.DISCONNECTED

# This basically just waits for someone to do something network wise and steps in.
# It makes hosting and joining more bearable.
func _thread(userdata):
	while G.running:
		semaphore.wait()
		
		G.network_state = action
		match action:
			G.DISCONNECTING:
				if is_server: G.info = "Closing server"
				else: G.info = "Disconnecting from server"
				G.debug(G.info)
				
				leave()
				
				G.info = "Not Connected"
				G.network_state = G.DISCONNECTED
			G.CONNECTING:
				G.info = "Connecting to server '%s'" % args[1]
				G.debug(G.info)
				
				var err = join(args[0], args[1])
				if err:
					G.info = "Not Connected"
					G.debug("Failed to connect. " + err, G.MSG_ERR)
					G.network_state = G.DISCONNECTED
			G.BINDING:
				G.info = "Binding server to port %d" % args
				G.debug(G.info)
				var err = host(args)
				if err:
					G.info = "Not Connected"
					G.debug("Failed to host. " + err, G.MSG_ERR)
					G.network_state = G.DISCONNECTED
				else:
					G.info = "Hosting server"
					G.debug(G.info)
					G.network_state = G.HOSTING
		
		action = -1
	
	leave()

# Convenience function
func act(action_: int, args_):
	if action == -1: # Prevents race condition
		action = action_
		args = args_
		semaphore.post()

func host(port: int):
	# Only open if server is not already open
	if peer:
		if is_server: return "Server already exists!"
		else: return "Cannot host when connected to server"
	
	# Start by opening a UPnP port (necessary for peer-to-peer connections)
	var code = upnp.discover()
	if code != UPNP.UPNP_RESULT_SUCCESS: return "Could not find UPnP router. " + G.upnp_err_string(code)
	code = upnp.add_port_mapping(port)
	if code != UPNP.UPNP_RESULT_SUCCESS: return "Could not open UPnP port. " + G.upnp_err_string(code)
	server_port = port
	
	# Get IP to create join code. Join codes are "like" encrypted ips. They also increase the time it takes to host...
	var ip = get_public_ip()
	if ip: join_code = _encode_ip(ip, server_port)
	else: return "Could not create join code"
	
	# Finally, create and bind server.
	peer = NetworkedMultiplayerENet.new()
	code = peer.create_server(server_port, 100)
	if code != OK: return "Could not create server. " + G.err_string(code)
	
	is_server = true
	get_tree().network_peer = peer

func join(data, name):
	# Check validity of data
	if !base64regex.search(data): return "Invalid code"
	
	# Leave if connected (leave still works if not connected)
	leave()
	
	# Get data
	var ip_port = _decode_ip(data)
	# Make client
	peer = NetworkedMultiplayerENet.new()
	var code = peer.create_client(ip_port[0], ip_port[1])
	if code != OK: return "Could not resolve address. " + G.err_string(code)
	get_tree().network_peer = peer
	
	# Update data
	is_server = false
	join_code = data
	join_name = name

func leave():
	# Close server
	if peer:
		if is_server: G.rpc("debug", "Server is shutting down")
		# Close connection
		peer.close_connection()
	cleanup()

func cleanup():
	# Cleanup peer refs
	get_tree().network_peer = null
	peer = null
	# Cleanup cart if running
	G.stop_cart()
	# Cleanup global stuff
	G.sid = 1
	G.players = [1]
	G.pnames = {1: G.config.get_value("NGP", "username", "player")}
	G.update_p_list()
	# Cleanup join code and server name
	join_code = ""
	join_name = ""
