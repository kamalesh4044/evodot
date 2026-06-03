extends Area3D

enum Type { HEALTH, AMMO }
@export var pickup_type: Type = Type.HEALTH
@export var amount: int = 50

func _ready():
	var mat = StandardMaterial3D.new()
	if pickup_type == Type.HEALTH:
		mat.albedo_color = Color.GREEN
	else:
		mat.albedo_color = Color.YELLOW
	$MeshInstance3D.material_override = mat

func _process(delta):
	rotation.y += 2.0 * delta
	position.y += sin(Time.get_ticks_msec() / 200.0) * 0.005

func _on_body_entered(body):
	if multiplayer.is_server():
		if body.is_in_group("players"):
			if pickup_type == Type.HEALTH and body.has_method("heal"):
				body.heal.rpc(amount)
				_destroy.rpc()
			elif pickup_type == Type.AMMO and body.has_method("add_ammo"):
				body.add_ammo.rpc(amount)
				_destroy.rpc()

@rpc("call_local", "authority")
func _destroy():
	queue_free()
