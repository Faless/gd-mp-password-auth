extends Node
class_name PasswordAuth

const RND_SIZE = 128
const HMAC_SIZE = 32

@export var autostart := true

signal auth_failed(peer, reason)

var password := "password":
	set(value):
		_secret = value.to_utf8_buffer()
		password = value

var _secret := PackedByteArray()
var _crypto = Crypto.new()

var pending := {}
var started := false


func _ready():
	if autostart:
		start(password)


func _exit_tree():
	stop()


func stop():
	if multiplayer.peer_authenticating.is_connected(_authenticating):
		multiplayer.peer_authenticating.disconnect(_authenticating)
	if multiplayer.peer_authentication_failed.is_connected(_auth_failed):
		multiplayer.peer_authentication_failed.disconnect(_auth_failed)
	if started:
		multiplayer.set_auth_callback(Callable())
	started = false


func start(password:=""):
	stop()
	if not password.is_empty():
		self.password = password
	multiplayer.peer_authenticating.connect(_authenticating)
	multiplayer.peer_authentication_failed.connect(_auth_failed)
	multiplayer.set_auth_callback(_authenticate_callback)
	started = true


func _authenticating(peer):
	if multiplayer.is_server():
		return
	assert(peer == 1)
	# The client initiate the connection by sending random data
	pending[peer] = _crypto.generate_random_bytes(RND_SIZE)
	multiplayer.send_auth(peer, pending[peer])


func _authenticate_callback(peer, data):
	if multiplayer.is_server():
		if not pending.has(peer):
			# If we don't know this peer yet, he should have sent exactly RND_SIZE bytes.
			if data.size() != RND_SIZE:
				_refuse(peer, "Expected %d bytes, received %d." % [RND_SIZE, data.size()])
				return
			# Generate and send random data.
			var bytes = _crypto.generate_random_bytes(RND_SIZE)
			multiplayer.send_auth(peer, bytes)
			# Keep track of the received and generated data so it can check the HMAC later.
			pending[peer] = data + bytes
		else:
			if data.size() != HMAC_SIZE:
				_refuse(peer, "Expected %d bytes, received %d." % [HMAC_SIZE, data.size()])
			# If we know the peer, he should have sent the HMAC of the data.
			var hash = _crypto.hmac_digest(HashingContext.HASH_SHA256, _secret, pending[peer])
			pending.erase(peer)
			if _crypto.constant_time_compare(hash, data):
				multiplayer.complete_auth.call_deferred(peer)
				pending.erase(peer)
			else:
				_refuse(peer, "Password verification failed.")
	else:
		assert(peer == 1)

		# As a client, we should already know this peer (server).
		if not pending.has(peer):
			_refuse(peer, "Received unexpected message.")
			return

		# The server should have sent exactly RND_SIZE bytes.
		if data.size() != RND_SIZE:
			_refuse(peer, "Expected %d bytes, received %d." % [RND_SIZE, data.size()])
			return

		# Reply with HMAC of the data we sent plus the data we received.
		var full = pending[peer] + data
		multiplayer.send_auth(peer, _crypto.hmac_digest(HashingContext.HASH_SHA256, _secret, full))
		multiplayer.complete_auth(peer)
		pending.erase(peer)


func _refuse(peer, p_msg:=""):
	multiplayer.disconnect_peer(peer)
	pending.erase(peer)
	_auth_failed(peer)
	auth_failed.emit(peer, p_msg)


func _auth_failed(peer):
	auth_failed.emit(peer, "")
