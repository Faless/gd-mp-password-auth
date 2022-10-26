extends Control

enum PeerType {ENET = 0, WS = 1, RTC = 2}
@export_enum("ENet,WebSocket,WebRTC") var peer_type := 0

var peer = null

@onready var auth = $PasswordAuth
@onready var line_edit = $VBoxContainer/HBoxContainer/LineEdit

func _ready():
	line_edit.text = auth.password
	var args = OS.get_cmdline_user_args()
	for i in range(0, args.size()):
		var a = args[i]
		if a == "s":
			start_server()
			return
		if a == "c":
			start_client()
			return

	# Connect signals
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)


func _auth_failed(id):
	_log("Peer %d failed to authenticate." % [id])


func _connected(id):
	_log("Peer %d connected." % [id])


func _disconnected(id):
	_log("Peer %d disconnected." % [id])


func _log(p_msg):
	var msg = p_msg
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		msg = "[%d] %s" % [multiplayer.get_unique_id(), msg]
	print(msg)


func _err(p_msg):
	var msg = p_msg
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		msg = "[%d] %s" % [multiplayer.get_unique_id(), msg]
	push_error(msg)


func start_server():
	if peer_type == PeerType.ENET:
		peer = ENetMultiplayerPeer.new()
		peer.create_server(4433)
	elif peer_type == PeerType.WS:
		peer = WebSocketMultiplayerPeer.new()
		peer.create_server(8080)
	else:
		_err("Peer Type not supported: %d" % peer_type)
	multiplayer.multiplayer_peer = peer
	_log("Created server %d" % peer_type)


func start_client():
	if peer_type == PeerType.ENET:
		peer = ENetMultiplayerPeer.new()
		peer.create_client("127.0.0.1", 4433)
	elif peer_type == PeerType.WS:
		peer = WebSocketMultiplayerPeer.new()
		peer.create_client("ws://localhost:8080")
	else:
		_err("Peer Type not supported: %d" % peer_type)
		return
	multiplayer.multiplayer_peer = peer
	_log("Created client %d" % peer_type)


func _on_line_edit_text_changed(new_text):
	auth.password = new_text


func _on_password_auth_auth_failed(peer: int, reason: String):
	var msg = "Auth failed for %d." % peer
	var r = "Unknown" if reason.is_empty() else reason
	msg += " Reason: %s" % r
	_log(msg)
	push_error("[%d] %s" % [multiplayer.get_unique_id(), msg])
